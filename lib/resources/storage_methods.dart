import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageMethods {
  final supabase = Supabase.instance.client;

  Future<String> uploadImageToStorage(String childName, Uint8List file, bool isPost) async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) {
      throw Exception('Not authenticated');
    }
    final uid = authUser.id;
    String path = '$uid';
    if (isPost) {
      String id = const Uuid().v1();
      path = '$path/$id.jpg';
    } else {
      path = '$path/profile.jpg';
    }
    await supabase.storage.from(childName).uploadBinary(path, file, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    final publicUrl = supabase.storage.from(childName).getPublicUrl(path);
    return publicUrl;
  }

  Future<String> uploadMediaToStorage(String childName, Uint8List file,
      {bool isPost = true, String contentType = 'application/octet-stream', String fileExt = ''}) async {
    if (file.isEmpty) {
      return '';
    }
    final authUser = supabase.auth.currentUser;
    if (authUser == null) {
      throw Exception('Not authenticated');
    }
    final uid = authUser.id;
    String path = '$uid';
    if (isPost) {
      String id = const Uuid().v1();
      final ext = fileExt.isNotEmpty ? fileExt : (contentType == 'image/jpeg' ? '.jpg' : (contentType == 'video/mp4' ? '.mp4' : ''));
      path = '$path/$id$ext';
    } else {
      path = '$path/profile.jpg';
    }
    await supabase.storage.from(childName).uploadBinary(path, file, fileOptions: FileOptions(contentType: contentType, upsert: true));
    final publicUrl = supabase.storage.from(childName).getPublicUrl(path);
    return publicUrl;
  }

  Future<String> uploadBytesGetPath(String childName, Uint8List file,
      {bool isPost = true, String contentType = 'application/octet-stream', String fileExt = ''}) async {
    if (file.isEmpty) {
      return '';
    }
    final authUser = supabase.auth.currentUser;
    if (authUser == null) {
      throw Exception('Not authenticated');
    }
    final uid = authUser.id;
    String path = '$uid';
    if (isPost) {
      String id = const Uuid().v1();
      final ext = fileExt.isNotEmpty ? fileExt : (contentType == 'image/jpeg' ? '.jpg' : (contentType == 'video/mp4' ? '.mp4' : ''));
      path = '$path/$id$ext';
    } else {
      path = '$path/profile.jpg';
    }
    await supabase.storage.from(childName).uploadBinary(path, file, fileOptions: FileOptions(contentType: contentType, upsert: true));
    return path;
  }

  Future<void> deletePublicUrl(String bucket, String publicUrl) async {
    try {
      final marker = '/object/public/$bucket/';
      final idx = publicUrl.indexOf(marker);
      if (idx == -1) return;
      final path = publicUrl.substring(idx + marker.length);
      await supabase.storage.from(bucket).remove([path]);
    } catch (_) {}
  }
}
