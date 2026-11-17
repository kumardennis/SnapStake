import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/moments_controller.dart';
import '../controllers/betting_controller.dart';
import '../widgets/moment_video_player.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final AuthController _authController = Get.find<AuthController>();
  final BettingController _bettingController = Get.find<BettingController>();
  final MomentsController _momentsController = Get.find<MomentsController>();

  late TabController _tabController;

  // User stats
  Map<String, dynamic> userStats = {};
  List<Map<String, dynamic>> userBets = [];
  List<Map<String, dynamic>> userMoments = [];

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final userId = _authController.userProfile.value?['id'];
      if (userId == null) {
        setState(() {
          error = 'User not authenticated';
          isLoading = false;
        });
        return;
      }

      // Load user data in parallel
      final futures = await Future.wait([
        _bettingController.getUserBetsWithWinnings(),
        _momentsController.getUserMoments(),
      ]);

      final bets = futures[0];
      final moments = futures[1];

      // Calculate user statistics
      final stats = _calculateUserStats(bets, moments);

      setState(() {
        userBets = bets;
        userMoments = moments;
        userStats = stats;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load profile: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> _calculateUserStats(
    List<Map<String, dynamic>> bets,
    List<Map<String, dynamic>> moments,
  ) {
    int totalBets = bets.length;
    int totalMoments = moments.length;
    double totalBetAmount = 0.0;
    int wonBets = 0;
    int lostBets = 0;
    int activeBets = 0;
    double totalWinnings = 0.0;
    double totalProfit = 0.0;

    for (final bet in bets) {
      final amount = (bet['amount'] as num?)?.toDouble() ?? 0.0;
      totalBetAmount += amount;

      final status = bet['status'] as String?;
      if (status == 'won') {
        wonBets++;
        // Use the calculated actual winnings from pool-based system
        final actualWinnings =
            (bet['actual_winnings'] as num?)?.toDouble() ?? 0.0;
        totalWinnings += actualWinnings;
        totalProfit +=
            actualWinnings - amount; // profit = winnings - original bet
      } else if (status == 'lost') {
        lostBets++;
        totalProfit -= amount; // loss = negative original bet amount
      } else if (status == 'active') {
        activeBets++;
      }
    }

    final winRate =
        (wonBets + lostBets) > 0 ? (wonBets / (wonBets + lostBets) * 100) : 0.0;

    return {
      'totalBets': totalBets,
      'totalMoments': totalMoments,
      'totalBetAmount': totalBetAmount,
      'wonBets': wonBets,
      'lostBets': lostBets,
      'activeBets': activeBets,
      'totalWinnings': totalWinnings,
      'totalProfit': totalProfit,
      'winRate': winRate,
    };
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.alertCircle, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error ?? 'Something went wrong',
            style: const TextStyle(fontSize: 18, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadProfileData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            const Color(0xFFFF8A5B),
            AppColors.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar and Name
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage:
                      _authController.userAvatar != null
                          ? NetworkImage(_authController.userAvatar!)
                          : null,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child:
                      _authController.userAvatar == null
                          ? Text(
                            (_authController.userName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _authController.userName ?? 'Unknown User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _authController.userEmail ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Moments',
                    '${userStats['totalMoments'] ?? 0}',
                    LucideIcons.camera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Bets',
                    '${userStats['totalBets'] ?? 0}',
                    LucideIcons.zap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Win Rate',
                    '${(userStats['winRate'] ?? 0.0).toStringAsFixed(1)}%',
                    LucideIcons.target,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Betting Statistics
          _buildSectionHeader('Betting Statistics'),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildDetailedStatCard(
                  'Total Bet',
                  '${(userStats['totalBetAmount'] ?? 0.0).toStringAsFixed(2)} STK',
                  AppColors.primary,
                  LucideIcons.wallet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailedStatCard(
                  'Total Winnings',
                  '${(userStats['totalWinnings'] ?? 0.0).toStringAsFixed(2)} STK',
                  AppColors.success,
                  LucideIcons.trendingUp,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildDetailedStatCard(
                  'Won Bets',
                  '${userStats['wonBets'] ?? 0}',
                  AppColors.success,
                  LucideIcons.check,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailedStatCard(
                  'Lost Bets',
                  '${userStats['lostBets'] ?? 0}',
                  AppColors.error,
                  LucideIcons.x,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildDetailedStatCard(
                  'Active Bets',
                  '${userStats['activeBets'] ?? 0}',
                  AppColors.primary,
                  LucideIcons.clock,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailedStatCard(
                  'Win Rate',
                  '${(userStats['winRate'] ?? 0.0).toStringAsFixed(1)}%',
                  AppColors.info,
                  LucideIcons.target,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildDetailedStatCard(
            'Net Profit/Loss',
            '${(userStats['totalProfit'] ?? 0.0) >= 0 ? '+' : ''}${(userStats['totalProfit'] ?? 0.0).toStringAsFixed(2)} STK',
            (userStats['totalProfit'] ?? 0.0) >= 0
                ? AppColors.success
                : AppColors.error,
            (userStats['totalProfit'] ?? 0.0) >= 0
                ? LucideIcons.trendingUp
                : LucideIcons.trendingDown,
          ),

          const SizedBox(height: 24),

          // Account Actions
          _buildSectionHeader('Account'),
          const SizedBox(height: 12),

          _buildActionButton('Edit Profile', LucideIcons.user, () {
            // TODO: Navigate to edit profile page
            Get.snackbar('Coming Soon', 'Profile editing feature coming soon!');
          }),

          const SizedBox(height: 12),

          _buildActionButton('Settings', LucideIcons.settings, () {
            // TODO: Navigate to settings page
            Get.snackbar('Coming Soon', 'Settings feature coming soon!');
          }),

          const SizedBox(height: 12),

          _buildActionButton(
            'Sign Out',
            LucideIcons.logOut,
            () => _authController.signOut(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDetailedStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBetsTab() {
    if (userBets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.zap, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No bets placed yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start betting on moments to see your history here!',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userBets.length,
      itemBuilder: (context, index) {
        final bet = userBets[index];
        return _buildBetCard(bet);
      },
    );
  }

  Widget _buildMomentsTab() {
    if (userMoments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.camera, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              'No moments created yet',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first moment to engage with the community!',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Get.toNamed('/camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 16),
                  SizedBox(width: 8),
                  Text('Create Moment'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userMoments.length,
      itemBuilder: (context, index) {
        final moment = userMoments[index];
        return _buildMomentCard(moment);
      },
    );
  }

  Widget _buildBetCard(Map<String, dynamic> bet) {
    final status = bet['status'] as String? ?? 'active';
    final outcome = bet['outcome'] as String? ?? '';
    final amount = (bet['amount'] as num?)?.toDouble() ?? 0.0;
    final placedAt = DateTime.tryParse(bet['placed_at'] ?? '');

    // Extract moment details for debugging
    final momentData = bet['moments'] as Map<String, dynamic>? ?? {};
    final momentId = momentData['id']?.toString() ?? 'Unknown ID';
    final description = momentData['description'] ?? 'Unknown moment';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'won':
        statusColor = AppColors.success;
        statusIcon = LucideIcons.check;
        break;
      case 'lost':
        statusColor = AppColors.error;
        statusIcon = LucideIcons.x;
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = LucideIcons.clock;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(statusIcon, color: statusColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Moment ID: $momentId',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Add small video preview if video exists
          if (momentData['video_link'] != null) ...[
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.text,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MomentVideoPlayer(
                  videoPath:
                      momentData['display_video_url'] ??
                      momentData['video_link'],
                  height: 120,
                  autoPlay: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Text(
                'Bet: ${outcome.toUpperCase()}',
                style: TextStyle(
                  color: outcome == 'yes' ? Colors.green : Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${amount.toStringAsFixed(2)} STK',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (placedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatDate(placedAt),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMomentCard(Map<String, dynamic> moment) {
    final status = moment['status'] as String? ?? 'active';
    final createdAt = DateTime.tryParse(moment['created_at'] ?? '');

    // Calculate betting statistics from fetched bets data
    final bets = moment['bets'] as List<dynamic>? ?? [];
    final bool isRevealed = status == 'revealed';

    // For revealed moments, show all bets; for active moments, show only active bets
    final relevantBets =
        isRevealed
            ? bets
            : bets.where((bet) => bet['status'] == 'active').toList();

    final totalBets = relevantBets.length;
    final totalAmount = relevantBets.fold<double>(
      0.0,
      (sum, bet) => sum + (bet['amount']?.toDouble() ?? 0.0),
    );

    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = AppColors.success;
        break;
      case 'revealed':
        statusColor = AppColors.info;
        break;
      case 'expired':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.textLight;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to moment page
            Get.toNamed(
              '/moment',
              arguments: {'momentId': moment['id'].toString()},
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  moment['description'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      LucideIcons.users,
                      color: AppColors.textLight,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalBets bets',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      LucideIcons.wallet,
                      color: AppColors.textLight,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${totalAmount.toStringAsFixed(2)} STK',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
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
              backgroundColor: AppColors.background,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.3),
              scrolledUnderElevation: 8,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppColors.text,
              title: const Text(
                'Profile',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                onPressed: () {
                  // Navigate back to home when coming from bottom navigation
                  Get.offAllNamed('/home');
                },
                icon: const Icon(LucideIcons.arrowLeft, color: AppColors.text),
              ),
              actions: [
                IconButton(
                  onPressed: _loadProfileData,
                  icon: const Icon(
                    LucideIcons.refreshCw,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            body:
                isLoading
                    ? _buildLoadingWidget()
                    : error != null
                    ? _buildErrorWidget()
                    : Column(
                      children: [
                        // Profile Header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildProfileHeader(),
                        ),

                        // Tab Bar
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.dark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: 'Stats'),
                              Tab(text: 'Bets'),
                              Tab(text: 'Moments'),
                            ],
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textLight,
                            indicator: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),

                        // Tab Views
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildStatsTab(),
                              _buildBetsTab(),
                              _buildMomentsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
