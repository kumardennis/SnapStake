import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/custom_bottom_nav.dart';

class CreateMomentPage extends StatefulWidget {
  const CreateMomentPage({super.key});

  @override
  State<CreateMomentPage> createState() => _CreateMomentPageState();
}

class _CreateMomentPageState extends State<CreateMomentPage> {
  @override
  void initState() {
    super.initState();
    // Set current page index after the widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final NavigationController navController =
          Get.find<NavigationController>();
      navController.setCurrentIndex(1);
    });
  }

  void _startRecording() {
    // Navigate to camera recording page
    Get.toNamed('/camera');
  }

  @override
  Widget build(BuildContext context) {
    final NavigationController navController = Get.find<NavigationController>();
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
              backgroundColor: AppColors.background,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.3),
              scrolledUnderElevation: 8,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppColors.text,
              title: const Text(
                'Create Moment',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(LucideIcons.arrowLeft, color: AppColors.text),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Film/Clapperboard Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.clapperboard,
                        size: 80,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Title
                    Text(
                      'Create a\nMoment!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                        height: 1.1,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Description
                    Text(
                      'Record a situation, let people bet on\nwhat happens, then reveal the\noutcome!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textLight,
                        height: 1.5,
                      ),
                    ),

                    const Spacer(),

                    // Start Recording Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      margin: const EdgeInsets.only(bottom: 32),
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
                        onPressed: _startRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(1, 42, 79, 143),
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
                                LucideIcons.plus,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Start Recording',
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
                  ],
                ),
              ),
            ),
            bottomNavigationBar: Obx(
              () => CustomBottomNav(
                selectedIndex: navController.selectedIndex.value,
                onItemSelected: navController.onItemSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
