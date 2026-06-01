class AssociationMember {
  final String id;
  final String associationId;
  final String userId;
  final String role; // 'owner', 'editor'
  final String? customTitle; // custom team roles

  AssociationMember({
    required this.id,
    required this.associationId,
    required this.userId,
    required this.role,
    this.customTitle,
  });

  factory AssociationMember.fromJson(Map<String, dynamic> json) {
    return AssociationMember(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'editor',
      customTitle: json['custom_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'association_id': associationId,
      'user_id': userId,
      'role': role,
      'custom_title': customTitle,
    };
  }

  AssociationMember copyWith({
    String? id,
    String? associationId,
    String? userId,
    String? role,
    String? customTitle,
  }) {
    return AssociationMember(
      id: id ?? this.id,
      associationId: associationId ?? this.associationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      customTitle: customTitle ?? this.customTitle,
    );
  }
}
