class Competition {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final String sportType;
  final String sportSubtype; // 'Modern' or 'Classic'
  final String?
  compGroupName; // 'FinalRep Underground', 'FinalRep Qualifier', 'FinalRep Final', or null
  final String status; // 'upcoming', 'ongoing', 'completed'
  final String? area;
  final String? country;
  final String? city;
  final String? titleImageUrl;
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
    this.area,
    this.country,
    this.city,
    this.titleImageUrl,
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
      area: json['area'] as String?,
      country: json['country'] as String?,
      city: json['city'] as String?,
      titleImageUrl: json['title_image_url'] as String?,
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
      'area': area,
      'country': country,
      'city': city,
      'title_image_url': titleImageUrl,
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
  bool get isPartOfGroup =>
      compGroupName != null && compGroupName!.trim().isNotEmpty;

  double get latitude {
    final c = city?.toLowerCase() ?? '';
    if (c.contains('hamburg')) return 53.5511;
    if (c.contains('berlin')) return 52.5200;
    if (c.contains('vienna')) return 48.2082;
    if (c.contains('new york')) return 40.7128;
    if (c.contains('tokyo')) return 35.6762;
    if (c.contains('frankfurt')) return 50.1109;
    if (c.contains('munich')) return 48.1351;

    final loc = location.toLowerCase();
    if (loc.contains('germany')) return 51.1657;
    if (loc.contains('austria')) return 47.5162;
    if (loc.contains('japan')) return 36.2048;
    if (loc.contains('usa') || loc.contains('united states')) return 37.0902;
    return 0.0;
  }

  double get longitude {
    final c = city?.toLowerCase() ?? '';
    if (c.contains('hamburg')) return 9.9937;
    if (c.contains('berlin')) return 13.4050;
    if (c.contains('vienna')) return 16.3738;
    if (c.contains('new york')) return -74.0060;
    if (c.contains('tokyo')) return 139.6503;
    if (c.contains('frankfurt')) return 8.6821;
    if (c.contains('munich')) return 11.5820;

    final loc = location.toLowerCase();
    if (loc.contains('germany')) return 10.4515;
    if (loc.contains('austria')) return 14.5501;
    if (loc.contains('japan')) return 138.2529;
    if (loc.contains('usa') || loc.contains('united states')) return -95.7129;
    return 0.0;
  }
}
