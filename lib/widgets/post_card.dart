import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as r;
import 'package:instagram_clone_flutter/feed/feed_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/models/user.dart' as model;
import 'package:instagram_clone_flutter/providers/user_provider.dart';
import 'package:instagram_clone_flutter/resources/supabase_methods.dart';
import 'package:instagram_clone_flutter/screens/comments_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/utils/global_variable.dart';
import 'package:instagram_clone_flutter/screens/profile_screen.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/widgets/like_animation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:instagram_clone_flutter/widgets/video_player_widget.dart';
import 'package:instagram_clone_flutter/services/supabase_video_service.dart';

class PostCard extends r.ConsumerStatefulWidget {
  final Map<String, dynamic> snap;
  final ScrollController? scrollController;
  const PostCard({
    Key? key,
    required this.snap,
    this.scrollController,
  }) : super(key: key);

  @override
  r.ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends r.ConsumerState<PostCard> with AutomaticKeepAliveClientMixin<PostCard> {
  int commentLen = 0;
  bool isLikeAnimating = false;
  bool _descExpanded = false;
  bool _saved = false;
  Map<String, dynamic>? _latestComment;
  String? _videoPath;
  bool _shouldPlay = false;
  String? _signedImageUrl;
  bool _resolvingImage = false;
  DateTime? _signedExp;
  String _profImageResolved = '';

  @override
  void initState() {
    super.initState();
    fetchCommentLen();
    _setupVideoPath();
    _setupImageUrl();
    _setupProfImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateVisibility();
    });
    widget.scrollController?.addListener(_onScroll);
  }

  fetchCommentLen() async {
    try {
      final client = Supabase.instance.client;
      final snap = await client
          .from('comments')
          .select()
          .eq('post_id', widget.snap['post_id']);
      final list = snap as List;
      commentLen = list.length;
      if (list.isNotEmpty) {
        list.sort((a, b) {
          final da = DateTime.tryParse(a['date_published'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse(b['date_published'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        _latestComment = list.first;
      }
    } catch (err) {
      showSnackBar(
        context,
        err.toString(),
        variant: SnackBarVariant.error,
      );
    }
    setState(() {});
  }

  String _timeAgo(String? iso) {
    final dt = DateTime.tryParse(iso ?? '') ?? DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dt);
  }

  deletePost(String postId) async {
    try {
      await FireStoreMethods().deletePost(postId);
    } catch (err) {
      showSnackBar(
        context,
        err.toString(),
        variant: SnackBarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final model.User? user = Provider.of<UserProvider>(context).user;
    final width = MediaQuery.of(context).size.width;
    final playingId = ref.watch(currentPlayingPostIdProvider);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: width > webScreenSize ? secondaryColor : mobileBackgroundColor,
        ),
        color: mobileBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Column(
        children: [
          // HEADER SECTION OF THE POST
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 16,
            ).copyWith(right: 0),
            child: Row(
              children: <Widget>[
                InkWell(
                  onTap: () {
                    ref.read(currentPlayingPostIdProvider.notifier).state = null;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          uid: widget.snap['uid'].toString(),
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 18,
                    child: (() {
                      final u = _profImageResolved;
                      if (u.isEmpty) return const Icon(Icons.person);
                      return null;
                    })(),
                    backgroundImage: (() {
                      final u = _profImageResolved;
                      if (u.isEmpty) return null;
                      return NetworkImage(u);
                    })(),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        InkWell(
                          onTap: () {
                            ref.read(currentPlayingPostIdProvider.notifier).state = null;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  uid: widget.snap['uid'].toString(),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            widget.snap['username'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(widget.snap['date_published']?.toString()),
                          style: const TextStyle(color: secondaryColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
          ),
          // IMAGE SECTION OF THE POST
          GestureDetector(
            onDoubleTap: () {
              if (user != null) {
                final prevLikes = List<String>.from(widget.snap['likes'] ?? []);
                final newLikes = List<String>.from(prevLikes);
                if (newLikes.contains(user.uid)) {
                  newLikes.remove(user.uid);
                } else {
                  newLikes.add(user.uid);
                }
                setState(() {
                  widget.snap['likes'] = newLikes;
                  isLikeAnimating = true;
                });
                FireStoreMethods().likePost(
                  widget.snap['post_id'].toString(),
                  user.uid,
                  prevLikes,
                );
              } else {
                showSnackBar(context, 'Sign in to like posts');
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                (() {
                  final url = (widget.snap['post_url'] ?? widget.snap['postUrl'])?.toString();
                  final mtype = (widget.snap['media_type'] ?? 'image').toString();
                  if (mtype == 'video') {
                    return AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: (() {
                          if (_videoPath == null || _videoPath!.isEmpty) {
                            final thumb = (widget.snap['thumb_url'] ?? '').toString();
                            if (thumb.isNotEmpty) {
                              String t = thumb;
                              if (!t.startsWith('http')) {
                                return FutureBuilder<String>(
                                  future: Supabase.instance.client.storage.from('posts').createSignedUrl(t, 3600).onError((_, __) async {
                                    return Supabase.instance.client.storage.from('posts').getPublicUrl(t);
                                  }),
                                  builder: (ctx, snap) {
                                    if (!snap.hasData) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    final su = snap.data ?? '';
                                    if (su.isEmpty) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    return Image.network(
                                      su,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                    );
                                  },
                                );
                              }
                              return Image.network(
                                t,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                              );
                            }
                            return const Center(child: CircularProgressIndicator());
                          }
                          final thumb = (widget.snap['thumb_url'] ?? '').toString();
                          return VideoPlayerWidget(
                            bucket: 'posts',
                            path: _videoPath!,
                            autoplay: true,
                            showControls: false,
                            showCenterPlay: true,
                            shouldPlay: _shouldPlay && (playingId == widget.snap['post_id'].toString()),
                            muted: false,
                            looping: true,
                            placeholder: thumb.isNotEmpty
                                ? (() {
                                    String t = thumb;
                                    if (!t.startsWith('http')) {
                                      return FutureBuilder<String>(
                                        future: Supabase.instance.client.storage.from('posts').createSignedUrl(t, 3600).onError((_, __) async {
                                          return Supabase.instance.client.storage.from('posts').getPublicUrl(t);
                                        }),
                                        builder: (ctx, snap) {
                                          if (!snap.hasData) {
                                            return const Center(child: CircularProgressIndicator());
                                          }
                                          final su = snap.data ?? '';
                                          if (su.isEmpty) {
                                            return const Center(child: CircularProgressIndicator());
                                          }
                                          return Image.network(
                                            su,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const Center(child: CircularProgressIndicator());
                                            },
                                          );
                                        },
                                      );
                                    }
                                    return Image.network(
                                      t,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                    );
                                  })()
                                : null,
                          );
                        })(),
                      ),
                    );
                  }
                  if (url == null || url.isEmpty) {
                    return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 48));
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: (() {
                        final resolved = _signedImageUrl ?? (url.startsWith('http') ? url : '');
                        if ((resolved).isEmpty) {
                          if (_resolvingImage) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 48));
                        }
                        return Image.network(
                          resolved,
                          fit: BoxFit.fitWidth,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        );
                      })(),
                      ),
                    );
                 })(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isLikeAnimating ? 1 : 0,
                  child: LikeAnimation(
                    isAnimating: isLikeAnimating,
                    duration: const Duration(
                      milliseconds: 400,
                    ),
                    onEnd: () {
                      setState(() {
                        isLikeAnimating = false;
                      });
                    },
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 100,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // LIKE, COMMENT SECTION OF THE POST
          Row(
            children: <Widget>[
              LikeAnimation(
                isAnimating: user != null && widget.snap['likes'].contains(user.uid),
                smallLike: true,
                child: IconButton(
                  icon: user != null && widget.snap['likes'].contains(user.uid)
                      ? const Icon(
                          Icons.favorite,
                          color: Colors.red,
                        )
                      : const Icon(
                          Icons.favorite_border,
                        ),
                  onPressed: () {
                    if (user == null) {
                      showSnackBar(context, 'Sign in to like posts');
                      return;
                    }
                    final prevLikes = List<String>.from(widget.snap['likes'] ?? []);
                    final newLikes = List<String>.from(prevLikes);
                    if (newLikes.contains(user.uid)) {
                      newLikes.remove(user.uid);
                    } else {
                      newLikes.add(user.uid);
                    }
                    setState(() {
                      widget.snap['likes'] = newLikes;
                    });
                    FireStoreMethods().likePost(
                      widget.snap['post_id'].toString(),
                      user.uid,
                      prevLikes,
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.comment_outlined,
                ),
                onPressed: () {
                  ref.read(currentPlayingPostIdProvider.notifier).state = null;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CommentsScreen(
                        postId: widget.snap['post_id'].toString(),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                  icon: const Icon(
                    Icons.send,
                  ),
                  onPressed: () {}),
              Expanded(
                  child: Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                    icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
                    onPressed: () {
                      setState(() { _saved = !_saved; });
                    }),
              ))
            ],
          ),
          //DESCRIPTION AND NUMBER OF COMMENTS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DefaultTextStyle(
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(fontWeight: FontWeight.w800),
                    child: Text(
                      '${widget.snap['likes'].length} likes',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 8),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 60),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: primaryColor),
                            children: [
                              TextSpan(
                                text: widget.snap['username'].toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' ${widget.snap['description']}'),
                            ],
                          ),
                          maxLines: _descExpanded ? null : 2,
                          overflow: _descExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                      ),
                      if ((widget.snap['description'] ?? '').toString().isNotEmpty)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => setState(() { _descExpanded = !_descExpanded; }),
                            child: Text(_descExpanded ? 'less' : 'more', style: const TextStyle(color: secondaryColor)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_latestComment != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: primaryColor),
                        children: [
                          TextSpan(text: _latestComment!['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: ' ${_latestComment!['text'] ?? ''}'),
                        ],
                      ),
                    ),
                  ),
                InkWell(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'View all $commentLen comments',
                      style: const TextStyle(
                        fontSize: 16,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                  onTap: () {
                    ref.read(currentPlayingPostIdProvider.notifier).state = null;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CommentsScreen(
                          postId: widget.snap['post_id'].toString(),
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    DateFormat.yMMMd().format(
                      DateTime.tryParse(widget.snap['date_published'].toString()) ?? DateTime.now(),
                    ),
                    style: const TextStyle(
                      color: secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snap['post_url'] != widget.snap['post_url'] || oldWidget.snap['media_type'] != widget.snap['media_type'] || oldWidget.snap['video_path'] != widget.snap['video_path']) {
      _setupVideoPath();
      _setupImageUrl();
    }
    if (oldWidget.snap['prof_image'] != widget.snap['prof_image']) {
      _setupProfImage();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  void _setupVideoPath() {
    final mtype = (widget.snap['media_type'] ?? 'image').toString();
    final url = (widget.snap['post_url'] ?? widget.snap['postUrl'])?.toString() ?? '';
    final path = (widget.snap['video_path'] ?? '')?.toString() ?? '';
    if (mtype == 'video') {
      String? p = path.isNotEmpty ? path : null;
      if ((p == null || p.isEmpty) && url.isNotEmpty && url.startsWith('http')) {
        final svc = SupabaseVideoService();
        p = svc.extractPathFromPublicUrl('posts', url);
      }
      _videoPath = p;
      setState(() {});
    } else {
      _videoPath = null;
    }
  }

  Future<void> _setupProfImage() async {
    final raw = (widget.snap['prof_image'] ?? '')?.toString() ?? '';
    if (raw.isEmpty) {
      _profImageResolved = '';
      setState(() {});
      return;
    }
    if (!raw.startsWith('http')) {
      try {
        final su = await Supabase.instance.client.storage
            .from('profilepics')
            .createSignedUrl(raw, 3600)
            .onError((_, __) async => Supabase.instance.client.storage.from('profilepics').getPublicUrl(raw));
        _profImageResolved = su;
      } catch (_) {
        _profImageResolved = '';
      }
      setState(() {});
      return;
    }
    try {
      final path = SupabaseVideoService().extractPathFromPublicUrl('profilepics', raw);
      if (path != null && path.isNotEmpty) {
        final su = await Supabase.instance.client.storage
            .from('profilepics')
            .createSignedUrl(path, 3600)
            .onError((_, __) async => Supabase.instance.client.storage.from('profilepics').getPublicUrl(path));
        _profImageResolved = su;
      } else {
        _profImageResolved = raw;
      }
    } catch (_) {
      _profImageResolved = raw;
    }
    setState(() {});
  }

  Future<void> _setupImageUrl() async {
    final mtype = (widget.snap['media_type'] ?? 'image').toString();
    final raw = (widget.snap['post_url'] ?? widget.snap['postUrl'])?.toString() ?? '';
    if (mtype != 'image') {
      _signedImageUrl = null;
      _signedExp = null;
      return;
    }
    if (raw.isEmpty) {
      _signedImageUrl = '';
      _signedExp = null;
      return;
    }
    if (raw.startsWith('http')) {
      _signedImageUrl = raw;
      _signedExp = DateTime.now().add(const Duration(seconds: 3600));
      return;
    }
    setState(() { _resolvingImage = true; });
    try {
      final su = await Supabase.instance.client.storage.from('posts').createSignedUrl(raw, 3600).onError((_, __) async {
        return Supabase.instance.client.storage.from('posts').getPublicUrl(raw);
      });
      if (!mounted) return;
      setState(() {
        _signedImageUrl = su;
        _signedExp = DateTime.now().add(const Duration(seconds: 3600));
        _resolvingImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _signedImageUrl = ''; _resolvingImage = false; });
    }
  }

  void _onScroll() {
    _updateVisibility();
  }

  void _updateVisibility() {
    try {
      final render = context.findRenderObject();
      if (render is RenderBox) {
        final size = render.size;
        final topLeft = render.localToGlobal(Offset.zero);
        final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);
        Rect viewport;
        final scrollable = Scrollable.of(context);
        final sv = scrollable?.context.findRenderObject();
        if (sv is RenderBox) {
          final svTopLeft = sv.localToGlobal(Offset.zero);
          viewport = Rect.fromLTWH(svTopLeft.dx, svTopLeft.dy, sv.size.width, sv.size.height);
        } else {
          final screenSize = MediaQuery.of(context).size;
          viewport = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
        }
        final viewportCenterY = viewport.top + viewport.height / 2;
        final itemCenterY = rect.top + rect.height / 2;
        final distance = (itemCenterY - viewportCenterY).abs();
        final startZone = viewport.height * 0.20; // 20% of viewport height
        final stopZone = viewport.height * 0.30; // 30% hysteresis
        bool nextShouldPlay;
        if (_shouldPlay) {
          nextShouldPlay = distance <= (stopZone / 2);
        } else {
          nextShouldPlay = distance <= (startZone / 2);
        }
        final myId = widget.snap['post_id'].toString();
        final currentId = ref.read(currentPlayingPostIdProvider);
        if (nextShouldPlay) {
          if (currentId != myId) {
            ref.read(currentPlayingPostIdProvider.notifier).state = myId;
          }
        } else {
          if (currentId == myId) {
            ref.read(currentPlayingPostIdProvider.notifier).state = null;
          }
        }
        if (nextShouldPlay != _shouldPlay) {
          setState(() { _shouldPlay = nextShouldPlay; });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }
}
