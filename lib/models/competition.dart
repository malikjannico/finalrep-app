class Competition {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final String sportType;
  final String sportSubtype; // 'Modern' or 'Classic'
  final String? compGroupName; // 'FinalRep Underground', 'FinalRep Qualifier', 'FinalRep Final', or null
  final String status; // 'upcoming', 'ongoing', 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;

  Competition({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    this.sportType = 'Streetlifting',
    required this.sportSubtype,
    this.compGroupName,
    this.status = 'upcoming',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['start_date'] as String).toLocal(),
      endDate: DateTime.parse(json['end_date'] as String).toLocal(),
      location: json['location'] as String,
      sportType: json['sport_type'] as String? ?? 'Streetlifting',
      sportSubtype: json['sport_subtype'] as String,
      compGroupName: json['comp_group_name'] as String?,
      status: json['status'] as String? ?? 'upcoming',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'location': location,
      'sport_type': sportType,
      'sport_subtype': sportSubtype,
      'comp_group_name': compGroupName,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Streetlifting helper methods
  List<String> get disciplines {
    if (sportSubtype.toLowerCase() == 'modern') {
      return ['Muscle Up', 'Pull Up', 'Dip', 'Squat'];
    } else {
      return ['Pull Up', 'Dip'];
    }
  }

  bool get isModern => sportSubtype.toLowerCase() == 'modern';
  bool get isClassic => sportSubtype.toLowerCase() == 'classic';
  bool get isPartOfGroup => compGroupName != null && compGroupName!.trim().isNotEmpty;
}
