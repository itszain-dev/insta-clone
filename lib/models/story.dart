class Story {
  final String storyId;
  final String uid;
  final String username;
  final String mediaUrl;
  final String mediaType;
  final String thumbUrl;
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isArchived;
  final int viewsCount;

  const Story({
    required this.storyId,
    required this.uid,
    required this.username,
    required this.mediaUrl,
    required this.mediaType,
    required this.thumbUrl,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.isArchived,
    required this.viewsCount,
  });

  static Story fromMap(Map<String, dynamic> snapshot) {
    final sid = snapshot['story_id'] ?? snapshot['storyId'] ?? '';
    final created = snapshot['created_at'];
    final expires = snapshot['expires_at'];
    final createdDt = created is String
        ? DateTime.tryParse(created) ?? DateTime.now()
        : (created as DateTime? ?? DateTime.now());
    final expiresDt = expires is String
        ? DateTime.tryParse(expires) ?? DateTime.now()
        : (expires as DateTime? ?? DateTime.now());
    return Story(
      storyId: sid.toString(),
      uid: (snapshot['uid'] ?? '').toString(),
      username: (snapshot['username'] ?? '').toString(),
      mediaUrl: (snapshot['media_url'] ?? snapshot['mediaUrl'] ?? '').toString(),
      mediaType: (snapshot['media_type'] ?? snapshot['mediaType'] ?? 'image').toString(),
      thumbUrl: (snapshot['thumb_url'] ?? snapshot['thumbUrl'] ?? '').toString(),
      caption: (snapshot['caption'] ?? '').toString(),
      createdAt: createdDt,
      expiresAt: expiresDt,
      isArchived: (snapshot['is_archived'] ?? snapshot['isArchived'] ?? false) as bool,
      viewsCount: (snapshot['views_count'] ?? snapshot['viewsCount'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'story_id': storyId,
        'uid': uid,
        'username': username,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'thumb_url': thumbUrl,
        'caption': caption,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_archived': isArchived,
        'views_count': viewsCount,
      };
}

