import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/resources/supabase_methods.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/widgets/video_player_widget.dart';
import 'package:instagram_clone_flutter/services/supabase_video_service.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String imageUrl;
  final String description;
  final String ownerUid;
  final String mediaType;
  final String postUrl;
  final String thumbUrl;
  final String videoPath;
  const PostDetailScreen({
    Key? key,
    required this.postId,
    required this.imageUrl,
    required this.description,
    required this.ownerUid,
    this.mediaType = 'image',
    this.postUrl = '',
    this.thumbUrl = '',
    this.videoPath = '',
  }) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() { _deleting = true; });
    try {
      final res = await FireStoreMethods().deletePost(widget.postId);
      if (res == 'success') {
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        showSnackBar(context, res, variant: SnackBarVariant.error);
      }
    } catch (e) {
      showSnackBar(context, e.toString(), variant: SnackBarVariant.error);
    } finally {
      if (mounted) setState(() { _deleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final canDelete = me == widget.ownerUid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text('Post'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: (() {
                  if (widget.mediaType == 'video') {
                    String path = widget.videoPath.isNotEmpty ? widget.videoPath : '';
                    if (path.isEmpty) {
                      final url = widget.postUrl.isNotEmpty ? widget.postUrl : widget.imageUrl;
                      if (url.startsWith('http')) {
                        final svc = SupabaseVideoService();
                        final p = svc.extractPathFromPublicUrl('posts', url);
                        if (p != null) path = p;
                      }
                    }
                    if (path.isEmpty) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.thumbUrl.isNotEmpty)
                            (() {
                              final t = widget.thumbUrl;
                              if (t.startsWith('http')) return Image.network(t, fit: BoxFit.cover);
                              return FutureBuilder<String>(
                                future: Supabase.instance.client.storage.from('posts').createSignedUrl(t, 3600).onError((_, __) async {
                                  return Supabase.instance.client.storage.from('posts').getPublicUrl(t);
                                }),
                                builder: (ctx, snap) {
                                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                  final su = snap.data ?? '';
                                  if (su.isEmpty) return const SizedBox.shrink();
                                  return Image.network(su, fit: BoxFit.cover);
                                },
                              );
                            })(),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }
                    return VideoPlayerWidget(
                      bucket: 'posts',
                      path: path,
                      autoplay: true,
                      showControls: true,
                      placeholder: (() {
                        final t = widget.thumbUrl;
                        if (t.isEmpty) return null;
                        if (t.startsWith('http')) return Image.network(t, fit: BoxFit.cover);
                        return FutureBuilder<String>(
                          future: Supabase.instance.client.storage.from('posts').createSignedUrl(t, 3600).onError((_, __) async {
                            return Supabase.instance.client.storage.from('posts').getPublicUrl(t);
                          }),
                          builder: (ctx, snap) {
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                            final su = snap.data ?? '';
                            if (su.isEmpty) return const SizedBox.shrink();
                            return Image.network(su, fit: BoxFit.cover);
                          },
                        );
                      })(),
                    );
                  }
                  final u = widget.imageUrl;
                  if (u.startsWith('http')) {
                    return Image.network(u, fit: BoxFit.cover);
                  }
                  return FutureBuilder<String>(
                    future: Supabase.instance.client.storage.from('posts').createSignedUrl(u, 3600).onError((_, __) async {
                      return Supabase.instance.client.storage.from('posts').getPublicUrl(u);
                    }),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final su = snap.data ?? '';
                      if (su.isEmpty) return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                      return Image.network(su, fit: BoxFit.cover);
                    },
                  );
                })(),
              ),
            ),
          ),
          if (widget.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.description),
            ),
          const SizedBox(height: 24),
          if (canDelete)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _deleting
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: mobileBackgroundColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text('Delete post?', style: TextStyle(color: primaryColor)),
                            content: const Text('This action cannot be undone.', style: TextStyle(color: secondaryColor)),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: secondaryColor),
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _delete();
                        }
                      },
                icon: _deleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('Delete post'),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
