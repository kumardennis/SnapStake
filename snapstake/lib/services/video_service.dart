import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class for managing video operations and URL generation
/// Handles video URL caching and refreshing for optimal performance
class VideoService {
  final SupabaseClient _client = Supabase.instance.client;

  // Cache for storing video URLs with timestamps
  static final Map<String, VideoUrlCache> _urlCache = {};

  /// Cache duration in seconds (1 hour)
  static const int _cacheDurationSeconds = 3600;

  /// Get a displayable video URL with caching
  /// This method provides efficient video URL management
  Future<String?> getVideoUrl(String videoPath) async {
    if (videoPath.isEmpty) return null;

    // Clean the path if it's already a full URL
    final cleanPath = _extractFilePath(videoPath);

    // Check cache first
    final cached = _urlCache[cleanPath];
    if (cached != null && !cached.isExpired) {
      print('📱 Using cached URL for: $cleanPath');
      return cached.url;
    }

    // Generate fresh signed URL
    try {
      final signedUrl = await _client.storage
          .from('videos')
          .createSignedUrl(cleanPath, _cacheDurationSeconds);

      // Cache the URL
      _urlCache[cleanPath] = VideoUrlCache(
        url: signedUrl,
        expiresAt: DateTime.now().add(
          Duration(seconds: _cacheDurationSeconds - 60),
        ), // Expire 1 minute early for safety
      );

      print('🔗 Generated fresh URL for: $cleanPath');
      return signedUrl;
    } catch (e) {
      print('❌ Error generating video URL: $e');
      return null;
    }
  }

  /// Extract file path from various URL formats
  String _extractFilePath(String input) {
    // If it's just a path, return as-is
    if (!input.startsWith('http')) {
      return input;
    }

    // Extract path from URL
    try {
      final uri = Uri.parse(input);
      final pathSegments = uri.pathSegments;

      // Handle different URL formats
      if (pathSegments.contains('videos')) {
        final videosIndex = pathSegments.indexOf('videos');
        if (videosIndex < pathSegments.length - 1) {
          return pathSegments.skip(videosIndex + 1).join('/');
        }
      }

      // Fallback: assume it's already a clean path
      return pathSegments.join('/');
    } catch (e) {
      print('⚠️ Failed to parse URL, using as-is: $input');
      return input;
    }
  }

  /// Preload video URLs for a list of moments
  /// This helps improve performance by loading URLs in advance
  Future<void> preloadVideoUrls(List<Map<String, dynamic>> moments) async {
    final futures =
        moments
            .where((moment) => moment['video_link'] != null)
            .map((moment) => getVideoUrl(moment['video_link']))
            .toList();

    await Future.wait(futures);
    print('📦 Preloaded ${futures.length} video URLs');
  }

  /// Clear expired URLs from cache
  void cleanCache() {
    _urlCache.removeWhere((key, cache) => cache.isExpired);
    print('🧹 Cleaned video URL cache');
  }

  /// Clear all cached URLs
  void clearCache() {
    _urlCache.clear();
    print('🗑️ Cleared all video URL cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final validEntries =
        _urlCache.values.where((cache) => !cache.isExpired).length;
    final expiredEntries = _urlCache.length - validEntries;

    return {
      'totalEntries': _urlCache.length,
      'validEntries': validEntries,
      'expiredEntries': expiredEntries,
    };
  }
}

/// Cache entry for video URLs
class VideoUrlCache {
  final String url;
  final DateTime expiresAt;

  VideoUrlCache({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
