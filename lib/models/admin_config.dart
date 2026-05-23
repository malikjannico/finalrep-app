class SportDefinition {
  final String name;
  final String? description;

  SportDefinition({required this.name, this.description});

  factory SportDefinition.fromJson(Map<String, dynamic> json) => SportDefinition(
        name: json['name'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };
}

class FormatDefinition {
  final String sportName;
  final String name;
  final String? description;

  FormatDefinition({
    required this.sportName,
    required this.name,
    this.description,
  });

  factory FormatDefinition.fromJson(Map<String, dynamic> json) => FormatDefinition(
        sportName: json['sport_name'] as String? ?? '',
        name: json['name'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'sport_name': sportName,
        'name': name,
        'description': description,
      };
}

class DisciplineDefinition {
  final String name;
  final String? description;

  DisciplineDefinition({required this.name, this.description});

  factory DisciplineDefinition.fromJson(Map<String, dynamic> json) =>
      DisciplineDefinition(
        name: json['name'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };
}

class FormatDisciplineLink {
  final String sportName;
  final String formatName;
  final String disciplineName;

  FormatDisciplineLink({
    required this.sportName,
    required this.formatName,
    required this.disciplineName,
  });

  factory FormatDisciplineLink.fromJson(Map<String, dynamic> json) =>
      FormatDisciplineLink(
        sportName: json['sport_name'] as String? ?? '',
        formatName: json['format_name'] as String? ?? '',
        disciplineName: json['discipline_name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'sport_name': sportName,
        'format_name': formatName,
        'discipline_name': disciplineName,
      };
}

class SportConfig {
  final List<SportDefinition> sports;
  final List<FormatDefinition> formats;
  final List<DisciplineDefinition> disciplines;
  final List<FormatDisciplineLink> links;

  SportConfig({
    required this.sports,
    required this.formats,
    required this.disciplines,
    required this.links,
  });

  factory SportConfig.fromJson(Map<String, dynamic> json) {
    return SportConfig(
      sports: (json['sports'] as List? ?? [])
          .map((e) => SportDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      formats: (json['formats'] as List? ?? [])
          .map((e) => FormatDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      disciplines: (json['disciplines'] as List? ?? [])
          .map((e) => DisciplineDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      links: (json['links'] as List? ?? [])
          .map((e) => FormatDisciplineLink.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sports': sports.map((e) => e.toJson()).toList(),
      'formats': formats.map((e) => e.toJson()).toList(),
      'disciplines': disciplines.map((e) => e.toJson()).toList(),
      'links': links.map((e) => e.toJson()).toList(),
    };
  }

  SportConfig copyWith({
    List<SportDefinition>? sports,
    List<FormatDefinition>? formats,
    List<DisciplineDefinition>? disciplines,
    List<FormatDisciplineLink>? links,
  }) {
    return SportConfig(
      sports: sports ?? this.sports,
      formats: formats ?? this.formats,
      disciplines: disciplines ?? this.disciplines,
      links: links ?? this.links,
    );
  }
}
