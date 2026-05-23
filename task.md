# Tasks - Platform Features Update

**Status:** Completed 🎉

## Phase 1: Models & Repositories
- [x] Create models for `Association`, `AssociationMember`, `CompetitionGroup`, `AthleteGroup`, `SportConfig`, `PermissionApplication`, `Attempt`, `Flight`, `ScheduleItem`, `SystemNotification`
- [x] Implement repositories: `AssociationRepository`, `AdminRepository`, `NotificationRepository` with in-memory fallbacks

## Phase 2: Providers & Business Logic
- [x] Update `AuthProvider` for lowercase logins, forgot password email/username support, admin permissions, and notifications
- [x] Update `CompetitionProvider` to include:
  - [x] Association management, groups, scopes, and team members
  - [x] Rich competition creation flows (fees calculation, custom inputs, disclaimers)
  - [x] Flights, planning schedules, and weigh-in details
  - [x] Streetlifting Modern rules: plates configurations, attempts validation, timer, 3-referee majority (2:1 dips/squats) vs unanimous (3:0) scoring, anonymous voting, VAR request tracking
  - [x] Sport rankings filters

## Phase 3: Authentication & Profile UI
- [x] Lowercase username input dynamically and verify on `LoginPage`
- [x] Add forgot password username/email support in LoginPage dialog
- [x] Profile Page styling: settings icon placement, half-avatar shifting, details left-aligned under photo, social channel icons, upcoming/completed meets tabs, highest rankings list, PRs display

## Phase 4: Associations & Admin UI
- [x] Implement `AssociationCreationPage` wizard
- [x] Implement `AssociationDetailPage` metadata & rules
- [x] Implement `AssociationManagementPage` roles, sub-associations, team members, competition/athlete classes
- [x] Implement `AdminDashboardPage` permissions and config toggles

## Phase 5: Competitions & Judging UI
- [x] Implement `CompetitionCreationWizard` geocoded location, payments, volunteers details
- [x] Implement `CompetitionManagementPanel` registrations, flights balancing, staff schedule builders, CSV exports
- [x] Implement `CompetitionHandlingView` timer, Plat Judge red/black/yellow/blue triggers, Head Judge panel, and VAR request
- [x] Implement `RankingsPage` filters
- [x] Implement `NotificationsPage` inbox list and category settings toggles

## Phase 6: Verification
- [x] Write unit/widget tests for lowercase logins, attempts plate calculations, judging majority vote, and permissions
- [x] Ensure `flutter test` completes successfully (all 153 tests pass cleanly)

## Phase 7: Follow-up & Refinement
- [x] Configure `FinalRep Underground` to be exclusively in Modern format across repositories, tests, and the remote database.
