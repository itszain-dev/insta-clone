import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/services/supabase_video_service.dart';
import 'stories_state.dart';

final storiesProvider = StateNotifierProvider<StoriesNotifier, StoriesState>((ref) {
  final client = Supabase.instance.client;
  return StoriesNotifier(client: client);
});

class StoriesNotifier extends StateNotifier<StoriesState> {
  final SupabaseClient client;
  StoriesNotifier({required this.client}) : super(StoriesState.initial());

  Future<void> init() async {
    if (state.initialized) return;
    await _load();
  }

  Future<void> refresh() async {
    state = StoriesState.initial().copyWith(isLoading: true);
    await _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final me = client.auth.currentUser;
    if (me == null) {
      state = state.copyWith(items: const [], viewedIds: {}, photoByUid: const {}, initialized: true, isLoading: false);
      return;
    }

    try {
      final userRow = await client.from('users').select('following, username, photo_url').eq('uid', me.id).single();
      final following = List<String>.from(userRow['following'] ?? const []);
      final ids = <String>{...following, me.id};
      final nowIso = DateTime.now().toIso8601String();

      final storiesRows = await client
          .from('stories')
          .select()
          .or(ids.map((e) => 'uid.eq.$e').join(','))
          .gt('expires_at', nowIso)
          .eq('is_archived', false)
          .order('created_at', ascending: false);

      final latestByUser = <String, Map<String, dynamic>>{};
      for (final s in (storiesRows as List)) {
        final uid = (s['uid'] ?? '').toString();
        if (!latestByUser.containsKey(uid)) {
          latestByUser[uid] = s as Map<String, dynamic>;
        }
      }
      final storyIds = latestByUser.values.map((e) => (e['story_id'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
      final viewedSet = <String>{};
      if (storyIds.isNotEmpty) {
        final viewsRows = await client
            .from('story_views')
            .select('story_id')
            .eq('viewer_uid', me.id)
            .or(storyIds.map((e) => 'story_id.eq.$e').join(','));
        for (final v in (viewsRows as List)) {
          viewedSet.add((v['story_id'] ?? '').toString());
        }
      }

      final items = <Map<String, dynamic>>[];
      final selfHasStory = latestByUser.containsKey(me.id);
      final selfImg = (userRow['photo_url'] ?? '').toString();
      items.add({
        'uid': me.id,
        'username': (userRow['username'] ?? 'You').toString(),
        'story_id': latestByUser[me.id]?['story_id'] ?? '',
        'thumb_url': selfImg,
        'media_url': latestByUser[me.id]?['media_url'] ?? selfImg,
        '_self': true,
        '_has': selfHasStory,
      });
      items.addAll(latestByUser.values.where((e) => (e['uid'] ?? '').toString() != me.id));

      final userUids = items.map((e) => (e['uid'] ?? '').toString()).toSet().toList();
      final photoByUid = <String, String>{};
      if (userUids.isNotEmpty) {
        final usersRows = await client.from('users').select('uid, photo_url').or(userUids.map((e) => 'uid.eq.$e').join(','));
        for (final u in (usersRows as List)) {
          final uid = (u['uid'] ?? '').toString();
          final raw = (u['photo_url'] ?? '').toString();
          String url = '';
          if (raw.isNotEmpty) {
            if (!raw.startsWith('http')) {
              try {
                url = await client.storage.from('profilepics').createSignedUrl(raw, 3600).onError((_, __) async {
                  return client.storage.from('profilepics').getPublicUrl(raw);
                });
              } catch (_) {
                url = '';
              }
            } else {
              final path = SupabaseVideoService().extractPathFromPublicUrl('profilepics', raw);
              if (path != null && path.isNotEmpty) {
                try {
                  url = await client.storage.from('profilepics').createSignedUrl(path, 3600).onError((_, __) async {
                    return client.storage.from('profilepics').getPublicUrl(path);
                  });
                } catch (_) {
                  url = raw;
                }
              } else {
                url = raw;
              }
            }
          }
          photoByUid[uid] = url;
        }
      }

      state = state.copyWith(
        items: items,
        viewedIds: viewedSet,
        photoByUid: photoByUid,
        initialized: true,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(initialized: true, isLoading: false);
    }
  }

  void markViewedByUid(String uid) {
    try {
      final sid = state.items.firstWhere((e) => (e['uid'] ?? '').toString() == uid)['story_id']?.toString() ?? '';
      if (sid.isEmpty) return;
      final updated = {...state.viewedIds, sid};
      state = state.copyWith(viewedIds: updated);
    } catch (_) {}
  }
}
