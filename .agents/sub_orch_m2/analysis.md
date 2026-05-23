# Synthesized Technical Analysis & Implementation Plan: Milestone 2

## Consensus
- **Data Models**:
  - `Profile` model needs: `isCompetitionCreator`, `isAssociationCreator`, `isAdmin` fields (all defaulting to `false`), with corresponding `fromJson`, `toJson`, and `copyWith` updates.
  - `Competition` model needs: `associationId`, `competitionGroupId`, `athleteGroupIds` (List), and `rulebookUrl`.
  - `PermissionApplication` (NEW): fields `id`, `userId`, `type` ('create_competition' / 'create_association'), `reason`, `status` ('pending' / 'approved' / 'rejected'), `createdAt`.
  - `AdminConfig` / `SportConfig` (NEW): representing custom sports, formats, disciplines configuration.
  - `Association` (NEW): fields `id`, `name`, `profilePictureUrl`, `bannerUrl`, `scope` ('global'/'area'/'national'), `areaName`, `country`, `website`, `description`, `rulebooks` (Map of sport name -> URL), `socialChannels` (Map of channel -> handle), `parentAssociationId`, `status` ('pending'/'approved'/'rejected'), `ownerId`.
  - `AssociationMember` (NEW): fields `id`, `associationId`, `userId`, `role` ('owner'/'editor'), `customTitle`.
  - `CompetitionGroup` (NEW): fields `id`, `associationId`, `name`, `sport`, `format`, `isActive`, `isAthleteGroupsRequired`.
  - `AthleteGroup` (NEW): fields `id`, `associationId`, `competitionGroupId`, `name`, `sport`, `format`, `gender`, `maxWeight`, `isActive`.
- **Repository Layer**:
  - `ProfileRepository`: add `updatePermissions(String userId, {bool? isCompetitionCreator, bool? isAssociationCreator, bool? isAdmin})`.
  - `AdminRepository` (NEW): Handles configurations (sports, formats, disciplines) and user applications with static mock storage arrays as offline/error fallbacks.
  - `AssociationRepository` (NEW): Handles creation, members list, competition groups, athlete groups, with static mock fallbacks.
- **Provider/State Layer**:
  - `AuthProvider`: Expose permission fields and methods to apply, approve/reject, promote admin, load/save sports config.
  - `CompetitionProvider`: Expose association CRUD, members management, groups configuration. If association selected during competition creation, inherit rulebook and athlete groups.
- **UI Layer**:
  - `AdminDashboardPage` (NEW): applications list, user promotion, sports configurations.
  - `AssociationCreationPage` (NEW): 5-step stepper/wizard with validation.
  - `AssociationDetailPage` (NEW): banner, logo, metadata, tabs for meets/sub-associations/members.
  - `AssociationManagementPage` (NEW): edit metadata, members list, competition/athlete groups.
  - Entry points in Drawer / Search feed.

## Implementation Steps for Worker
### Step 1: Model extensions and creation
- Update `lib/models/profile.dart` and `lib/models/competition.dart`.
- Create `lib/models/permission_application.dart`, `lib/models/admin_config.dart`, `lib/models/association.dart`, `lib/models/association_member.dart`, `lib/models/competition_group.dart`, and `lib/models/athlete_group.dart`.
- Ensure everything serializes correctly.

### Step 2: Repositories & Mock fallbacks
- Create `lib/repositories/admin_repository.dart` and `lib/repositories/association_repository.dart` with in-memory fallback caches.
- Update `lib/repositories/profile_repository.dart` with permission updates.
- Verify everything compiles.

### Step 3: Provider integration
- Update `lib/providers/auth_provider.dart` and `lib/providers/competition_provider.dart`.
- Wire up the new repositories in `lib/main.dart`.

### Step 4: UI Development
- Create `AdminDashboardPage`, `AssociationCreationPage`, `AssociationDetailPage`, `AssociationManagementPage`.
- Build the permission application form dialog.
- Integrate nav links.

### Step 5: Verification
- Run tests and ensure all pass.
