import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/models/post.dart';

class PostRepository {
  final SupabaseClient client;
  const PostRepository({required this.client});

  Future<List<Post>> fetchPage({required int offset, required int limit}) async {
    try {
      final data = await client
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final list = (data as List).map((e) => Post.fromMap(e as Map<String, dynamic>)).toList();
      return list;
    } catch (_) {
      final data = await client
          .from('posts')
          .select()
          .order('date_published', ascending: false)
          .range(offset, offset + limit - 1);
      final list = (data as List).map((e) => Post.fromMap(e as Map<String, dynamic>)).toList();
      return list;
    }
  }

  List<Post> _normalizeUrls(List<Post> posts) {
    // No-op: UI handles signing or public URL resolution as needed
    return posts;
  }
}
