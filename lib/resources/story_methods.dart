import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/resources/storage_methods.dart';
import 'package:instagram_clone_flutter/resources/supabase_methods.dart';
import 'package:instagram_clone_flutter/services/video_processing_service.dart';

class StoryMethods {
  final supabase = Supabase.instance.client;

  Future<String> uploadStory({
    required Uint8List file,
    required String uid,
    required String username,
    String? caption,
    String mediaType = 'image',
    String? thumbUrl,
  }) async {
    String res = 'Some error occurred';
    try {
      String mediaUrl;
      String localThumb = thumbUrl ?? '';
      if (mediaType == 'video') {
        final compressed = await FireStoreMethods().compressVideoToBytes(file);
        final path = await StorageMethods().uploadBytesGetPath('stories', compressed, isPost: true, contentType: 'video/mp4', fileExt: '.mp4');
        mediaUrl = path;
      } else {
        mediaUrl = await StorageMethods().uploadMediaToStorage('stories', file, isPost: true, contentType: 'image/jpeg', fileExt: '.jpg');
      }
      final row = {
        'uid': uid,
        'username': username,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'thumb_url': localThumb,
        'caption': caption ?? '',
      };
      await supabase.from('stories').insert(row);
      if (mediaType == 'video') {
        Future(() async {
          try {
            final data = await VideoProcessingService().process(bucket: 'stories', path: mediaUrl, quality: '720p');
            final tUrl = (data['thumb_url'] ?? '').toString();
            if (tUrl.isNotEmpty) {
              await supabase.from('stories').update({'thumb_url': tUrl}).eq('media_url', mediaUrl);
            }
          } catch (_) {}
        });
      }
      res = 'success';
    } catch (e) {
      res = e.toString();
    }
    return res;
  }

  Future<void> markViewed({required String storyId, required String viewerUid}) async {
    await supabase.from('story_views').insert({
      'story_id': storyId,
      'viewer_uid': viewerUid,
    }).onError((error, _) async {
      return null;
    });
  }

  Future<String> deleteStory({required String storyId, required String mediaUrl}) async {
    String res = 'Some error occurred';
    try {
      await StorageMethods().deletePublicUrl('stories', mediaUrl);
      await supabase.from('stories').delete().eq('story_id', storyId);
      res = 'success';
    } catch (e) {
      res = e.toString();
    }
    return res;
  }
}
