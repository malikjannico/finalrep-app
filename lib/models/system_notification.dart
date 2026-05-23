class SystemNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String category; // registration, permissions, payments, schedule, flights
  final bool isRead;
  final DateTime createdAt;

  SystemNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.category,
    this.isRead = false,
    required this.createdAt,
  });

  factory SystemNotification.fromJson(Map<String, dynamic> json) {
    return SystemNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      category: json['category'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'category': category,
      'is_read': isRead,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  SystemNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? category,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return SystemNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
