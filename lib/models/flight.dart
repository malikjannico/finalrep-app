class Flight {
  final String id;
  final String competitionId;
  final String name;
  final List<String> athleteIds;
  final String status;

  Flight({
    required this.id,
    required this.competitionId,
    required this.name,
    required this.athleteIds,
    this.status = 'pending',
  });

  factory Flight.fromJson(Map<String, dynamic> json) {
    return Flight(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      name: json['name'] as String,
      athleteIds: List<String>.from(json['athlete_ids'] as List),
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'competition_id': competitionId,
      'name': name,
      'athlete_ids': athleteIds,
      'status': status,
    };
  }

  Flight copyWith({
    String? id,
    String? competitionId,
    String? name,
    List<String>? athleteIds,
    String? status,
  }) {
    return Flight(
      id: id ?? this.id,
      competitionId: competitionId ?? this.competitionId,
      name: name ?? this.name,
      athleteIds: athleteIds ?? this.athleteIds,
      status: status ?? this.status,
    );
  }
}
