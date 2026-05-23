# Analysis Report: User Profiles Customization (R2) Data Models and Repositories

## Executive Summary
This analysis details the required model and repository changes to support social media link integration, profile persistence updates, and new profile sections (Upcoming/Completed Meets, Highest Rankings, and Personal Records). The core data models can be extended cleanly with no structural modifications to the query logic in the repository, provided the corresponding database column mappings are correctly configured.

---

## 1. Social Media Links in Profile Model and UI Representation

### Model Extensions (`lib/models/profile.dart`)
To store social media links, the `Profile` model needs a `Map<String, String>? socialLinks` field where the keys represent the platform name (e.g., `'instagram'`, `'youtube'`) and values represent the handle or URL.

#### Proposed Dart Code Changes:
```dart
class Profile {
  // Existing fields...
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String? gender;
  final String? country;
  final String? profilePictureUrl;
  final String? description;
  final String colorMode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // New field
  final Map<String, String>? socialLinks;

  Profile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.gender,
    this.country,
    this.profilePictureUrl,
    this.description,
    this.colorMode = 'system',
    this.createdAt,
    this.updatedAt,
    this.socialLinks, // New field
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      gender: json['gender'] as String?,
      country: json['country'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      description: json['description'] as String?,
      colorMode: json['color_mode'] as String? ?? 'system',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
      // Deserialize JSONB map to Map<String, String>
      socialLinks: json['social_links'] != null
          ? Map<String, String>.from(json['social_links'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'gender': gender,
      'country': country,
      'profile_picture_url': profilePictureUrl,
      'description': description,
      'color_mode': colorMode,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      // Serialize to JSONB field
      if (socialLinks != null) 'social_links': socialLinks,
    };
  }

  Profile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? email,
    String? gender,
    String? country,
    String? profilePictureUrl,
    String? description,
    String? colorMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? socialLinks, // New parameter
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      description: description ?? this.description,
      colorMode: colorMode ?? this.colorMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      socialLinks: socialLinks ?? this.socialLinks, // New mapping
    );
  }
}
```

### UI Presentation Strategy (Names and Icons)
To display the social links cleanly in the UI, we should create a helper class that maps platform names to display names, icons, and base URLs.

#### Helper Class:
```dart
import 'package:flutter/material.dart';

class SocialPlatformInfo {
  final String displayName;
  final IconData icon;
  final String baseUrl;

  const SocialPlatformInfo({
    required this.displayName,
    required this.icon,
    required this.baseUrl,
  });
}

class SocialMediaHelper {
  static const Map<String, SocialPlatformInfo> platforms = {
    'instagram': SocialPlatformInfo(
      displayName: 'Instagram',
      icon: Icons.camera_alt_outlined,
      baseUrl: 'https://instagram.com/',
    ),
    'youtube': SocialPlatformInfo(
      displayName: 'YouTube',
      icon: Icons.play_circle_outline,
      baseUrl: 'https://youtube.com/',
    ),
    'twitter': SocialPlatformInfo(
      displayName: 'Twitter',
      icon: Icons.alternate_email,
      baseUrl: 'https://twitter.com/',
    ),
    'tiktok': SocialPlatformInfo(
      displayName: 'TikTok',
      icon: Icons.music_note,
      baseUrl: 'https://tiktok.com/@',
    ),
    'website': SocialPlatformInfo(
      displayName: 'Website',
      icon: Icons.link,
      baseUrl: '',
    ),
  };

  static String getFullUrl(String platform, String handleOrUrl) {
    final info = platforms[platform.toLowerCase()];
    if (info == null) return handleOrUrl;
    if (handleOrUrl.startsWith('http://') || handleOrUrl.startsWith('https://')) {
      return handleOrUrl;
    }
    return '${info.baseUrl}$handleOrUrl';
  }
}
```

#### UI Representation (Horizontal Wrap of Chips):
Using this mapping, social links can be rendered inside a `Wrap` widget on the profile details card:
```dart
Widget _buildSocialLinksRow(Profile profile) {
  if (profile.socialLinks == null || profile.socialLinks!.isEmpty) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: profile.socialLinks!.entries.map((entry) {
        final platform = entry.key;
        final handle = entry.value;
        final info = SocialMediaHelper.platforms[platform.toLowerCase()];
        
        final displayName = info?.displayName ?? platform;
        final icon = info?.icon ?? Icons.link;

        return ActionChip(
          avatar: Icon(icon, size: 16),
          label: Text('$displayName: $handle'),
          onPressed: () async {
            final urlString = SocialMediaHelper.getFullUrl(platform, handle);
            final url = Uri.parse(urlString);
            // Launch the URL (using url_launcher package if available)
          },
        );
      }).toList(),
    ),
  );
}
```

---

## 2. Profile Repository Updates

### Data Persistence and Retrieval Analysis
The `ProfileRepository` in `lib/repositories/profile_repository.dart` handles database interactions for users via the Supabase client:
1. **Retrieval**: Uses `_client.from('profiles').select().eq('id', id).maybeSingle()`. Since `.select()` retrieves all columns from the database, the new `social_links` column will be included in the JSON payload returned from the DB. `Profile.fromJson` will automatically process this mapping.
2. **Persistence**: `updateProfile` converts the profile model to a map with `profile.toJson()`. It then passes this directly into the Supabase `.update()` statement.
3. **Implication**: If `Profile` data serialization and deserialization is updated, **no modifications to the body of the `ProfileRepository` methods are needed** to fetch or persist the new `socialLinks` data. It is completely transparent.

### Required Database Updates
To support this, a migration is required on the Supabase database to add the new `social_links` column:
```sql
ALTER TABLE public.profiles
ADD COLUMN social_links JSONB DEFAULT '{}'::jsonb;
```

---

## 3. Profile Sections (Meets, Rankings, Personal Records)

To implement the "Upcoming/Completed Meets", "Highest Rankings", and "Personal Records" sections, we need to design their models, database tables, and retrieval repositories.

### Section A: Upcoming/Completed Meets
A Meet corresponds to a `Competition` (defined in `lib/models/competition.dart`). A user is associated with a meet via registrations.

#### 1. Database Schema
```sql
-- Junction table for meet registrations
CREATE TABLE public.meet_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    competition_id UUID REFERENCES public.competitions(id) ON DELETE CASCADE,
    competition_class TEXT, -- e.g., "Male -83kg"
    status TEXT DEFAULT 'registered', -- e.g., 'registered', 'withdrawn', 'completed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(profile_id, competition_id)
);

-- Table for completed meet results
CREATE TABLE public.meet_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    competition_id UUID REFERENCES public.competitions(id) ON DELETE CASCADE,
    competition_class TEXT NOT NULL,
    total_score NUMERIC NOT NULL, -- Sum of best lifts
    rank INTEGER NOT NULL, -- Placement in category
    best_lifts JSONB NOT NULL, -- e.g., {"Muscle Up": 15.0, "Pull Up": 42.5}
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(profile_id, competition_id)
);
```

#### 2. Dart Models
```dart
class MeetRegistration {
  final String id;
  final String profileId;
  final String competitionId;
  final String? competitionClass;
  final String status;
  final DateTime createdAt;
  final Competition? competition; // Loaded relation

  MeetRegistration({
    required this.id,
    required this.profileId,
    required this.competitionId,
    this.competitionClass,
    this.status = 'registered',
    required this.createdAt,
    this.competition,
  });

  factory MeetRegistration.fromJson(Map<String, dynamic> json) {
    return MeetRegistration(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      competitionId: json['competition_id'] as String,
      competitionClass: json['competition_class'] as String?,
      status: json['status'] as String? ?? 'registered',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      competition: json['competition'] != null
          ? Competition.fromJson(json['competition'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MeetResult {
  final String id;
  final String profileId;
  final String competitionId;
  final String competitionClass;
  final double totalScore;
  final int rank;
  final Map<String, double> bestLifts;
  final DateTime createdAt;
  final Competition? competition; // Loaded relation

  MeetResult({
    required this.id,
    required this.profileId,
    required this.competitionId,
    required this.competitionClass,
    required this.totalScore,
    required this.rank,
    required this.bestLifts,
    required this.createdAt,
    this.competition,
  });

  factory MeetResult.fromJson(Map<String, dynamic> json) {
    return MeetResult(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      competitionId: json['competition_id'] as String,
      competitionClass: json['competition_class'] as String? ?? '',
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
      rank: json['rank'] as int? ?? 0,
      bestLifts: Map<String, double>.from(
        (json['best_lifts'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      competition: json['competition'] != null
          ? Competition.fromJson(json['competition'] as Map<String, dynamic>)
          : null,
    );
  }
}
```

---

### Section B: Highest Rankings
A history of user rankings across divisions (e.g. National, Global).

#### 1. Database Schema
```sql
CREATE TABLE public.highest_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    rank_type TEXT NOT NULL, -- e.g., 'Global', 'National', 'Group'
    category TEXT NOT NULL, -- e.g., 'Modern -83kg'
    rank INTEGER NOT NULL,
    score NUMERIC NOT NULL, -- Points or total weight
    source_meet_title TEXT, -- Cached text name of meet
    source_meet_id UUID REFERENCES public.competitions(id) ON DELETE SET NULL,
    achieved_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 2. Dart Model
```dart
class HighestRanking {
  final String id;
  final String profileId;
  final String rankType;
  final String category;
  final int rank;
  final double score;
  final String? sourceMeetTitle;
  final String? sourceMeetId;
  final DateTime achievedAt;

  HighestRanking({
    required this.id,
    required this.profileId,
    required this.rankType,
    required this.category,
    required this.rank,
    required this.score,
    this.sourceMeetTitle,
    this.sourceMeetId,
    required this.achievedAt,
  });

  factory HighestRanking.fromJson(Map<String, dynamic> json) {
    return HighestRanking(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      rankType: json['rank_type'] as String,
      category: json['category'] as String,
      rank: json['rank'] as int,
      score: (json['score'] as num).toDouble(),
      sourceMeetTitle: json['source_meet_title'] as String?,
      sourceMeetId: json['source_meet_id'] as String?,
      achievedAt: DateTime.parse(json['achieved_at'] as String).toLocal(),
    );
  }
}
```

---

### Section C: Personal Records (PRs)
Tracks a user's heaviest single lifts (1RMs) in each streetlifting discipline.

#### 1. Database Schema
```sql
CREATE TABLE public.personal_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    discipline TEXT NOT NULL, -- 'Muscle Up', 'Pull Up', 'Dip', 'Squat'
    weight NUMERIC NOT NULL, -- weight in kg
    reps INTEGER DEFAULT 1,
    location TEXT, -- e.g., 'Gym', 'FinalRep Hamburg'
    competition_id UUID REFERENCES public.competitions(id) ON DELETE SET NULL,
    achieved_at TIMESTAMPTZ DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT FALSE
);
```

#### 2. Dart Model
```dart
class PersonalRecord {
  final String id;
  final String profileId;
  final String discipline;
  final double weight;
  final int reps;
  final String? location;
  final String? competitionId;
  final DateTime achievedAt;
  final bool isVerified;

  PersonalRecord({
    required this.id,
    required this.profileId,
    required this.discipline,
    required this.weight,
    this.reps = 1,
    this.location,
    this.competitionId,
    required this.achievedAt,
    this.isVerified = false,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    return PersonalRecord(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      discipline: json['discipline'] as String,
      weight: (json['weight'] as num).toDouble(),
      reps: json['reps'] as int? ?? 1,
      location: json['location'] as String?,
      competitionId: json['competition_id'] as String?,
      achievedAt: DateTime.parse(json['achieved_at'] as String).toLocal(),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}
```

---

### Repository Data Fetching Methods
To keep the main user profile lookup fast, the profiles sections should be loaded asynchronously via distinct fetching methods inside `ProfileRepository`:

```dart
class ProfileRepository {
  // Existing fields/methods...

  /// Fetch a user's upcoming meets (where start_date is in the future)
  Future<List<Competition>> getUserUpcomingMeets(String profileId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await _client
          .from('meet_registrations')
          .select('*, competition:competitions(*)')
          .eq('profile_id', profileId)
          .eq('status', 'registered')
          .gte('competition.start_date', now);

      final list = response as List? ?? [];
      final meets = list
          .map((data) => data['competition'])
          .where((comp) => comp != null)
          .map((compJson) => Competition.fromJson(compJson as Map<String, dynamic>))
          .toList();
          
      meets.sort((a, b) => a.startDate.compareTo(b.startDate));
      return meets;
    } catch (e) {
      debugPrint('Error getting upcoming meets: $e');
      return [];
    }
  }

  /// Fetch a user's completed meets (using the results table)
  Future<List<MeetResult>> getUserCompletedMeets(String profileId) async {
    try {
      final response = await _client
          .from('meet_results')
          .select('*, competition:competitions(*)')
          .eq('profile_id', profileId);

      final list = response as List? ?? [];
      final results = list
          .map((data) => MeetResult.fromJson(data as Map<String, dynamic>))
          .toList();
          
      results.sort((a, b) => b.competition?.startDate.compareTo(a.competition?.startDate ?? DateTime.now()) ?? 0);
      return results;
    } catch (e) {
      debugPrint('Error getting completed meets: $e');
      return [];
    }
  }

  /// Fetch a user's highest rankings
  Future<List<HighestRanking>> getUserHighestRankings(String profileId) async {
    try {
      final response = await _client
          .from('highest_rankings')
          .select()
          .eq('profile_id', profileId)
          .order('rank', ascending: true);

      final list = response as List? ?? [];
      return list
          .map((data) => HighestRanking.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting highest rankings: $e');
      return [];
    }
  }

  /// Fetch a user's personal records
  Future<List<PersonalRecord>> getUserPersonalRecords(String profileId) async {
    try {
      final response = await _client
          .from('personal_records')
          .select()
          .eq('profile_id', profileId);

      final list = response as List? ?? [];
      return list
          .map((data) => PersonalRecord.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting personal records: $e');
      return [];
    }
  }
}
```

This model architecture is decoupled, supports relational joins, and maps cleanly to the Supabase client without causing context bloat on basic login.
