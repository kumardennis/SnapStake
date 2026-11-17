import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../controllers/auth_controller.dart';
import '../repositories/moments_repo.dart';

class MomentSetupPage extends StatefulWidget {
  final XFile videoFile;

  const MomentSetupPage({super.key, required this.videoFile});

  @override
  State<MomentSetupPage> createState() => _MomentSetupPageState();
}

class _MomentSetupPageState extends State<MomentSetupPage> {
  final TextEditingController _descriptionController = TextEditingController();
  final RxList<String> _outcomes = <String>["Yes", "No"].obs;
  final RxDouble _timerMinutes = 15.0.obs;
  final RxBool _useCustomDeadline = false.obs;
  final Rxn<DateTime> _customDeadline = Rxn<DateTime>();
  final RxString _description = ''.obs;

  VideoPlayerController? _videoController;
  final RxBool _isVideoInitialized = false.obs;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      _description.value = _descriptionController.text;
    });
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      print('Initializing video from: ${widget.videoFile.path}');

      // Check if video file exists first
      final fileExists = await _checkVideoFile();
      if (!fileExists) {
        print('Video file does not exist or is empty');
        return;
      }

      _videoController = VideoPlayerController.file(
        File(widget.videoFile.path),
      );
      await _videoController!.initialize();

      // Add listener for video state changes
      _videoController!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      _isVideoInitialized.value = true;
      print(
        'Video initialized successfully. Duration: ${_videoController!.value.duration}',
      );
      setState(() {});
    } catch (e) {
      print('Error initializing video: $e');
      _isVideoInitialized.value = false;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatDeadline(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }

  Future<void> _pickCustomDeadline() async {
    final now = DateTime.now();
    final initial = _customDeadline.value ?? now.add(const Duration(hours: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null) return;

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!selected.isAfter(now.add(const Duration(minutes: 5)))) {
      Get.snackbar(
        'Invalid deadline',
        'Please select a time at least 5 minutes from now.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    _customDeadline.value = selected;
  }

  DateTime _resolveOutcomeDeadline() {
    if (_useCustomDeadline.value && _customDeadline.value != null) {
      return _customDeadline.value!;
    }
    return DateTime.now().add(Duration(minutes: _timerMinutes.value.round()));
  }

  Future<bool> _checkVideoFile() async {
    try {
      final file = File(widget.videoFile.path);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      print('Video file exists: $exists, size: $size bytes');
      return exists && size > 0;
    } catch (e) {
      print('Error checking video file: $e');
      return false;
    }
  }

  Future<void> _goLive() async {
    if (_description.value.isEmpty) {
      Get.snackbar(
        'Error',
        'Please add a description for your moment',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    if (_outcomes.length < 2) {
      Get.snackbar(
        'Error',
        'Please add at least 2 possible outcomes',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    // Get current user from AuthController
    final authController = Get.find<AuthController>();
    final currentUser = authController.currentUser.value;

    if (currentUser == null) {
      Get.snackbar(
        'Error',
        'User not authenticated. Please sign in again.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    if (_useCustomDeadline.value && _customDeadline.value == null) {
      Get.snackbar(
        'Error',
        'Please pick a deadline date and time.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    final deadline = _resolveOutcomeDeadline();
    if (!deadline.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      Get.snackbar(
        'Error',
        'Deadline must be at least 5 minutes from now.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        barrierDismissible: false,
      );

      final momentsRepo = MomentsRepository();

      final videoFile = File(widget.videoFile.path);
      final videoUrl = await momentsRepo.uploadVideo(
        videoFile: videoFile,
        userId: currentUser.id,
      );

      if (videoUrl == null) {
        Get.back();
        Get.snackbar(
          'Error',
          'Failed to upload video. Please try again.',
          snackPosition: SnackPosition.TOP,
        );
        return;
      }

      print('✅ Video uploaded: $videoUrl');

      final moment = await momentsRepo.createMoment(
        creatorId: authController.userProfile.value?['id'],
        description: _description.value.trim(),
        outcomeTimestamp: deadline.toUtc().toIso8601String(),
        videoUrl: videoUrl,
      );

      Get.back(); // Close loading dialog

      if (moment != null) {
        print('✅ Moment created successfully: ${moment['id']}');

        await _saveMomentVideoToGallery(videoFile);

        Get.snackbar(
          'Success',
          'Your moment is now live! People can start betting.',
          snackPosition: SnackPosition.TOP,
        );

        // Navigate back to home
        Get.offAllNamed('/home');
      } else {
        Get.snackbar(
          'Error',
          'Failed to create moment. Please try again.',
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      Get.back();
      print('❌ Error creating moment: $e');

      Get.snackbar(
        'Error',
        'Something went wrong: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> _saveMomentVideoToGallery(File videoFile) async {
    try {
      final saved = await GallerySaver.saveVideo(
        videoFile.path,
        albumName: 'SnapStake',
      );

      if (saved == true) {
        Get.snackbar(
          'Saved',
          'Video saved to your gallery.',
          snackPosition: SnackPosition.TOP,
        );
      } else {
        Get.snackbar(
          'Note',
          'Moment is live, but we could not save the video to gallery.',
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      print('❌ Error saving video to gallery: $e');
      Get.snackbar(
        'Note',
        'Moment is live, but gallery save failed.',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.subtleGlowGradient),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.secondaryGlowGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppColors.text,
              title: const Text(
                'Create Moment',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              leading: IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(LucideIcons.arrowLeft, color: AppColors.text),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Preview
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Obx(
                      () =>
                          _isVideoInitialized.value && _videoController != null
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    // Video Player
                                    SizedBox(
                                      width: double.infinity,
                                      height: 200,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width:
                                              _videoController!
                                                  .value
                                                  .size
                                                  .width,
                                          height:
                                              _videoController!
                                                  .value
                                                  .size
                                                  .height,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      ),
                                    ),
                                    // Play/Pause overlay
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () async {
                                          print(
                                            'Video tapped. Currently playing: ${_videoController!.value.isPlaying}',
                                          );
                                          try {
                                            if (_videoController!
                                                .value
                                                .isPlaying) {
                                              await _videoController!.pause();
                                              print('Video paused');
                                            } else {
                                              await _videoController!.play();
                                              print('Video started playing');
                                            }
                                          } catch (e) {
                                            print(
                                              'Error controlling video playback: $e',
                                            );
                                          }
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                          child: Center(
                                            child: AnimatedOpacity(
                                              opacity:
                                                  _videoController!
                                                          .value
                                                          .isPlaying
                                                      ? 0.0
                                                      : 0.8,
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  20,
                                                ),
                                                child: Icon(
                                                  _videoController!
                                                          .value
                                                          .isPlaying
                                                      ? LucideIcons.pause
                                                      : LucideIcons.play,
                                                  size: 40,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // File info overlay
                                    Positioned(
                                      bottom: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Duration: ${_formatDuration(_videoController!.value.duration)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    // Loading/Error state
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Loading video...',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // File path info (for development)
                                    Positioned(
                                      bottom: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Video: ${widget.videoFile.name}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Retry button if initialization fails
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            print(
                                              'Retrying video initialization...',
                                            );
                                            _initializeVideo();
                                          },
                                          icon: const Icon(
                                            LucideIcons.refreshCw,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Warning message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'You can\'t edit this after posting',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description input
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    maxLength: 100,
                    style: const TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Describe what could happen...',
                      hintStyle: TextStyle(color: AppColors.textLight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Possible outcomes section
                  const Text(
                    'Possible Outcomes',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Container(
                  //   width: double.infinity,
                  //   height: 48,
                  //   decoration: BoxDecoration(
                  //     gradient: AppColors.gradient,
                  //     borderRadius: BorderRadius.circular(24),
                  //     boxShadow: [
                  //       BoxShadow(
                  //         color: AppColors.primary.withOpacity(0.3),
                  //         blurRadius: 8,
                  //         offset: const Offset(0, 4),
                  //       ),
                  //     ],
                  //   ),
                  //   child: ElevatedButton(
                  //     onPressed: _showAddOutcomeDialog,
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.transparent,
                  //       shadowColor: Colors.transparent,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(24),
                  //       ),
                  //     ),
                  //     child: const Text(
                  //       'Select possible outcomes',
                  //       style: TextStyle(
                  //         color: AppColors.text,
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 16),

                  // Outcomes list
                  Obx(
                    () => Column(
                      children:
                          _outcomes.asMap().entries.map((entry) {
                            final index = entry.key;
                            final outcome = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.textDisabled,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      outcome,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    index == 0
                                        ? LucideIcons.check
                                        : LucideIcons.x,
                                    size: 20,
                                    color: AppColors.warning,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Timer section
                  const Text(
                    'Bets will be closed and Outcome video will be up in',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Obx(
                    () => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => _useCustomDeadline.value = false,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color:
                                        !_useCustomDeadline.value
                                            ? AppColors.primary
                                            : AppColors.textDisabled,
                                  ),
                                ),
                                child: Text(
                                  'Quick (mins)',
                                  style: TextStyle(
                                    color:
                                        !_useCustomDeadline.value
                                            ? AppColors.primary
                                            : AppColors.text,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => _useCustomDeadline.value = true,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color:
                                        _useCustomDeadline.value
                                            ? AppColors.primary
                                            : AppColors.textDisabled,
                                  ),
                                ),
                                child: Text(
                                  'Set deadline',
                                  style: TextStyle(
                                    color:
                                        _useCustomDeadline.value
                                            ? AppColors.primary
                                            : AppColors.text,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (!_useCustomDeadline.value) ...[
                          Text(
                            '${_timerMinutes.value.round()}min',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Slider(
                            value: _timerMinutes.value,
                            min: 5,
                            max: 60,
                            divisions: 11,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              _timerMinutes.value = value;
                            },
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.textDisabled),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.calendarClock,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _customDeadline.value == null
                                        ? 'No deadline selected'
                                        : _formatDeadline(
                                          _customDeadline.value!,
                                        ),
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _pickCustomDeadline,
                                  child: Text(
                                    _customDeadline.value == null
                                        ? 'Pick'
                                        : 'Change',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Go Live button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _goLive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              LucideIcons.play,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Go Live!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
