import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../controllers/camera_controller.dart';
import '../controllers/moments_controller.dart';

class CameraRecordingPage extends StatefulWidget {
  const CameraRecordingPage({super.key});

  @override
  State<CameraRecordingPage> createState() => _CameraRecordingPageState();
}

class _CameraRecordingPageState extends State<CameraRecordingPage> {
  late AppCameraController cameraController;

  // NEW: pinch zoom state
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    cameraController = Get.put(AppCameraController());
    _initializeCamera();
  }

  bool get _isOutcomeRecording {
    final args = Get.arguments as Map<String, dynamic>?;
    return args?['isOutcomeRecording'] == true;
  }

  int? get _momentId {
    final args = Get.arguments as Map<String, dynamic>?;
    return args?['momentId']?.toInt();
  }

  String? get _outcome {
    final args = Get.arguments as Map<String, dynamic>?;
    return args?['outcome']?.toString();
  }

  Future<void> _initializeCamera() async {
    // First check camera availability
    await cameraController.checkCameraAvailability();
    // Then initialize the camera
    await cameraController.initializeCamera();
  }

  Future<void> _handleOutcomeRecording(XFile video) async {
    if (_momentId == null || _outcome == null) {
      Get.snackbar(
        'Error',
        'Missing moment information',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    try {
      final file = File(video.path);
      final momentsController = Get.find<MomentsController>();

      final success = await momentsController.revealMomentOutcome(
        momentId: _momentId!,
        outcomeVideo: file,
        actualOutcome: _outcome!,
      );

      if (success) {
        Get.back(result: true);
      } else {
        Get.snackbar(
          'Error',
          'Failed to reveal outcome. Please try again.',
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      print('❌ Error revealing outcome: $e');
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> _startRecording() async {
    print('▶️ Starting recording...');
    await cameraController.startRecording();
  }

  Future<void> _stopRecording() async {
    print('⏹️ Stopping recording...');
    final video = await cameraController.stopRecording();
    if (video == null) return;

    if (_isOutcomeRecording) {
      // NEW: confirmation step BEFORE uploading/revealing
      final shouldUpload = await Get.bottomSheet<bool>(
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Text(
                  'Use this video as outcome proof?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Outcome: ${_outcome ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(result: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Get.back(result: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Upload & Reveal'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        isDismissible: false,
        enableDrag: false,
      );

      if (shouldUpload == true) {
        await _handleOutcomeRecording(video);
      } else {
        // Retake: stay on camera screen, do nothing
        return;
      }
    } else {
      // Go to setup flow for moment creation
      Get.offNamed(
        '/moment-setup',
        arguments: {
          'videoFile': video, // pass XFile (MomentSetupPage expects XFile)
        },
      );
    }
  }

  @override
  void dispose() {
    cameraController.disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (!cameraController.isCameraAvailable.value) {
          return const Center(
            child: Text(
              'Camera not available',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (!cameraController.isInitialized.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            // Camera Preview + Pinch Zoom
            SizedBox.expand(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) async {
                  _baseZoom = await cameraController.getZoomLevel();
                },
                onScaleUpdate: (details) async {
                  // Only treat as zoom gesture when pinch (two fingers)
                  if (details.pointerCount < 2) return;

                  final nextZoom = (_baseZoom * details.scale);
                  await cameraController.setZoomLevel(nextZoom);
                },
                child: CameraPreview(cameraController.cameraController!),
              ),
            ),

            // Flip camera button (top-left)
            Positioned(
              top: 54,
              left: 16,
              child: Obx(() {
                final disabled =
                    cameraController.isSwitchingCamera.value ||
                    cameraController.isRecording.value;

                return IconButton(
                  onPressed:
                      disabled ? null : () => cameraController.toggleCamera(),
                  icon: Icon(
                    Icons.cameraswitch,
                    color: disabled ? Colors.white38 : Colors.white,
                    size: 30,
                  ),
                  tooltip: 'Switch camera',
                );
              }),
            ),

            // Recording Indicator
            if (cameraController.isRecording.value)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => Get.back(),
                  ),

                  // Record Button (tap to start/stop)
                  Obx(() {
                    final disabled =
                        cameraController.isSwitchingCamera.value ||
                        !cameraController.isInitialized.value;

                    return GestureDetector(
                      onTap:
                          disabled
                              ? null
                              : () async {
                                if (cameraController.isRecording.value) {
                                  print('⏹️ Tap -> stop recording');
                                  await _stopRecording();
                                } else {
                                  print('▶️ Tap -> start recording');
                                  await _startRecording();
                                }
                              },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color:
                              cameraController.isRecording.value
                                  ? Colors.red
                                  : Colors.transparent,
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Spacer for alignment
                  const SizedBox(width: 32),
                ],
              ),
            ),

            // Instructions
            Positioned(
              bottom: 140,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cameraController.isRecording.value
                        ? 'Tap to stop'
                        : 'Tap to start recording',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
