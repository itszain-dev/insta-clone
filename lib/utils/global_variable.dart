import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/screens/add_post_screen.dart';
import 'package:instagram_clone_flutter/screens/feed_screen.dart';
import 'package:instagram_clone_flutter/screens/profile_screen.dart';
import 'package:instagram_clone_flutter/screens/search_screen.dart';

const webScreenSize = 600;

List<Widget> buildHomeScreenItems() {
  final currentUser = Supabase.instance.client.auth.currentUser;
  return [
    const FeedScreen(),
    const SearchScreen(),
    const AddPostScreen(),
    const Text('notifications'),
    if (currentUser != null)
      ProfileScreen(uid: currentUser.id)
    else
      const Center(child: Text('Not signed in')),
  ];
}
