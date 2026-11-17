import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../services/video_service.dart';
import 'bets_repo.dart';

/// Repository class for moment-related database operations
/// Handles CRUD operations for moments using Supabase
class MomentsRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final VideoService _videoService = VideoService();

  // =================== MOMENT CRUD OPERATIONS ===================

  /// Create a new moment in the database
  Future<Map<String, dynamic>?> createMoment({
    required int creatorId,
    required String description,
    required String outcomeTimestamp,
    required String videoUrl,
  }) async {
    try {
      final momentData = {
        'creator_id': creatorId,
        'description': description,
        'outcome_timestamp': outcomeTimestamp,
        'video_link': videoUrl,
        'status': 'active',
      };

      final response =
          await _client.from('moments').insert(momentData).select().single();

      return response;
    } catch (e) {
      print('❌ Error creating moment: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMoments({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('moments')
          .select('''
            *,
            users!inner(
              *
            ),
            bets(
              id,
              outcome,
              amount,
              status
            )
          ''')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('📱 Fetched ${response.length} active moments with betting data');

      // Use VideoService to generate cached URLs for efficient display
      await _videoService.preloadVideoUrls(response);

      // Add display URLs to each moment
      for (var moment in response) {
        if (moment['video_link'] != null) {
          final displayUrl = await _videoService.getVideoUrl(
            moment['video_link'],
          );
          if (displayUrl != null) {
            moment['display_video_url'] = displayUrl;
          }
        }
      }

      return response;
    } catch (e) {
      print('❌ Error fetching moments: $e');
      return [];
    }
  }

  /// Get moments created by a specific user
  Future<List<Map<String, dynamic>>> getUserMoments(int userId) async {
    try {
      final response = await _client
          .from('moments')
          .select('''
            *,
            bets(
              id,
              outcome,
              amount,
              status
            )
          ''')
          .eq('creator_id', userId)
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      print('❌ Error fetching user moments: $e');
      return [];
    }
  }

  /// Get a single moment by ID with fresh video URL
  Future<Map<String, dynamic>?> getMomentById(int momentId) async {
    try {
      final response =
          await _client
              .from('moments')
              .select('''
            *,
            users!inner(
              *
            ),
            bets(
              id,
              outcome,
              amount,
              status,
              user_id
            )
          ''')
              .eq('id', momentId)
              .single();

      // Add display URL if video exists
      if (response['video_link'] != null) {
        final displayUrl = await _videoService.getVideoUrl(
          response['video_link'],
        );
        if (displayUrl != null) {
          response['display_video_url'] = displayUrl;
        }
      }

      return response;
    } catch (e) {
      print('❌ Error fetching moment: $e');
      return null;
    }
  }

  /// Update moment status (active -> revealed -> expired)
  Future<bool> updateMomentStatus(String momentId, String status) async {
    try {
      await _client
          .from('moments')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', momentId);

      return true;
    } catch (e) {
      print('❌ Error updating moment status: $e');
      return false;
    }
  }

  /// Delete a moment (soft delete by updating status)
  Future<bool> deleteMoment(String momentId) async {
    try {
      await _client
          .from('moments')
          .update({
            'status': 'deleted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', momentId);

      print('✅ Moment deleted: $momentId');
      return true;
    } catch (e) {
      print('❌ Error deleting moment: $e');
      return false;
    }
  }

  // =================== VIDEO UPLOAD ===================

  /// Upload video file to Supabase Storage and return the file path
  /// We store the path and generate signed URLs when needed for display
  Future<String?> uploadVideo({
    required File videoFile,
    required String userId,
  }) async {
    try {
      final fileExtension = videoFile.path.split('.').last.toLowerCase();
      final supportedExtensions = {'mp4', 'mov', 'm4v', 'webm'};
      final normalizedExtension =
          supportedExtensions.contains(fileExtension) ? fileExtension : 'mp4';

      final fileName =
          'moment_${userId}_${DateTime.now().millisecondsSinceEpoch}.$normalizedExtension';
      final filePath = '$userId/moments/$fileName';

      final contentType = switch (normalizedExtension) {
        'mov' => 'video/quicktime',
        'm4v' => 'video/x-m4v',
        'webm' => 'video/webm',
        _ => 'video/mp4',
      };

      print('📤 Uploading video: $fileName');
      print(
        '   File size: ${(await videoFile.length() / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      await _client.storage
          .from('videos')
          .upload(
            filePath,
            videoFile,
            fileOptions: FileOptions(contentType: contentType),
          );

      // Return the file path to store in database
      // We'll generate signed URLs when we need to display the video
      print('✅ Video uploaded successfully');
      print('   File path: $filePath');

      // Store just the file path, not a URL with expiration
      return filePath;
    } catch (e) {
      print('❌ Error uploading video: $e');
      return null;
    }
  }

  /// Upload media file to Supabase Storage and return the file path.
  /// Reverted to video-only semantics: uploads to 'videos' bucket and returns a path (not a public URL).
  Future<String?> uploadMediaFile(File file, String userId) async {
    try {
      final fileExtension = file.path.split('.').last.toLowerCase();
      final supportedExtensions = {'mp4', 'mov', 'm4v', 'webm'};
      final normalizedExtension =
          supportedExtensions.contains(fileExtension) ? fileExtension : 'mp4';

      // Keep naming consistent with uploadVideo()
      final fileName =
          'moment_${userId}_${DateTime.now().millisecondsSinceEpoch}.$normalizedExtension';
      final filePath = '$userId/moments/$fileName';

      final contentType = switch (normalizedExtension) {
        'mov' => 'video/quicktime',
        'm4v' => 'video/x-m4v',
        'webm' => 'video/webm',
        _ => 'video/mp4',
      };

      print('📤 Uploading media (video) to videos bucket: $filePath');

      await _client.storage
          .from('videos')
          .upload(
            filePath,
            file,
            fileOptions: FileOptions(contentType: contentType),
          );

      print('✅ Upload successful. Returning file path: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error uploading media: $e');
      return null;
    }
  }

  /// Get a displayable video URL from stored path using VideoService
  Future<String?> getDisplayVideoUrl(String videoPath) async {
    return await _videoService.getVideoUrl(videoPath);
  }

  /// Clear video URL cache (useful for memory management)
  void clearVideoCache() {
    _videoService.clearCache();
    print('🗑️ Cleared video cache from MomentsRepository');
  }

  /// Get video cache statistics
  Map<String, dynamic> getVideoCacheStats() {
    return _videoService.getCacheStats();
  }

  /// Update video URL in moment record (useful for refreshing expired URLs)
  Future<bool> updateMomentVideoUrl(String momentId, String newVideoUrl) async {
    try {
      await _client
          .from('moments')
          .update({
            'video_link': newVideoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', momentId);

      print('✅ Video URL updated for moment: $momentId');
      return true;
    } catch (e) {
      print('❌ Error updating video URL: $e');
      return false;
    }
  }

  // =================== REAL-TIME SUBSCRIPTIONS ===================

  /// Subscribe to moment updates for real-time features
  RealtimeChannel subscribeMoments({
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    return _client
        .channel('moments_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'moments',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'moments',
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'moments',
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();
  }

  // =================== UTILITY METHODS ===================

  /// Get moments that are ready to be revealed (timer expired)
  Future<List<Map<String, dynamic>>> getMomentsReadyToReveal() async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _client
          .from('moments')
          .select()
          .eq('status', 'active')
          .lt('reveal_at', now);

      print('⏰ Found ${response.length} moments ready to reveal');
      return response;
    } catch (e) {
      print('❌ Error fetching moments ready to reveal: $e');
      return [];
    }
  }

  /// Search moments by description or user name
  Future<List<Map<String, dynamic>>> searchMoments(String query) async {
    try {
      final response = await _client
          .from('moments')
          .select('''
            *,
            users!inner(
              *
            ),
            bets(
              id,
              outcome,
              amount,
              status
            )
          ''')
          .eq('status', 'active')
          .or(
            'description.ilike.%$query%,users.firstname.ilike.%$query%,users.lastname.ilike.%$query%,users.username.ilike.%$query%',
          )
          .order('created_at', ascending: false);

      print('🔍 Found ${response.length} moments for query: "$query"');
      return response;
    } catch (e) {
      print('❌ Error searching moments: $e');
      return [];
    }
  }

  /// Reveal moment outcome and settle bets
  Future<bool> revealMomentOutcome({
    required int momentId,
    required String outcomeVideoPath,
    required String actualOutcome,
  }) async {
    try {
      // Update moment with outcome details
      print('🎯 Revealing outcome for moment: $momentId');
      print('   Outcome: $actualOutcome');
      print('   Outcome video path: $outcomeVideoPath');
      print('   Updating database record...');
      await _client
          .from('moments')
          .update({
            'status': 'revealed',
            'outcome_result': actualOutcome,
            'outcome_video_link': outcomeVideoPath,
            'outcome_revealed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', momentId);

      // Resolve all bets for this moment
      print('💰 Resolving bets for moment: $momentId');
      final betsRepo = BetsRepository();
      final betsResolved = await betsRepo.resolveMomentBets(
        momentId,
        actualOutcome,
      );

      if (!betsResolved) {
        print('⚠️ Warning: Failed to resolve bets for moment $momentId');
        // Continue anyway - moment outcome is revealed even if bet resolution fails
      } else {
        print('✅ All bets resolved successfully for moment: $momentId');
      }

      print('✅ Moment outcome revealed: $momentId, outcome: $actualOutcome');
      return true;
    } catch (e) {
      print('❌ Error revealing moment outcome: $e');
      return false;
    }
  }

  Future<void> updateMomentOutcome({
    required int momentId,
    required String outcomeVideoUrl,
    required String actualOutcome,
  }) async {
    try {
      await _client
          .from('moments')
          .update({
            'outcome_video_link': outcomeVideoUrl,
            'outcome_result': actualOutcome,
            'status': 'revealed',
          })
          .eq('id', momentId);

      print('✅ Moment outcome updated: $momentId');
    } catch (e) {
      print('❌ Error updating moment outcome: $e');
      rethrow;
    }
  }
}
