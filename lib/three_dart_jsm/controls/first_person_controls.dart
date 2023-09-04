part of jsm_controls;

class FirstPersonControls with EventDispatcher {
  FirstPersonControls(this.object,this.listenableKey):super(){
    this.domElement.addEventListener( 'contextmenu', contextmenu, false );
    this.domElement.addEventListener( 'mousemove', onMouseMove, false );
    this.domElement.addEventListener( 'pointerdown', onMouseDown, false );
    this.domElement.addEventListener( 'pointeruo', onMouseUp, false );
    //this.domElement.setAttribute( 'tabindex', - 1 );

    this.domElement.addEventListener( 'keydown', onKeyDown, false );
    this.domElement.addEventListener( 'keyup', onKeyUp, false );

    handleResize();
	  setOrientation(this);
  }

  late GlobalKey<DomLikeListenableState> listenableKey;
  DomLikeListenableState get domElement => listenableKey.currentState!;

	Camera object;

	// API

	bool enabled = true;

	double movementSpeed = 1.0;
  Vector3 cameraVelocity = Vector3();
	double lookSpeed = 0.5;

	bool lookVertical = true;
	bool autoForward = false;

	bool activeLook = true;

	bool heightSpeed = false;
	double heightCoef = 1.0;
	double heightMin = 0.0;
	double heightMax = 1.0;

	bool constrainVertical = false;
	double verticalMin = 0;
	double verticalMax = Math.PI;

	bool mouseDragOn = false;

	// internals

	double autoSpeedFactor = 0.0;

	double mouseX = 0;
	double mouseY = 0;

	bool moveForward = false;
	bool moveBackward = false;
	bool moveLeft = false;
	bool moveRight = false;

  bool moveUp = false;
	bool moveDown = false;

	double viewHalfX = 0;
	double viewHalfY = 0;

	// private variables

	num lat = 0;
	num lon = 0;

	Vector3 lookDirection = Vector3();
	Spherical spherical = Spherical();
	Vector3 target = Vector3();
  Vector3 targetPosition = Vector3();

	void handleResize(){
		this.viewHalfX = this.domElement.clientWidth / 2;
		this.viewHalfY = this.domElement.clientHeight / 2;
	}

	void onMouseDown( event ) {
		//this.domElement.focus();

		event.preventDefault();
		//event.stopPropagation();

		if ( this.activeLook ) {

			switch ( event.button ) {

				case 0: this.moveForward = true; break;
				case 2: this.moveBackward = true; break;

			}

		}

		this.mouseDragOn = true;
	}

	void onMouseUp( event ) {
		event.preventDefault();
		event.stopPropagation();

		if ( this.activeLook ) {
			switch ( event.button ) {
				case 0: this.moveForward = false; break;
				case 2: this.moveBackward = false; break;
			}
		}

		this.mouseDragOn = false;
	}

	void onMouseMove(event) {
		this.mouseX = event.pageX - this.domElement.offsetLeft - this.viewHalfX;
		this.mouseY = event.pageY - this.domElement.offsetTop - this.viewHalfY;
	}

	void onKeyDown( event) {
		switch ( event.keyId ) {

			case 119: /*up*/
			case 119: /*W*/ this.moveForward = true; break;

			case 37: /*left*/
			case 97: /*A*/ this.moveLeft = true; break;

			case 40: /*down*/
			case 115: /*S*/ this.moveBackward = true; break;

			case 39: /*right*/
			case 100: /*D*/ this.moveRight = true; break;

			case 114: /*R*/ this.moveUp = true; break;
			case 102: /*F*/ this.moveDown = true; break;

		}

	}

	void onKeyUp( event ) {
		switch ( event.keyId ) {
			case 38: /*up*/
			case 119: /*W*/ this.moveForward = false; break;

			case 37: /*left*/
			case 97: /*A*/ this.moveLeft = false; break;

			case 40: /*down*/
			case 115: /*S*/ this.moveBackward = false; break;

			case 39: /*right*/
			case 100: /*D*/ this.moveRight = false; break;

			case 114: /*R*/ this.moveUp = false; break;
			case 102: /*F*/ this.moveDown = false; break;

		}

	}

	FirstPersonControls lookAt ( x, y, z ) {

		if ( x.isVector3 ) {

			target.copy( x );

		} else {

			target.set( x, y, z );

		}

		this.object.lookAt( target );

		setOrientation( this );

		return this;

	}

	void update(double delta) {
    if ( this.enabled == false ) return;

    if ( this.heightSpeed ) {
      double y = MathUtils.clamp<double>( this.object.position.y, this.heightMin, this.heightMax );
      var heightDelta = y - this.heightMin;

      this.autoSpeedFactor = delta * ( heightDelta * this.heightCoef );

    }
    else {
      this.autoSpeedFactor = 0.0;
    }

    var actualMoveSpeed = delta * this.movementSpeed;

    if ( this.moveForward || ( this.autoForward && ! this.moveBackward ) ) this.object.translateZ( - ( actualMoveSpeed + this.autoSpeedFactor ) );
    if ( this.moveBackward ) this.object.translateZ( actualMoveSpeed );

    if ( this.moveLeft ) this.object.translateX( - actualMoveSpeed );
    if ( this.moveRight ) this.object.translateX( actualMoveSpeed );

    if ( this.moveUp ) this.object.translateY( actualMoveSpeed );
    if ( this.moveDown ) this.object.translateY( - actualMoveSpeed );

    double actualLookSpeed = delta * this.lookSpeed;

    if ( ! this.activeLook ) {

      actualLookSpeed = 0;

    }

    double verticalLookRatio = 1;

    if ( this.constrainVertical ) {

      verticalLookRatio = Math.PI / ( this.verticalMax - this.verticalMin );

    }

    lon -= this.mouseX * actualLookSpeed;
    if ( this.lookVertical ) lat -= this.mouseY * actualLookSpeed * verticalLookRatio;

    lat = Math.max( - 85, Math.min( 85, lat ) );

    num phi = MathUtils.degToRad( 90 - lat );
    num theta = MathUtils.degToRad( lon );

    if ( this.constrainVertical ) {

      phi = MathUtils.mapLinear( phi, 0, Math.PI, this.verticalMin, this.verticalMax );

    }

    var position = this.object.position;

    targetPosition.setFromSphericalCoords( 1, phi, theta ).add( position );

    this.object.lookAt( targetPosition );
	}

	void contextmenu( event ) {
		event.preventDefault();
	}

	void dispose() {
		this.domElement.removeEventListener( 'contextmenu', contextmenu, false );
		this.domElement.removeEventListener( 'mousedown', onMouseDown, false );
		this.domElement.removeEventListener( 'mousemove', onMouseMove, false );
		this.domElement.removeEventListener( 'mouseup', onMouseUp, false );

		this.domElement.removeEventListener( 'keydown', onKeyDown, false );
		this.domElement.removeEventListener( 'keyup', onKeyUp, false );

	}

	void setOrientation( controls ) {
		var quaternion = controls.object.quaternion;

		lookDirection.set( 0, 0, - 1 ).applyQuaternion( quaternion );
		spherical.setFromVector3( lookDirection );

		lat = 90 - MathUtils.radToDeg( spherical.phi );
		lon = MathUtils.radToDeg( spherical.theta );
	}

}
