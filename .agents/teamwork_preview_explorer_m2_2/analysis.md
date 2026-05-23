# Milestone 2 Technical Analysis & Recommendations: System Administration & Associations

This report presents a read-only investigation and design documentation for implementing **R3 (System Administration)** and **R4 (Associations & Management)** modules within the FinalRep application.

---

## 1. Direct Observations & Codebase Analysis

### Existing Files Inspected
- **`lib/models/profile.dart`**: Currently lacks properties for user roles (`isCompetitionCreator`, `isAssociationCreator`, `isAdmin`). It does include standard fields, a `socialLinks` map, and standard json serializers/deserializers.
- **`lib/models/competition.dart`**: Contains competition metadata and helper methods for disciplines, but has no relation to `Association` or `CompetitionGroup` models.
- **`lib/repositories/profile_repository.dart`**: Queries the `profiles` table. Handles fetching profiles by ID, username, and email. Lacks methods for updating permission flags, approving applications, or administrative tasks.
- **`lib/providers/auth_provider.dart`**: Uses `ProfileRepository` to load the current user's profile. Lacks properties for user permissions, triggers for promotion, or hooks for submitting/checking applications.
- **`lib/providers/competition_provider.dart`**: Currently handles search, layout toggling, sorting, and location/date filters for competitions. Has no association-related management logic, wizard support, or group configuration logic.
- **`lib/views/search_feed_page.dart`**: Renders the main dashboard, navigation drawer, and subnav bar. Lacks entry points for Admin Dashboard, Create Association, or My Associations.
- **`lib/views/settings_page.dart` & `lib/views/profile_page.dart`**: Renders profile information and credentials settings. Lacks fields or dialog triggers for applying for permissions.

---

## 2. Details of Proposed Classes, Models & Fields

### A. Extended `Profile` Model (`lib/models/profile.dart`)
Add the following boolean fields to represent user roles:
- `final bool isCompetitionCreator;` (default `false`)
- `final bool isAssociationCreator;` (default `false`)
- `final bool isAdmin;` (default `false`)

**Modifications**:
- **Constructor**: Add optional named arguments with default values (`false`).
- **`Profile.fromJson`**:
  ```dart
  isCompetitionCreator: json['is_competition_creator'] as bool? ?? false,
  isAssociationCreator: json['is_association_creator'] as bool? ?? false,
  isAdmin: json['is_admin'] as bool? ?? false,
  ```
- **`toJson`**:
  ```dart
  'is_competition_creator': isCompetitionCreator,
  'is_association_creator': isAssociationCreator,
  'is_admin': isAdmin,
  ```
- **`copyWith`**: Add corresponding parameters and map them in the return statement.

---

### B. New Data Models

#### 1. `PermissionApplication` (`lib/models/permission_application.dart`)
Represents a user request to become a competition or association creator.
```dart
class PermissionApplication {
  final String id;
  final String userId;
  final String type; // 'create_competition' or 'create_association'
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  PermissionApplication({
    required this.id,
    required this.userId,
    required this.type,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
  });

  factory PermissionApplication.fromJson(Map<String, dynamic> json) {
    return PermissionApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'reason': reason,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  PermissionApplication copyWith({
    String? id,
    String? userId,
    String? type,
    String? reason,
    String? status,
    DateTime? createdAt,
  }) {
    return PermissionApplication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

#### 2. Sport Configuration Models (`lib/models/admin_config.dart`)
Supports adding, renaming, and linking sports, formats, and disciplines.
```dart
class SportConfig {
  final String id;
  final String name;
  final String? description;

  SportConfig({required this.id, required this.name, this.description});

  factory SportConfig.fromJson(Map<String, dynamic> json) {
    return SportConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'description': description};
}

class FormatConfig {
  final String id;
  final String sportId;
  final String name;
  final String? description;
  final List<String> disciplineIds; // Linked discipline IDs

  FormatConfig({
    required this.id,
    required this.sportId,
    required this.name,
    this.description,
    required this.disciplineIds,
  });

  factory FormatConfig.fromJson(Map<String, dynamic> json) {
    return FormatConfig(
      id: json['id'] as String,
      sportId: json['sport_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      disciplineIds: List<String>.from(json['discipline_ids'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sport_id': sportId,
        'name': name,
        'description': description,
        'discipline_ids': disciplineIds,
      };
}

class DisciplineConfig {
  final String id;
  final String name;
  final String? description;

  DisciplineConfig({required this.id, required this.name, this.description});

  factory DisciplineConfig.fromJson(Map<String, dynamic> json) {
    return DisciplineConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'description': description};
}
```

#### 3. `Association` Model (`lib/models/association.dart`)
```dart
class Association {
  final String id;
  final String name;
  final String? profilePictureUrl;
  final String? bannerUrl;
  final String scope; // 'global', 'area', 'national'
  final String? areaName;
  final String? country;
  final String? website;
  final String? description;
  final Map<String, String> rulebooks; // Map of sport name -> URL web link
  final Map<String, String> socialChannels; // Map of channel -> handle
  final String? parentAssociationId;
  final String status; // 'pending', 'approved', 'rejected'
  final String ownerId;

  Association({
    required this.id,
    required this.name,
    this.profilePictureUrl,
    this.bannerUrl,
    required this.scope,
    this.areaName,
    this.country,
    this.website,
    this.description,
    required this.rulebooks,
    required this.socialChannels,
    this.parentAssociationId,
    this.status = 'pending',
    required this.ownerId,
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
      description: json['description'] as String?,
      rulebooks: json['rulebooks'] is Map
          ? (json['rulebooks'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      socialChannels: json['social_channels'] is Map
          ? (json['social_channels'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      parentAssociationId: json['parent_association_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      ownerId: json['owner_id'] as String? ?? '',
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
    );
  }
}
```

#### 4. `AssociationMember` Model (`lib/models/association_member.dart`)
```dart
class AssociationMember {
  final String id;
  final String associationId;
  final String userId;
  final String role; // 'owner' or 'editor'
  final String? customTitle; // E.g., 'Head Coach', 'Organizer'

  AssociationMember({
    required this.id,
    required this.associationId,
    required this.userId,
    required this.role,
    this.customTitle,
  });

  factory AssociationMember.fromJson(Map<String, dynamic> json) {
    return AssociationMember(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'editor',
      customTitle: json['custom_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'association_id': associationId,
        'user_id': userId,
        'role': role,
        'custom_title': customTitle,
      };
}
```

#### 5. `CompetitionGroup` & `AthleteGroup` Models (`lib/models/competition_group.dart` & `lib/models/athlete_group.dart`)
```dart
class CompetitionGroup {
  final String id;
  final String associationId;
  final String name;
  final String sport;
  final String format;
  final bool isActive;
  final bool isAthleteGroupsRequired; // Custom requirement configuration

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
      isAthleteGroupsRequired: json['is_athlete_groups_required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'association_id': associationId,
        'name': name,
        'sport': sport,
        'format': format,
        'is_active': isActive,
        'is_athlete_groups_required': isAthleteGroupsRequired,
      };
}

class AthleteGroup {
  final String id;
  final String associationId;
  final String competitionGroupId;
  final String name;
  final String sport;
  final String format;
  final String? gender; // 'male', 'female', 'mixed'
  final double? maxWeight;
  final bool isActive;

  AthleteGroup({
    required this.id,
    required this.associationId,
    required this.competitionGroupId,
    required this.name,
    required this.sport,
    required this.format,
    this.gender,
    this.maxWeight,
    this.isActive = true,
  });

  factory AthleteGroup.fromJson(Map<String, dynamic> json) {
    return AthleteGroup(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      competitionGroupId: json['competition_group_id'] as String,
      name: json['name'] as String,
      sport: json['sport'] as String,
      format: json['format'] as String,
      gender: json['gender'] as String?,
      maxWeight: (json['max_weight'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'association_id': associationId,
        'competition_group_id': competitionGroupId,
        'name': name,
        'sport': sport,
        'format': format,
        'gender': gender,
        'max_weight': maxWeight,
        'is_active': isActive,
      };
}
```

---

## 3. Repositories & In-Memory Fallbacks

### A. Extended `ProfileRepository` (`lib/repositories/profile_repository.dart`)
Add methods for promoting users and changing permission values directly:
```dart
Future<Profile?> updatePermissions(String userId, {bool? isCompetitionCreator, bool? isAssociationCreator, bool? isAdmin}) async {
  try {
    final Map<String, dynamic> data = {};
    if (isCompetitionCreator != null) data['is_competition_creator'] = isCompetitionCreator;
    if (isAssociationCreator != null) data['is_association_creator'] = isAssociationCreator;
    if (isAdmin != null) data['is_admin'] = isAdmin;

    final response = await _client
        .from('profiles')
        .update(data)
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
  } catch (e) {
    debugPrint('Error updating permissions in DB: $e');
    // Fallback updates profile local properties if profile is retrieved from mock store
    return null;
  }
}
```

### B. New `AdminRepository` (`lib/repositories/admin_repository.dart`)
Handles configuration management and system-level applications.
- **In-Memory Fallbacks**:
  Maintain static arrays for:
  - `static List<PermissionApplication> _mockApplications = [];`
  - `static Map<String, dynamic> _mockSportsConfig = {
      'sports': [{'id': 'sl', 'name': 'Streetlifting', 'description': 'Bodyweight training with weights'}],
      'formats': [{'id': 'modern', 'sport_id': 'sl', 'name': 'Modern', 'description': 'Muscle Up, Pull Up, Dip, Squat', 'discipline_ids': ['mu', 'pu', 'dp', 'sq']}],
      'disciplines': [
        {'id': 'mu', 'name': 'Muscle Up'},
        {'id': 'pu', 'name': 'Pull Up'},
        {'id': 'dp', 'name': 'Dip'},
        {'id': 'sq', 'name': 'Squat'}
      ]
    };`

- **Repository Methods (implementing Supabase call + try-catch fallback)**:
  - `Future<List<PermissionApplication>> getPermissionApplications()`
  - `Future<PermissionApplication> applyForPermissions(String userId, String type, String reason)`
  - `Future<void> updateApplicationStatus(String id, String status)`
  - `Future<void> promoteToAdmin(String userId)`
  - `Future<Map<String, dynamic>> loadSportsConfig()`
  - `Future<void> saveSportsConfig(Map<String, dynamic> config)`

### C. New `AssociationRepository` (`lib/repositories/association_repository.dart`)
- **In-Memory Fallbacks**:
  - `static List<Association> _mockAssociations = [];`
  - `static List<AssociationMember> _mockMembers = [];`
  - `static List<CompetitionGroup> _mockCompGroups = [];`
  - `static List<AthleteGroup> _mockAthleteGroups = [];`
- **Repository Methods (implementing Supabase call + try-catch fallback)**:
  - `Future<Association> createAssociation(Association association)`
  - `Future<Association> updateAssociation(Association association)`
  - `Future<Association?> getAssociationDetails(String id)`
  - `Future<List<AssociationMember>> getAssociationMembers(String associationId)`
  - `Future<AssociationMember> addAssociationMember(String associationId, String userId, String role, {String? customTitle})`
  - `Future<void> removeAssociationMember(String associationId, String userId)`
  - `Future<void> transferAssociationOwnership(String associationId, String newOwnerId)`
  - `Future<List<CompetitionGroup>> getCompetitionGroups(String associationId)`
  - `Future<List<AthleteGroup>> getAthleteGroups(String associationId)`
  - `Future<CompetitionGroup> createCompetitionGroup(CompetitionGroup group)`
  - `Future<CompetitionGroup> updateCompetitionGroup(CompetitionGroup group)`
  - `Future<AthleteGroup> createAthleteGroup(AthleteGroup group)`
  - `Future<AthleteGroup> updateAthleteGroup(AthleteGroup group)`

---

## 4. Provider Changes & Coordination Contracts

### A. `AuthProvider` modifications (`lib/providers/auth_provider.dart`)
- **Properties / Getters**:
  ```dart
  bool get isCompetitionCreator => _currentUserProfile?.isCompetitionCreator ?? false;
  bool get isAssociationCreator => _currentUserProfile?.isAssociationCreator ?? false;
  bool get isAdmin => _currentUserProfile?.isAdmin ?? false;
  ```
- **New Admin Actions**:
  - `Future<void> applyForPermissions(String type, String reason)`: Submits an application for the current user.
  - `Future<List<PermissionApplication>> fetchApplications()`: For admin view.
  - `Future<void> approvePermission(String id, String userId, String type)`: Approves application, calls database/fallback to update user permissions flag, notify listeners.
  - `Future<void> rejectPermission(String id)`: Rejects application, notify listeners.
  - `Future<void> promoteUserToAdmin(String userId)`: Sets user's `isAdmin` to true.
  - `Future<Map<String, dynamic>> getSportsConfig()`: Access current configuration.
  - `Future<void> updateSportsConfig(Map<String, dynamic> config)`: Saves new sports/formats configuration.

### B. `CompetitionProvider` modifications (`lib/providers/competition_provider.dart`)
- Expose state for associations, competition groups, and athlete groups.
- **Wizard Integration**:
  - Add wizard state management functions if the wizard UI delegates saving to the provider.
- **Association CRUD Methods**:
  - Expose creation, details loader, member modifications, ownership transfers, and status approvals for associations applying to a parent.
- **Competition Setup Coordination**:
  - In `createCompetition(Competition comp)` (from R5/R6 updates), if an association is selected:
    - Automatically inherit and set `rulebookUrl = selectedAssociation.rulebooks[comp.sportType]`.
    - Retrieve active `CompetitionGroup` and apply its requirements. Ensure required athlete groups are enforced; otherwise, let user add custom groups.

---

## 5. UI Layer & Views Design

### A. Admin Dashboard (`lib/views/admin_dashboard_page.dart`)
Only accessible if `authProvider.isAdmin` is true. Contains three views (using a `TabBar` or `NavigationRail`):
1. **Creator Applications**:
   - Lists all `pending` applications with requesting User Full Name/Username, date, type (Competition/Association Creator), and text reason.
   - Includes distinct action buttons: **Approve** (success toast, triggers user promotion, updates list) and **Reject** (rejection confirmation).
   - Lists already accepted creators, with a search field and options to toggle rights or promote to Admin.
2. **Association Applications**:
   - Shows new associations applying with parent association links.
   - Provides Approve/Reject controls.
3. **Sports Configurations Table**:
   - Tree/table listing of Sports, Formats (under each sport), and Disciplines.
   - Ability to "Add Sport", "Add Format", "Add Discipline" via dialog fields.
   - Allows linking disciplines to formats (e.g. multi-select checkbox grids).

### B. Permissions Application Form (`lib/views/permission_application_dialog.dart`)
- Accessible from `SettingsPage` or `ProfilePage`.
- Form containing:
  - Radio toggle or segmented button: "Competition Creator" vs "Association Creator".
  - Text input for "Application Reason" (multiline, validated to ensure it's not empty).
  - Submit button.
  - If a pending request exists, hide form and show: "Your application is currently under review."

### C. Association Views
1. **`AssociationCreationPage` (`lib/views/association_creation_page.dart`)**:
   - 5-Step wizard with validation and visual progress indicators (dots or stepper):
     - **Step 1**: Association Name, description, banner image picker, avatar image picker.
     - **Step 2**: Scope selection (Segmented button: global, area, national). If National, show dropdown country list. If Area, show text input.
     - **Step 3**: Supported Sports and Formats (Checkbox list).
     - **Step 4**: Web links configuration: rulebook URL per selected sport, website URL, social media handles.
     - **Step 5**: Summary & parent association link (Optional list of approved associations). If parent selected, require parent application text reason.
2. **`AssociationDetailPage` (`lib/views/association_detail_page.dart`)**:
   - Layout: Banner (top), profile picture overlap, name, description, website, and rulebooks.
   - Tabs:
     - **Competitions**: Switchable list for upcoming meets vs. completed meets.
     - **Sub-Associations**: Sub-associations tree list.
     - **Team Members**: Team members list showing their role and custom title.
   - Header action: If current user is Owner or Editor of the association, render a gear/edit icon navigating to `AssociationManagementPage`.
3. **`AssociationManagementPage` (`lib/views/association_management_page.dart`)**:
   - Tabs/Panels:
     - **Metadata update**: Reuse Step 1-4 fields from creation wizard.
     - **Team management**: Search user profiles, add to team, select role (Owner vs. Editor), input custom title. Owner/Admin can perform ownership transfer.
     - **Competition Groups**: Config table to add group name, choose sport and format, toggle `isActive` (if inactive, disable during competition creation), toggle `isAthleteGroupsRequired`.
     - **Athlete Groups**: Setup weight classes per competition group (name, gender, max weight), toggle `isActive`.

### D. Navigation Integration
- **`SearchFeedPage` Drawer**:
  - If user is logged in, show `ListTile` for "My Associations" (navigates to user's managed associations) or "Create Association" (if user has `isAssociationCreator` permission).
  - If user is admin, show `ListTile` for "Admin Dashboard" (leading to `AdminDashboardPage`).
- **`SearchFeedPage` Desktop Header**:
  - Append "My Associations" or "Admin Panel" to sub-navigation bar when authenticated as creator/admin.

---

## 6. Step-by-Step Implementation Strategy

### Milestone 1: Data Models & Serialization
1. Create new models:
   - `lib/models/permission_application.dart`
   - `lib/models/admin_config.dart`
   - `lib/models/association.dart`
   - `lib/models/association_member.dart`
   - `lib/models/competition_group.dart`
   - `lib/models/athlete_group.dart`
2. Extend `lib/models/profile.dart` with `isCompetitionCreator`, `isAssociationCreator`, `isAdmin` properties and update serialization.
3. Write unit tests in `test/models_test.dart` to verify `fromJson`, `toJson`, and `copyWith` for all new models.

### Milestone 2: Repositories & In-Memory Fallbacks
1. Create `lib/repositories/admin_repository.dart` and `lib/repositories/association_repository.dart` with static mock storage arrays.
2. Implement repository methods fetching from Supabase and reverting to static fallbacks on catch blocks.
3. Extend `lib/repositories/profile_repository.dart` with `updatePermissions(...)`.
4. Run `flutter test` to ensure compilation.

### Milestone 3: State Management (Providers)
1. Add state fields, getters, and action methods in `lib/providers/auth_provider.dart` for permission applications, configurations, and administrative controls.
2. Add state fields, getters, and action methods in `lib/providers/competition_provider.dart` for association CRUD, group configurations, and rules enforcement checks.
3. Register the new repositories in `lib/main.dart` and pass them to provider constructors.
4. Write provider unit tests mocking the database calls and verifying permission promotion flows.

### Milestone 4: Admin Dashboard & Permission UI
1. Implement `lib/views/admin_dashboard_page.dart` (Applications review tab, Sports config tree/table, Users promotion tab).
2. Implement application dialog UI.
3. Add permission application trigger button in `lib/views/settings_page.dart`.
4. Add "Admin Dashboard" navigation entries in drawer and desktop headers.

### Milestone 5: Association Management Pages
1. Implement `lib/views/association_creation_page.dart` stepper wizard.
2. Implement `lib/views/association_detail_page.dart` layout (competitions list, team list).
3. Implement `lib/views/association_management_page.dart` panels (member roles, weight classes, and group requirements).
4. Add "Create Association" navigation entries in drawer and desktop headers.

### Milestone 6: Verification & Testing
1. Write unit and widget tests targeting:
   - Access controls (ensuring non-admins cannot open `AdminDashboardPage`).
   - Stepper validations (scope, channels step validations).
   - In-memory fallback behavior when remote database requests fail.

---

## 7. Pitfalls, Security and Contract Constraints

- **Route Settings Name Validation**: All new pages pushed via `Navigator.push` must specify a `RouteSettings(name: '/...')` to guarantee that deep-linking navigates correctly and avoids route mismatch crashes. E.g., `RouteSettings(name: '/admin')`.
- **Database Trigger Latency**: In Supabase, user profile creation is often handled by an asynchronous database trigger on the auth schema. The retry logic in `_fetchProfileWithRetry` in `AuthProvider` must be respected so updates to permission properties do not cause visual sync delays.
- **Access Safety Guard**:
  - Always verify user permissions inside the build method of administrative pages, throwing an unauthorized view or popping the navigator if a non-authorized profile attempts access.
  - E.g. in `AdminDashboardPage`:
    ```dart
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin) {
      return const Scaffold(body: Center(child: Text("Unauthorized")));
    }
    ```
