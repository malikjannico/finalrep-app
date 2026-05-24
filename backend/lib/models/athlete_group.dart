class AthleteGroup {
  final String id;
  final String associationId;
  final String? competitionGroupId;
  final String name; // e.g. "-80kg Male" or "Male -80kg"
  final String sport;
  final String format;
  final String gender; // 'Male', 'Female', 'Mixed', etc.
  final double? maxWeight; // null for open class
  final bool isActive;

  AthleteGroup({
    required this.id,
    required this.associationId,
    this.competitionGroupId,
    required this.name,
    required this.sport,
    required this.format,
    required this.gender,
    this.maxWeight,
    this.isActive = true,
  });

  factory AthleteGroup.fromJson(Map<String, dynamic> json) {
    return AthleteGroup(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      competitionGroupId: json['competition_group_id'] as String?,
      name: json['name'] as String,
      sport: json['sport'] as String,
      format: json['format'] as String,
      gender: json['gender'] as String? ?? 'Mixed',
      maxWeight: json['max_weight'] != null
          ? (json['max_weight'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'association_id': associationId,
      'competition_group_id': competitionGroupId,
      'name': name,
      'sport': sport,
      'format': format,
      'gender': gender,
      'max_weight': maxWeight,
      'is_active': isActive,
    };
  }

  AthleteGroup copyWith({
    String? id,
    String? associationId,
    String? competitionGroupId,
    String? name,
    String? sport,
    String? format,
    String? gender,
    double? maxWeight,
    bool? isActive,
  }) {
    return AthleteGroup(
      id: id ?? this.id,
      associationId: associationId ?? this.associationId,
      competitionGroupId: competitionGroupId ?? this.competitionGroupId,
      name: name ?? this.name,
      sport: sport ?? this.sport,
      format: format ?? this.format,
      gender: gender ?? this.gender,
      maxWeight: maxWeight ?? this.maxWeight,
      isActive: isActive ?? this.isActive,
    );
  }
}
