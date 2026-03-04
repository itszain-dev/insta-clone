import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseVideoService {
  final SupabaseClient client = Supabase.instance.client;

  Future<String> signUrl(String bucket, String path, {int expiresIn = 3600}) async {
    final res = await client.storage.from(bucket).createSignedUrl(path, expiresIn);
    return res;
  }

  String? extractPathFromPublicUrl(String bucket, String publicUrl) {
    final marker = '/object/public/$bucket/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return null;
    return publicUrl.substring(idx + marker.length);
  }
}
