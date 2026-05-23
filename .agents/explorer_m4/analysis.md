# Analysis Report: Streetlifting Rules & Competition Handling Design

## 1. Codebase Exploration Findings
During exploration of the codebase, the following files and directories were identified as relevant to the competition management, repositories, providers, models, and tests:

### Models (`lib/models/`)
- `competition.dart`: The core competition model. It contains fields for registration modes, dates, fee requirements, limits, disclaimer configurations, and helper getters like `disciplines`, `isModern`, and `isClassic`.
- `association.dart`: Represents associations (e.g., GSF, ESA), which govern rules and rulebooks.
- `association_member.dart`: Represents membership roles (owner, editor, member) in an association.
- `athlete_group.dart`: Represents athlete divisions/weight classes (e.g., "-80kg Male").
- `competition_group.dart`: Grouping of competitions (e.g., "FinalRep Qualifier", "FinalRep Underground").
- `permission_application.dart`: Handles administrative request objects.
- `profile.dart`: User profile model containing permission flags (`isCompetitionCreator`, `isAssociationCreator`, `isAdmin`) and social links.

### Repositories (`lib/repositories/`)
- `competition_repository.dart`: Handles Supabase queries for upcoming/specific competitions.
- `association_repository.dart`: Manages association entities, roles, and groups with mock fallback caches.
- `profile_repository.dart`: Manages profile lookups, searches, and mock datasets for rankings and PRs.
- `admin_repository.dart`: Manages permission workflows and sports configuration details.

### Providers (`lib/providers/`)
- `competition_provider.dart`: Houses filter queries, layout states (grid, list, map), and handles association CRUD operations.
- `auth_provider.dart`: Handles logins, registrations, password recovery, and username/email parsing.

### Views (`lib/views/`)
- `login_page.dart`
- `register_page.dart`
- `profile_page.dart`
- `competition_creation_wizard.dart`
- `competition_detail_page.dart`
- `admin_dashboard_page.dart`
- `association_creation_page.dart`
- `association_detail_page.dart`
- `association_management_page.dart`
- `search_feed_page.dart`
- `world_map_view.dart`

---

## 2. Analysis of E2E Test Expectations (Streetlifting Rules & Judging)
Looking closely at the E2E boundary test file `test/e2e/tier2_boundary_test.dart` and `test/e2e/mock_views.dart`, the following behaviors, keys, and widget interfaces are expected by the testing infrastructure:

1. **Attempt Weight Input & Validations (Test 2.5.1)**:
   - Target widget name/key: `Key('attempt_weight_input')` (TextField).
   - Validation failures for non-multiple weights must trigger a SnackBar with text: `"Weight must be multiple of 1.25kg!"` for Muscle Up/Pull Up/Dip (Modern/Classic standard).
   - Plate calculations display text: `"Standard Plates: 0x25kg, 0x20kg"` (shows the configuration of 25kg and 20kg plates).
   
2. **Ascending Weight Rule (Test 2.5.2)**:
   - Successive attempts cannot decrease in weight.
   - If a weight is entered that is lower than the previous attempt (e.g., entering `8.75` after a successful `10.0` attempt), it must show an error SnackBar with text: `"Attempt weight must be ascending!"`.

3. **Judging & Scoreboards (Test 2.5.3)**:
   - Three platform judges (J1, J2, J3) vote Good Lift vs No Lift.
   - Joggle buttons: `Key('judge_1_toggle')`, `Key('judge_2_toggle')`, `Key('judge_3_toggle')` to toggle individual votes.
   - A dropdown menu to select the failure reason: `Key('failure_reason_dropdown')`.
   - Submit judging button: `Key('judge_submit')`.
   - Result display text: `"LIFT FAILED"` vs `"LIFT PASSED"`.
   - **Voting Rules Check**:
     - *Majority (2:1) allowed*:
       - **Dip**: Failure reason `"Invalid Depth"`.
       - **Squat**: Failure reasons `"Bent Knees"` and `"Invalid Depth"`.
     - *Unanimous (3:0) required*:
       - All other combinations of disciplines and failure reasons (e.g., Muscle Up with `"Chicken Wing"`).
       - If a combination requiring unanimous scoring has even one No Lift vote (2 Good vs 1 No), it must output `"LIFT FAILED"`.

4. **Video Assisted Referee - VAR (Test 2.5.4)**:
   - Button key: `Key('var_request_btn')` (displays text with available credits, e.g., `"Request VAR (Credits: 1)"`).
   - If VAR is requested, it displays review buttons:
     - `Key('var_confirm_fail')` (confirm lift failed).
     - `Key('var_overrule_pass')` (overrule to passed lift).
   - If overruled to passed, the attempt weight is added to the valid attempts, the lift status becomes `"LIFT PASSED"`, and the VAR credit is restored (incremented back).

5. **Athlete Disqualification (Test 2.5.5)**:
   - If an athlete fails all 3 attempts of a discipline, they are disqualified from the meet.
   - Disqualified status displays a widget with key: `Key('dq_status')` containing the text: `"ATHLETE DISQUALIFIED (0/3 lifts valid)"`.

---

## 3. Stubs & Missing Infrastructure
We observed that the production codebase does not currently contain:
1. `Attempt` model.
2. `Flight` model.
3. `ScheduleItem` model.
4. `SystemNotification` model.
5. `NotificationRepository`.
6. A modular Rules Engine (the rules logic is currently hardcoded within the `CompetitionHandlingPage` widget in `test/e2e/mock_views.dart`).
7. Provider integrations for attempts, referee scoring, flights, schedules, and weigh-ins.
8. A production `CompetitionHandlingView` file in `lib/views/`.

To support the implementation phase, these missing models, repositories, providers, and views must be created in production, and the test harness (`test/e2e/e2e_test_harness.dart`) must eventually import the production widgets instead of the mock pages.

---

## 4. Proposed Design for the Streetlifting Rules Engine
To keep business logic clean, testable, and separate from the UI widgets, we propose creating a dedicated utility class: `lib/utils/streetlifting_rules.dart`.

### Features
1. **Validation of Increments**:
   - Smallest increment for Muscle Up, Pull Up, Dip = `1.25` kg.
   - Smallest increment for Squat = `2.5` kg.
   - Validation uses rounding multiplication to bypass floating-point precision:
     ```dart
     static String? validateIncrement(double weight, String discipline) {
       final minIncrement = (discipline == 'Squat') ? 2.5 : 1.25;
       final weightCents = (weight * 100).round();
       final incCents = (minIncrement * 100).round();
       if (weightCents % incCents != 0) {
         return 'Weight must be multiple of ${minIncrement}kg!';
       }
       return null;
     }
     ```

2. **Ascending Order Validation**:
   - Ensure the new attempt weight is higher than or equal to the previous attempted weight.
   - ```dart
     static bool isAscending(double newWeight, double? previousWeight) {
       if (previousWeight == null) return true;
       return newWeight >= previousWeight;
     }
     ```

3. **Plates Pre-Calculation**:
   - Greedy plate matching logic based on the standard streetlifting plates:
     - 25kg (Red), 20kg (Blue), 15kg (Yellow), 10kg (Green), 5kg (White), 2.5kg (Black), 1.25kg (Silver).
   - Format standard plates specifically to include `0x25kg, 0x20kg` format checks required by tests.

4. **Platform Judging Rules**:
   - Determine if a lift passes based on the discipline, judge votes (list of 3 booleans), and the selected failure reason:
     ```dart
     static bool evaluateJudging({
       required String discipline,
       required List<bool> votes,
       String? failureReason,
     }) {
       int goodCount = votes.where((v) => v).length;
       if (goodCount == 3) return true;
       if (goodCount < 2) return false;

       // Under 2:1 majority rule
       if (discipline == 'Dip' && failureReason == 'Invalid Depth') {
         return true;
       }
       if (discipline == 'Squat' && (failureReason == 'Bent Knees' || failureReason == 'Invalid Depth')) {
         return true;
       }
       // All other combinations require unanimous 3:0
       return false;
     }
     ```

---

## 5. Detailed Technical Implementation Plan

### Step 1: Create Missing Models (`lib/models/`)
- **[attempt.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/attempt.dart)**:
  Contains fields `id`, `athleteId`, `competitionId`, `discipline`, `attemptNumber`, `weight`, `status` ('pending', 'valid', 'invalid'), `judgeVotes` (List of 3 booleans), `failureReason` (String?), and `varRequested` (bool).
- **[flight.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/flight.dart)**:
  Contains `id`, `competitionId`, `name` (e.g. Flight A), `athleteIds` (List of IDs), and `status`.
- **[schedule_item.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/schedule_item.dart)**:
  Contains `id`, `competitionId`, `type` (weigh_in, flight, awards, staff_meeting), `title`, `startDateTime`, `endDateTime`, `assignees` (List).
- **[system_notification.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/models/system_notification.dart)**:
  Contains `id`, `userId`, `title`, `message`, `category` (registration, permissions, payments, schedule, flights), `isRead`, `createdAt`.

### Step 2: Implement Notification Repository (`lib/repositories/notification_repository.dart`)
- Provide fetch, mark-as-read, and insert database operations, with an in-memory list fallback matching other repositories.

### Step 3: Extend Repositories for Competitions & Attempts
- Add methods in `CompetitionRepository` to:
  - Load/save `Attempt` tables.
  - Load/save `Flight` tables.
  - Load/save `ScheduleItem` tables.

### Step 4: Update Provider State Management (`lib/providers/competition_provider.dart`)
- Integrate current handling state for the dashboard.
- Methods to expose:
  - `selectAttemptWeight(String athleteId, String discipline, int attemptNumber, double weight)` (perform validation, plate calculation, and update state).
  - `submitJudgingVotes(List<bool> votes, String? failureReason)` (evaluate using rules engine, update attempt status).
  - `requestVARReview()` (debit credit, trigger review screen).
  - `resolveVARReview(bool overrule)` (re-evaluate lift status, restore credit if overruled).
  - `balanceFlights(String competitionId)` (distribute athletes into balanced flights).
  - `recordWeighIn(String athleteId, double weight, String rackHeight, String dipWidth, {bool isDisqualified = false})`
  - `publishSchedule(String competitionId, {bool isPublic = true})`

### Step 5: Implement UI Views in `lib/views/`
- **[competition_handling_view.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/competition_handling_view.dart)**:
  Create the production view that matches the layout, keys, and text expected by E2E boundary tests. Include the execution timer countdown, anonymous judge trigger toggles, failure reason dropdown, VAR overrule buttons, and disqualification indicators.
- **[notifications_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/notifications_page.dart)**:
  List user notifications and toggle settings.
- **[rankings_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/lib/views/rankings_page.dart)**:
  Provide a scoreboard list that supports filter queries by sport, format, and weight classes.

### Step 6: Hook Up Real Views to test harness
- Update `test/e2e/e2e_test_harness.dart` to import the real views instead of `mock_views.dart` for the completed flows, verifying full compliance with tests.
- Execute `flutter test` to verify everything remains green.
