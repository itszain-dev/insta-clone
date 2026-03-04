import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/widgets/story_ring.dart';
import 'package:instagram_clone_flutter/screens/story_viewer_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/widgets/story_add_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instagram_clone_flutter/stories/stories_notifier.dart';
import 'package:instagram_clone_flutter/feed/feed_notifier.dart';
import 'package:instagram_clone_flutter/services/supabase_video_service.dart';

class StoriesBar extends ConsumerStatefulWidget {
  const StoriesBar({super.key});

  @override
  ConsumerState<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends ConsumerState<StoriesBar> {
  bool? _selfActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storiesProvider.notifier).init();
      _updateSelfActive();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser;
    if (me == null) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(storiesProvider);
    if (!state.initialized && state.isLoading) {
      return const SizedBox(height: 104);
    }
    final items = state.items;
    final viewedSet = state.viewedIds;
    final photoByUid = state.photoByUid;
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final s = items[index];
          final uid = (s['uid'] ?? '').toString();
          final profileImg = (photoByUid[uid] ?? '').isNotEmpty
              ? (photoByUid[uid] ?? '')
              : (s['thumb_url'] ?? '').toString();
          final img = profileImg.isNotEmpty ? profileImg : (s['media_url'] ?? '').toString();
          final uname = s['_self'] == true ? 'Your Story' : (s['username'] ?? '').toString();
          final sid = (s['story_id'] ?? '').toString();
          final viewed = sid.isNotEmpty && viewedSet.contains(sid);
          final isSelf = s['_self'] == true;
          final hasStoryDynamic = isSelf ? (_selfActive ?? sid.isNotEmpty) : true;
          return FutureBuilder<String>(
            future: _resolveStoryAvatarUrl(
              raw: img,
              preferProfile: (photoByUid[uid] ?? '').isNotEmpty,
            ),
            builder: (ctx, snap) {
              final url = snap.data ?? '';
              return StoryRing(
            imageUrl: url,
            username: uname,
            viewed: viewed,
            isSelf: isSelf,
            hasStory: hasStoryDynamic,
            onTap: () async {
              final navigator = Navigator.of(context);
              if (isSelf) {
                final nowIsoTap = DateTime.now().toIso8601String();
                final clientTap = Supabase.instance.client;
                final activeRows = await clientTap
                    .from('stories')
                    .select('story_id')
                    .eq('uid', uid)
                    .gt('expires_at', nowIsoTap)
                    .eq('is_archived', false)
                    .limit(1);
                final hasActive = (activeRows is List && activeRows.isNotEmpty);
                if (!hasActive) {
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
                  if (type == null) return;
                  final file = type == 'video' ? await pickVideo(ImageSource.gallery) : await pickImage(ImageSource.gallery);
                  if (file == null) return;
                  if (!mounted) return;
                  await showModalBottomSheet<bool>(
                    context: context,
                    backgroundColor: Colors.black,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    builder: (_) => StoryAddSheet(file: file, mediaType: type),
                  );
                  await _updateSelfActive();
                  return;
                }
              }
              if (!context.mounted) return;
              final uids = items.map((e) => (e['uid'] ?? '').toString()).toList();
              ref.read(currentPlayingPostIdProvider.notifier).state = null;
              await navigator.push(
                MaterialPageRoute(
                  builder: (_) => StoryViewerScreen(uid: uid, queue: uids, position: index, profileUrl: photoByUid[uid]),
                ),
              );
              ref.read(storiesProvider.notifier).markViewedByUid(uid);
              await _updateSelfActive();
            },
          );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateSelfActive() async {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser;
    if (me == null) return;
    final nowIsoTap = DateTime.now().toIso8601String();
    try {
      final rows = await client
          .from('stories')
          .select('story_id')
          .eq('uid', me.id)
          .gt('expires_at', nowIsoTap)
          .eq('is_archived', false)
          .limit(1);
      final active = (rows is List && rows.isNotEmpty);
      if (mounted) {
        setState(() {
          _selfActive = active;
        });
      }
    } catch (_) {}
  }

  Future<String> _resolveStoryAvatarUrl({required String raw, bool preferProfile = true}) async {
    try {
      if (raw.isEmpty) return '';
      if (!raw.startsWith('http')) {
        final bucket = preferProfile ? 'profilepics' : 'stories';
        final su = await Supabase.instance.client.storage
            .from(bucket)
            .createSignedUrl(raw, 3600)
            .onError((_, __) async => Supabase.instance.client.storage.from(bucket).getPublicUrl(raw));
        return su;
      }
      final svc = SupabaseVideoService();
      final pProfile = svc.extractPathFromPublicUrl('profilepics', raw);
      if (pProfile != null && pProfile.isNotEmpty) {
        final su = await Supabase.instance.client.storage
            .from('profilepics')
            .createSignedUrl(pProfile, 3600)
            .onError((_, __) async => Supabase.instance.client.storage.from('profilepics').getPublicUrl(pProfile));
        return su;
      }
      final pStories = svc.extractPathFromPublicUrl('stories', raw);
      if (pStories != null && pStories.isNotEmpty) {
        final su = await Supabase.instance.client.storage
            .from('stories')
            .createSignedUrl(pStories, 3600)
            .onError((_, __) async => Supabase.instance.client.storage.from('stories').getPublicUrl(pStories));
        return su;
      }
      return raw;
    } catch (_) {
      return raw;
    }
  }
}
