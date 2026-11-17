import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../app_colors.dart';
import '../controllers/moments_controller.dart';
import '../controllers/betting_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/moment_link_service.dart';
import '../widgets/moment_video_player.dart';
import '../widgets/outcome_upload_widget.dart';

class MomentPage extends StatefulWidget {
  final String momentId;

  const MomentPage({super.key, required this.momentId});

  @override
  State<MomentPage> createState() => _MomentPageState();
}

class _MomentPageState extends State<MomentPage> {
  final MomentsController _momentsController = Get.find<MomentsController>();
  final BettingController _bettingController = Get.find<BettingController>();

  Map<String, dynamic>? moment;
  bool isLoading = true;
  String? error;
  bool hasUserBet = false; // Track if current user has already bet

  final TextEditingController _betAmountController = TextEditingController();
  String? selectedOutcome; // 'yes' or 'no'

  @override
  void initState() {
    super.initState();
    _loadMoment();
  }

  @override
  void dispose() {
    _betAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadMoment() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Ensure the repository receives an int id
      final id = int.tryParse(widget.momentId);
      if (id == null) {
        setState(() {
          error = 'Invalid moment id';
          isLoading = false;
        });
        return;
      }

      final result = await _momentsController.getMomentById(id);

      if (result != null) {
        // Check if user has already bet on this moment
        final userHasBet = await _bettingController.hasUserBetOnMoment(
          widget.momentId,
        );

        print('User has bet on moment: $userHasBet');

        setState(() {
          moment = result;
          hasUserBet = userHasBet;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Moment not found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load moment: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _placeBet() async {
    if (selectedOutcome == null || _betAmountController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select an outcome and enter bet amount',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    final betAmount = double.tryParse(_betAmountController.text);
    if (betAmount == null || betAmount <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid bet amount',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    final momentId = int.parse(widget.momentId);

    // Use the betting controller to place the bet
    final success = await _bettingController.placeBet(
      momentId: momentId,
      outcome: selectedOutcome!,
      amount: betAmount,
    );

    if (success) {
      setState(() {
        selectedOutcome = null;
        _betAmountController.clear();
      });
    }
  }

  Future<void> _shareMoment() async {
    if (moment == null) return;

    final creatorId =
        (moment!['creator_id'] ?? moment!['users']?['id'])?.toString();
    final publicUrl = MomentLinkService.buildPublicMomentUrl(
      widget.momentId,
      creatorId: creatorId,
    );

    final description =
        (moment!['description'] ?? 'Check out this moment').toString().trim();

    final shareText =
        '$description\n\nBet on this moment on SnapStake:\n$publicUrl';

    try {
      await Share.share(shareText, subject: 'SnapStake Moment');
    } catch (e) {
      Get.snackbar(
        'Error',
        'Unable to share this moment right now.',
        snackPosition: SnackPosition.TOP,
      );
      print('❌ Error sharing moment: $e');
    }
  }

  Widget _buildLoadingWidget() {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        scrolledUnderElevation: 8,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text(
          'Moment',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.text),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.alertCircle,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              error ?? 'Something went wrong',
              style: const TextStyle(fontSize: 18, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMoment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingWidget();
    }

    if (error != null || moment == null) {
      return _buildErrorWidget();
    }

    final user = moment!['users'] ?? {};
    final createdAt = DateTime.tryParse(moment!['created_at'] ?? '');
    final outcomeAt = DateTime.tryParse(moment!['outcome_timestamp'] ?? '');
    final timeRemaining = outcomeAt?.difference(DateTime.now());
    final bool isExpired = (timeRemaining?.inSeconds ?? 0) <= 0;

    // Calculate betting statistics from fetched bets data
    final bets = moment!['bets'] as List<dynamic>? ?? [];
    final bool isRevealed = moment!['status'] == 'revealed';

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
                backgroundColor: AppColors.background,
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.3),
                scrolledUnderElevation: 8,
                surfaceTintColor: Colors.transparent,
                foregroundColor: AppColors.text,
                title: const Text(
                  'Moment',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leading: IconButton(
                  onPressed: () {
                    // Refresh moments list when going back to show updated status
                    final momentsController = Get.find<MomentsController>();
                    momentsController.refreshMoments();
                    Get.back();
                  },
                  icon: const Icon(
                    LucideIcons.arrowLeft,
                    color: AppColors.text,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: _shareMoment,
                    icon: const Icon(LucideIcons.share2, color: AppColors.text),
                    tooltip: 'Share',
                  ),
                  IconButton(
                    onPressed: _loadMoment,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Moment Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[850]!,
                            Colors.grey[900]!,
                            Colors.black87,
                          ],
                          stops: const [0.1, 0.6, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Info & Time
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage:
                                      user['avatar'] != null
                                          ? NetworkImage(user['avatar'])
                                          : null,
                                  backgroundColor: AppColors.primary,
                                  child:
                                      user['avatar'] == null
                                          ? Text(
                                            _getUserDisplayName(
                                              user,
                                            )[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getUserDisplayName(user),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _getTimeText(createdAt),
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Status Badge - show revealed, active time, or expired
                                if (moment!['status'] == 'revealed')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.success,
                                      ),
                                    ),
                                    child: const Text(
                                      'REVEALED',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (!isExpired)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    child: Text(
                                      _formatTimeRemaining(timeRemaining!),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.error,
                                      ),
                                    ),
                                    child: const Text(
                                      'EXPIRED',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Description
                            Text(
                              moment!['description'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Video Player
                            if (moment!['video_link'] != null)
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: MomentVideoPlayer(
                                  videoPath:
                                      moment!['display_video_url'] ??
                                      moment!['video_link'],
                                  autoPlay: false,
                                  fit: BoxFit.cover,
                                  adaptiveFrame: true,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Stats
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.users,
                                  color: Colors.grey[400],
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$totalBets bets',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Icon(
                                  LucideIcons.wallet,
                                  color: Colors.grey[400],
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${totalAmount.toStringAsFixed(2)} STK',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Outcome Results Section (when revealed)
                    if (moment!['status'] == 'revealed') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          // Use dark background for better contrast
                          color: const Color(0xFF1A1A1A),
                          border: Border.all(
                            color: AppColors.success,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    LucideIcons.checkCircle,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Outcome Revealed',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Actual Outcome
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                // Solid background for better contrast
                                color:
                                    moment!['outcome_result'] == 'yes'
                                        ? const Color(0xFF059669) // Solid green
                                        : const Color(0xFFDC2626), // Solid red
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      moment!['outcome_result'] == 'yes'
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    moment!['outcome_result'] == 'yes'
                                        ? LucideIcons.checkCircle
                                        : LucideIcons.xCircle,
                                    color:
                                        Colors
                                            .white, // White for maximum contrast
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'The outcome was: ${(moment!['outcome_result'] ?? 'unknown').toString().toUpperCase()}',
                                    style: const TextStyle(
                                      color:
                                          Colors
                                              .white, // White text for maximum contrast
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Outcome Video (if available)
                            if (moment!['outcome_video_link'] != null) ...[
                              const Text(
                                'Outcome Proof Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.success,
                                    width: 2,
                                  ),
                                ),
                                child: MomentVideoPlayer(
                                  videoPath: moment!['outcome_video_link'],
                                  autoPlay: false,
                                  fit: BoxFit.cover,
                                  adaptiveFrame: true,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Betting Results
                            const Text(
                              'Betting Results',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Yes Bets
                            _buildBetCategoryResults(
                              'YES',
                              'yes',
                              bets,
                              moment!['outcome_result'],
                            ),

                            const SizedBox(height: 12),

                            // No Bets
                            _buildBetCategoryResults(
                              'NO',
                              'no',
                              bets,
                              moment!['outcome_result'],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],

                    // Outcome Upload Widget (for creator when there are bets, regardless of expiration)
                    if (totalBets > 0 &&
                        moment!['creator_id'] ==
                            Get.find<AuthController>()
                                .userProfile
                                .value?['id'] &&
                        moment!['status'] != 'revealed')
                      OutcomeUploadWidget(
                        moment: moment!,
                        onOutcomeRevealed: _loadMoment,
                      ),

                    // Betting Section
                    if (!isExpired &&
                        !hasUserBet &&
                        moment!['status'] != 'revealed') ...[
                      const SizedBox(height: 8),

                      // Simplified Yes/No Selection
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      selectedOutcome == 'yes'
                                          ? const Color(0xFF10B981)
                                          : Colors.grey[900],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        selectedOutcome == 'yes'
                                            ? const Color(0xFF10B981)
                                            : AppColors.secondary,
                                    width: 1.5,
                                  ),
                                  // Add green glow when selected, teal glow when not
                                  boxShadow:
                                      selectedOutcome == 'yes'
                                          ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withOpacity(0.4),
                                              blurRadius: 12,
                                              spreadRadius: 1,
                                            ),
                                            BoxShadow(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withOpacity(0.2),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                          : [
                                            BoxShadow(
                                              color: AppColors.secondary
                                                  .withOpacity(0.3),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                            BoxShadow(
                                              color: AppColors.secondary
                                                  .withOpacity(0.15),
                                              blurRadius: 18,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.trendingUp,
                                      size: 20,
                                      color:
                                          selectedOutcome == 'yes'
                                              ? Colors.white
                                              : Colors.grey[400],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'YES',
                                      style: TextStyle(
                                        color:
                                            selectedOutcome == 'yes'
                                                ? Colors.white
                                                : Colors.grey[400],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedOutcome = 'no';
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      selectedOutcome == 'no'
                                          ? const Color(0xFFEF4444)
                                          : Colors.grey[900],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        selectedOutcome == 'no'
                                            ? const Color(0xFFEF4444)
                                            : AppColors.primary,
                                    width: 1.5,
                                  ),
                                  // Add red glow when selected, orange glow when not
                                  boxShadow:
                                      selectedOutcome == 'no'
                                          ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFEF4444,
                                              ).withOpacity(0.4),
                                              blurRadius: 12,
                                              spreadRadius: 1,
                                            ),
                                            BoxShadow(
                                              color: const Color(
                                                0xFFEF4444,
                                              ).withOpacity(0.2),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                          : [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withOpacity(0.15),
                                              blurRadius: 18,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.trendingDown,
                                      size: 20,
                                      color:
                                          selectedOutcome == 'no'
                                              ? Colors.white
                                              : Colors.grey[400],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'NO',
                                      style: TextStyle(
                                        color:
                                            selectedOutcome == 'no'
                                                ? Colors.white
                                                : Colors.grey[400],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Modern Bet Amount Input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                _betAmountController.text.isNotEmpty
                                    ? AppColors.primary
                                    : AppColors.secondary,
                            width: 1.5,
                          ),
                          // Add orange glow when there's text, teal glow when empty
                          boxShadow:
                              _betAmountController.text.isNotEmpty
                                  ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(
                                        0.15,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                  : [
                                    BoxShadow(
                                      color: AppColors.secondary.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                    BoxShadow(
                                      color: AppColors.secondary.withOpacity(
                                        0.15,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ],
                        ),
                        child: TextField(
                          controller: _betAmountController,
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            // Trigger rebuild to update glow effects
                            setState(() {});
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            helperText:
                                'Rate your confidence: 1 STK (low) - 10 STK (high)',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                            prefixIcon: Container(
                              width: 50,
                              alignment: Alignment.center,
                              child: Text(
                                'S',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(20),
                            suffixText: 'STK',
                            suffixStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Modern Place Bet Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient:
                              selectedOutcome != null &&
                                      _betAmountController.text.isNotEmpty
                                  ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF8B5CF6),
                                    ],
                                  )
                                  : null,
                          color:
                              selectedOutcome == null ||
                                      _betAmountController.text.isEmpty
                                  ? Colors.grey[800]
                                  : null,
                          borderRadius: BorderRadius.circular(16),
                          // Add purple glow when active
                          boxShadow:
                              selectedOutcome != null &&
                                      _betAmountController.text.isNotEmpty
                                  ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withOpacity(0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF8B5CF6,
                                      ).withOpacity(0.3),
                                      blurRadius: 30,
                                      spreadRadius: 3,
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap:
                                selectedOutcome != null &&
                                        _betAmountController.text.isNotEmpty
                                    ? _placeBet
                                    : null,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Obx(
                                () =>
                                    _bettingController.isPlacingBet.value
                                        ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                        : Text(
                                          selectedOutcome != null &&
                                                  _betAmountController
                                                      .text
                                                      .isNotEmpty
                                              ? 'Bet ${_betAmountController.text} STK on ${selectedOutcome?.toUpperCase()}'
                                              : 'Select outcome & amount (1.00 STK min & 10.00 STK max)',
                                          style: TextStyle(
                                            color:
                                                selectedOutcome != null &&
                                                        _betAmountController
                                                            .text
                                                            .isNotEmpty
                                                    ? Colors.white
                                                    : Colors.grey[500],
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Expired or Already Bet State or Revealed
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              hasUserBet
                                  ? AppColors.info.withOpacity(0.1)
                                  : AppColors.error.withOpacity(0.1),
                          border: Border.all(
                            color:
                                hasUserBet ? AppColors.info : AppColors.error,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              hasUserBet
                                  ? LucideIcons.check
                                  : LucideIcons.clock,
                              size: 48,
                              color:
                                  hasUserBet ? AppColors.info : AppColors.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hasUserBet
                                  ? 'Bet Already Placed'
                                  : 'Betting Closed',
                              style: TextStyle(
                                color:
                                    hasUserBet
                                        ? AppColors.info
                                        : AppColors.error,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasUserBet
                                  ? 'You have already placed a bet on this moment.'
                                  : 'This moment has expired. No more bets can be placed.',
                              style: TextStyle(
                                color:
                                    hasUserBet
                                        ? AppColors.infoLight
                                        : AppColors.textLight,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getUserDisplayName(Map<String, dynamic> user) {
    final firstName = user['firstname'];
    final lastName = user['lastname'];

    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName;
    } else if (user['username'] != null) {
      return user['username'];
    } else {
      return 'Anonymous';
    }
  }

  String _getTimeText(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h left';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m left';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m left';
    } else {
      return '${duration.inSeconds}s left';
    }
  }

  Widget _buildBetCategoryResults(
    String categoryLabel,
    String categoryOutcome,
    List<dynamic> allBets,
    String? actualOutcome,
  ) {
    final categoryBets =
        allBets.where((bet) => bet['outcome'] == categoryOutcome).toList();
    final totalBets = categoryBets.length;
    final totalAmount = categoryBets.fold<double>(
      0.0,
      (sum, bet) => sum + (bet['amount']?.toDouble() ?? 0.0),
    );

    final isWinning = actualOutcome == categoryOutcome;

    // Calculate total payout info for display
    double losingAmount = 0.0;
    String payoutInfo = '';

    if (isWinning && totalBets > 0) {
      // Get total amount from losing bets
      final losingBets =
          allBets.where((bet) => bet['outcome'] != categoryOutcome).toList();
      losingAmount = losingBets.fold<double>(
        0.0,
        (sum, bet) => sum + (bet['amount']?.toDouble() ?? 0.0),
      );

      // Each winner gets: original bet + proportional share of losing pot
      // Example: 5 STK bet gets 5 STK + (5/34 x 10 STK) = 6.47 STK
      payoutInfo =
          'Winners get: Original bet + proportional share of ${losingAmount.toStringAsFixed(2)} STK losing pot';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Use darker background with better contrast
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinning ? AppColors.success : AppColors.error,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWinning ? LucideIcons.trophy : LucideIcons.x,
                color: isWinning ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$categoryLabel Bets',
                style: TextStyle(
                  color: Colors.white, // White text for better contrast
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isWinning)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'WINNERS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$totalBets bettors',
                style: TextStyle(color: AppColors.textLight, fontSize: 14),
              ),
              const SizedBox(width: 20),
              Text(
                '${totalAmount.toStringAsFixed(2)} STK wagered',
                style: TextStyle(color: AppColors.textLight, fontSize: 14),
              ),
            ],
          ),
          if (isWinning && totalBets > 0) ...[
            const SizedBox(height: 8),
            Text(
              payoutInfo,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Example: 5 STK bet -> 5 STK + ${(losingAmount * 5 / totalAmount).toStringAsFixed(2)} STK = ${(5 + (losingAmount * 5 / totalAmount)).toStringAsFixed(2)} STK',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
