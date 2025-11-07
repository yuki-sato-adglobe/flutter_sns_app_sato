import 'package:supabase_flutter/supabase_flutter.dart';
import '../post.dart';

class SnsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 投稿を取得（ページネーション）
  Future<List<Post>> fetchPosts({int limit = 10, int offset = 0}) async {
    final response = await _supabase
        .from('posts')
        .select('*, likes(user_id)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final currentUserId = _supabase.auth.currentUser?.id;

    return response.map<Post>((json) {
      final likes = json['likes'] as List<dynamic>? ?? [];
      final isLiked = likes.any((like) => like['user_id'] == currentUserId);
      return Post.fromJson({
        ...json,
        'is_liked': isLiked,
      });
    }).toList();
  }

  // 投稿を作成
  Future<Post> createPost(String content) async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('posts')
        .insert({
          'content': content,
          'user_id': userId,
        })
        .select()
        .single();

    return Post.fromJson(response);
  }

  // 投稿を更新
  Future<Post> updatePost(String postId, String newContent) async {
    final response = await _supabase
        .from('posts')
        .update({
          'content': newContent,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', postId)
        .select()
        .single();

    return Post.fromJson(response);
  }

  // 投稿を削除
  Future<void> deletePost(String postId) async {
    await _supabase.from('posts').delete().eq('id', postId);
  }

  // いいねをトグル
  Future<void> toggleLike(String postId) async {
    final userId = _supabase.auth.currentUser!.id;

    // 既にいいねしているかチェック
    final existingLike = await _supabase
        .from('likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    // 現在のlikes_countを取得
    final post = await _supabase
        .from('posts')
        .select('likes_count')
        .eq('id', postId)
        .single();
    int likesCount = post['likes_count'] as int;

    if (existingLike != null) {
      // いいねを削除
      await _supabase
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);

      // likes_countをデクリメント
      await _supabase
          .from('posts')
          .update({'likes_count': likesCount - 1})
          .eq('id', postId);
    } else {
      // いいねを追加
      await _supabase.from('likes').insert({
        'post_id': postId,
        'user_id': userId,
      });

      // likes_countをインクリメント
      await _supabase
          .from('posts')
          .update({'likes_count': likesCount + 1})
          .eq('id', postId);
    }
  }
}