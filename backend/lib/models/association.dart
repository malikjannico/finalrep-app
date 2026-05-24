class Association {
  final String id;
  final String name;
  final String? profilePictureUrl;
  final String? bannerUrl;
  final String scope; // 'global', 'area', 'national'
  final String? areaName; // e.g., 'Europe'
  final String? country;
  final String? website;
  final String description;
  final Map<String, String> rulebooks; // sportName -> rulebookUrl
  final Map<String, String> socialChannels; // channelName -> handle
  final String? parentAssociationId;
  final String status; // 'pending', 'approved', 'rejected'
  final String ownerId;
  final List<String> supportedSports;
  final List<String> supportedFormats;

  Association({
    required this.id,
    required this.name,
    this.profilePictureUrl,
    this.bannerUrl,
    required this.scope,
    this.areaName,
    this.country,
    this.website,
    this.description = '',
    required this.rulebooks,
    required this.socialChannels,
    this.parentAssociationId,
    this.status = 'pending',
    required this.ownerId,
    this.supportedSports = const [],
    this.supportedFormats = const [],
  });

  factory Association.fromJson(Map<String, dynamic> json) {
    return Association(
      id: json['id'] as String,
      name: json['name'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      scope: json['scope'] as String? ?? 'global',
      areaName: json['area_name'] as String?,
      country: json['country'] as String?,
      website: json['website'] as String?,
      description: json['description'] as String? ?? '',
      rulebooks: json['rulebooks'] != null
          ? Map<String, String>.from(json['rulebooks'] as Map)
          : {},
      socialChannels: json['social_channels'] != null
          ? Map<String, String>.from(json['social_channels'] as Map)
          : {},
      parentAssociationId: json['parent_association_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      ownerId: json['owner_id'] as String? ?? '',
      supportedSports: json['supported_sports'] != null
          ? List<String>.from(json['supported_sports'] as List)
          : [],
      supportedFormats: json['supported_formats'] != null
          ? List<String>.from(json['supported_formats'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profile_picture_url': profilePictureUrl,
      'banner_url': bannerUrl,
      'scope': scope,
      'area_name': areaName,
      'country': country,
      'website': website,
      'description': description,
      'rulebooks': rulebooks,
      'social_channels': socialChannels,
      'parent_association_id': parentAssociationId,
      'status': status,
      'owner_id': ownerId,
      'supported_sports': supportedSports,
      'supported_formats': supportedFormats,
    };
  }

  Association copyWith({
    String? id,
    String? name,
    String? profilePictureUrl,
    String? bannerUrl,
    String? scope,
    String? areaName,
    String? country,
    String? website,
    String? description,
    Map<String, String>? rulebooks,
    Map<String, String>? socialChannels,
    String? parentAssociationId,
    String? status,
    String? ownerId,
    List<String>? supportedSports,
    List<String>? supportedFormats,
  }) {
    return Association(
      id: id ?? this.id,
      name: name ?? this.name,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      scope: scope ?? this.scope,
      areaName: areaName ?? this.areaName,
      country: country ?? this.country,
      website: website ?? this.website,
      description: description ?? this.description,
      rulebooks: rulebooks ?? this.rulebooks,
      socialChannels: socialChannels ?? this.socialChannels,
      parentAssociationId: parentAssociationId ?? this.parentAssociationId,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      supportedSports: supportedSports ?? this.supportedSports,
      supportedFormats: supportedFormats ?? this.supportedFormats,
    );
  }
}
