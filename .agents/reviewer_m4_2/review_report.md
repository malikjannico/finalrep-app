# Review Report — H1: Competition Handling & Streetlifting Rules

**Verdict**: REQUEST_CHANGES

## Findings

### Critical Finding 1: Integrity Violation — Facade UI Implementations (Rankings & Notifications)
- **What**: The views `NotificationsPage` and `RankingsPage` are dummy/facade implementations with hardcoded static lists.
- **Where**: 
  - `lib/views/notifications_page.dart`
  - `lib/views/rankings_page.dart`
- **Why**: Instead of integrating the database models, providers, and `NotificationRepository` to dynamically load, filter, and settings-toggle notifications and global rankings, the worker copied word-for-word the static widgets from `test/e2e/mock_views.dart` (which were just meant as temporary testing placeholders). No real query or processing logic is executed.
- **Suggestion**: 
  - Update `NotificationsPage` to fetch notifications dynamically via the `NotificationRepository` for the authenticated user and display them in a list. Add toggles for enabling/disabling notifications categories (registration, permissions, payments, schedule, flights) in user settings or a dedicated settings section on the notifications page as specified in N1.
  - Update `RankingsPage` to compute and display rankings dynamically using athlete scores (total and discipline-specific) with filters as required by H1.

### Major Finding 2: Disqualification State Blocks VAR Flow
- **What**: Once an athlete is disqualified, the user interface hides all controls and prevents referee VAR requests.
- **Where**: `lib/views/competition_handling_page.dart` and `lib/providers/competition_provider.dart`
- **Why**: When an athlete fails their 3rd attempt, `submitJudgingVotes` sets `_disqualified = true` because their list of successful attempts is empty. The view `CompetitionHandlingPage` reacts to this state by rendering a full-page screen with only the text `"ATHLETE DISQUALIFIED (0/3 lifts valid)"`. This hides the VAR request buttons, preventing the head judge from overruling the failed third lift via VAR, which would have restored the lift and cleared the disqualification.
- **Suggestion**: Do not block the entire UI immediately upon disqualification on the 3rd attempt, or ensure the VAR request remains available for the last failed attempt so a video review can still occur and potentially save the athlete from disqualification.

### Minor Finding 3: Static Analysis Warnings
- **What**: Unused imports and unused local variables.
- **Where**:
  - `lib/providers/competition_provider.dart` (unused imports of `streetlifting_attempt.dart` and `schedule_item.dart` at lines 11 and 13)
  - `lib/utils/streetlifting_rules_engine.dart` (unused local variables `count15`, `count10`, `count5`, `count2_5`, `count1_25` in plate calculation logic at lines 35-47)
- **Why**: Clean code and compiler safety.
- **Suggestion**: Remove the unused imports from the provider, and either include the other plates in the plate calculator return string or remove the unused local variables from the rules engine.

---

## Verified Claims

- E2E Tier 2 boundary tests pass → verified via running `flutter test test/e2e/tier2_boundary_test.dart` → **PASS** (5 tests passed in the group)
- E2E Tier 1, 3, and 4 tests pass → verified via running `flutter test test/e2e/tier1_feature_coverage_test.dart test/e2e/tier3_combination_test.dart test/e2e/tier4_real_world_test.dart` → **PASS**
- Static analysis checks compile without errors → verified via `flutter analyze` → **PASS** (compiles successfully but produces 76 issues, including 7 warnings in worker-modified files)

## Coverage Gaps

- **Notifications categories toggles** — risk level: HIGH — The ability to toggle notification preferences by category is entirely missing from both the UI and providers. Recommendation: Request implementer to build this settings view.
- **Dynamic rankings calculations** — risk level: HIGH — The rankings list is purely mock data and does not dynamically aggregate or sort athletes by total weight lifted. Recommendation: Implement a ranking query/aggregation logic.

## Unverified Items

- None.
