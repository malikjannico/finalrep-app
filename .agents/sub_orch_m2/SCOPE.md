# Scope: Milestone 2 - Admin Panel & Associations

## Architecture
- User permissions configuration and persistence (`isCompetitionCreator`, `isAssociationCreator`, `isAdmin`).
- Permission applications models, repository methods, and UI forms.
- Sports, Formats, and Disciplines configuration models, repositories, and UI config tables.
- Association models (`Association`, `AssociationMember`, `CompetitionGroup`, `AthleteGroup`), repositories, providers, creation wizard, details page, and management panel.
- Integration with Providers: `AuthProvider` (to manage user details/permissions/applications) and `CompetitionProvider` (to expose association metadata, management tools, groups, etc.).

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Data Models | Create models for `PermissionApplication`, `SportConfig` / `AdminConfig`, `Association`, `AssociationMember`, `CompetitionGroup`, `AthleteGroup`. Extend `Profile` model. | none | DONE |
| 2 | Repositories & In-Memory Fallbacks | Implement `AdminRepository` and `AssociationRepository`. Extend `ProfileRepository` with permission-related methods. | M1 | DONE |
| 3 | Providers & Business Logic | Extend `AuthProvider` (handle permission application status, promote users, sports configs) and `CompetitionProvider` (manage association details, roles, groups). | M2 | DONE |
| 4 | Admin Dashboard & Permissions UI | Implement `AdminDashboardPage` (admin actions, permission approvals, configurations). Implement application form for permissions. | M3 | DONE |
| 5 | Association Pages UI | Implement `AssociationCreationPage` wizard, `AssociationDetailPage`, and `AssociationManagementPage`. | M3 | DONE |
| 6 | Verification & Tests | Write unit/widget tests to verify permissions, admin promotions, and associations creation/management. | M4, M5 | DONE |

## Interface Contracts
### AuthProvider ↔ AdminRepository / ProfileRepository
- `applyForPermissions(String type, String reason)`: Submits a permission application.
- `getPermissionApplications()`: Returns all applications.
- `approvePermissionApplication(String applicationId)`: Approves an application.
- `rejectPermissionApplication(String applicationId)`: Rejects an application.
- `promoteToAdmin(String userId)`: Sets `isAdmin` to true.
- `loadSportsConfig()`: Retrieves custom sports, formats, disciplines.
- `saveSportsConfig(SportConfig config)`: Persists configuration.

### CompetitionProvider ↔ AssociationRepository
- `createAssociation(Association association)`: Wizard workflow save.
- `updateAssociation(Association association)`: Edit metadata.
- `getAssociationDetails(String id)`: Details page loading.
- `getAssociationMembers(String associationId)`: Load member lists.
- `addAssociationMember(String associationId, String userId, String role)`: Editor/Owner assignment.
- `removeAssociationMember(String associationId, String userId)`: De-assign roles.
- `transferAssociationOwnership(String associationId, String newOwnerId)`: Owner transfer.
- `getCompetitionGroups(String associationId)`: Load groups.
- `getAthleteGroups(String associationId)`: Load athlete weight classes, etc.
