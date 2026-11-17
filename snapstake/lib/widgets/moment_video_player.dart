import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/video_service.dart';
import '../app_colors.dart';

/// Custom video player widget that handles Supabase video URLs
/// Uses VideoService for efficient URL management and caching
class MomentVideoPlayer extends StatefulWidget {
  final String videoPath;
  final bool autoPlay;
  final bool showControls;
  final BoxFit fit;
  final bool adaptiveFrame;
  final double portraitFrameAspectRatio;
  final double landscapeFrameAspectRatio;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const MomentVideoPlayer({
    super.key,
    required this.videoPath,
    this.autoPlay = false,
    this.showControls = true,
    this.fit = BoxFit.contain,
    this.adaptiveFrame = false,
    this.portraitFrameAspectRatio = 3 / 4,
    this.landscapeFrameAspectRatio = 16 / 9,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<MomentVideoPlayer> createState() => _MomentVideoPlayerState();
}

class _MomentVideoPlayerState extends State<MomentVideoPlayer> {
  VideoPlayerController? _controller;
  final VideoService _videoService = VideoService();
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Get a fresh video URL from the service
      final videoUrl = await _videoService.getVideoUrl(widget.videoPath);

      if (videoUrl == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load video';
        });
        return;
      }

      // Initialize video player with the URL
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await _controller!.initialize();

      if (widget.autoPlay) {
        await _controller!.play();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      print('❌ Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _buildFriendlyErrorMessage(e);
        });
      }
    }
  }

  String _buildFriendlyErrorMessage(Object error) {
    final text = error.toString();

    if (text.contains('OSStatus error -9405') ||
        text.contains('operation could not be completed')) {
      return 'This video format is not supported on this device.';
    }

    if (text.contains('403') || text.contains('401')) {
      return 'Video link expired. Please tap Retry.';
    }

    return 'Failed to load video. Please tap Retry.';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return _buildLoadingWidget();
    }

    final videoSize = _controller!.value.size;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: videoSize.width,
              height: videoSize.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        if (widget.showControls) _buildVideoControls(),
      ],
    );
  }

  Widget _buildVideoControls() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
              setState(() {});
            },
            icon: Icon(
              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.primary,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              _controller!.setVolume(
                _controller!.value.volume == 0 ? 1.0 : 0.0,
              );
              setState(() {});
            },
            icon: Icon(
              _controller!.value.volume == 0
                  ? Icons.volume_off
                  : Icons.volume_up,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Failed to load video',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _initializeVideo,
              child: const Text(
                'Retry',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _getFrameAspectRatio() {
    if (!widget.adaptiveFrame || widget.height != null) {
      return null;
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return widget.portraitFrameAspectRatio;
    }

    final sourceAspectRatio = _controller!.value.aspectRatio;
    return sourceAspectRatio >= 1
        ? widget.landscapeFrameAspectRatio
        : widget.portraitFrameAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = _buildLoadingWidget();
    } else if (_hasError) {
      content = _buildErrorWidget();
    } else {
      content = _buildVideoPlayer();
    }

    final frameAspectRatio = _getFrameAspectRatio();
    if (frameAspectRatio != null) {
      content = AspectRatio(aspectRatio: frameAspectRatio, child: content);
    }

    if (widget.width != null || widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      child: content,
    );
  }
}
