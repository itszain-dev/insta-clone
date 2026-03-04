class StoriesState {
  final List<Map<String, dynamic>> items;
  final Set<String> viewedIds;
  final Map<String, String> photoByUid;
  final bool initialized;
  final bool isLoading;

  const StoriesState({
    required this.items,
    required this.viewedIds,
    required this.photoByUid,
    required this.initialized,
    required this.isLoading,
  });

  factory StoriesState.initial() => const StoriesState(
        items: [],
        viewedIds: {},
        photoByUid: {},
        initialized: false,
        isLoading: false,
      );

  StoriesState copyWith({
    List<Map<String, dynamic>>? items,
    Set<String>? viewedIds,
    Map<String, String>? photoByUid,
    bool? initialized,
    bool? isLoading,
  }) {
    return StoriesState(
      items: items ?? this.items,
      viewedIds: viewedIds ?? this.viewedIds,
      photoByUid: photoByUid ?? this.photoByUid,
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

