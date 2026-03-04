class Post {
  final String description;
  final String uid;
  final String username;
  final List likes;
  final String postId;
  final DateTime datePublished;
  final String postUrl;
  final String profImage;
  final String mediaType;
  final String thumbUrl;
  final String videoPath;

  const Post(
      {required this.description,
      required this.uid,
      required this.username,
      required this.likes,
      required this.postId,
      required this.datePublished,
      required this.postUrl,
      required this.profImage,
      this.mediaType = 'image',
      this.thumbUrl = '',
      this.videoPath = '',
      });

  Post copyWith({
    String? description,
    String? uid,
    String? username,
    List? likes,
    String? postId,
    DateTime? datePublished,
    String? postUrl,
    String? profImage,
    String? mediaType,
    String? thumbUrl,
    String? videoPath,
  }) {
    return Post(
      description: description ?? this.description,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      likes: likes ?? this.likes,
      postId: postId ?? this.postId,
      datePublished: datePublished ?? this.datePublished,
      postUrl: postUrl ?? this.postUrl,
      profImage: profImage ?? this.profImage,
      mediaType: mediaType ?? this.mediaType,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      videoPath: videoPath ?? this.videoPath,
    );
  }

  static Post fromMap(Map<String, dynamic> snapshot) {
    final pid = snapshot['postId'] ?? snapshot['post_id'] ?? '';
    final created = snapshot['created_at'] ?? snapshot['date_published'];
    final dt = created is String ? DateTime.tryParse(created) ?? DateTime.now() : (created as DateTime? ?? DateTime.now());
    final url = snapshot['postUrl'] ?? snapshot['post_url'] ?? '';
    final img = snapshot['profImage'] ?? snapshot['prof_image'] ?? '';
    final mtype = snapshot['media_type'] ?? 'image';
    final thumb = snapshot['thumb_url'] ?? '';
    final vpath = snapshot['video_path'] ?? '';
    return Post(
      description: snapshot['description'] ?? '',
      uid: snapshot['uid'] ?? '',
      likes: snapshot['likes'] ?? const [],
      postId: pid.toString(),
      datePublished: dt,
      username: snapshot['username'] ?? '',
      postUrl: url.toString(),
      profImage: img.toString(),
      mediaType: mtype.toString(),
      thumbUrl: thumb.toString(),
      videoPath: vpath.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        "description": description,
        "uid": uid,
        "likes": likes,
        "username": username,
        "postId": postId,
        "datePublished": datePublished,
        'postUrl': postUrl,
        'profImage': profImage
      };

  Map<String, dynamic> toDbMap() => {
        'description': description,
        'uid': uid,
        'username': username,
        'likes': likes,
        'post_id': postId,
        'date_published': datePublished.toIso8601String(),
        'post_url': postUrl,
        'prof_image': profImage,
        'media_type': mediaType,
        'thumb_url': thumbUrl,
        'video_path': videoPath,
      };
}
