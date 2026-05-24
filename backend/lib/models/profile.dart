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
  final Map<String, String>? socialLinks;
  final bool isCompetitionCreator;
  final bool isAssociationCreator;
  final bool isAdmin;
  final Map<String, bool> notificationPreferences;

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
    this.socialLinks,
    this.isCompetitionCreator = false,
    this.isAssociationCreator = false,
    this.isAdmin = false,
    this.notificationPreferences = const {
      'registration': true,
      'permissions': true,
      'payments': true,
      'schedule': true,
      'flights': true,
    },
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
      socialLinks: json['social_links'] is Map
          ? (json['social_links'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : null,
      isCompetitionCreator: json['is_competition_creator'] as bool? ?? false,
      isAssociationCreator: json['is_association_creator'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? false,
      notificationPreferences: (() {
        final Map<String, bool> defaults = {
          'registration': true,
          'permissions': true,
          'payments': true,
          'schedule': true,
          'flights': true,
        };
        if (json['notification_preferences'] is Map) {
          final parsed = (json['notification_preferences'] as Map).map(
            (k, v) => MapEntry(k.toString(), v is bool ? v : true),
          );
          return {...defaults, ...parsed};
        }
        return defaults;
      }()),
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
      if (socialLinks != null) 'social_links': socialLinks,
      'is_competition_creator': isCompetitionCreator,
      'is_association_creator': isAssociationCreator,
      'is_admin': isAdmin,
      'notification_preferences': notificationPreferences,
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
    Map<String, String>? socialLinks,
    bool? isCompetitionCreator,
    bool? isAssociationCreator,
    bool? isAdmin,
    Map<String, bool>? notificationPreferences,
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
      socialLinks: socialLinks ?? this.socialLinks,
      isCompetitionCreator: isCompetitionCreator ?? this.isCompetitionCreator,
      isAssociationCreator: isAssociationCreator ?? this.isAssociationCreator,
      isAdmin: isAdmin ?? this.isAdmin,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }
}
