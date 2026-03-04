import 'package:supabase_flutter/supabase_flutter.dart';

class VideoProcessingService {
  final SupabaseClient client = Supabase.instance.client;

  Future<Map<String, dynamic>> process({required String bucket, required String path, String quality = '720p'}) async {
    final res = await client.functions.invoke('process_video', body: {
      'bucket': bucket,
      'path': path,
      'quality': quality,
    });
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }
}
