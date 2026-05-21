class Profile {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String? gender;
  final String? country;
  final String? profilePictureUrl;
  final String? description;
  final String colorMode; // 'light', 'dark', 'system'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.gender,
    this.country,
    this.profilePictureUrl,
    this.description,
    this.colorMode = 'system',
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      gender: json['gender'] as String?,
      country: json['country'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      description: json['description'] as String?,
      colorMode: json['color_mode'] as String? ?? 'system',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'gender': gender,
      'country': country,
      'profile_picture_url': profilePictureUrl,
      'description': description,
      'color_mode': colorMode,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? email,
    String? gender,
    String? country,
    String? profilePictureUrl,
    String? description,
    String? colorMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      description: description ?? this.description,
      colorMode: colorMode ?? this.colorMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
