import 'package:instagram_clone_flutter/models/post.dart';

class FeedState {
  final List<Post> posts;
  final bool initialized;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int nextOffset;

  const FeedState({
    required this.posts,
    required this.initialized,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.nextOffset,
  });

  factory FeedState.initial() => const FeedState(
        posts: [],
        initialized: false,
        isLoading: false,
        isLoadingMore: false,
        hasMore: true,
        nextOffset: 0,
      );

  FeedState copyWith({
    List<Post>? posts,
    bool? initialized,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? nextOffset,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}
