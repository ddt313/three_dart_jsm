// part of jsm_postprocessing;

// class OutputPass extends Pass {
//   late Map<String, dynamic> uniforms;
//   late ShaderMaterial shaderMaterial;
//   late FullScreenQuad fsQuad;
//   late String? _outputColorSpace;
//   late String? _toneMapping;

//   OutputPass() : super() {
//     final Map<String, dynamic> shader = OutputShader;

//     this.uniforms = UniformsUtils.clone(shader["uniforms"]!);

//     this.shaderMaterial = new RawShaderMaterial(
//         {"name": shader["name"],
//         "uniforms": this.uniforms,
//         "vertexShader": shader["vertexShader"],
//         "fragmentShader": shader["fragmentShader"],});

//     this.fsQuad = new FullScreenQuad(this.shaderMaterial);
//     this._outputColorSpace = null;
// 		this._toneMapping = null;
//   }

// 	render( renderer, writeBuffer, readBuffer, {num? deltaTime, bool? maskActive} ) {
// 		this.uniforms[ 'tDiffuse' ].value = readBuffer.texture;
// 		this.uniforms[ 'toneMappingExposure' ].value = renderer.toneMappingExposure;

// 		// rebuild defines if required

// 		if ( this._outputColorSpace != renderer.outputColorSpace || this._toneMapping != renderer.toneMapping ) {

// 			this._outputColorSpace = renderer.outputColorSpace;
// 			this._toneMapping = renderer.toneMapping;

// 			this.shaderMaterial.defines = {};

// 			if ( ColorManagement.getTransfer( this._outputColorSpace ) == 'srgb' ) this.shaderMaterial.defines.SRGB_TRANSFER = '';

// 			if ( this._toneMapping == LinearToneMapping ) this.shaderMaterial.defines.LINEAR_TONE_MAPPING = '';
// 			else if ( this._toneMapping == ReinhardToneMapping ) this.shaderMaterial.defines.REINHARD_TONE_MAPPING = '';
// 			else if ( this._toneMapping == CineonToneMapping ) this.shaderMaterial.defines.CINEON_TONE_MAPPING = '';
// 			else if ( this._toneMapping == ACESFilmicToneMapping ) this.shaderMaterial.defines.ACES_FILMIC_TONE_MAPPING = '';
// 			// else if ( this._toneMapping == AgXToneMapping ) this.shaderMaterial.defines.AGX_TONE_MAPPING = '';
// 			// else if ( this._toneMapping == NeutralToneMapping ) this.shaderMaterial.defines.NEUTRAL_TONE_MAPPING = '';
// 			else if ( this._toneMapping == CustomToneMapping ) this.shaderMaterial.defines.CUSTOM_TONE_MAPPING = '';

// 			this.shaderMaterial.needsUpdate = true;

// 		}

// 		//

// 		if ( this.renderToScreen == true ) {

// 			renderer.setRenderTarget( null );
// 			this.fsQuad.render( renderer );

// 		} else {

// 			renderer.setRenderTarget( writeBuffer );
// 			if ( this.clear ) renderer.clear( renderer.autoClearColor, renderer.autoClearDepth, renderer.autoClearStencil );
// 			this.fsQuad.render( renderer );

// 		}

// 	}

// 	dispose() {

// 		this.shaderMaterial.dispose();
// 		this.fsQuad.dispose();

// 	}

// }

// import 'package:three_js_core/three_js_core.dart';
// import 'package:three_js_math/three_js_math.dart';
// import 'package:three_js_postprocessing/post/index.dart';
// import 'package:three_js_postprocessing/shaders/outpass_shader.dart';
// import 'pass.dart';

import 'package:three_dart/three_dart.dart';
import 'package:three_dart_jsm/three_dart_jsm/postprocessing/index.dart';

import '../shaders/OutputShader.dart';

final LINEAR_SRGB_TO_LINEAR_DISPLAY_P3 = Matrix3().identity().set(
      0.8224621,
      0.177538,
      0.0,
      0.0331941,
      0.9668058,
      0.0,
      0.0170827,
      0.0723974,
      0.9105199,
    );

final LINEAR_DISPLAY_P3_TO_LINEAR_SRGB = /*@__PURE__*/
    Matrix3().identity().set(1.2249401, -0.2249404, 0.0, -0.0420569, 1.0420571, 0.0, -0.0196376, -0.0786361, 1.0982735);

final Map<String, dynamic> COLOR_SPACES = {
  'LinearSRGBColorSpace': {
    'transfer': 'linear',
    'primaries': 'rec709',
    'toReference': (color) => color,
    'fromReference': (color) => color,
  },
  'SRGBColorSpace': {
    'transfer': 'srgb',
    'primaries': 'rec709',
    'toReference': (Color color) => color.convertSRGBToLinear(),
    'fromReference': (Color color) => color.convertLinearToSRGB(),
  },
  'LinearDisplayP3ColorSpace': {
    'transfer': 'linear',
    'primaries': 'p3',
    'toReference': (Color color) => color.applyMatrix3(LINEAR_DISPLAY_P3_TO_LINEAR_SRGB),
    'fromReference': (Color color) => color.applyMatrix3(LINEAR_SRGB_TO_LINEAR_DISPLAY_P3),
  },
  'DisplayP3ColorSpace': {
    'transfer': 'srgb',
    'primaries': 'p3',
    'toReference': (Color color) => color.convertSRGBToLinear().applyMatrix3(LINEAR_DISPLAY_P3_TO_LINEAR_SRGB),
    'fromReference': (Color color) => color.applyMatrix3(LINEAR_SRGB_TO_LINEAR_DISPLAY_P3).convertLinearToSRGB(),
  },
};

class OutputPass extends Pass {
  dynamic _toneMapping;
  dynamic _outputColorSpace;
  OutputPass() : super() {
    final Map<String, dynamic> shader = outputShader;

    uniforms = UniformsUtils.clone(shader['uniforms']);

    material = RawShaderMaterial({
      'name': shader['name'],
      'uniforms': uniforms,
      'vertexShader': shader['vertexShader'],
      'fragmentShader': shader['fragmentShader']
    });

    fsQuad = FullScreenQuad(material);
  }

  String? getTransfer(colorSpace) {
    if (colorSpace == NoColorSpace) return 'linear';
    return COLOR_SPACES[colorSpace]?['transfer'];
  }

  @override
  void render(renderer, writeBuffer, readBuffer, {num? deltaTime, bool? maskActive}) {
    uniforms['tDiffuse']['value'] = readBuffer.texture;
    uniforms['toneMappingExposure']['value'] = renderer.toneMappingExposure;

    // rebuild defines if required

    if (_toneMapping != renderer.toneMapping) {
      //_outputColorSpace != renderer.outputColorSpace ||

      _outputColorSpace = 'srgb'; //renderer.outputColorSpace;
      _toneMapping = renderer.toneMapping;

      material.defines = {};

      if (getTransfer(_outputColorSpace) == 'srgb') {
        material.defines!['SRGB_TRANSFER'] = '';
      }

      if (_toneMapping == LinearToneMapping) {
        material.defines!['LINEAR_TONE_MAPPING'] = '';
      } else if (_toneMapping == ReinhardToneMapping) {
        material.defines!['REINHARD_TONE_MAPPING'] = '';
      } else if (_toneMapping == CineonToneMapping) {
        material.defines!['CINEON_TONE_MAPPING'] = '';
      } else if (_toneMapping == ACESFilmicToneMapping) {
        material.defines!['ACES_FILMIC_TONE_MAPPING'] = '';
      } else if (_toneMapping == 6) {
        material.defines!['AGX_TONE_MAPPING'] = '';
      } else if (_toneMapping == 7) {
        material.defines!['NEUTRAL_TONE_MAPPING'] = '';
      }

      material.needsUpdate = true;
    }

    //

    if (renderToScreen == true) {
      renderer.setRenderTarget(null);
      fsQuad.render(renderer);
    } else {
      renderer.setRenderTarget(writeBuffer);
      if (clear) renderer.clear(renderer.autoClearColor, renderer.autoClearDepth, renderer.autoClearStencil);
      fsQuad.render(renderer);
    }
  }

  void dispose() {
    material.dispose();
    fsQuad.dispose();
  }
}
