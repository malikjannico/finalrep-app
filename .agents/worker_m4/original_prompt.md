## 2026-05-23T13:42:42Z

Your task is to implement and verify all requirements under H1 (Competition Management & Handling, Streetlifting Rules) in the FinalRep Streetlifting application.

Please follow these steps:
1. Read the explorer's analysis.md and handoff.md under /Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/explorer_m4/ to understand the required model fields, rules engine logic, provider methods, and widget keys.
2. Implement the following production code:
   a. Models in `lib/models/`:
      - `streetlifting_attempt.dart`: Attempt number (1, 2, 3), weight, discipline (Muscle Up, Pull Up, Dip, Squat), status (pending, valid, invalid), judgeVotes (List of 3 booleans), failureReason (String?), varRequested (bool).
      - `flight.dart`: flight name, athlete IDs, status.
      - `schedule_item.dart`: type (weigh_in, flight, awards, staff_meeting), title, times, assignees.
      - `system_notification.dart`: categories (registration, permissions, payments, schedule, flights), read/unread status.
   b. Repository:
      - Create `lib/repositories/notification_repository.dart`.
      - Extend `lib/repositories/competition_repository.dart` to support attempts, flights, schedule items, and roster management.
   c. Rules Engine in `lib/utils/streetlifting_rules_engine.dart`:
      - Validation: weight must be multiple of 1.25kg (Muscle Up, Pull Up, Dip) or 2.5kg (Squat). Successive attempts must be ascending.
      - Plate calculation: greedy plate matching logic based on standard plates (25kg, 20kg, 15kg, 10kg, 5kg, 2.5kg, 1.25kg + micro-weights). Must display string "Standard Plates: Xx25kg, Yx20kg" where X and Y are count of plates.
      - Judging rules: majority (2:1) allowed for Dips Depth (Invalid Depth) and Squat knees/depth (Bent Knees, Invalid Depth). Unanimous (3:0) required for all other errors (like Muscle Up "Chicken Wing").
      - DQ rules: 0 of 3 successful attempts in a discipline disqualifies the athlete.
      - VAR rules: 1 VAR credit, overrule to "Good Lift" restores the credit.
   d. Provider in `lib/providers/competition_provider.dart`:
      - Expose methods for recording attempts, plate math, judging votes, VAR reviews, balancing flights, and recording weigh-in bodyweights/DQ toggle.
   e. Views in `lib/views/`:
      - Create `lib/views/competition_handling_page.dart` (class `CompetitionHandlingPage`), `lib/views/notifications_page.dart` (class `NotificationsPage`), and `lib/views/rankings_page.dart` (class `RankingsPage`).
      - Match all widget keys, SnackBar text, status texts, dropdown options, and interaction flows exactly as expected in `test/e2e/tier2_boundary_test.dart`.
3. Hook up the production views to the tests:
   - Edit `test/e2e/tier2_boundary_test.dart` and `test/e2e/e2e_test_harness.dart` to import and route to the new production views instead of `mock_views.dart`.
4. Run all E2E and unit tests using `flutter test test/e2e/tier2_boundary_test.dart` to verify that your implementation passes successfully.
5. Create a handoff.md report summarizing the changes made, the exact files modified/created, and the command run with its output showing passing tests.
