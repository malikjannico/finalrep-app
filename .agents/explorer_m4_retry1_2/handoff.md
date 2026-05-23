# Handoff Report — H1 & N1 Milestone Facade Remediation & DQ-VAR Fix

## 1. Observation
- **Plate configuration calculator**:
  - In `lib/utils/streetlifting_rules_engine.dart` (lines 23-51), the `calculatePlatesString` method calculates 25kg, 20kg, 15kg, 10kg, 5kg, 2.5kg, and 1.25kg plates, but discards everything other than 25kg and 20kg, returning `'Standard Plates: ${count25}x25kg, ${count20}x20kg'`.
  - In `test/e2e/tier2_boundary_test.dart` (line 174), the test performs:
    ```dart
    expect(find.text('Standard Plates: 0x25kg, 0x20kg'), findsOneWidget);
    ```
    This shows the test does a strict matching assertion on that exact string widget.

- **Notifications view**:
  - In `lib/views/notifications_page.dart` (lines 10-22), the notification list contains static, hardcoded list tiles (e.g., `ListTile(title: Text('Registration Approved'), ...)`).
  - In `lib/repositories/notification_repository.dart` (lines 12-27), there is a `getNotifications(String userId)` method that retrieves notifications dynamically from the `notifications` table in Supabase.

- **Rankings view**:
  - In `lib/views/rankings_page.dart` (lines 10-22), the rankings page renders a static, hardcoded list of two athletes (`'1. John Doe - 420.0kg'` and `'2. Jane Smith - 390.0kg'`).
  - In `lib/repositories/profile_repository.dart` (lines 186-201), the repository provides `getUserHighestRankings(String profileId)` querying the `highest_rankings` table.

- **Athlete Disqualification VAR Lockout**:
  - In `lib/views/competition_handling_page.dart` (lines 53-62) and `test/e2e/mock_views.dart` (lines 326-327), if the provider's `isDisqualified` is true, the `build` method returns an exclusive `Scaffold` containing only the text `'ATHLETE DISQUALIFIED (0/3 lifts valid)'`.
  - This removes all other widgets, including the VAR request and resolution buttons, preventing any referee interaction despite the athlete having a VAR credit.
  - In `lib/providers/competition_provider.dart` (line 882-931) and `test/e2e/mock_views.dart`, `submitJudgingVotes` sets `_disqualified = true` on the 3rd failed lift without waiting to check if a VAR overrule might reverse the decision.

---

## 2. Logic Chain
1. To prevent breaking the strict UI assertions in the test suite (such as `expect(find.text('Standard Plates: 0x25kg, 0x20kg'), findsOneWidget)`), the text widget displaying `Standard Plates: Xx25kg, Yx20kg` must exist in its exact form in `CompetitionHandlingPage` and `mock_views.dart`.
2. To satisfy the prompt's request to visualize all calculated plates without breaking the tests, we must introduce a helper method `calculateAllPlates` in the rules engine, and render a second text widget below the standard plate count displaying the remaining plates (15kg, 10kg, 5kg, 2.5kg, 1.25kg).
3. Since `NotificationsPage` and `RankingsPage` are currently completely hardcoded, they are facades. To make them genuine, we must rewrite them as dynamic/stateful components that query Supabase tables (`notifications` and `meet_results`) via repositories or database clients.
4. To fulfill the N1 specifications, `NotificationsPage` must implement user settings switches (enabling/disabling category alerts) and UI FilterChips for each category (registration, permissions, payments, schedule, flights), along with interactive mark-as-read updates.
5. To fix the DQ lockout bug, `CompetitionHandlingPage` and `mock_views.dart` must not block the entire layout when `isDisqualified` is true. Rendering DQ status as an on-page banner allows other UI components—namely, the interactive VAR request and resolve buttons—to remain interactive in the widget tree.
6. The state provider (`CompetitionProvider`) must be updated: if a VAR review is resolved in favor of the athlete (`overrule = true`), the disqualification status must be set back to false (`_disqualified = false`), the attempt must be recorded as successful, and the athlete must advance to the next discipline.

---

## 3. Caveats
- Since the E2E boundary tests do not currently verify the `NotificationsPage` or `RankingsPage`, we have the freedom to design robust, feature-rich views without breaking existing test assertions, but they must use real Supabase queries and fallbacks to ensure compatibility.
- Disabling normal attempt controls (inputs, submit button) when disqualified is necessary so that referees do not submit further regular lifts once disqualified, while leaving only VAR options active.

---

## 4. Conclusion
We conclude that:
1. `StreetliftingRulesEngine` must calculate all plates, and `CompetitionHandlingPage` must render them as two separate text widgets to maintain test compatibility.
2. `NotificationsPage` and `RankingsPage` must be rewritten to dynamically fetch data and provide robust filter/sort/switch functionality.
3. The full-screen Scaffold blocking layout for disqualified athletes must be replaced with an in-page banner, and the provider's `resolveVARReview` must be modified to reset `_disqualified = false` and progress the athlete upon a successful VAR overrule.

---

## 5. Verification Method
1. **Test Suite Execution**: Run `flutter test test/e2e/tier2_boundary_test.dart` to verify that all existing plate calculation and disqualification test cases continue to pass cleanly.
2. **Interactive UI Verification**:
   - Verify that when an athlete fails all 3 attempts of their first discipline, a banner is displayed indicating DQ, and the regular inputs are disabled, but the VAR request button remains active.
   - Request and approve VAR review: verify the DQ banner disappears, the VAR credit is preserved/restored, and the discipline transitions to the next list item.
3. **Inspect Views**:
   - Confirm `lib/views/notifications_page.dart` retrieves data via `NotificationRepository` for the logged-in user and allows toggling categories.
   - Confirm `lib/views/rankings_page.dart` retrieves data from `meet_results` (or fallback mock data) and sorts dynamically based on selections.
