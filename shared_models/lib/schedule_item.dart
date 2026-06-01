class ScheduleItem {
  final String id;
  final String competitionId;
  final String type; // weigh_in, flight, awards, staff_meeting
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final List<String> assignees;

  ScheduleItem({
    required this.id,
    required this.competitionId,
    required this.type,
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    required this.assignees,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      startDateTime: DateTime.parse(
        json['start_date_time'] as String,
      ).toLocal(),
      endDateTime: DateTime.parse(json['end_date_time'] as String).toLocal(),
      assignees: List<String>.from(json['assignees'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'competition_id': competitionId,
      'type': type,
      'title': title,
      'start_date_time': startDateTime.toUtc().toIso8601String(),
      'end_date_time': endDateTime.toUtc().toIso8601String(),
      'assignees': assignees,
    };
  }

  ScheduleItem copyWith({
    String? id,
    String? competitionId,
    String? type,
    String? title,
    DateTime? startDateTime,
    DateTime? endDateTime,
    List<String>? assignees,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      competitionId: competitionId ?? this.competitionId,
      type: type ?? this.type,
      title: title ?? this.title,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      assignees: assignees ?? this.assignees,
    );
  }
}
