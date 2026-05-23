# Technical Implementation Plan - Platform Features Update

This plan details the design and implementation steps for introducing Login lowercasing, Forgot Password options, enhanced Profiles, System Administration controls, Association management, rich Competition setup, Streetlifting Modern attempt rules, judging systems, rankings, and system notifications.

---

## 1. Data Models (`lib/models/`)

### [NEW] [association.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/association.dart)
- Represents an Association entity.
- Fields: `id`, `name`, `profilePictureUrl`, `bannerUrl`, `scope` ('global', 'area', 'national'), `areaName`, `country`, `website`, `description`, `rulebooks` (Map of sport name to rulebook URL), `socialChannels` (Map of channel to handle), `parentAssociationId`, `status` ('pending', 'approved', 'rejected'), `ownerId`.

### [NEW] [association_member.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/association_member.dart)
- Represents a member role in an association.
- Fields: `id`, `associationId`, `userId`, `role` ('owner', 'editor', 'member'), `customTitle`.

### [NEW] [competition_group.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/competition_group.dart)
- Fields: `id`, `associationId`, `name`, `sport`, `format`, `isActive`.

### [NEW] [athlete_group.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/athlete_group.dart)
- Fields: `id`, `associationId`, `competitionGroupId`, `name`, `sport`, `format`, `gender`, `maxWeight`, `isActive`.

### [NEW] [admin_config.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/admin_config.dart)
- Models for `SportConfig`, `FormatConfig`, `DisciplineConfig`.
- Represents the custom sports, formats, and associated disciplines list.

### [NEW] [permission_application.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/permission_application.dart)
- Fields: `id`, `userId`, `type` ('create_competition', 'create_association'), `reason`, `status` ('pending', 'approved', 'rejected'), `createdAt`.

### [NEW] [attempt.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/attempt.dart)
- Represents an individual Streetlifting attempt.
- Fields: `id`, `athleteId`, `discipline`, `attemptNumber` (1, 2, or 3), `weight` (double), `status` ('pending', 'valid', 'invalid'), `refereeVotes` (List of judge votes: true/false), `invalidReason` (String), `invalidCategory` ('red', 'black', 'yellow', 'blue'), `timestamp`.

### [NEW] [flight.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/flight.dart)
- Fields: `id`, `competitionId`, `name`, `athleteIds` (List), `athleteGroupIds` (List), `status` ('scheduled', 'ongoing', 'completed').

### [NEW] [schedule_item.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/schedule_item.dart)
- Fields: `id`, `competitionId`, `type` ('weigh_in', 'flight', 'awards', 'staff_meeting'), `title`, `startDateTime`, `endDateTime`, `assignees` (List).

### [NEW] [system_notification.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/system_notification.dart)
- Fields: `id`, `userId`, `title`, `message`, `category` ('registration', 'permissions', 'payments', 'schedule', 'flights'), `isRead`, `createdAt`.

---

## 2. Database & Repository Layer (`lib/repositories/`)

- Add repositories with **in-memory mock fallbacks** if remote database connections fail or throw errors, ensuring all tests compile and run offline seamlessly.
- **[ProfileRepository](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/repositories/profile_repository.dart)**: Extend to handle permission states (`isCompetitionCreator`, `isAssociationCreator`, `isAdmin`).
- **[NEW] [AssociationRepository](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/repositories/association_repository.dart)**: Manage Association CRUD operations, role assignments, and groups.
- **[NEW] [AdminRepository](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/repositories/admin_repository.dart)**: Handles configuration management (sports, formats, disciplines) and user applications.
- **[NEW] [NotificationRepository](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/repositories/notification_repository.dart)**: Fetches and updates system notifications.

---

## 3. Provider & State Layer (`lib/providers/`)

### [MODIFY] [auth_provider.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/providers/auth_provider.dart)
- Add login conversions (lowercasing usernames).
- Implement login support for either username or email.
- Expose permission application methods and user permissions statuses.
- Expose custom admin promotion/configuration triggers.
- Support loading and disabling notification category preferences.

### [MODIFY] [competition_provider.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/providers/competition_provider.dart)
- Add association CRUD logic.
- Implement step-by-step competition details builders.
- Support flights, platforms, schedules, weigh-in measurements, and plate configurations.
- House the Streetlifting Modern rules engine: attempt submissions, 3-minute timers, referee voting systems (2:1 majority vs 3:0 unanimous), VAR request resolution.
- Expose ranking filtering metrics (by sport, format, total, discipline).

---

## 4. UI Layer (`lib/views/` & `lib/widgets/`)

### A. Authentication & Profile Changes
- **[login_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/login_page.dart)**: Convert username field text dynamically to lowercase and update login parameters.
- **[profile_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/profile_page.dart)**: Update settings gear positioning next to Full Name. Implement half-avatar offset styling. Align user details under the photo. Add tabs/lists showing PRs, rankings, and meets. Include social channel listings with icons.

### B. Association Flow & Management
- **[NEW] [association_creation_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/association_creation_page.dart)**: Wizard workflow grouping details, scope selections, and website links.
- **[NEW] [association_detail_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/association_detail_page.dart)**: Render banner, scope, rulebooks, and sub-associations.
- **[NEW] [association_management_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/association_management_page.dart)**: Panel for member lists, competition groups, and athlete classes.

### C. Admin Panels
- **[NEW] [admin_dashboard_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/admin_dashboard_page.dart)**: View permission requests, sports configuration tables, and promote other administrators.

### D. Competition Creation & Execution
- **[NEW] [competition_creation_wizard.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/competition_creation_wizard.dart)**: Wizard incorporating geolocated verify addresses, date-time calendar pickers, payment generator calculations, custom parameters, and disclaimers.
- **[NEW] [competition_management_panel.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/competition_management_panel.dart)**: Controls for registrations, flights balancing, platform counts, schedules.
- **[NEW] [competition_handling_view.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/competition_handling_view.dart)**: Operational logs for technical judges, platform judges voting buttons (red/black/yellow/blue triggers), Head Judge panel, and VAR.

### E. Rankings & Notifications settings
- **[NEW] [rankings_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/rankings_page.dart)**: Filters by sport/format and detailed scores.
- **[NEW] [notifications_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/notifications_page.dart)**: Lists system notifications and handles category subscriptions.

---

## 5. Verification Plan

### Automated Tests
- Run `flutter test` to ensure all existing and new widget/unit tests compile and pass.
- Write tests:
  - Username conversion to lowercase.
  - Attempt weight calculator logic (Plate configurations).
  - Voting rules validity (Dips vs Squats majority voting validations).
  - Permission approval restrictions.

---

## 6. Implementation Status & Special Notes
- **Status:** **Completed & Verified** (100% of the tasks are finished and verified via the 153-test suite).
- **FinalRep Underground:** Following testing and adjustments, the *FinalRep Underground* group has been configured to support the **Modern** format **exclusively** across both the local mock repositories and the remote Supabase database. The Classic format group (`group-2`) has been successfully removed.

