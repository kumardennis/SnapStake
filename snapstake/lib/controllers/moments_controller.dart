import 'package:snapstake/repositories/bets_repo.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../repositories/moments_repo.dart';
import '../controllers/auth_controller.dart';

/// Controller for managing moments operations and state
class MomentsController extends GetxController {
  final MomentsRepository _momentsRepo = MomentsRepository();
  final BetsRepository _betsRepo = Get.put(BetsRepository());
  final AuthController _authController = Get.find<AuthController>();

  // Observable state
  final RxList<Map<String, dynamic>> moments = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isCreating = false.obs;
  final RxString error = ''.obs;

  // Pagination
  final RxInt currentOffset = 0.obs;
  final RxBool hasMoreMoments = true.obs;
  static const int momentsPerPage = 20;

  @override
  void onInit() {
    super.onInit();
    loadMoments();
  }

  /// Load moments (initial load or refresh)
  Future<void> loadMoments({bool refresh = false}) async {
    try {
      if (refresh) {
        isRefreshing.value = true;
        currentOffset.value = 0;
        hasMoreMoments.value = true;
      } else {
        isLoading.value = true;
      }

      error.value = '';

      final result = await _momentsRepo.getMoments(
        limit: momentsPerPage,
        offset: 0,
      );

      if (refresh) {
        moments.value = result;
      } else {
        moments.value = result;
      }

      // Update pagination state
      hasMoreMoments.value = result.length >= momentsPerPage;
      currentOffset.value = result.length;

      print('📱 Loaded ${result.length} moments');
    } catch (e) {
      error.value = 'Failed to load moments: ${e.toString()}';
      print('❌ Error loading moments: $e');
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// Refresh moments (pull-to-refresh)
  Future<void> refreshMoments() async {
    await loadMoments(refresh: true);
  }

  /// Load more moments for pagination
  Future<void> loadMoreMoments() async {
    if (!hasMoreMoments.value || isLoading.value || isRefreshing.value) {
      return;
    }

    try {
      final result = await _momentsRepo.getMoments(
        limit: momentsPerPage,
        offset: currentOffset.value,
      );

      if (result.isNotEmpty) {
        moments.addAll(result);
        currentOffset.value = moments.length;
        hasMoreMoments.value = result.length >= momentsPerPage;
        print(
          '📱 Loaded ${result.length} more moments (total: ${moments.length})',
        );
      } else {
        hasMoreMoments.value = false;
        print('📱 No more moments to load');
      }
    } catch (e) {
      print('❌ Error loading more moments: $e');
      Get.snackbar(
        'Error',
        'Failed to load more moments',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Get a specific moment by ID
  Future<Map<String, dynamic>?> getMomentById(int momentId) async {
    try {
      return await _momentsRepo.getMomentById(momentId);
    } catch (e) {
      print('❌ Error getting moment: $e');
      return null;
    }
  }

  /// Create a new moment
  Future<bool> createMoment({
    required String description,
    required String outcomeTimestamp,
    required String videoUrl,
  }) async {
    try {
      isCreating.value = true;

      // Get current user ID
      final userId = _authController.userProfile.value?['id'];
      if (userId == null) {
        Get.snackbar(
          'Error',
          'You must be logged in to create moments',
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }

      // Validate inputs
      if (description.trim().isEmpty) {
        Get.snackbar(
          'Error',
          'Please provide a description for your moment',
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }

      if (videoUrl.trim().isEmpty) {
        Get.snackbar(
          'Error',
          'Video is required for creating a moment',
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }

      // Create the moment
      final result = await _momentsRepo.createMoment(
        creatorId: userId,
        description: description.trim(),
        outcomeTimestamp: outcomeTimestamp,
        videoUrl: videoUrl,
      );

      if (result != null) {
        // Add to the beginning of the list for immediate feedback
        moments.insert(0, result);

        Get.snackbar(
          'Success',
          'Your moment has been created successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary.withOpacity(0.1),
        );

        // Refresh to get proper ordering and stats
        refreshMoments();
        return true;
      } else {
        Get.snackbar(
          'Error',
          'Failed to create moment. Please try again.',
          snackPosition: SnackPosition.TOP,
        );
        return false;
      }
    } catch (e) {
      print('❌ Error in MomentsController.createMoment: $e');
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.TOP,
      );
      return false;
    } finally {
      isCreating.value = false;
    }
  }

  /// Update moment status
  Future<bool> updateMomentStatus(String momentId, String status) async {
    try {
      final success = await _momentsRepo.updateMomentStatus(momentId, status);

      if (success) {
        // Update local state
        final momentIndex = moments.indexWhere(
          (m) => m['id'].toString() == momentId,
        );
        if (momentIndex != -1) {
          moments[momentIndex]['status'] = status;
          moments.refresh(); // Trigger UI update
        }

        Get.snackbar(
          'Success',
          'Moment status updated to ${status.toUpperCase()}',
          snackPosition: SnackPosition.TOP,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to update moment status',
          snackPosition: SnackPosition.TOP,
        );
      }

      return success;
    } catch (e) {
      print('❌ Error updating moment status: $e');
      Get.snackbar(
        'Error',
        'Something went wrong while updating moment',
        snackPosition: SnackPosition.TOP,
      );
      return false;
    }
  }

  /// Reveal moment outcome with video proof
  Future<bool> revealMomentOutcome({
    required int momentId,
    required File outcomeVideo,
    required String actualOutcome,
  }) async {
    try {
      print('💰 Resolving bets for moment: $momentId');

      final user = _authController.currentUser.value;
      if (user == null) {
        print('❌ Not authenticated');
        return false;
      }

      // Upload outcome video (returns storage path, not a URL)
      final videoPath = await _momentsRepo.uploadMediaFile(
        outcomeVideo,
        user.id,
      );

      if (videoPath == null) {
        throw Exception('Failed to upload outcome video');
      }

      // Update moment with outcome (sets status: revealed)
      await _momentsRepo.updateMomentOutcome(
        momentId: momentId,
        outcomeVideoUrl: videoPath,
        actualOutcome: actualOutcome,
      );

      // Resolve all bets for this moment
      final betsResolved = await _betsRepo.resolveMomentBets(
        momentId,
        actualOutcome,
      );
      if (!betsResolved) {
        print('⚠️ Warning: Failed to resolve bets for moment $momentId');
      }

      // Refresh moments list
      await loadMoments(refresh: true);

      print('✅ Moment outcome revealed: $momentId, outcome: $actualOutcome');
      return true;
    } catch (e) {
      print('❌ Error revealing moment outcome: $e');
      return false;
    }
  }

  /// Get moments created by current user
  Future<List<Map<String, dynamic>>> getUserMoments() async {
    try {
      final userId = _authController.userProfile.value?['id'];
      if (userId == null) return [];

      return await _momentsRepo.getUserMoments(userId);
    } catch (e) {
      print('❌ Error getting user moments: $e');
      return [];
    }
  }

  /// Navigation helpers
  void openMoment(Map<String, dynamic> moment) {
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

  /// Video cache management
  void clearVideoCache() {
    _momentsRepo.clearVideoCache();
    Get.snackbar(
      'Success',
      'Video cache cleared',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Map<String, dynamic> getVideoCacheStats() {
    return _momentsRepo.getVideoCacheStats();
  }

  /// Search and filter methods
  void searchMoments(String query) {
    // TODO: Implement search functionality
    // This could filter the current moments list or make a new API call
    print('🔍 Searching moments for: $query');
  }

  void filterMomentsByStatus(String status) {
    // TODO: Implement filtering by status (active, revealed, expired)
    print('🔍 Filtering moments by status: $status');
  }

  /// Cleanup
  @override
  void onClose() {
    // Clean up any subscriptions or timers here
    super.onClose();
  }
}
