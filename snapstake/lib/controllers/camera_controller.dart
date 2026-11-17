import 'package:camera/camera.dart';
import 'package:get/get.dart';

class AppCameraController extends GetxController {
  CameraController? cameraController;

  final RxBool isRecording = false.obs;
  final RxBool isInitialized = false.obs;
  final RxBool isCameraAvailable = false.obs;

  List<CameraDescription> _cameras = <CameraDescription>[];
  int _selectedCameraIndex = 0;
  final RxBool isSwitchingCamera = false.obs;

  // NEW: zoom bounds + current zoom
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  /// Check if camera is available on the device
  Future<void> checkCameraAvailability() async {
    try {
      _cameras = await availableCameras();
      isCameraAvailable.value = _cameras.isNotEmpty;

      if (_cameras.isEmpty) {
        print('⚠️ No cameras available on this device');
      } else {
        print('✅ Found ${_cameras.length} camera(s)');
      }
    } catch (e) {
      print('❌ Error checking camera availability: $e');
      isCameraAvailable.value = false;
      _cameras = <CameraDescription>[];
    }
  }

  /// Initialize the camera
  Future<void> initializeCamera() async {
    if (!isCameraAvailable.value) {
      print('⚠️ Camera not available, skipping initialization');
      return;
    }

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
        isCameraAvailable.value = _cameras.isNotEmpty;
      }
      if (_cameras.isEmpty) {
        print('⚠️ No cameras found');
        isCameraAvailable.value = false;
        return;
      }

      // clamp index
      if (_selectedCameraIndex < 0 || _selectedCameraIndex >= _cameras.length) {
        _selectedCameraIndex = 0;
      }

      final camera = _cameras[_selectedCameraIndex];
      print('📸 Initializing camera: ${camera.name} (${camera.lensDirection})');

      isInitialized.value = false;

      // Dispose previous controller
      await cameraController?.dispose();

      cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await cameraController!.initialize();

      // NEW: load zoom capabilities
      _minZoom = await cameraController!.getMinZoomLevel();
      _maxZoom = await cameraController!.getMaxZoomLevel();
      _currentZoom = 1.0;
      await cameraController!.setZoomLevel(_currentZoom);

      isInitialized.value = true;

      print('✅ Camera initialized successfully (zoom $_minZoom - $_maxZoom)');
    } catch (e) {
      print('❌ Error initializing camera: $e');
      isInitialized.value = false;
      isCameraAvailable.value = false;
    }
  }

  /// Start recording video
  Future<void> startRecording() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      print('❌ Camera not initialized');
      return;
    }

    if (isRecording.value) {
      print('⚠️ Already recording');
      return;
    }

    try {
      await cameraController!.startVideoRecording();
      isRecording.value = true;
      print('🎥 Started recording');
    } catch (e) {
      print('❌ Error starting recording: $e');
    }
  }

  /// Stop recording video
  Future<XFile?> stopRecording() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      print('❌ Camera not initialized');
      return null;
    }

    if (!isRecording.value) {
      print('⚠️ Not currently recording');
      return null;
    }

    try {
      final video = await cameraController!.stopVideoRecording();
      isRecording.value = false;
      print('✅ Stopped recording: ${video.path}');
      return video;
    } catch (e) {
      print('❌ Error stopping recording: $e');
      isRecording.value = false;
      return null;
    }
  }

  /// Switch between front/back (or cycle if more)
  Future<void> toggleCamera() async {
    if (_cameras.length < 2) {
      print('⚠️ Only one camera available, cannot toggle');
      return;
    }
    if (isRecording.value) {
      print('⚠️ Cannot switch camera while recording');
      return;
    }

    try {
      isSwitchingCamera.value = true;

      // Prefer toggling between front/back when available, otherwise just cycle.
      final current = _cameras[_selectedCameraIndex];

      int nextIndex = (_selectedCameraIndex + 1) % _cameras.length;

      // If there are both front & back, pick opposite lens direction.
      final hasFront = _cameras.any((c) => c.lensDirection == CameraLensDirection.front);
      final hasBack = _cameras.any((c) => c.lensDirection == CameraLensDirection.back);

      if (hasFront && hasBack) {
        final targetDirection = current.lensDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;
        final idx = _cameras.indexWhere((c) => c.lensDirection == targetDirection);
        if (idx != -1) nextIndex = idx;
      }

      _selectedCameraIndex = nextIndex;
      await initializeCamera();
    } finally {
      isSwitchingCamera.value = false;
    }
  }

  /// NEW
  Future<double> getZoomLevel() async {
    return _currentZoom;
  }

  /// NEW
  Future<void> setZoomLevel(double zoom) async {
    if (cameraController == null || !cameraController!.value.isInitialized) return;

    final clamped = zoom.clamp(_minZoom, _maxZoom).toDouble();
    _currentZoom = clamped;

    try {
      await cameraController!.setZoomLevel(_currentZoom);
    } catch (e) {
      // Some devices/emulators may not support zoom; ignore safely
      print('⚠️ setZoomLevel failed: $e');
    }
  }

  /// Dispose camera resources
  void disposeCamera() {
    cameraController?.dispose();
    cameraController = null;
    isInitialized.value = false;
    isRecording.value = false;
    print('🗑️ Camera disposed');
  }

  @override
  void onClose() {
    disposeCamera();
    super.onClose();
  }
}
