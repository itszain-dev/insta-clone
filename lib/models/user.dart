class User {
  final String email;
  final String uid;
  final String photoUrl;
  final String username;
  final String bio;
  final List followers;
  final List following;

  const User(
      {required this.username,
      required this.uid,
      required this.photoUrl,
      required this.email,
      required this.bio,
      required this.followers,
      required this.following});

  static User fromMap(Map<String, dynamic> snapshot) {
    return User(
      username: snapshot["username"],
      uid: (snapshot["uid"] ?? '').toString(),
      email: snapshot["email"],
      photoUrl: snapshot["photoUrl"] ?? snapshot["photo_url"] ?? '',
      bio: snapshot["bio"] ?? '',
      followers: snapshot["followers"] ?? [],
      following: snapshot["following"] ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        "username": username,
        "uid": uid,
        "email": email,
        "photoUrl": photoUrl,
        "bio": bio,
        "followers": followers,
        "following": following,
      };
}
