import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';

class PostProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Post> _posts = [];
  bool _isLoading = false;
  int _page = 0;
  final int _limit = 10;
  String? _editingPostId;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get editingPostId => _editingPostId;

  Future<void> fetchPosts() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .order('created_at', ascending: false)
          .range(_page * _limit, (_page + 1) * _limit - 1);

      final newPosts = response.map((json) => Post.fromJson(json)).toList();

      // Check likes for current user
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        for (var post in newPosts) {
          final like = await _supabase
              .from('likes')
              .select()
              .eq('post_id', post.id)
              .eq('user_id', userId)
              .maybeSingle();
          post.isLikedByMe = like != null;
        }
      }

      _posts.addAll(newPosts);
      _page++;
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPost(String content) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || content.trim().isEmpty) return;

    try {
      final response = await _supabase
          .from('posts')
          .insert({'content': content, 'user_id': userId})
          .select()
          .single();

      final newPost = Post.fromJson(response);
      newPost.isLikedByMe = false;
      _posts.insert(0, newPost);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  void startEditing(String postId) {
    _editingPostId = postId;
    notifyListeners();
  }

  void cancelEditing() {
    _editingPostId = null;
    notifyListeners();
  }

  Future<void> editPost(String postId, String newContent) async {
    if (newContent.trim().isEmpty) return;

    try {
      await _supabase
          .from('posts')
          .update({'content': newContent})
          .eq('id', postId);

      final post = _posts.firstWhere((p) => p.id == postId);
      post.content = newContent;
      _editingPostId = null;
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _supabase
          .from('posts')
          .delete()
          .eq('id', postId);

      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> toggleLike(String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final post = _posts.firstWhere((p) => p.id == postId);

    try {
      if (post.isLikedByMe) {
        await _supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        post.likesCount--;
        post.isLikedByMe = false;
      } else {
        await _supabase
            .from('likes')
            .insert({'post_id': postId, 'user_id': userId});
        post.likesCount++;
        post.isLikedByMe = true;
      }
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }
}