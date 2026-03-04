import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:instagram_clone_flutter/services/supabase_video_service.dart';
import 'package:instagram_clone_flutter/widgets/video_controller_factory.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String bucket;
  final String path;
  final bool autoplay;
  final bool showControls;
  final VoidCallback? onEnded;
  final Widget? placeholder;
  final bool muted;
  final String? filePath;
  final bool showCenterPlay;
  final bool shouldPlay;
  final bool looping;
  const VideoPlayerWidget({super.key, required this.bucket, required this.path, this.autoplay = true, this.showControls = true, this.onEnded, this.placeholder, this.muted = true, this.filePath, this.showCenterPlay = false, this.shouldPlay = true, this.looping = false});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _v;
  ChewieController? _c;
  bool _loading = true;
  bool _error = false;
  Timer? _initTimeout;
  bool _didFireEnd = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.shouldPlay || widget.autoplay) {
      _init();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = _v;
    if (!oldWidget.shouldPlay && widget.shouldPlay && !_initialized) {
      _init();
      return;
    }
    if (v != null && v.value.isInitialized) {
      if (!widget.shouldPlay && v.value.isPlaying) {
        v.pause();
      } else if (widget.shouldPlay && !v.value.isPlaying) {
        if (mounted) v.play();
      }
    }
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = false; });
    try {
      if ((widget.filePath ?? '').isNotEmpty) {
        if (kIsWeb) {
          throw Exception('Local file playback not supported on web');
        }
        _v = createVideoController(filePath: widget.filePath, url: '');
      } else {
        final svc = SupabaseVideoService();
        final url = await svc.signUrl(widget.bucket, widget.path, expiresIn: 3600);
        _v = createVideoController(filePath: null, url: url);
        unawaited(DefaultCacheManager().downloadFile(url));
      }
      _v!.setVolume((kIsWeb || widget.muted) ? 0.0 : 1.0);
      _initTimeout?.cancel();
      _initTimeout = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        if (!_v!.value.isInitialized) {
          setState(() { _error = true; });
        }
      });
      await _v!.initialize();
      _initialized = true;
      _didFireEnd = false;
      _v!.addListener(() {
        final v = _v!;
        if (v.value.isInitialized && !v.value.isPlaying && v.value.position >= v.value.duration && !_didFireEnd) {
          _didFireEnd = true;
          widget.onEnded?.call();
        }
      });
      _c = ChewieController(
        videoPlayerController: _v!,
        autoInitialize: true,
        autoPlay: false,
        looping: widget.looping,
        showControls: widget.showControls,
        allowMuting: widget.showControls,
        allowFullScreen: widget.showControls && !kIsWeb,
      );
      setState(() { _loading = false; });
      if (widget.autoplay && widget.shouldPlay) {
        _v!.play();
      } else {
        _v!.pause();
      }
    } catch (_) {
      setState(() { _error = true; });
    } finally {
      _initTimeout?.cancel();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    _v?.pause();
    _v?.dispose();
    _initTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      if (widget.placeholder != null) return widget.placeholder!;
      return const Center(child: CircularProgressIndicator());
    }
    if (_error || _v == null || _c == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.white70),
            const SizedBox(height: 8),
            TextButton(onPressed: _init, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (!widget.showCenterPlay) {
      return Chewie(controller: _c!);
    }
    final isPlaying = _v!.value.isPlaying;
    return Stack(
      alignment: Alignment.center,
      children: [
        Chewie(controller: _c!),
        GestureDetector(
          onTap: () {
            if (_v!.value.isPlaying) {
              _v!.pause();
            } else {
              _v!.play();
            }
            setState(() {});
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
            child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
          ),
        ),
      ],
    );
  }
}
