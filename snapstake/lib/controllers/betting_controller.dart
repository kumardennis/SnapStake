import 'package:get/get.dart';
import '../repositories/bets_repo.dart';
import '../controllers/auth_controller.dart';

/// Controller for managing betting operations
class BettingController extends GetxController {
  final BetsRepository _betsRepo = BetsRepository();
  final AuthController _authController = Get.find<AuthController>();

  final RxBool isPlacingBet = false.obs;

  /// Place a bet on a moment
  Future<bool> placeBet({
    required int momentId,
    required String outcome,
    required double amount,
  }) async {
    try {
      isPlacingBet.value = true;

      // Get current user ID
      final userId = _authController.userProfile.value?['id'];
      if (userId == null) {
        Get.snackbar(
          'Error',
          'You must be logged in to place bets',
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }

      // Validate bet amount
      if (amount < 0) {
        Get.snackbar(
          'Error',
          'Minimum bet amount is 1 STK',
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }

      // Place the bet
      final result = await _betsRepo.placeBet(
        momentId: momentId,
        userId: userId,
        outcome: outcome,
        amount: amount,
      );

      if (result != null) {
        Get.snackbar(
          'Success',
          'Your bet of ${amount.toStringAsFixed(2)} STK on ${outcome.toUpperCase()} has been placed!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary.withOpacity(0.1),
        );

        Get.toNamed('/home');
        return true;
      } else {
        Get.snackbar(
          'Error',
          'Failed to place bet. Please try again.',
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }
    } catch (e) {
      print('❌ Error in BettingController.placeBet: $e');
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.TOP,
      );
      return false;
    } finally {
      isPlacingBet.value = false;
    }
  }

  /// Quick bet navigation - opens moment page for betting
  void openBettingPage(Map<String, dynamic> moment) {
    if (moment['id'] != null) {
      Get.toNamed('/moment', arguments: {'momentId': moment['id'].toString()});
    } else {
      Get.snackbar(
        'Error',
        'Invalid moment ID',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  /// Get betting statistics for a moment
  Future<Map<String, dynamic>?> getMomentBettingStats(String momentId) async {
    try {
      return await _betsRepo.getMomentBettingStats(momentId);
    } catch (e) {
      print('❌ Error getting betting stats: $e');
      return null;
    }
  }

  /// Get user's bets
  Future<List<Map<String, dynamic>>> getUserBets() async {
    try {
      final userId = _authController.userProfile.value?['id'];
      if (userId == null) return [];

      return await _betsRepo.getUserBets(userId);
    } catch (e) {
      print('❌ Error getting user bets: $e');
      return [];
    }
  }

  /// Get user's bets with calculated winnings
  Future<List<Map<String, dynamic>>> getUserBetsWithWinnings() async {
    try {
      final userId = _authController.userProfile.value?['id'];
      if (userId == null) return [];

      return await _betsRepo.getUserBetsWithWinnings(userId);
    } catch (e) {
      print('❌ Error getting user bets with winnings: $e');
      return [];
    }
  }

  /// Check if user has already bet on a moment
  Future<bool> hasUserBetOnMoment(String momentId) async {
    try {
      final userBets = await getUserBets();
      return userBets.any(
        (bet) =>
            bet['moment_id'].toString() == momentId &&
            bet['status'] == 'active',
      );
    } catch (e) {
      print('❌ Error checking user bet: $e');
      return false;
    }
  }

  /// Check if user has already bet on multiple moments
  Future<Set<String>> getUserBetMomentIds() async {
    try {
      final userBets = await getUserBets();
      print('🔍 Raw user bets: $userBets');
      final activeBets =
          userBets.where((bet) => bet['status'] == 'active').toList();
      print('🔍 Active user bets: $activeBets');
      final momentIds =
          activeBets.map((bet) => bet['moment_id'].toString()).toSet();
      print('🔍 Extracted moment IDs: $momentIds');
      return momentIds;
    } catch (e) {
      print('❌ Error getting user bet moment IDs: $e');
      return <String>{};
    }
  }
}
