class StreetliftingAttempt {
  final String id;
  final String competitionId;
  final String athleteId;
  final int attemptNumber; // 1, 2, 3
  final double weight;
  final String discipline; // Muscle Up, Pull Up, Dip, Squat
  final String status; // pending, valid, invalid
  final List<bool> judgeVotes;
  final String? failureReason;
  final bool varRequested;

  StreetliftingAttempt({
    required this.id,
    required this.competitionId,
    required this.athleteId,
    required this.attemptNumber,
    required this.weight,
    required this.discipline,
    this.status = 'pending',
    required this.judgeVotes,
    this.failureReason,
    this.varRequested = false,
  });

  factory StreetliftingAttempt.fromJson(Map<String, dynamic> json) {
    return StreetliftingAttempt(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      athleteId: json['athlete_id'] as String,
      attemptNumber: json['attempt_number'] as int,
      weight: (json['weight'] as num).toDouble(),
      discipline: json['discipline'] as String,
      status: json['status'] as String? ?? 'pending',
      judgeVotes: List<bool>.from(json['judge_votes'] as List),
      failureReason: json['failure_reason'] as String?,
      varRequested: json['var_requested'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'competition_id': competitionId,
      'athlete_id': athleteId,
      'attempt_number': attemptNumber,
      'weight': weight,
      'discipline': discipline,
      'status': status,
      'judge_votes': judgeVotes,
      if (failureReason != null) 'failure_reason': failureReason,
      'var_requested': varRequested,
    };
  }

  StreetliftingAttempt copyWith({
    String? id,
    String? competitionId,
    String? athleteId,
    int? attemptNumber,
    double? weight,
    String? discipline,
    String? status,
    List<bool>? judgeVotes,
    String? failureReason,
    bool? varRequested,
  }) {
    return StreetliftingAttempt(
      id: id ?? this.id,
      competitionId: competitionId ?? this.competitionId,
      athleteId: athleteId ?? this.athleteId,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      weight: weight ?? this.weight,
      discipline: discipline ?? this.discipline,
      status: status ?? this.status,
      judgeVotes: judgeVotes ?? this.judgeVotes,
      failureReason: failureReason ?? this.failureReason,
      varRequested: varRequested ?? this.varRequested,
    );
  }
}
