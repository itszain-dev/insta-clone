import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/resources/story_methods.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter/widgets/story_add_sheet.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:instagram_clone_flutter/widgets/video_player_widget.dart';
import 'package:instagram_clone_flutter/services/supabase_video_service.dart';

class StoryViewerScreen extends StatefulWidget {
  final String uid;
  final List<String>? queue;
  final int? position;
  final String? profileUrl;
  const StoryViewerScreen({super.key, required this.uid, this.queue, this.position, this.profileUrl});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  int index = 0;
  Timer? _timer;
  final Duration _duration = const Duration(seconds: 5);
  bool _mediaReady = false;
  late String _uid;
  late List<String> _queue;
  int _queuePos = 0;
  String? _profileUrl;
  VideoPlayerController? _controller;
  bool _vidReady = false;
  String? _currentVideoUrl;
  bool _vidError = false;
  Timer? _vidInitTimeout;
  int _seq = 0;
  double _dragY = 0.0;
  double _dismissProgress = 0.0;
  late final AnimationController _dismissCtrl;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _queue = List<String>.from(widget.queue ?? const []);
    _queuePos = (widget.position ?? 0).clamp(0, _queue.isEmpty ? 0 : _queue.length - 1);
    _profileUrl = widget.profileUrl;
    if ((_profileUrl ?? '').isEmpty) {
      _loadProfileUrlFor(_uid);
    }
    _dismissCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))
      ..addListener(() {
        setState(() {
          _dismissProgress = _dismissCtrl.value;
        });
      });
  }

  Future<void> _loadProfileUrlFor(String uid) async {
    final client = Supabase.instance.client;
    try {
      final row = await client.from('users').select('photo_url').eq('uid', uid).limit(1);
      final url = (row is List && row.isNotEmpty) ? (row.first['photo_url'] ?? '').toString() : '';
      if (!mounted) return;
      setState(() { _profileUrl = url; });
    } catch (_) {}
  }

  Future<bool> _advanceToNextUser() async {
    if (_queue.isEmpty) return false;
    final client = Supabase.instance.client;
    final nowIso = DateTime.now().toIso8601String();
    var i = _queuePos + 1;
    while (i < _queue.length) {
      final nextUid = _queue[i];
      final rows = await client
          .from('stories')
          .select('story_id')
          .eq('uid', nextUid)
          .gt('expires_at', nowIso)
          .eq('is_archived', false)
          .limit(1);
      final hasActive = (rows is List && rows.isNotEmpty);
      if (hasActive) {
        if (!mounted) return false;
        _timer?.cancel();
        setState(() {
          _uid = nextUid;
          _queuePos = i;
          index = 0;
          _mediaReady = false;
          _seq += 1;
        });
        _loadProfileUrlFor(nextUid);
        return true;
      }
      i += 1;
    }
    return false;
  }

  void _startTimer(List<Map<String, dynamic>> data) {
    _timer?.cancel();
    final mySeq = _seq;
    _timer = Timer(_duration, () {
      if (!mounted) return;
      if (_seq != mySeq) return;
      if (index < data.length - 1) {
        setState(() { index += 1; _seq += 1; });
        _mediaReady = false;
      } else {
        _advanceToNextUser().then((moved) {
          if (!moved && mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  void _initVideo(String url, List<Map<String, dynamic>> data) {
    if (_currentVideoUrl == url && _controller != null) {
      return;
    }
    _controller?.pause();
    _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _vidReady = false;
    _currentVideoUrl = url;
    _controller!.setLooping(false);
    _controller!.setVolume(0.0);
    _vidError = false;
    _vidInitTimeout?.cancel();
    _vidInitTimeout = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (!_vidReady) {
        setState(() { _vidError = true; });
      }
    });
    _controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() { _vidReady = true; });
      _controller!.play();
      _vidInitTimeout?.cancel();
    }).catchError((_) {});
    _controller!.addListener(() {
      final v = _controller!;
      if (v.value.isInitialized && !v.value.isPlaying && v.value.position >= v.value.duration) {
        if (index < data.length - 1) {
          setState(() { index += 1; });
          _mediaReady = false;
        } else {
          _advanceToNextUser().then((moved) {
            if (!moved && mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      }
    });
  }

  Future<String> _signedUrlFor(String bucket, String input) async {
    final svc = SupabaseVideoService();
    String? path;
    if (input.startsWith('http')) {
      path = svc.extractPathFromPublicUrl(bucket, input);
    } else {
      path = input;
    }
    if (path == null || path.isEmpty) return input;
    try {
      return await svc.signUrl(bucket, path, expiresIn: 3600);
    } catch (_) {
      return input;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.pause();
    _controller?.dispose();
    _dismissCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final nowIso = DateTime.now().toIso8601String();
    final size = MediaQuery.of(context).size;
    final bool isWeb = kIsWeb;
    final double mediaAspect = 9 / 16;
    final double mediaMaxWidth = 420.0;
    final double mediaWidth = isWeb ? math.min(size.height * (9 / 16), mediaMaxWidth) : size.width;
    final double mediaHeight = isWeb ? mediaWidth / mediaAspect : size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_uid),
        future: client
            .from('stories')
            .select()
            .eq('uid', _uid)
            .gt('expires_at', nowIso)
            .eq('is_archived', false)
            .order('created_at', ascending: true),
        builder: (context, snapshot) {
          final data = snapshot.data ?? const [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SafeArea(
              child: Stack(
                children: [
                  const Center(child: CircularProgressIndicator()),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }
          if (data.isEmpty) {
            return SafeArea(
              child: Stack(
                children: [
                  const Center(child: Text('No stories', style: TextStyle(color: Colors.white))),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }
          index = index.clamp(0, data.length - 1);
          final s = data[index];
          final url = (s['media_url'] ?? '').toString();
          final mtype = (s['media_type'] ?? 'image').toString();
          final me = client.auth.currentUser;
          if (me != null) {
            StoryMethods().markViewed(storyId: (s['story_id'] ?? '').toString(), viewerUid: me.id);
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              _timer?.cancel();
              final w = MediaQuery.of(context).size.width;
              if (details.localPosition.dx > w / 2) {
                if (index < data.length - 1) {
                  setState(() { index += 1; _seq += 1; });
                  _mediaReady = false;
                  _dismissCtrl.stop();
                  _dismissCtrl.value = 0.0;
                  _dismissProgress = 0.0;
                } else {
                  _advanceToNextUser().then((moved) {
                    if (!moved && mounted) {
                      Navigator.of(context).pop();
                    }
                  });
                }
              } else {
                if (index > 0) {
                  setState(() { index -= 1; _seq += 1; });
                  _mediaReady = false;
                  _dismissCtrl.stop();
                  _dismissCtrl.value = 0.0;
                  _dismissProgress = 0.0;
                } else {
                  Navigator.of(context).pop();
                }
              }
            },
            onPanStart: (_) {
              _dismissCtrl.stop();
            },
            onPanUpdate: (details) {
              final dy = details.delta.dy;
              if (dy > 0) {
                setState(() {
                  _dragY = (_dragY + dy).clamp(0.0, mediaHeight);
                  _dismissProgress = (_dragY / (mediaHeight == 0 ? 1 : mediaHeight)).clamp(0.0, 1.0);
                });
              }
            },
            onPanEnd: (details) {
              if (_dismissProgress > 0.2) {
                _dismissCtrl.forward(from: _dismissProgress).whenComplete(() {
                  if (mounted) Navigator.of(context).pop();
                });
              } else {
                _dismissCtrl.reverse(from: _dismissProgress).whenComplete(() {
                  if (!mounted) return;
                  setState(() { _dragY = 0.0; _dismissProgress = 0.0; });
                });
              }
            },
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.black)),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 150),
                      offset: Offset(0, _dismissProgress),
                      child: SizedBox(
                        key: ValueKey('${_uid}-$index'),
                        width: mediaWidth,
                        height: mediaHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isWeb ? 12 : 0),
                          child: (() {
                        if (mtype == 'video') {
                          String path = url;
                          if (url.startsWith('http')) {
                            final svc = SupabaseVideoService();
                            final p = svc.extractPathFromPublicUrl('stories', url);
                            if (p != null) path = p;
                          }
                          return VideoPlayerWidget(
                            bucket: 'stories',
                            path: path,
                            autoplay: true,
                            showControls: false,
                            muted: kIsWeb ? true : false,
                            placeholder: FutureBuilder<String>(
                              future: (() {
                                final turl = (s['thumb_url'] ?? '').toString();
                                if (turl.isEmpty) return Future<String>.value('');
                                return _signedUrlFor('stories', turl);
                              })(),
                              builder: (ctx, snap) {
                                final u = snap.data ?? '';
                                if (u.isEmpty) return const Center(child: CircularProgressIndicator());
                                return Image.network(u, fit: BoxFit.contain, alignment: Alignment.center);
                              },
                            ),
                            onEnded: () {
                              if (index < data.length - 1) {
                                setState(() { index += 1; });
                                _mediaReady = false;
                              } else {
                                _advanceToNextUser().then((moved) {
                                  if (!moved && mounted) {
                                    Navigator.of(context).pop();
                                  }
                                });
                              }
                            },
                          );
                        }
                        return FutureBuilder<String>(
                          future: _signedUrlFor('stories', url),
                          builder: (ctx, snap) {
                            final u = snap.data ?? '';
                            if (u.isEmpty) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            return Image.network(
                              u,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (frame != null && !_mediaReady) {
                                  _mediaReady = true;
                                  _startTimer(data);
                                }
                                return child;
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                final expected = loadingProgress.expectedTotalBytes ?? 1;
                                final loaded = loadingProgress.cumulativeBytesLoaded;
                                final pct = loaded / expected;
                                return Center(
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: CircularProgressIndicator(value: pct, color: blueColor),
                                  ),
                                );
                              },
                            );
                          },
                        );
                        })(),
                      ),
                    ),
                  ),
                  ),
                ),
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerMove: (event) {
                      final dy = event.delta.dy;
                      if (dy > 0) {
                        setState(() {
                          _dragY = (_dragY + dy).clamp(0.0, mediaHeight);
                          _dismissProgress = (_dragY / (mediaHeight == 0 ? 1 : mediaHeight)).clamp(0.0, 1.0);
                        });
                      }
                    },
                    onPointerUp: (_) {
                      if (_dismissProgress > 0.2) {
                        _dismissCtrl.forward(from: _dismissProgress).whenComplete(() {
                          if (mounted) Navigator.of(context).pop();
                        });
                      } else {
                        _dismissCtrl.reverse(from: _dismissProgress).whenComplete(() {
                          if (!mounted) return;
                          setState(() { _dragY = 0.0; _dismissProgress = 0.0; });
                        });
                      }
                    },
                  ),
                ),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isWeb ? mediaWidth : double.infinity),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                            child: Row(
                              children: List.generate(data.length, (i) {
                                final active = i <= index;
                                return Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: active ? blueColor : secondaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isWeb ? mediaWidth : double.infinity),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: NetworkImage(
                                    ((_profileUrl ?? '').isNotEmpty
                                        ? _profileUrl!
                                        : ((s['thumb_url'] ?? '').toString().isNotEmpty
                                            ? (s['thumb_url'] ?? '').toString()
                                            : (s['media_url'] ?? '').toString())),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (s['username'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isWeb ? mediaWidth : double.infinity),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (me != null && (s['uid'] ?? '').toString() == me.id) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                    onPressed: () async {
                                      final sid = (s['story_id'] ?? '').toString();
                                      final mediaUrl = (s['media_url'] ?? '').toString();
                                      _timer?.cancel();
                                      final confirmed = await showModalBottomSheet<bool>(
                                        context: context,
                                        backgroundColor: mobileBackgroundColor,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                        ),
                                        builder: (ctx) {
                                          return SafeArea(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  const Text('Delete story?', style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.w600)),
                                                  const SizedBox(height: 8),
                                                  const Text('This will remove the story for everyone.', style: TextStyle(color: secondaryColor)),
                                                  const SizedBox(height: 16),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: OutlinedButton(
                                                          onPressed: () => Navigator.pop(ctx, false),
                                                          child: const Text('Cancel'),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text('Delete'),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                      if (confirmed == true) {
                                        final res = await StoryMethods().deleteStory(storyId: sid, mediaUrl: mediaUrl);
                                        if (!mounted) return;
                                        if (res == 'success') {
                                          showSnackBar(context, 'Story deleted', variant: SnackBarVariant.success);
                                          _mediaReady = false;
                                          if (index >= data.length - 1) {
                                            _advanceToNextUser().then((moved) {
                                              if (!moved && mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            });
                                          } else {
                                            setState(() {});
                                          }
                                        } else {
                                          showSnackBar(context, res, variant: SnackBarVariant.error);
                                        }
                                      } else {
                                        _startTimer(data);
                                      }
                                    },
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Delete Story'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: blueColor,
                                      foregroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                    onPressed: () async {
                                      _timer?.cancel();
                                      final type = await showDialog<String>(
                                        context: context,
                                        builder: (ctx) {
                                          return SimpleDialog(
                                            title: const Text('Add to your story'),
                                            children: [
                                              SimpleDialogOption(
                                                padding: const EdgeInsets.all(20),
                                                child: const Text('Photo from gallery'),
                                                onPressed: () => Navigator.pop(ctx, 'image'),
                                              ),
                                              SimpleDialogOption(
                                                padding: const EdgeInsets.all(20),
                                                child: const Text('Video from gallery'),
                                                onPressed: () => Navigator.pop(ctx, 'video'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (type == null) { _startTimer(data); return; }
                                      final file = type == 'video' ? await pickVideo(ImageSource.gallery) : await pickImage(ImageSource.gallery);
                                      if (file == null) { _startTimer(data); return; }
                                      if (!mounted) return;
                                      await showModalBottomSheet(
                                        context: context,
                                        backgroundColor: mobileBackgroundColor,
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                        builder: (_) => StoryAddSheet(file: file, mediaType: type),
                                      );
                                      if (mounted) setState(() { _mediaReady = false; });
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Story'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
