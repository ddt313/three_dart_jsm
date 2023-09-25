import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart/three_dart.dart' hide Texture, Color;
import 'package:three_dart_jsm/three_dart_jsm.dart';

class EffectController{
  EffectController({
    this.material = 'shiny',
    this.speed = 1.0,
    this.numBlobs = 10,
    this.resolution = 28,
    this.isolation = 80,

    this.floor = true,
    this.wallx = false,
    this.wallz = false,
    Function()? dummy
  }){
    this.dummy = dummy ?? (){};

  }

  String material;
  double speed;
  int numBlobs;
  int resolution;
  int isolation;
  bool floor;
  bool wallx;
  bool wallz;

  late Function? dummy;
}

class webgl_marching_cubes extends StatefulWidget {
  const webgl_marching_cubes({
    Key? key,
    required this.fileName
  }) : super(key: key);

  final String fileName;

  @override
  _webgl_marching_cubesState createState() => _webgl_marching_cubesState();
}

class _webgl_marching_cubesState extends State<webgl_marching_cubes> {
  FocusNode node = FocusNode();
  // gl values
  late FlutterGlPlugin three3dRender;
  WebGLRenderTarget? renderTarget;
  WebGLRenderer? renderer;
  int? fboId;
  late double width;
  late double height;
  Size? screenSize;
  late Scene scene;
  late Camera camera;
  double dpr = 1.0;
  bool verbose = false;
  bool disposed = false;
  final GlobalKey<DomLikeListenableState> _globalKey = GlobalKey<DomLikeListenableState>();
  dynamic sourceTexture;

  late OrbitControls controls;
  late EffectController effectController;
  String currentMaterial = 'plastic';
  late MarchingCubes effect;
  double time = 0;
  final clock = three.Clock();

  @override
  void initState() {
    super.initState();
  }
  @override
  void dispose() {
    disposed = true;
    three3dRender.dispose();
    super.dispose();
  }
  
  void initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mqd = MediaQuery.of(context);

    screenSize = mqd.size;
    dpr = mqd.devicePixelRatio;

    initPlatformState();
  }
  void animate() {
    if (!mounted || disposed) {
      return;
    }
    render();

		final delta = clock.getDelta();
		time += delta * effectController.speed * 0.5;

    updateCubes(effect, time, effectController.numBlobs, effectController.floor, effectController.wallx, effectController.wallz );

    Future.delayed(const Duration(milliseconds: 40), () {
      animate();
    });
  }
	// this controls content of marching cubes voxel field
  void updateCubes(MarchingCubes object, double time, int numblobs, bool floor, bool wallx, bool wallz ) {
    object.reset();

    // fill the field with some metaballs
    final rainbow = [
      three.Color( 0xff0000 ),
      three.Color( 0xffbb00 ),
      three.Color( 0xffff00 ),
      three.Color( 0x00ff00 ),
      three.Color( 0x0000ff ),
      three.Color( 0x9400bd ),
      three.Color( 0xc800eb )
    ];

    const subtract = 12;
    final strength = 1.2 / ( ( Math.sqrt( numblobs ) - 1 ) / 4 + 1 );

    for (int i = 0; i < numblobs; i ++ ) {

      final ballx = Math.sin( i + 1.26 * time * ( 1.03 + 0.5 * Math.cos( 0.21 * i ) ) ) * 0.27 + 0.5;
      final bally = Math.abs( Math.cos( i + 1.12 * time * Math.cos( 1.22 + 0.1424 * i ) ) ) * 0.77; // dip into the floor
      final ballz = Math.cos( i + 1.32 * time * 0.1 * Math.sin( ( 0.92 + 0.53 * i ) ) ) * 0.27 + 0.5;

      if(currentMaterial == 'multiColors' ) {
        object.addBall( ballx, bally, ballz, strength, subtract, rainbow[ i % 7 ] );
      } 
      else {
        object.addBall( ballx, bally, ballz, strength, subtract );
      }
    }

    if ( floor ) object.addPlaneY( 2, 12 );
    if ( wallz ) object.addPlaneZ( 2, 12 );
    if ( wallx ) object.addPlaneX( 2, 12 );

    object.update();

  }
  Future<void> initPage() async {
    scene = Scene();
    scene.background = three.Color( 0x050505 );

    camera = PerspectiveCamera(45, width / height, 1, 10000);
    camera.position.set( - 500, 500, 1500 );

    // lights
    three.DirectionalLight light = three.DirectionalLight( 0xffffff, 3 );
    light.position.set( 0.5, 0.5, 1 );
    scene.add(light);

    three.PointLight pointLight = three.PointLight( 0xff7c00, 3, 0, 0 );
    pointLight.position.set( 0, 0, 100 );
    scene.add( pointLight );

    three.AmbientLight ambientLight = three.AmbientLight( 0x323232, 3 );
    scene.add( ambientLight );

    // MATERIALS
    Map<String,three.Material> materials = generateMaterials();

    // MARCHING CUBES

    double resolution = 28;

    effect = MarchingCubes(resolution, materials[currentMaterial], true, true, 100000 );
    effect.position.set( 0, 0, 0 );
    effect.scale.set( 700, 700, 700 );

    effect.enableUvs = false;
    effect.enableColors = false;

    scene.add( effect );

    // CONTROLS
    controls = OrbitControls( camera, _globalKey);
    controls.minDistance = 500;
    controls.maxDistance = 5000;

    effectController = EffectController(
      material: 'plastic',
      speed: 1.0,
      numBlobs: 10,
      resolution: 28,
      isolation: 80,
      floor: true,
      wallx: false,
      wallz: false,
    );
  }

  Map<String,three.Material> generateMaterials() {
    final materials = {
				'shiny': three.MeshStandardMaterial( { 'color': 0x9c0000, 'roughness': 0.1, 'metalness': 1.0 } ),
				'chrome': three.MeshLambertMaterial( { 'color': 0xffffff} ),
				'liquid': three.MeshLambertMaterial( { 'color': 0xffffff, 'refractionRatio': 0.85 } ),
				'matte': three.MeshPhongMaterial( { 'specular': 0x494949, 'shininess': 1 } ),
				'flat': three.MeshLambertMaterial( {'flatShading': true} ),
				'textured': three.MeshPhongMaterial( { 'color': 0xffffff, 'specular': 0x111111, 'shininess': 1} ),
				'colors': three.MeshPhongMaterial( { 'color': 0xffffff, 'specular': 0xffffff, 'shininess': 2, 'vertexColors': true } ),
				'multiColors': three.MeshPhongMaterial( { 'shininess': 2, 'vertexColors': true } ),
				'plastic': three.MeshPhongMaterial( { 'color': three.Color(0xff414141),'specular': three.Color(0.5, 0.5, 0.5), 'shininess': 15 } ),
    };
    return materials;
  }

  void render() {
    final _gl = three3dRender.gl;
    renderer!.render(scene, camera);
    _gl.flush();
    if(!kIsWeb) {
      three3dRender.updateTexture(sourceTexture);
    }
  }
  void initRenderer() {
    Map<String, dynamic> _options = {
      "width": width,
      "height": height,
      "gl": three3dRender.gl,
      "antialias": true,
      "canvas": three3dRender.element,
    };

    if(!kIsWeb && Platform.isAndroid){
      _options['logarithmicDepthBuffer'] = true;
    }

    renderer = WebGLRenderer(_options);
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(width, height, false);
    renderer!.shadowMap.enabled = true;

    if(!kIsWeb){
      WebGLRenderTargetOptions pars = WebGLRenderTargetOptions({"format": RGBAFormat,"samples": 8});
      renderTarget = WebGLRenderTarget((width * dpr).toInt(), (height * dpr).toInt(), pars);
      renderTarget!.samples = 8;
      renderer!.setRenderTarget(renderTarget);
      sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget!);
    }
    else{
      renderTarget = null;
    }
  }
  void initScene() async{
    await initPage();
    initRenderer();
    animate();
  }
  Future<void> initPlatformState() async {
    width = screenSize!.width;
    height = screenSize!.height;

    three3dRender = FlutterGlPlugin();

    Map<String, dynamic> _options = {
      "antialias": true,
      "alpha": true,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr,
      'precision': 'highp'
    };
    await three3dRender.initialize(options: _options);

    setState(() {});

    // TODO web wait dom ok!!!
    Future.delayed(const Duration(milliseconds: 100), () async {
      await three3dRender.prepareContext();
      initScene();
    });
  }

  Widget threeDart() {
    return Builder(builder: (BuildContext context) {
      initSize(context);
      return Container(
        width: screenSize!.width,
        height: screenSize!.height,
        color: Theme.of(context).canvasColor,
        child: DomLikeListenable(
          key: _globalKey,
          builder: (BuildContext context) {
            FocusScope.of(context).requestFocus(node);
            return Container(
              width: width,
              height: height,
              color: Theme.of(context).canvasColor,
              child: Builder(builder: (BuildContext context) {
                if (kIsWeb) {
                  return three3dRender.isInitialized
                      ? HtmlElementView(
                          viewType:
                              three3dRender.textureId!.toString())
                      : Container();
                } else {
                  return three3dRender.isInitialized
                      ? Texture(textureId: three3dRender.textureId!)
                      : Container();
                }
              })
            );
          }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: Stack(
        children: [
          threeDart(),
        ],
      )
    );
  }
}