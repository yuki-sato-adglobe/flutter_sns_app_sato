import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';
import '../models/providers/sns_service.dart';

// Supabase client
final supabase = Supabase.instance.client;

class SnsHomeScreen extends StatefulWidget {
  const SnsHomeScreen({super.key});

  @override
  State<SnsHomeScreen> createState() => _SnsHomeScreenState();
}

class _SnsHomeScreenState extends State<SnsHomeScreen> {
  final SnsService _snsService = SnsService();
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentOffset = 0;
  final int _limit = 10;

  String? _editingPostId;
  TextEditingController _editController = TextEditingController();

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _setupRealtimeSubscription();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _postController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _realtimeChannel = supabase
        .channel('posts_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            _loadPosts(refresh: true);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (payload) {
            _loadPosts(refresh: true);
          },
        )
        .subscribe();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentOffset = 0;
        _posts = [];
      });
    }

    setState(() => _isLoading = true);
    try {
      final posts = await _snsService.fetchPosts(limit: _limit, offset: _currentOffset);
      setState(() {
        if (refresh) {
          _posts = posts;
        } else {
          _posts.addAll(posts);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !_isLoadingMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    setState(() => _isLoadingMore = true);
    _currentOffset += _limit;
    try {
      final posts = await _snsService.fetchPosts(limit: _limit, offset: _currentOffset);
      setState(() {
        _posts.addAll(posts);
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more posts: $e')),
        );
      }
    }
  }

  Future<void> _createPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty || content.length > 512) return;

    try {
      await _snsService.createPost(content);
      _postController.clear();
      _loadPosts(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    }
  }

  Future<void> _updatePost() async {
    final newContent = _editController.text.trim();
    if (newContent.isEmpty || newContent.length > 512) return;

    try {
      await _snsService.updatePost(_editingPostId!, newContent);
      setState(() {
        _editingPostId = null;
        _editController.clear();
      });
      _loadPosts(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating post: $e')),
        );
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _snsService.deletePost(postId);
        _loadPosts(refresh: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting post: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      await _snsService.toggleLike(postId);
      _loadPosts(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling like: $e')),
        );
      }
    }
  }

  void _startEditing(Post post) {
    setState(() {
      _editingPostId = post.id;
      _editController.text = post.content;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingPostId = null;
      _editController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SNS App'),
        actions: [
          IconButton(
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          // Post input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    maxLength: 512,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'What\'s on your mind?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _createPost,
                  child: const Text('Post'),
                ),
              ],
            ),
          ),
          // Posts list
          Expanded(
            child: _isLoading && _posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final post = _posts[index];
                      final isEditing = _editingPostId == post.id;
                      final isOwnPost = post.userId == supabase.auth.currentUser?.id;

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isEditing)
                                Column(
                                  children: [
                                    TextField(
                                      controller: _editController,
                                      maxLength: 512,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: _cancelEditing,
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: _updatePost,
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(post.content),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => _toggleLike(post.id),
                                          icon: Icon(
                                            post.isLikedByCurrentUser
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: post.isLikedByCurrentUser
                                                ? Colors.red
                                                : null,
                                          ),
                                        ),
                                        Text('${post.likesCount}'),
                                        if (isOwnPost) ...[
                                          IconButton(
                                            onPressed: () => _startEditing(post),
                                            icon: const Icon(Icons.edit),
                                          ),
                                          IconButton(
                                            onPressed: () => _deletePost(post.id),
                                            icon: const Icon(Icons.delete),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}