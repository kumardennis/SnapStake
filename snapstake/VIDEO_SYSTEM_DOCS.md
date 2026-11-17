# SnapStake Video System Architecture

## **Complete Video Handling Flow**

### **1. Video Storage (Database)**
```
Database Field: video_link
Example Value: "48cd6351-dd89-47a5-b462-ae369a277124/moments/moment_48cd6351-dd89-47a5-b462-ae369a277124_1766059127132.mp4"
```
- ✅ Stores **file paths** (not expiring URLs)
- ✅ Permanent references to Supabase Storage
- ✅ No URL expiration issues

### **2. VideoService (Smart URL Management)**
```dart
class VideoService {
  // ✅ Caching system for performance
  static final Map<String, VideoUrlCache> _urlCache = {};
  
  // ✅ Converts file paths to signed URLs
  Future<String?> getVideoUrl(String videoPath) async {
    // Check cache first
    // Generate fresh signed URL if needed
    // Cache for 1 hour
  }
}
```

### **3. MomentsRepository (Performance Optimization)**
```dart
Future<List<Map<String, dynamic>>> getMoments() async {
  // ✅ Fetch moments from database
  final response = await _client.from('moments').select('*');
  
  // ✅ Pre-load video URLs for better performance
  await _videoService.preloadVideoUrls(response);
  
  // ✅ Add display URLs to moment objects
  for (var moment in response) {
    moment['display_video_url'] = await _videoService.getVideoUrl(moment['video_link']);
  }
}
```

### **4. UI Components (Optimized Display)**
```dart
// MomentCard & MomentPage
MomentVideoPlayer(
  // ✅ Use pre-generated URL if available, fallback to file path
  videoPath: moment['display_video_url'] ?? moment['video_link'],
)
```

### **5. MomentVideoPlayer (Robust Playback)**
```dart
class _MomentVideoPlayerState extends State<MomentVideoPlayer> {
  Future<void> _initializeVideo() async {
    // ✅ Always gets fresh URL through VideoService
    final videoUrl = await _videoService.getVideoUrl(widget.videoPath);
    
    // ✅ Handles both file paths and URLs
    // ✅ Error handling and retry logic
    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
  }
}
```

## **Benefits of This Architecture**

### **Performance**
- ✅ **URL Caching**: Reduces Supabase API calls
- ✅ **Pre-loading**: Videos load faster in feeds
- ✅ **Smart Fallbacks**: Always works even if cache fails

### **Reliability**
- ✅ **No Expiring URLs**: Database stores permanent file paths
- ✅ **Auto-Refresh**: URLs refresh automatically when needed
- ✅ **Error Recovery**: Retries and fallback mechanisms

### **Scalability**
- ✅ **Efficient Storage**: Only file paths in database
- ✅ **Reduced API Load**: Cached URL generation
- ✅ **Clean Architecture**: Separation of concerns

## **How It Handles Your Video Example**

**Input**: `48cd6351-dd89-47a5-b462-ae369a277124/moments/moment_48cd6351-dd89-47a5-b462-ae369a277124_1766059127132.mp4`

**Flow**:
1. **MomentCard** receives moment data with `video_link`
2. **Repository** pre-generates `display_video_url` using **VideoService**
3. **MomentVideoPlayer** gets optimized URL or falls back to file path
4. **VideoService** converts to signed URL: `https://hveihxobdippfydfqgti.supabase.co/storage/v1/object/sign/videos/48cd6351-dd89-47a5-b462-ae369a277124/moments/moment_48cd6351-dd89-47a5-b462-ae369a277124_1766059127132.mp4?token=...`
5. **Video plays** smoothly with caching for future requests

## **Network Error Handling**

The system now includes:
- ✅ **NetworkHelper**: Detects and handles network issues
- ✅ **Graceful Degradation**: Works offline with cached URLs
- ✅ **User Feedback**: Clear error messages for connection issues
- ✅ **Automatic Retry**: Retries failed operations

## **File Structure**

```
lib/
├── services/
│   ├── video_service.dart     # Smart URL management & caching
│   └── network_helper.dart    # Network error handling
├── repositories/
│   └── moments_repo.dart      # Database ops with video optimization
├── widgets/
│   ├── moment_card.dart       # Optimized video display
│   └── moment_video_player.dart  # Robust video playback
└── pages/
    └── moment_page.dart       # Full-screen video experience
```

This architecture provides a **production-ready video system** that's:
- 🚀 **Fast**: Cached URLs and pre-loading
- 🛡️ **Reliable**: Error handling and fallbacks  
- 📱 **Smooth**: Optimized for mobile experience
- 🔧 **Maintainable**: Clean, separated concerns
