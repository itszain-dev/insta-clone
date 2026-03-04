import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instagram_clone_flutter/feed/feed_state.dart';
import 'package:instagram_clone_flutter/feed/post_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/models/post.dart';
import 'package:instagram_clone_flutter/services/video_processing_service.dart';

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  final client = Supabase.instance.client;
  final repo = PostRepository(client: client);
  return FeedNotifier(repo: repo);
});

final currentPlayingPostIdProvider = StateProvider<String?>((ref) => null);

class FeedNotifier extends StateNotifier<FeedState> {
  final PostRepository repo;
  final int pageSize;
  FeedNotifier({required this.repo, this.pageSize = 10}) : super(FeedState.initial());

  Future<void> init() async {
    if (state.initialized) return;
    state = state.copyWith(isLoading: true);
    final items = await repo.fetchPage(offset: 0, limit: pageSize);
    items.shuffle();
    state = state.copyWith(
      posts: items,
      initialized: true,
      isLoading: false,
      hasMore: items.length == pageSize,
      nextOffset: items.length,
    );
    _backfillMissingThumbs(items);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    final items = await repo.fetchPage(offset: state.nextOffset, limit: pageSize);
    items.shuffle();
    final combined = [...state.posts, ...items];
    state = state.copyWith(
      posts: combined,
      isLoadingMore: false,
      hasMore: items.length == pageSize,
      nextOffset: state.nextOffset + items.length,
    );
    _backfillMissingThumbs(items);
  }

  Future<void> refresh() async {
    state = FeedState.initial().copyWith(isLoading: true);
    final items = await repo.fetchPage(offset: 0, limit: pageSize);
    items.shuffle();
    state = state.copyWith(
      posts: items,
      initialized: true,
      isLoading: false,
      hasMore: items.length == pageSize,
      nextOffset: items.length,
    );
  }
  Future<void> _backfillMissingThumbs(List<Post> items) async {
    try {
      final client = Supabase.instance.client;
      for (final p in items) {
        if (p.mediaType == 'video' && (p.thumbUrl.isEmpty)) {
          final path = p.videoPath;
          if (path.isEmpty) continue;
          try {
            final data = await VideoProcessingService().process(bucket: 'posts', path: path, quality: '720p');
            final processedPath = (data['processed_path'] ?? '').toString();
            final tUrl = (data['thumb_url'] ?? '').toString();
            final updates = <String, dynamic>{};
            if (processedPath.isNotEmpty) updates['video_path'] = processedPath;
            if (tUrl.isNotEmpty) {
              updates['thumb_url'] = tUrl;
              if (p.postUrl.isEmpty) updates['post_url'] = tUrl;
            }
            if (updates.isNotEmpty) {
              await client.from('posts').update(updates).eq('post_id', p.postId);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
