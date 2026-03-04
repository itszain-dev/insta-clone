import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/screens/profile_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/services/connectivity_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  bool isShowUsers = false;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.isOnline.addListener(_onOnlineChanged);
  }

  void _onOnlineChanged() {
    if (ConnectivityService.instance.isOnline.value) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: mobileSearchColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search users',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          isShowUsers = false;
                        });
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            onSubmitted: (_) {
              setState(() {
                isShowUsers = searchController.text.isNotEmpty;
              });
            },
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                setState(() {
                  isShowUsers = searchController.text.isNotEmpty;
                });
              });
            },
          ),
        ),
      ),
      body: isShowUsers
          ? FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('users')
                  .select()
                  .ilike('username', '${searchController.text}%'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to search users. Check your internet.'));
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                final docs = snapshot.data!;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            uid: doc['uid'],
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          child: (() {
                            final url = (doc['photo_url'] ?? doc['photoUrl']) ?? '';
                            if (url.isEmpty) return const Icon(Icons.person);
                            return null;
                          })(),
                          backgroundImage: (() {
                            final url = (doc['photo_url'] ?? doc['photoUrl']) ?? '';
                            if (url.isEmpty) return null;
                            return NetworkImage(url);
                          })(),
                        ),
                        title: Text(
                          doc['username'],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      ),
                    );
                  },
                );
              },
            )
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('posts')
                  .select()
                  .order('date_published'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load posts'));
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                final docs = snapshot.data!;
                return MasonryGridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 5 : 3,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final mtype = (docs[index]['media_type'] ?? 'image').toString();
                    final raw = ((mtype == 'video' ? docs[index]['thumb_url'] : docs[index]['post_url']) ?? docs[index]['postUrl']) ?? '';
                    final displayRaw = raw.toString();
                    Widget buildImage() {
                      if (displayRaw.isEmpty) return const SizedBox.shrink();
                      if (displayRaw.startsWith('http')) {
                        return Image.network(displayRaw, fit: BoxFit.cover);
                      }
                      return FutureBuilder<String>(
                        future: Supabase.instance.client.storage.from('posts').createSignedUrl(displayRaw, 3600).onError((_, __) async {
                          return Supabase.instance.client.storage.from('posts').getPublicUrl(displayRaw);
                        }),
                        builder: (ctx, snap) {
                          final su = snap.data ?? '';
                          // Debug
                          try {
                            // ignore: avoid_print
                            print('[search_grid] index=$index type=$mtype raw=$displayRaw signed=$su');
                          } catch (_) {}
                          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                          if (su.isEmpty) return const SizedBox.shrink();
                          return Image.network(su, fit: BoxFit.cover);
                        },
                      );
                    }
                    return Stack(
                      children: [
                        buildImage(),
                        if (mtype == 'video') const Positioned.fill(child: Align(alignment: Alignment.center, child: Icon(Icons.play_circle_fill, color: Colors.white70))),
                      ],
                    );
                  },
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    ConnectivityService.instance.isOnline.removeListener(_onOnlineChanged);
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
