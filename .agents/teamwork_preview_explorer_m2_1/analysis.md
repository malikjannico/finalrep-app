# Technical Analysis & Implementation Plan: R3 (System Administration) & R4 (Associations & Management)

## Executive Summary
This document provides a comprehensive technical exploration and implementation blueprint for introducing R3 (System Administration) and R4 (Associations & Management) features in the FinalRep App. All recommendations are designed to integrate seamlessly with the existing clean architecture (Model-Repository-Provider-UI) and to include full testability via in-memory mock fallbacks.

---

## 1. Class & Code Modifications

### A. Data Models (`lib/models/`)

#### 1. `lib/models/profile.dart` (Modify)
*   **Fields to Add**:
    *   `final bool isCompetitionCreator;`
    *   `final bool isAssociationCreator;`
    *   `final bool isAdmin;`
*   **Constructor Changes**:
    *   Initialize with defaults: `this.isCompetitionCreator = false`, `this.isAssociationCreator = false`, `this.isAdmin = false`.
*   **Serialization Changes**:
    *   `fromJson`: Parse keys `is_competition_creator` (fallback to false), `is_association_creator` (fallback to false), and `is_admin` (fallback to false).
    *   `toJson`: Add `'is_competition_creator'`, `'is_association_creator'`, `'is_admin'`.
    *   `copyWith`: Include the three flags.

#### 2. `lib/models/competition.dart` (Modify)
*   **Fields to Add**:
    *   `final String? associationId;` (Association hosting this competition, if any)
    *   `final String? competitionGroupId;` (Linked competition group from association)
    *   `final List<String>? athleteGroupIds;` (Active weight classes/categories applied)
    *   `final String? rulebookUrl;` (Inherited from association or custom)
*   **Constructor & Serialization**:
    *   Update constructor, `fromJson`, `toJson` to serialize these fields properly.

#### 3. `lib/models/permission_application.dart` (NEW)
Models the permission requests submitted by users.
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

  factory PermissionApplication.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
}
```

#### 4. `lib/models/admin_config.dart` (NEW)
Models custom sports configurations, formats, and linked disciplines.
```dart
class SportConfig {
  final String name;
  final String? description;
  final List<FormatConfig> formats;

  SportConfig({required this.name, this.description, required this.formats});
  factory SportConfig.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
}

class FormatConfig {
  final String name;
  final String? description;
  final List<String> disciplineNames; // Linked disciplines

  FormatConfig({required this.name, this.description, required this.disciplineNames});
  factory FormatConfig.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
}

class DisciplineConfig {
  final String name;
  final String? description;

  DisciplineConfig({required this.name, this.description});
  factory DisciplineConfig.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
}
```

#### 5. `lib/models/association.dart` (NEW)
Represents a Streetlifting association.
*   **Fields**:
    *   `final String id;`
    *   `final String name;`
    *   `final String? profilePictureUrl;`
    *   `final String? bannerUrl;`
    *   `final String scope;` // 'global', 'area', 'national'
    *   `final String? areaName;`
    *   `final String? country;`
    *   `final List<String> supportedSports;`
    *   `final List<String> supportedFormats;`
    *   `final Map<String, String> rulebooks;` // Map of sport name to rulebook URL
    *   `final String? website;`
    *   `final Map<String, String> socialChannels;` // Map of channel to handle
    *   `final String? description;`
    *   `final String? parentAssociationId;`
    *   `final String status;` // 'pending', 'approved', 'rejected' (for sub-associations applying to parent)
    *   `final String ownerId;`

#### 6. `lib/models/association_member.dart` (NEW)
Defines association membership roles.
*   **Fields**:
    *   `final String id;`
    *   `final String associationId;`
    *   `final String userId;`
    *   `final String role;` // 'owner', 'editor', 'member'
    *   `final String? customTitle;`

#### 7. `lib/models/competition_group.dart` (NEW)
E.g., "FinalRep Qualifier", "FinalRep Underground" groups under an association.
*   **Fields**:
    *   `final String id;`
    *   `final String associationId;`
    *   `final String name;`
    *   `final String sport;`
    *   `final String format;`
    *   `final bool isActive;`

#### 8. `lib/models/athlete_group.dart` (NEW)
E.g., Weight classes or age divisions under a competition group.
*   **Fields**:
    *   `final String id;`
    *   `final String associationId;`
    *   `final String competitionGroupId;`
    *   `final String name;`
    *   `final String sport;`
    *   `final String format;`
    *   `final String? gender;`
    *   `final double? maxWeight;`
    *   `final bool isActive;`

---

### B. Database & Repository Layer (`lib/repositories/`)

All repositories must implement local in-memory maps or fallback data structures to handle offline state or db errors.

#### 1. `lib/repositories/profile_repository.dart` (Modify)
*   **Methods to Add**:
    *   `Future<bool> promoteToAdmin(String userId)`: Sets `is_admin = true` for a profile.
    *   `Future<bool> updateUserPermissions(String userId, {bool? isCompetitionCreator, bool? isAssociationCreator, bool? isAdmin})`: Updates permission flags.

#### 2. `lib/repositories/admin_repository.dart` (NEW)
```dart
class AdminRepository {
  final SupabaseClient _client;
  // Local fallback maps for in-memory operation (tests / offline)
  final Map<String, PermissionApplication> _mockApplications = {};
  SportConfig? _mockSportConfig;

  AdminRepository(this._client);

  Future<List<PermissionApplication>> getPermissionApplications() async { ... }
  Future<PermissionApplication?> createPermissionApplication(PermissionApplication app) async { ... }
  Future<bool> updatePermissionApplicationStatus(String id, String status) async { ... }
  Future<SportConfig?> loadSportsConfig() async { ... }
  Future<bool> saveSportsConfig(SportConfig config) async { ... }
}
```

#### 3. `lib/repositories/association_repository.dart` (NEW)
Handles creation, members list, competition groups, and athlete classes.
```dart
class AssociationRepository {
  final SupabaseClient _client;
  
  // Local in-memory caches for fallback
  final Map<String, Association> _mockAssociations = {};
  final List<AssociationMember> _mockMembers = [];
  final List<CompetitionGroup> _mockCompGroups = [];
  final List<AthleteGroup> _mockAthleteGroups = [];

  AssociationRepository(this._client);

  // Association CRUD
  Future<Association?> createAssociation(Association association) async { ... }
  Future<Association?> updateAssociation(Association association) async { ... }
  Future<Association?> getAssociationById(String id) async { ... }
  Future<List<Association>> getAssociations() async { ... }

  // Member management
  Future<List<AssociationMember>> getAssociationMembers(String associationId) async { ... }
  Future<AssociationMember?> addAssociationMember(AssociationMember member) async { ... }
  Future<bool> removeAssociationMember(String associationId, String userId) async { ... }

  // Competition & Athlete groups
  Future<List<CompetitionGroup>> getCompetitionGroups(String associationId) async { ... }
  Future<CompetitionGroup?> createCompetitionGroup(CompetitionGroup group) async { ... }
  Future<bool> updateCompetitionGroup(CompetitionGroup group) async { ... }

  Future<List<AthleteGroup>> getAthleteGroups(String associationId) async { ... }
  Future<AthleteGroup?> createAthleteGroup(AthleteGroup group) async { ... }
  Future<bool> updateAthleteGroup(AthleteGroup group) async { ... }
}
```

---

### C. State Management Layer (`lib/providers/`)

#### 1. `lib/providers/auth_provider.dart` (Modify)
*   **Dependency Changes**: Accept `AdminRepository adminRepository` in constructor.
*   **Methods to Add**:
    *   `Future<void> applyForPermissions(String type, String reason)`: Submits application.
    *   `Future<List<PermissionApplication>> getPermissionApplications()`: Admins fetch all applications.
    *   `Future<void> approvePermissionApplication(String applicationId)`: Sets application status to 'approved' and promotes the user in profile table.
    *   `Future<void> rejectPermissionApplication(String applicationId)`: Rejects application.
    *   `Future<void> promoteToAdmin(String userId)`: Elevates `isAdmin` to true.
    *   `Future<SportConfig?> loadSportsConfig()`: Reads global sport config.
    *   `Future<void> saveSportsConfig(SportConfig config)`: Writes global sport config.

#### 2. `lib/providers/competition_provider.dart` (Modify)
*   **Dependency Changes**: Accept `AssociationRepository associationRepository` in constructor.
*   **Methods to Add**:
    *   `Future<void> createAssociation(Association association)`: Adds new association (wizard endpoint).
    *   `Future<void> updateAssociation(Association association)`: Edits metadata.
    *   `Future<Association?> getAssociationDetails(String id)`: Returns details.
    *   `Future<List<AssociationMember>> getAssociationMembers(String associationId)`
    *   `Future<void> addAssociationMember(String associationId, String userId, String role)`
    *   `Future<void> removeAssociationMember(String associationId, String userId)`
    *   `Future<void> transferAssociationOwnership(String associationId, String newOwnerId)`: Transfers ownership.
    *   `Future<List<CompetitionGroup>> getCompetitionGroups(String associationId)`
    *   `Future<List<AthleteGroup>> getAthleteGroups(String associationId)`
    *   `Future<void> createCompetitionGroup(CompetitionGroup group)`
    *   `Future<void> updateCompetitionGroupStatus(String groupId, bool isActive)`
    *   `Future<void> createAthleteGroup(AthleteGroup group)`
    *   `Future<void> updateAthleteGroupStatus(String groupId, bool isActive)`

---

### D. User Interface Layer (`lib/views/`)

#### 1. `lib/views/admin_dashboard_page.dart` (NEW)
*   **Accessibility**: Navigation drawer option visible only to `authProvider.currentUserProfile.isAdmin == true`.
*   **Interface Structure**:
    *   **Tab 1: Permissions Review**: Displays pending permission applications (creator applications) with name, date, type, reason, and action buttons (Approve/Reject).
    *   **Tab 2: Admin Promotion**: Search list of users with a button to promote the selected user to administrator.
    *   **Tab 3: Sports Config**: Table showing current sports list, formats, and linked disciplines. Buttons to "Add Sport", "Rename", "Add Format", "Edit Linked Disciplines".

#### 2. `lib/views/association_creation_page.dart` (NEW)
*   **Access**: Requires `profile.isAssociationCreator == true`. If not, presents the permission application form with reasons text input.
*   **Wizard Workflow Steps**:
    *   *Step 1: Identity*: Text field for Name, buttons to upload Profile picture / Banner image.
    *   *Step 2: Scope*: Dropdown for scope ('global', 'area', 'national') and country selector if 'national' is chosen.
    *   *Step 3: Sports Configurations*: Checklist of supported sports (dynamically loaded from `SportConfig`) and checkboxes for formats.
    *   *Step 4: Rulebooks*: Text fields to link rules for each selected sport.
    *   *Step 5: Channels*: Website link and social channel maps.
    *   *Step 6: Details & Application*: Association description text, optional Parent Association dropdown (to build sub-associations hierarchy), and a text field for application reason to submit to the parent owner.

#### 3. `lib/views/association_detail_page.dart` (NEW)
*   **Layout**: Rich layout featuring banner, avatar, scope, upcoming meets, complete meets, rules, channels, and sub-associations.
*   **Integrations**:
    *   Includes a button to navigate to `AssociationManagementPage` if the current user is Owner or Editor.
    *   Displays team members list and custom team titles.

#### 4. `lib/views/association_management_page.dart` (NEW)
*   **Tabs**:
    *   **Settings/Metadata**: Form to update fields from the creation wizard.
    *   **Members**: Manage member roles (Owner, Editor, Member), custom titles, and transfer ownership.
    *   **Sub-Associations applications**: List sub-association requests from other organizations, allowing the owner/admin to approve/reject them.
    *   **Competition Groups**: Panel to create and toggle active status of groups (e.g. FinalRep Qualifier).
    *   **Athlete Groups**: Panel to configure weight classes and define requirements (e.g. required weight classes).

---

## 2. Interface Contracts

```
+------------------+          creates / resolves          +-------------------+
|   LoginPage      |  ==================================> |    AuthProvider   |
+------------------+                                      +-------------------+
                                                                   ||
                                                             uses  ||
                                                                   \/
                                                          +-------------------+
                                                          |  AdminRepository  |
                                                          +-------------------+

+---------------------------+        delegates / saves       +---------------------+
| AssociationCreationWizard | =============================> | CompetitionProvider |
+---------------------------+                                +---------------------+
                                                                       ||
                                                                 uses  ||
                                                                       \/
                                                            +-----------------------+
                                                            | AssociationRepository |
                                                            +-----------------------+
```

---

## 3. Step-by-Step Implementation Strategy

```
Phase 1: Extend Profile & Competition Models, & Create Admin Configurations
  └── Extend Profile fields and serialization.
  └── Extend Competition fields and serialization.
  └── Create model classes for applications and configurations.

Phase 2: Establish Repositories & Providers (Logic & Memory Caching)
  └── Implement AdminRepository and AssociationRepository with fallback caches.
  └── Wire up repositories in main.dart.
  └── Implement permission handling and promotion logic in AuthProvider.
  └── Implement associations, groups, and membership controls in CompetitionProvider.

Phase 3: Design UI Views (Admin Panel & Creation Wizards)
  └── Implement AdminDashboardPage (approvals, promotions, configs).
  └── Implement AssociationCreationPage (wizard and applications).
  └── Implement AssociationDetailPage and AssociationManagementPage.
  └── Add admin/association creation entry points in the drawer/search feeds.

Phase 4: Verification & Coverage
  └── Unit test serialization, permissions, promotions, and state controls.
  └── Widget test wizards and permissions forms.
```

---

## 4. Dependencies & Potential Pitfalls

1.  **Late Db Trigger Latency**: Since user profiles are created/manipulated asynchronously in Supabase, ensure that whenever permission changes occur, the application fetches details with appropriate wait/retry protocols (as implemented in `_fetchProfileWithRetry`).
2.  **In-Memory Fallbacks Integrity**: Always mock queries that fetch user roles in associations so that widget tests running without actual database network connections do not crash.
3.  **Role Hierarchy Validation**: Validate that only owners or system administrators can execute ownership transfers (`transferAssociationOwnership`), preventing editors from executing unauthorized privilege escalation.
4.  **Active Competition Groups Restriction**: During competition creation, ensure the UI filters out inactive competition groups of the selected association.
