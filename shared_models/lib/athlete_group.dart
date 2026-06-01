class AthleteGroup {
  final String id;
  final String associationId;
  final String name; // e.g. "-80kg Male" or "Male -80kg"
  final String sport;
  final String format;
  final String gender; // 'Male', 'Female', 'Mixed', etc.
  final bool isActive;
  final int sortOrder;
  final Map<String, dynamic> sharingConfig;

  AthleteGroup({
    required this.id,
    required this.associationId,
    required this.name,
    required this.sport,
    required this.format,
    required this.gender,
    this.isActive = true,
    this.sortOrder = 0,
    this.sharingConfig = const {'mode': 'private', 'targets': []},
  });

  factory AthleteGroup.fromJson(Map<String, dynamic> json) {
    return AthleteGroup(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      name: json['name'] as String,
      sport: json['sport'] as String,
      format: json['format'] as String,
      gender: (() {
        final raw = (json['gender'] as String? ?? 'open').toLowerCase();
        if (raw == 'male' || raw == 'men') return 'men';
        if (raw == 'female' || raw == 'woman' || raw == 'women') return 'women';
        return 'open';
      })(),
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      sharingConfig: json['sharing_config'] != null
          ? Map<String, dynamic>.from(json['sharing_config'] as Map)
          : const {'mode': 'private', 'targets': []},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'association_id': associationId,
      'name': name,
      'sport': sport,
      'format': format,
      'gender': gender,
      'is_active': isActive,
      'sort_order': sortOrder,
      'sharing_config': sharingConfig,
    };
  }

  AthleteGroup copyWith({
    String? id,
    String? associationId,
    String? name,
    String? sport,
    String? format,
    String? gender,
    bool? isActive,
    int? sortOrder,
    Map<String, dynamic>? sharingConfig,
  }) {
    return AthleteGroup(
      id: id ?? this.id,
      associationId: associationId ?? this.associationId,
      name: name ?? this.name,
      sport: sport ?? this.sport,
      format: format ?? this.format,
      gender: gender ?? this.gender,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      sharingConfig: sharingConfig ?? this.sharingConfig,
    );
  }
}
