# System Administration & Associations Exploration Report (Milestone 2)

## 1. Executive Summary
This report details the implementation plan for Milestone 2, covering **R3: System Administration** (permissions, configurations, and admin dashboards) and **R4: Associations & Management** (association wizard, member management, details panel, competition & athlete groups). It provides precise definitions for all new data models, extensions to existing classes/repositories/providers, and a step-by-step implementation strategy for the worker agent.

---

## 2. Model Blueprint & Extensions

### 2.1. Extensions to Existing Models

#### `Profile` (`lib/models/profile.dart`)
We must add user permissions fields to determine roles.
- **Fields to Add**:
  ```dart
  final bool isCompetitionCreator;
  final bool isAssociationCreator;
  final bool isAdmin;
  ```
- **Constructor Defaults**:
  ```dart
  this.isCompetitionCreator = false,
  this.isAssociationCreator = false,
  this.isAdmin = false,
  ```
- **JSON Mapping (`fromJson` / `toJson`)**:
  - `is_competition_creator` -> `isCompetitionCreator` (default `false`)
  - `is_association_creator` -> `isAssociationCreator` (default `false`)
  - `is_admin` -> `isAdmin` (default `false`)
- **`copyWith` Extension**:
  Ensure all three fields are included as nullable parameters and correctly mapped.

#### `Competition` (`lib/models/competition.dart`)
Competitions can optionally belong to an association.
- **Fields to Add**:
  ```dart
  final String? associationId;
  ```
- **JSON Mapping**:
  - `association_id` -> `associationId` (nullable)

---

### 2.2. New Data Models

#### `PermissionApplication` (`lib/models/permission_application.dart`)
Tracks requests by users to become competition or association creators.
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
    required this.status,
    required this.createdAt,
  });

  factory PermissionApplication.fromJson(Map<String, dynamic> json) {
    return PermissionApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'reason': reason,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };

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

#### `SportConfig`, `FormatConfig`, `DisciplineConfig` (`lib/models/admin_config.dart`)
Models configurations representing sports, formats, and associated disciplines.
```dart
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
  };
}

class FormatConfig {
  final String id;
  final String name;
  final String? description;
  final List<String> disciplineIds;

  FormatConfig({required this.id, required this.name, this.description, this.disciplineIds = const []});

  factory FormatConfig.fromJson(Map<String, dynamic> json) {
    return FormatConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      disciplineIds: (json['discipline_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'discipline_ids': disciplineIds,
  };
}

class SportConfig {
  final String id;
  final String name;
  final String? description;
  final List<FormatConfig> formats;

  SportConfig({required this.id, required this.name, this.description, this.formats = const []});

  factory SportConfig.fromJson(Map<String, dynamic> json) {
    return SportConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      formats: (json['formats'] as List?)?.map((e) => FormatConfig.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'formats': formats.map((f) => f.toJson()).toList(),
  };
}
```

#### `Association` (`lib/models/association.dart`)
Defines the governing body structure.
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
  final Map<String, String> rulebooks; // e.g. {'Streetlifting': 'URL'}
  final Map<String, String> socialChannels; // e.g. {'instagram': 'handle'}
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
    this.rulebooks = const {},
    this.socialChannels = const {},
    this.parentAssociationId,
    required this.status,
    required this.ownerId,
  });

  factory Association.fromJson(Map<String, dynamic> json) {
    return Association(
      id: json['id'] as String,
      name: json['name'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      scope: json['scope'] as String,
      areaName: json['area_name'] as String?,
      country: json['country'] as String?,
      website: json['website'] as String?,
      description: json['description'] as String?,
      rulebooks: Map<String, String>.from(json['rulebooks'] ?? {}),
      socialChannels: Map<String, String>.from(json['social_channels'] ?? {}),
      parentAssociationId: json['parent_association_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      ownerId: json['owner_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
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

#### `AssociationMember` (`lib/models/association_member.dart`)
Defines user membership role in associations.
```dart
class AssociationMember {
  final String id;
  final String associationId;
  final String userId;
  final String role; // 'owner', 'editor', 'member'
  final String? customTitle;

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
      role: json['role'] as String,
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

#### `CompetitionGroup` & `AthleteGroup`
Represent custom disciplines/formats and categories/weight-classes per association.
- **`CompetitionGroup`** (`lib/models/competition_group.dart`):
  - `id` (String), `associationId` (String), `name` (String), `sport` (String), `format` (String), `isActive` (bool).
- **`AthleteGroup`** (`lib/models/athlete_group.dart`):
  - `id` (String), `associationId` (String), `competitionGroupId` (String), `name` (String), `sport` (String), `format` (String), `gender` (String), `maxWeight` (double?), `isActive` (bool).

---

## 3. Repositories Design (with Mock Fallbacks)

### 3.1. `ProfileRepository` Extensions (`lib/repositories/profile_repository.dart`)
We must add permission applications management and admin promotion.
- **Methods to add**:
  - `Future<void> applyForPermissions(String userId, String type, String reason)`: Inserts a row into `'permission_applications'`.
  - `Future<List<PermissionApplication>> getPermissionApplications()`: Retrieves all application rows.
  - `Future<void> approvePermissionApplication(String applicationId)`: Sets application status to `'approved'` and updates the corresponding permission (`isCompetitionCreator` or `isAssociationCreator`) to `true` in `profiles`.
  - `Future<void> rejectPermissionApplication(String applicationId)`: Sets status to `'rejected'`.
  - `Future<void> promoteToAdmin(String userId)`: Sets `is_admin` to `true` on the profile.
- **In-Memory Fallbacks**:
  Maintain a static/in-memory list `static final List<PermissionApplication> _mockApplications = []` inside the class. Catch any database connection/query exception and perform operations against this list to ensure local widget/E2E test capability.

### 3.2. `AdminRepository` (`lib/repositories/admin_repository.dart`)
Handles configuration config parameters.
- **Methods**:
  - `Future<List<SportConfig>> loadSportsConfig()`: Queries `'sports_config'` (returns a pre-seeded default configuration including 'Streetlifting' if table is empty or fails).
  - `Future<void> saveSportsConfig(List<SportConfig> configs)`: Inserts/upserts configured sports rows.
- **In-Memory Fallbacks**:
  Provide a default static list of `SportConfig` initialized with standard Streetlifting (Classic & Modern formats and standard lifts: Pull Up, Dip, Squat, Muscle Up).

### 3.3. `AssociationRepository` (`lib/repositories/association_repository.dart`)
Handles CRUD for associations, members, and groups.
- **Methods**:
  - `Future<Association> createAssociation(Association association)`: Inserts into `'associations'` and creates the owner membership row.
  - `Future<Association> updateAssociation(Association association)`
  - `Future<Association?> getAssociation(String id)`
  - `Future<List<Association>> getAssociations()`
  - `Future<List<AssociationMember>> getAssociationMembers(String associationId)`
  - `Future<void> addAssociationMember(String associationId, String userId, String role, {String? customTitle})`
  - `Future<void> removeAssociationMember(String associationId, String userId)`
  - `Future<void> transferAssociationOwnership(String associationId, String newOwnerId)`
  - `Future<List<CompetitionGroup>> getCompetitionGroups(String associationId)`
  - `Future<CompetitionGroup> createCompetitionGroup(CompetitionGroup group)`
  - `Future<CompetitionGroup> updateCompetitionGroup(CompetitionGroup group)`
  - `Future<List<AthleteGroup>> getAthleteGroups(String associationId)`
  - `Future<AthleteGroup> createAthleteGroup(AthleteGroup group)`
  - `Future<AthleteGroup> updateAthleteGroup(AthleteGroup group)`

---

## 4. Providers Enhancements

### 4.1. `AuthProvider` (`lib/providers/auth_provider.dart`)
Exposes user details, administrative permissions, and configuration.
- **Modifications**:
  - Add dependency on `AdminRepository` in constructor.
  - Add getters: `List<SportConfig> get sportsConfigs`.
  - **Methods to Add**:
    - `Future<void> applyForPermissions(String type, String reason)`: Calls repository.
    - `Future<List<PermissionApplication>> getPermissionApplications()`
    - `Future<void> approvePermissionApplication(String applicationId)`
    - `Future<void> rejectPermissionApplication(String applicationId)`
    - `Future<void> promoteToAdmin(String userId)`
    - `Future<void> loadSportsConfig()`: Populates state.
    - `Future<void> saveSportsConfig(SportConfig config)`

### 4.2. `CompetitionProvider` (`lib/providers/competition_provider.dart`)
Manages associations life-cycle and local association state.
- **Modifications**:
  - Add dependency on `AssociationRepository` in constructor.
  - Add state variables and getters:
    - `Association? get currentAssociation`
    - `List<AssociationMember> get associationMembers`
    - `List<CompetitionGroup> get competitionGroups`
    - `List<AthleteGroup> get athleteGroups`
  - **Methods to Add**:
    - Complete passthroughs for all `AssociationRepository` methods, invoking `notifyListeners()` on state modifications.

---

## 5. UI Implementation Plans

### 5.1. `AdminDashboardPage` (`lib/views/admin_dashboard_page.dart`)
- **Accessibility**: Restrict access using `if (!authProvider.currentUserProfile.isAdmin) { ... show Unauthorized view ... }`.
- **Interface Structure**: Use a tabbed interface.
  - **Tab 1: Permissions Applications**: Lists applications with user details and "Approve" / "Reject" buttons.
  - **Tab 2: Promote Admins**: Search field for user profiles, displaying a "Promote to Admin" button.
  - **Tab 3: Sports Configuration**: Table showing sports, formats, and linked disciplines, with inputs to add/rename them.

### 5.2. `AssociationCreationPage` (`lib/views/association_creation_page.dart`)
- **Wizard Structure**: A multi-step form with state validation.
  - **Step 1: Basic Info**: Name (validated as non-empty), description, profile picture/banner pickers.
  - **Step 2: Scope**: Dropdown for scope ('global', 'area', 'national'). If 'area', show Area Name field. If 'national', show Country picker.
  - **Step 3: Sports & Formats**: Checkboxes list populated from `authProvider.sportsConfigs`.
  - **Step 4: Rulebooks**: TextFields to input rulebook links for each selected sport.
  - **Step 5: Channels**: Website and social channel handles.
  - **Step 6: Details**: Description, optional parent association parent ID, and application reason.
- Submitting inserts the association as `'pending'` status.

### 5.3. `AssociationDetailPage` (`lib/views/association_detail_page.dart`)
- Displays cover banner, profile photo, and name with status chip.
- **Tabs**:
  - **About**: Description, scope, and parent/sub-associations links.
  - **Competitions**: Integrated feeds of upcoming and past meets filtering on this association.
  - **Rulebooks & Channels**: Web links and platform social icons.
  - **Team**: List of members, roles, and custom titles.
- **Management Access**: Render a floating action button or header edit icon if the authenticated user is an Owner or Editor in `association_members`.

### 5.4. `AssociationManagementPage` (`lib/views/association_management_page.dart`)
- Accessible only to Owners & Editors.
- **Sections**:
  - **Edit Metadata**: Form to edit website, banner, social links, rulebooks.
  - **Member Roles**: Add members by searching username, setting role ('editor', 'member'), and optional custom title. Remove member buttons. Ownership transfer option (Owner only).
  - **Competition & Athlete Groups**: Lists existing groups, with forms to add new ones and toggles to make them inactive.

---

## 6. Step-by-Step Implementation Strategy

1. **Step 1: Models & Existing Code Extension**
   - Extend `Profile` (`lib/models/profile.dart`) and `Competition` (`lib/models/competition.dart`).
   - Create new files: `permission_application.dart`, `admin_config.dart`, `association.dart`, `association_member.dart`, `competition_group.dart`, and `athlete_group.dart`.
   - Update `main.dart` and `test/e2e_test_harness.dart` schemas.

2. **Step 2: Repository Extensions & Creation**
   - Modify `ProfileRepository` with permission-related methods.
   - Create `AdminRepository` and `AssociationRepository` with full offline in-memory fallbacks.
   - Inject the new repositories into the `MultiProvider` in `main.dart` and initialize them in `E2ETestHarness`.

3. **Step 3: Provider Integrations**
   - Inject `AdminRepository` into `AuthProvider`. Extend `AuthProvider` with permissions and sports config loading.
   - Inject `AssociationRepository` into `CompetitionProvider`. Extend with association states and group CRUD.

4. **Step 4: E2E Test Harness Extensions**
   - Update `test/e2e/e2e_test_harness.dart` (`InMemoryDatabase` class and `MockPostgrestFilterBuilder` interceptor) to return appropriate collections for `'association_members'`, `'competition_groups'`, `'athlete_groups'`, and `'permission_applications'`.
   - *This step is critical to ensure existing and future tests pass during implementation.*

5. **Step 5: UI Views Development**
   - Implement `AdminDashboardPage` in `lib/views/admin_dashboard_page.dart`.
   - Implement `AssociationCreationPage` wizard in `lib/views/association_creation_page.dart`.
   - Implement `AssociationDetailPage` and `AssociationManagementPage`.
   - Replace placeholders/imports in `test/e2e/mock_views.dart` with the real widgets.

6. **Step 6: Layout Adjustments & Profile Upgrades**
   - On `ProfilePage` (`lib/views/profile_page.dart`), add "Apply for Permissions" actions.
   - Apply layout adjustments in `search_feed_page.dart` (make users page top header padding 0 in mobile, change navigation drawer profile header card onTap to set `_currentMobileTabIndex = 1` instead of pushing route, overlay back button on other user profiles banner).
   - Add a `ScrollController` in `ProfilePage` to hide the username in the header sliver when visible in the main body, and display it in a smaller font once scrolled out.

7. **Step 7: Testing & Verification**
   - Write comprehensive unit tests for the models and repositories.
   - Run `flutter test` to ensure all existing and new test suites compile and pass successfully.

---

## 7. Critical Pitfalls & Design Notes

1. **E2E Mock Tables Interception**:
   Any database queries to `'association_members'`, `'competition_groups'`, etc. will error out on mock executions if they are not added to `InMemoryDatabase` inside the E2E test harness. Ensure the mock database helper is fully updated.
2. **Username Lowercase Login**:
   `loginWithUsernameAndPassword` in `AuthProvider` is already verified using `.toLowerCase()` and `TextInputFormatter` in `LoginPage` lowercases typing. Ensure new username checks in the member search or admin promotion views also perform a case-insensitive match or lowercase comparison.
3. **Scroll Controller Lifecycle**:
   When implementing scroll detection on `ProfilePage` for showing/hiding the header username, ensure the `ScrollController` is correctly disposed in `dispose()` to avoid memory leaks.
4. **Ownership Transfer Safety**:
   When transferring association ownership, the repository must perform two queries atomically: update the `owner_id` in the `associations` table, and demote the former owner to `'editor'` while promoting the new owner to `'owner'` in `'association_members'`. Ensure try/catch blocks revert correctly if partial operations fail.
