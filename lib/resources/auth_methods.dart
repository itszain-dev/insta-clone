import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/models/user.dart' as model;
import 'package:instagram_clone_flutter/resources/storage_methods.dart';

class AuthMethods {
  final supabase = Supabase.instance.client;

  // get user details
  Future<model.User> getUserDetails() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) {
      throw Exception('Not authenticated');
    }
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('uid', authUser.id)
          .single();
      return model.User.fromMap(response);
    } catch (_) {
      // Fallback when offline or user row not reachable
      return model.User(
        username: (authUser.email ?? 'user').split('@').first,
        uid: authUser.id,
        photoUrl: '',
        email: authUser.email ?? '',
        bio: '',
        followers: const [],
        following: const [],
      );
    }
  }

  // Signing Up User

  Future<String> signUpUser({
    required String email,
    required String password,
    required String username,
    required String bio,
    required Uint8List file,
  }) async {
    String res = "Some error Occurred";
    try {
      if (email.isNotEmpty ||
          password.isNotEmpty ||
          username.isNotEmpty ||
          bio.isNotEmpty) {
        final signUpRes = await supabase.auth.signUp(email: email, password: password);
        final uid = signUpRes.user?.id ?? supabase.auth.currentUser?.id;
        if (uid == null) {
          return "Check your email to confirm sign up, then log in.";
        }

        String photoUrl =
            await StorageMethods().uploadImageToStorage('profilepics', file, false);

        final row = {
          'uid': uid,
          'email': email,
          'photo_url': photoUrl,
          'username': username,
          'bio': bio,
          'followers': <String>[],
          'following': <String>[],
        };
        await supabase.from('users').insert(row);

        res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } catch (err) {
      return err.toString();
    }
    return res;
  }

  // logging in user
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "Some error Occurred";
    try {
      if (email.isNotEmpty || password.isNotEmpty) {
        await supabase.auth.signInWithPassword(email: email, password: password);
        res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } catch (err) {
      return err.toString();
    }
    return res;
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
