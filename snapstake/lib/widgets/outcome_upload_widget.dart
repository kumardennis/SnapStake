import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';

/// Widget for moment creators to upload outcome video and reveal the result
class OutcomeUploadWidget extends StatefulWidget {
  final Map<String, dynamic> moment;
  final VoidCallback onOutcomeRevealed;

  const OutcomeUploadWidget({
    super.key,
    required this.moment,
    required this.onOutcomeRevealed,
  });

  @override
  State<OutcomeUploadWidget> createState() => _OutcomeUploadWidgetState();
}

class _OutcomeUploadWidgetState extends State<OutcomeUploadWidget> {
  String? selectedOutcome; // 'yes' or 'no'
  bool isUploading = false;

  Future<void> _recordOutcomeVideo() async {
    if (selectedOutcome == null) {
      Get.snackbar(
        'Error',
        'Please select the outcome (YES or NO) first',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    try {
      // Navigate to camera page for outcome recording
      final result = await Get.toNamed(
        '/camera',
        arguments: {
          'isOutcomeRecording': true,
          'momentId': widget.moment['id'],
          'outcome': selectedOutcome,
        },
      );

      if (result == true) {
        // Outcome was successfully recorded and uploaded
        widget.onOutcomeRevealed();
        Get.snackbar(
          'Success',
          'Outcome revealed successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.withOpacity(0.1),
        );
      }
    } catch (e) {
      print('❌ Error recording outcome: $e');
      Get.snackbar(
        'Error',
        'Failed to record outcome. Please try again.',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        // Use solid dark background with high contrast
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with better contrast
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.crown,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Reveal the Outcome',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description with better visibility
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!, width: 1),
            ),
            child: const Text(
              'As the creator, record a video showing the proof and declare the outcome.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Outcome Selection Title
          const Text(
            'Select the outcome:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 16),

          // Outcome Selection Buttons with improved contrast
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedOutcome = 'yes';
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color:
                          selectedOutcome == 'yes'
                              ? const Color(
                                0xFF059669,
                              ) // Darker green for better contrast
                              : const Color(0xFF374151), // Dark gray
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selectedOutcome == 'yes'
                                ? const Color(0xFF10B981)
                                : Colors.grey[600]!,
                        width: 2,
                      ),
                      boxShadow:
                          selectedOutcome == 'yes'
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.check, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'YES',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedOutcome = 'no';
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color:
                          selectedOutcome == 'no'
                              ? const Color(
                                0xFFDC2626,
                              ) // Darker red for better contrast
                              : const Color(0xFF374151), // Dark gray
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selectedOutcome == 'no'
                                ? const Color(0xFFEF4444)
                                : Colors.grey[600]!,
                        width: 2,
                      ),
                      boxShadow:
                          selectedOutcome == 'no'
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.x, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'NO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Record Button with enhanced styling
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  selectedOutcome != null && !isUploading
                      ? _recordOutcomeVideo
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    selectedOutcome != null
                        ? AppColors.primary
                        : const Color(0xFF4B5563),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: selectedOutcome != null ? 4 : 0,
                shadowColor:
                    selectedOutcome != null
                        ? AppColors.primary.withOpacity(0.3)
                        : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isUploading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  else
                    const Icon(
                      LucideIcons.video,
                      size: 22,
                      color: AppColors.background,
                    ),
                  const SizedBox(width: 12),
                  Text(
                    isUploading
                        ? 'Uploading...'
                        : selectedOutcome != null
                        ? 'Record Outcome Video'
                        : 'Select outcome first',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
