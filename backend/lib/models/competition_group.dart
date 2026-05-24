class CompetitionGroup {
  final String id;
  final String associationId;
  final String name;
  final String sport;
  final String format;
  final bool isActive;
  final bool isAthleteGroupsRequired;

  CompetitionGroup({
    required this.id,
    required this.associationId,
    required this.name,
    required this.sport,
    required this.format,
    this.isActive = true,
    this.isAthleteGroupsRequired = false,
  });

  factory CompetitionGroup.fromJson(Map<String, dynamic> json) {
    return CompetitionGroup(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      name: json['name'] as String,
      sport: json['sport'] as String,
      format: json['format'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isAthleteGroupsRequired:
          json['is_athlete_groups_required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'association_id': associationId,
      'name': name,
      'sport': sport,
      'format': format,
      'is_active': isActive,
      'is_athlete_groups_required': isAthleteGroupsRequired,
    };
  }

  CompetitionGroup copyWith({
    String? id,
    String? associationId,
    String? name,
    String? sport,
    String? format,
    bool? isActive,
    bool? isAthleteGroupsRequired,
  }) {
    return CompetitionGroup(
      id: id ?? this.id,
      associationId: associationId ?? this.associationId,
      name: name ?? this.name,
      sport: sport ?? this.sport,
      format: format ?? this.format,
      isActive: isActive ?? this.isActive,
      isAthleteGroupsRequired:
          isAthleteGroupsRequired ?? this.isAthleteGroupsRequired,
    );
  }
}
