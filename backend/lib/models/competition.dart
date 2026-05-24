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
  final String? associationId;
  final String? competitionGroupId;
  final List<String>? athleteGroupIds;
  final String? rulebookUrl;

  final DateTime registrationStart;
  final DateTime registrationEnd;
  final bool requiresFees;
  final double? feeAmount;
  final String? feeCurrency;
  final String? bankDetails;
  final String? paymentDescription;
  final DateTime? paymentStart;
  final DateTime? paymentEnd;
  final String registrationMode;
  final String? websiteUrl;
  final String? ticketShopUrl;
  final Map<String, String>? socials;
  final int? maxAthletes;
  final Map<String, int>? maxAthletesPerGroup;
  final int? maxVolunteers;
  final Map<String, int>? maxVolunteersPerPosition;
  final bool enableWaitlist;
  final bool volunteerNeeds;
  final List<String>? volunteerPositions;
  final Map<String, List<String>>? volunteerShifts;
  final List<Map<String, dynamic>>? customAthleteFields;
  final List<Map<String, dynamic>>? customVolunteerFields;
  final String? disclaimerText;
  final String? disclaimerUrl;
  final String? disclaimerType;
  final bool bannerSafeZoneGuide;

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
    this.associationId,
    this.competitionGroupId,
    this.athleteGroupIds,
    this.rulebookUrl,
    DateTime? registrationStart,
    DateTime? registrationEnd,
    this.requiresFees = false,
    this.feeAmount,
    this.feeCurrency,
    this.bankDetails,
    this.paymentDescription,
    this.paymentStart,
    this.paymentEnd,
    this.registrationMode = 'fcfs',
    this.websiteUrl,
    this.ticketShopUrl,
    this.socials,
    this.maxAthletes,
    this.maxAthletesPerGroup,
    this.maxVolunteers,
    this.maxVolunteersPerPosition,
    this.enableWaitlist = false,
    this.volunteerNeeds = false,
    this.volunteerPositions,
    this.volunteerShifts,
    this.customAthleteFields,
    this.customVolunteerFields,
    this.disclaimerText,
    this.disclaimerUrl,
    this.disclaimerType,
    this.bannerSafeZoneGuide = false,
  }) : registrationStart = registrationStart ?? startDate,
       registrationEnd = registrationEnd ?? endDate;

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
      associationId: json['association_id'] as String?,
      competitionGroupId: json['competition_group_id'] as String?,
      athleteGroupIds: json['athlete_group_ids'] != null
          ? List<String>.from(json['athlete_group_ids'] as List)
          : null,
      rulebookUrl: json['rulebook_url'] as String?,
      registrationStart: json['registration_start'] != null
          ? DateTime.parse(json['registration_start'] as String).toLocal()
          : null,
      registrationEnd: json['registration_end'] != null
          ? DateTime.parse(json['registration_end'] as String).toLocal()
          : null,
      requiresFees: json['requires_fees'] as bool? ?? false,
      feeAmount: json['fee_amount'] != null
          ? (json['fee_amount'] as num).toDouble()
          : null,
      feeCurrency: json['fee_currency'] as String?,
      bankDetails: json['bank_details'] as String?,
      paymentDescription: json['payment_description'] as String?,
      paymentStart: json['payment_start'] != null
          ? DateTime.parse(json['payment_start'] as String).toLocal()
          : null,
      paymentEnd: json['payment_end'] != null
          ? DateTime.parse(json['payment_end'] as String).toLocal()
          : null,
      registrationMode: json['registration_mode'] as String? ?? 'fcfs',
      websiteUrl: json['website_url'] as String?,
      ticketShopUrl: json['ticket_shop_url'] as String?,
      socials: json['socials'] != null
          ? Map<String, String>.from(json['socials'] as Map)
          : null,
      maxAthletes: json['max_athletes'] as int?,
      maxAthletesPerGroup: json['max_athletes_per_group'] != null
          ? Map<String, int>.from(json['max_athletes_per_group'] as Map)
          : null,
      maxVolunteers: json['max_volunteers'] as int?,
      maxVolunteersPerPosition: json['max_volunteers_per_position'] != null
          ? Map<String, int>.from(json['max_volunteers_per_position'] as Map)
          : null,
      enableWaitlist: json['enable_waitlist'] as bool? ?? false,
      volunteerNeeds: json['volunteer_needs'] as bool? ?? false,
      volunteerPositions: json['volunteer_positions'] != null
          ? List<String>.from(json['volunteer_positions'] as List)
          : null,
      volunteerShifts: json['volunteer_shifts'] != null
          ? (json['volunteer_shifts'] as Map).map(
              (k, v) => MapEntry(k as String, List<String>.from(v as List)),
            )
          : null,
      customAthleteFields: json['custom_athlete_fields'] != null
          ? (json['custom_athlete_fields'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : null,
      customVolunteerFields: json['custom_volunteer_fields'] != null
          ? (json['custom_volunteer_fields'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : null,
      disclaimerText: json['disclaimer_text'] as String?,
      disclaimerUrl: json['disclaimer_url'] as String?,
      disclaimerType: json['disclaimer_type'] as String?,
      bannerSafeZoneGuide: json['banner_safe_zone_guide'] as bool? ?? false,
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
      if (associationId != null) 'association_id': associationId,
      if (competitionGroupId != null)
        'competition_group_id': competitionGroupId,
      if (athleteGroupIds != null) 'athlete_group_ids': athleteGroupIds,
      if (rulebookUrl != null) 'rulebook_url': rulebookUrl,
      'registration_start': registrationStart.toUtc().toIso8601String(),
      'registration_end': registrationEnd.toUtc().toIso8601String(),
      'requires_fees': requiresFees,
      if (feeAmount != null) 'fee_amount': feeAmount,
      if (feeCurrency != null) 'fee_currency': feeCurrency,
      if (bankDetails != null) 'bank_details': bankDetails,
      if (paymentDescription != null) 'payment_description': paymentDescription,
      if (paymentStart != null)
        'payment_start': paymentStart!.toUtc().toIso8601String(),
      if (paymentEnd != null)
        'payment_end': paymentEnd!.toUtc().toIso8601String(),
      'registration_mode': registrationMode,
      if (websiteUrl != null) 'website_url': websiteUrl,
      if (ticketShopUrl != null) 'ticket_shop_url': ticketShopUrl,
      if (socials != null) 'socials': socials,
      if (maxAthletes != null) 'max_athletes': maxAthletes,
      if (maxAthletesPerGroup != null)
        'max_athletes_per_group': maxAthletesPerGroup,
      if (maxVolunteers != null) 'max_volunteers': maxVolunteers,
      if (maxVolunteersPerPosition != null)
        'max_volunteers_per_position': maxVolunteersPerPosition,
      'enable_waitlist': enableWaitlist,
      'volunteer_needs': volunteerNeeds,
      if (volunteerPositions != null) 'volunteer_positions': volunteerPositions,
      if (volunteerShifts != null) 'volunteer_shifts': volunteerShifts,
      if (customAthleteFields != null)
        'custom_athlete_fields': customAthleteFields,
      if (customVolunteerFields != null)
        'custom_volunteer_fields': customVolunteerFields,
      if (disclaimerText != null) 'disclaimer_text': disclaimerText,
      if (disclaimerUrl != null) 'disclaimer_url': disclaimerUrl,
      if (disclaimerType != null) 'disclaimer_type': disclaimerType,
      'banner_safe_zone_guide': bannerSafeZoneGuide,
    };
  }

  Competition copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? sportType,
    String? sportSubtype,
    String? compGroupName,
    String? status,
    String? area,
    String? country,
    String? city,
    String? titleImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? associationId,
    String? competitionGroupId,
    List<String>? athleteGroupIds,
    String? rulebookUrl,
    DateTime? registrationStart,
    DateTime? registrationEnd,
    bool? requiresFees,
    double? feeAmount,
    String? feeCurrency,
    String? bankDetails,
    String? paymentDescription,
    DateTime? paymentStart,
    DateTime? paymentEnd,
    String? registrationMode,
    String? websiteUrl,
    String? ticketShopUrl,
    Map<String, String>? socials,
    int? maxAthletes,
    Map<String, int>? maxAthletesPerGroup,
    int? maxVolunteers,
    Map<String, int>? maxVolunteersPerPosition,
    bool? enableWaitlist,
    bool? volunteerNeeds,
    List<String>? volunteerPositions,
    Map<String, List<String>>? volunteerShifts,
    List<Map<String, dynamic>>? customAthleteFields,
    List<Map<String, dynamic>>? customVolunteerFields,
    String? disclaimerText,
    String? disclaimerUrl,
    String? disclaimerType,
    bool? bannerSafeZoneGuide,
  }) {
    return Competition(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      sportType: sportType ?? this.sportType,
      sportSubtype: sportSubtype ?? this.sportSubtype,
      compGroupName: compGroupName ?? this.compGroupName,
      status: status ?? this.status,
      area: area ?? this.area,
      country: country ?? this.country,
      city: city ?? this.city,
      titleImageUrl: titleImageUrl ?? this.titleImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      associationId: associationId ?? this.associationId,
      competitionGroupId: competitionGroupId ?? this.competitionGroupId,
      athleteGroupIds: athleteGroupIds ?? this.athleteGroupIds,
      rulebookUrl: rulebookUrl ?? this.rulebookUrl,
      registrationStart: registrationStart ?? this.registrationStart,
      registrationEnd: registrationEnd ?? this.registrationEnd,
      requiresFees: requiresFees ?? this.requiresFees,
      feeAmount: feeAmount ?? this.feeAmount,
      feeCurrency: feeCurrency ?? this.feeCurrency,
      bankDetails: bankDetails ?? this.bankDetails,
      paymentDescription: paymentDescription ?? this.paymentDescription,
      paymentStart: paymentStart ?? this.paymentStart,
      paymentEnd: paymentEnd ?? this.paymentEnd,
      registrationMode: registrationMode ?? this.registrationMode,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      ticketShopUrl: ticketShopUrl ?? this.ticketShopUrl,
      socials: socials ?? this.socials,
      maxAthletes: maxAthletes ?? this.maxAthletes,
      maxAthletesPerGroup: maxAthletesPerGroup ?? this.maxAthletesPerGroup,
      maxVolunteers: maxVolunteers ?? this.maxVolunteers,
      maxVolunteersPerPosition:
          maxVolunteersPerPosition ?? this.maxVolunteersPerPosition,
      enableWaitlist: enableWaitlist ?? this.enableWaitlist,
      volunteerNeeds: volunteerNeeds ?? this.volunteerNeeds,
      volunteerPositions: volunteerPositions ?? this.volunteerPositions,
      volunteerShifts: volunteerShifts ?? this.volunteerShifts,
      customAthleteFields: customAthleteFields ?? this.customAthleteFields,
      customVolunteerFields:
          customVolunteerFields ?? this.customVolunteerFields,
      disclaimerText: disclaimerText ?? this.disclaimerText,
      disclaimerUrl: disclaimerUrl ?? this.disclaimerUrl,
      disclaimerType: disclaimerType ?? this.disclaimerType,
      bannerSafeZoneGuide: bannerSafeZoneGuide ?? this.bannerSafeZoneGuide,
    );
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
