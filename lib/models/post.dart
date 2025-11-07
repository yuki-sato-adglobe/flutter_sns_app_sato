class Post {
  final String id;
  String content;
  final String userId;
  final DateTime createdAt;
  int likesCount;
  bool isLikedByMe;

  Post({
    required this.id,
    required this.content,
    required this.userId,
    required this.createdAt,
    required this.likesCount,
    required this.isLikedByMe,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      content: json['content'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      likesCount: json['likes_count'] ?? 0,
      isLikedByMe: false,
    );
  }
}