import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/models/post.dart';
import 'package:instagram_clone_flutter/resources/storage_methods.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:instagram_clone_flutter/services/video_processing_service.dart';

class FireStoreMethods {
  final supabase = Supabase.instance.client;

  Future<String> uploadPost(String description, Uint8List file, String uid,
      String username, String profImage, {String mediaType = 'image'}) async {
    // asking uid here because we dont want to make extra calls to firebase auth when we can just get from our state management
    String res = "Some error occurred";
    try {
      String postUrl = '';
      String videoPath = '';
      String thumbUrl = '';
      if (mediaType == 'video') {
        final compressed = await compressVideoToBytes(file);
        videoPath = await StorageMethods().uploadBytesGetPath('posts', compressed, isPost: true, contentType: 'video/mp4', fileExt: '.mp4');
        postUrl = '';
      } else {
        postUrl = await StorageMethods().uploadBytesGetPath('posts', file, isPost: true, contentType: 'image/jpeg', fileExt: '.jpg');
      }
      final row = {
        'description': description,
        'uid': uid,
        'username': username,
        'likes': <String>[],
        'date_published': DateTime.now().toIso8601String(),
        'post_url': postUrl,
        'prof_image': profImage,
        'media_type': mediaType,
        'video_path': videoPath,
        'thumb_url': thumbUrl,
      };
      await supabase.from('posts').insert(row);
      if (mediaType == 'video' && (videoPath.isNotEmpty)) {
        Future(() async {
          try {
            final data = await VideoProcessingService().process(bucket: 'posts', path: videoPath, quality: '720p');
            final processedPath = (data['processed_path'] ?? '').toString();
            final tUrl = (data['thumb_url'] ?? '').toString();
            final updates = <String, dynamic>{};
            if (processedPath.isNotEmpty) updates['video_path'] = processedPath;
            if (tUrl.isNotEmpty) {
              updates['thumb_url'] = tUrl;
              updates['post_url'] = tUrl;
            }
            if (updates.isNotEmpty) {
              await supabase.from('posts').update(updates).eq('video_path', videoPath);
            }
          } catch (_) {}
        });
      }
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<Uint8List> compressVideoToBytes(Uint8List input) async {
    if (kIsWeb) {
      return input;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File(path);
      await file.writeAsBytes(input, flush: true);
      VideoCompress.setLogLevel(0);
      final info = await VideoCompress
          .compressVideo(
            file.path,
            quality: VideoQuality.MediumQuality,
            includeAudio: true,
          )
          .timeout(const Duration(seconds: 20));
      final out = info?.file;
      if (out == null) {
        return input;
      }
      return await out.readAsBytes();
    } catch (_) {
      return input;
    }
  }

  Future<Uint8List> generateVideoThumbnail(Uint8List input) async {
    if (kIsWeb) {
      return Uint8List(0);
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File(path);
      await file.writeAsBytes(input, flush: true);
      final bytes = await VideoCompress
          .getFileThumbnail(file.path, quality: 75)
          .timeout(const Duration(seconds: 12));
      return await bytes.readAsBytes();
    } catch (_) {
      return Uint8List(0);
    }
  }

  Future<String> likePost(String postId, String uid, List likes) async {
    String res = "Some error occurred";
    try {
      final currentLikes = List<String>.from(likes);
      if (currentLikes.contains(uid)) {
        currentLikes.remove(uid);
      } else {
        currentLikes.add(uid);
      }
      await supabase.from('posts').update({'likes': currentLikes}).eq('post_id', postId);
      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // Post comment
  Future<String> postComment(String postId, String text, String uid,
      String name, String profilePic) async {
    String res = "Some error occurred";
    try {
      if (text.isNotEmpty) {
        // if the likes list contains the user uid, we need to remove it
        String commentId = const Uuid().v1();
        await supabase.from('comments').insert({
          'profile_pic': profilePic,
          'username': name,
          'uid': uid,
          'text': text,
          'comment_id': commentId,
          'post_id': postId,
          'date_published': DateTime.now().toIso8601String(),
        });
        res = 'success';
      } else {
        res = "Please enter text";
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // Delete Post
  Future<String> deletePost(String postId) async {
    String res = "Some error occurred";
    try {
      await supabase.from('posts').delete().eq('post_id', postId);
      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<void> followUser(String uid, String followId) async {
    try {
      final self = await supabase.from('users').select('following').eq('uid', uid).single();
      final other = await supabase.from('users').select('followers').eq('uid', followId).single();
      final following = List<String>.from(self['following'] ?? []);
      final followers = List<String>.from(other['followers'] ?? []);

      if (following.contains(followId)) {
        following.remove(followId);
        followers.remove(uid);
      } else {
        following.add(followId);
        followers.add(uid);
      }

      await supabase.from('users').update({'following': following}).eq('uid', uid);
      await supabase.from('users').update({'followers': followers}).eq('uid', followId);
    } catch (e) {
      if (kDebugMode) print(e.toString());
    }
  }
}
