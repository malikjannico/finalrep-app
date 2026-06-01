class PermissionApplication {
  final String id;
  final String userId;
  final String type; // 'create_competition' or 'create_association'
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  PermissionApplication({
    required this.id,
    required this.userId,
    required this.type,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
  });

  factory PermissionApplication.fromJson(Map<String, dynamic> json) {
    return PermissionApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'reason': reason,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  PermissionApplication copyWith({
    String? id,
    String? userId,
    String? type,
    String? reason,
    String? status,
    DateTime? createdAt,
  }) {
    return PermissionApplication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
