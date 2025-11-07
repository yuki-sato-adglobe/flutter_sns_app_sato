class Post {
  final String id;
  final String content;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likesCount;
  bool isLikedByCurrentUser;

  Post({
    required this.id,
    required this.content,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.likesCount,
    this.isLikedByCurrentUser = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      content: json['content'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      likesCount: json['likes_count'] ?? 0,
      isLikedByCurrentUser: json['is_liked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'likes_count': likesCount,
    };
  }
}