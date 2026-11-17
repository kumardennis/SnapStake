import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/betting_controller.dart';
import '../controllers/moments_controller.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/moment_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late BettingController _bettingController;
  late MomentsController _momentsController;
  Set<String> userBetMomentIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    _bettingController = Get.find<BettingController>();
    _momentsController = Get.find<MomentsController>();

    // Load user bet data
    _loadUserBetData();

    // Set current page index after the widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final NavigationController navController =
          Get.find<NavigationController>();
      navController.setCurrentIndex(0);
    });
  }

  Future<void> _loadUserBetData() async {
    try {
      final betMomentIds = await _bettingController.getUserBetMomentIds();
      print('🔍 User bet moment IDs loaded: $betMomentIds');
      setState(() {
        userBetMomentIds = betMomentIds;
      });
    } catch (e) {
      print('❌ Error loading user bet data: $e');
    }
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
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.accentGlowGradient,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: AppColors.dark,
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.3),
                scrolledUnderElevation: 8,
                surfaceTintColor: Colors.transparent,
                foregroundColor: AppColors.text,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.secondary.withOpacity(0.05),
                        AppColors.dark,
                      ],
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.zap,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Home',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: () {
                        _momentsController.refreshMoments();
                        _loadUserBetData();
                      },
                      icon: Icon(
                        LucideIcons.refreshCw,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: () {
                        final AuthController authController =
                            Get.find<AuthController>();
                        authController.signOut();
                      },
                      icon: Icon(
                        LucideIcons.logOut,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              body: Obx(() {
                if (_momentsController.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (_momentsController.error.value.isNotEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0,
                        colors: [
                          AppColors.error.withOpacity(0.1),
                          AppColors.background,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.error.withOpacity(0.2),
                                  AppColors.error.withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.alertCircle,
                              size: 64,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Oops! Something went wrong',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _momentsController.error.value,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.gradient,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () => _momentsController.loadMoments(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (_momentsController.moments.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.5,
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.secondary.withOpacity(0.05),
                          AppColors.background,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated icon container
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary.withOpacity(0.3),
                                  AppColors.secondary.withOpacity(0.2),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.camera,
                              size: 80,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Title with gradient text effect
                          ShaderMask(
                            shaderCallback:
                                (bounds) => AppColors.gradient.createShader(
                                  Rect.fromLTWH(
                                    0,
                                    0,
                                    bounds.width,
                                    bounds.height,
                                  ),
                                ),
                            child: const Text(
                              'No active moments yet!',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Be the first to create a moment and let others bet on it!',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),

                          // Animated CTA button
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.gradient,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: AppColors.secondary.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () => Get.toNamed('/camera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.plus, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'Create Moment',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await _momentsController.refreshMoments();
                    await _loadUserBetData();
                  },
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _momentsController.moments.length,
                    itemBuilder: (context, index) {
                      final moment = _momentsController.moments[index];
                      final momentId = moment['id'].toString();
                      final hasUserBet = userBetMomentIds.contains(momentId);

                      print(
                        '🔍 Moment $momentId: hasUserBet=$hasUserBet, userBetMomentIds=$userBetMomentIds',
                      );

                      return MomentCard(
                        moment: moment,
                        onTap: () => _momentsController.openMoment(moment),
                        onBet:
                            hasUserBet
                                ? null
                                : () =>
                                    _bettingController.openBettingPage(moment),
                      );
                    },
                  ),
                );
              }),
              bottomNavigationBar: Obx(
                () => CustomBottomNav(
                  selectedIndex: navController.selectedIndex.value,
                  onItemSelected: navController.onItemSelected,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
