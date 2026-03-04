import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/resources/auth_methods.dart';
import 'package:instagram_clone_flutter/resources/supabase_methods.dart';
import 'package:instagram_clone_flutter/screens/login_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/utils/global_variable.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/screens/post_detail_screen.dart';
import 'package:instagram_clone_flutter/widgets/follow_button.dart';
import 'package:instagram_clone_flutter/services/connectivity_service.dart';
import 'package:instagram_clone_flutter/services/supabase_video_service.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  var userData = {};
  int postLen = 0;
  int followers = 0;
  int following = 0;
  bool isFollowing = false;
  bool isLoading = false;
  String _resolvedPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    getData();
    ConnectivityService.instance.isOnline.addListener(_onOnlineChanged);
  }

  void _onOnlineChanged() {
    if (ConnectivityService.instance.isOnline.value) {
      getData();
    }
  }

  getData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final userSnap = await Supabase.instance.client
          .from('users')
          .select()
          .eq('uid', widget.uid)
          .single();

      // get post lENGTH
      final postSnap = await Supabase.instance.client
          .from('posts')
          .select('post_id')
          .eq('uid', widget.uid);

      postLen = (postSnap as List).length;
      userData = userSnap;
      followers = (userSnap['followers'] as List).length;
      following = (userSnap['following'] as List).length;
      final me = Supabase.instance.client.auth.currentUser;
      isFollowing = me != null && (userSnap['followers'] as List).contains(me.id);
      final rawUrl = ((userSnap['photo_url'] ?? userSnap['photoUrl']) ?? '').toString();
      _resolvedPhotoUrl = await _resolveProfilePhotoUrl(rawUrl);
      setState(() {});
    } catch (e) {
      showSnackBar(
        context,
        e.toString(),
        variant: SnackBarVariant.error,
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<String> _resolveProfilePhotoUrl(String raw) async {
    try {
      if (raw.isEmpty) return '';
      // If raw is already a path (not starting with http), sign it.
      if (!raw.startsWith('http')) {
        final signed = await Supabase.instance.client.storage
            .from('profilepics')
            .createSignedUrl(raw, 3600)
            .onError((_, __) async => Supabase.instance.client.storage.from('profilepics').getPublicUrl(raw));
        return signed;
      }
      // If raw is a public URL, try to extract the path and sign (works for private buckets too).
      final path = SupabaseVideoService().extractPathFromPublicUrl('profilepics', raw);
      if (path != null && path.isNotEmpty) {
        final signed = await Supabase.instance.client.storage
            .from('profilepics')
            .createSignedUrl(path, 3600)
            .onError((_, __) async => Supabase.instance.client.storage.from('profilepics').getPublicUrl(path));
        return signed;
      }
      return raw;
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Scaffold(
            appBar: AppBar(
              backgroundColor: mobileBackgroundColor,
              title: Text(
                (userData['username'] ?? '').toString(),
              ),
              centerTitle: false,
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isWeb = constraints.maxWidth > webScreenSize;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWeb ? 900 : double.infinity,
                    ),
                    child: ListView(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWeb ? 32 : 16,
                            vertical: 16,
                          ),
                          child: Column(
                            children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: (() {
                              final url = _resolvedPhotoUrl;
                              if (url.isEmpty) return const Icon(Icons.person);
                              return null;
                            })(),
                            backgroundImage: (() {
                              final url = _resolvedPhotoUrl;
                              if (url.isEmpty) return null;
                              return NetworkImage(url);
                            })(),
                            radius: 40,
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    buildStatColumn(postLen, "posts"),
                                    buildStatColumn(followers, "followers"),
                                    buildStatColumn(following, "following"),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Supabase.instance.client.auth.currentUser?.id ==
                                            widget.uid
                                        ? FollowButton(
                                            text: 'Sign Out',
                                            backgroundColor:
                                                mobileBackgroundColor,
                                            textColor: primaryColor,
                                            borderColor: Colors.grey,
                                            function: () async {
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  backgroundColor: mobileBackgroundColor,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  title: const Text('Sign out?', style: TextStyle(color: primaryColor)),
                                                  content: const Text(
                                                    'You will be returned to the login screen.',
                                                    style: TextStyle(color: secondaryColor),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      style: TextButton.styleFrom(foregroundColor: secondaryColor),
                                                      onPressed: () => Navigator.of(ctx).pop(false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      style: TextButton.styleFrom(foregroundColor: blueColor),
                                                      onPressed: () => Navigator.of(ctx).pop(true),
                                                      child: const Text('Sign out'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirmed == true) {
                                                await AuthMethods().signOut();
                                                if (context.mounted) {
                                                  Navigator.of(context)
                                                      .pushReplacement(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          const LoginScreen(),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          )
                                        : isFollowing
                                            ? FollowButton(
                                                text: 'Unfollow',
                                                backgroundColor: Colors.white,
                                                textColor: Colors.black,
                                                borderColor: Colors.grey,
                                                function: () async {
                                                  final me = Supabase
                                                      .instance
                                                      .client
                                                      .auth
                                                      .currentUser;
                                                  if (me == null) return;
                                                  await FireStoreMethods()
                                                      .followUser(
                                                    me.id,
                                                    userData['uid'],
                                                  );

                                                  setState(() {
                                                    isFollowing = false;
                                                    followers--;
                                                  });
                                                },
                                              )
                                            : FollowButton(
                                                text: 'Follow',
                                                backgroundColor: Colors.blue,
                                                textColor: Colors.white,
                                                borderColor: Colors.blue,
                                                function: () async {
                                                  final me = Supabase
                                                      .instance
                                                      .client
                                                      .auth
                                                      .currentUser;
                                                  if (me == null) return;
                                                  await FireStoreMethods()
                                                      .followUser(
                                                    me.id,
                                                    userData['uid'],
                                                  );

                                                  setState(() {
                                                    isFollowing = true;
                                                    followers++;
                                                  });
                                                },
                                              )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(
                          top: 15,
                        ),
                        child: Text(
                          (userData['username'] ?? '').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(
                          top: 1,
                        ),
                        child: Text(
                          (userData['bio'] ?? '').toString(),
                        ),
                      ),
                    ],
                  ),
                        ),
                        const Divider(),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: Supabase.instance.client
                              .from('posts')
                              .select('post_id, post_url, description, media_type, thumb_url, video_path, date_published')
                              .eq('uid', widget.uid)
                              .order('date_published', ascending: false),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return const Center(child: Text('Unable to load posts'));
                            }
                            final items = snapshot.data ?? const [];
                            if (items.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 48),
                                  child: Text('No post yet'),
                                ),
                              );
                            }
                            return GridView.builder(
                              shrinkWrap: true,
                              itemCount: items.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isWeb ? 5 : 3,
                                crossAxisSpacing: 5,
                                mainAxisSpacing: 1.5,
                                childAspectRatio: 1,
                              ),
                              itemBuilder: (context, index) {
                                final snap = items[index];
                                final mtype = (snap['media_type'] ?? 'image').toString();
                                String url;
                                if (mtype == 'video') {
                                  final thumb = (snap['thumb_url'] ?? '') as String? ?? '';
                                  final purl = ((snap['post_url'] ?? snap['postUrl']) as String? ?? '');
                                  url = thumb.isNotEmpty ? thumb : (purl.isNotEmpty ? purl : '');
                                } else {
                                  url = ((snap['post_url'] ?? snap['postUrl']) as String? ?? '');
                                }
                                String displayUrl = url;
                                return GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => PostDetailScreen(
                                        postId: snap['post_id']?.toString() ?? '',
                                        imageUrl: displayUrl,
                                        description: (snap['description'] ?? '').toString(),
                                        ownerUid: widget.uid,
                                        mediaType: mtype,
                                        postUrl: ((snap['post_url'] ?? snap['postUrl']) as String? ?? ''),
                                        thumbUrl: ((snap['thumb_url'] ?? '') as String? ?? ''),
                                        videoPath: ((snap['video_path'] ?? '') as String? ?? ''),
                                      ),
                                    ),
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                       child: (() {
                                         Widget buildImage(String u) {
                                           if (u.isEmpty) return Container(color: Colors.black12);
                                           if (u.startsWith('http')) return Image.network(u, fit: BoxFit.cover);
                                           return FutureBuilder<String>(
                                             future: Supabase.instance.client.storage.from('posts').createSignedUrl(u, 3600).onError((_, __) async {
                                               return Supabase.instance.client.storage.from('posts').getPublicUrl(u);
                                             }),
                                             builder: (ctx, snap) {
                                               final su = snap.data ?? '';
                                               if (!snap.hasData) {
                                                 return const Center(child: CircularProgressIndicator());
                                               }
                                               if (su.isEmpty) return Container(color: Colors.black12);
                                               return Image.network(su, fit: BoxFit.cover);
                                             },
                                           );
                                         }
                                         if (mtype == 'video') {
                                           return Stack(
                                             fit: StackFit.expand,
                                             children: [
                                               buildImage(displayUrl),
                                               const Positioned.fill(
                                                 child: Align(
                                                   alignment: Alignment.center,
                                                   child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white70),
                                                 ),
                                               ),
                                             ],
                                           );
                                         }
                                         return buildImage(displayUrl);
                                       })(),
                                     ),
                                   ),
                                 );
                              },
                            );
                          },
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          );
  }

  @override
  void dispose() {
    ConnectivityService.instance.isOnline.removeListener(_onOnlineChanged);
    super.dispose();
  }

  Column buildStatColumn(int num, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          num.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
