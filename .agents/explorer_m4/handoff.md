# Handoff Report: Streetlifting Rules & Competition Handling

## 1. Observation
During codebase exploration and test analysis, the following exact paths and definitions were observed:

- **E2E test definitions**:
  - `test/e2e/tier2_boundary_test.dart` defines widget keys, failure text checks, and states for:
    - Attempt weight increments and plate calculations (lines 141-176): `Key('attempt_weight_input')`, and SnackBar validation text: `"Weight must be multiple of 1.25kg!"`, plates calculation format: `"Standard Plates: 0x25kg, 0x20kg"`.
    - Decreasing attempt weights blocked (lines 177-214): SnackBar error text: `"Attempt weight must be ascending!"`.
    - Platform judging majority vs unanimous voting (lines 215-254): `Key('judge_1_toggle')`, `Key('judge_2_toggle')`, `Key('judge_3_toggle')`, `Key('failure_reason_dropdown')` (values: `'Chicken Wing'`, `'Invalid Depth'`, `'Bent Knees'`, `'Kipping'`), `Key('judge_submit')`, and status text `"LIFT FAILED"` vs `"LIFT PASSED"`.
    - Video Assisted Referee (VAR) overrules (lines 255-303): `Key('var_request_btn')`, `Key('var_confirm_fail')`, `Key('var_overrule_pass')`.
    - Athlete disqualification (lines 304-344): `Key('dq_status')` containing `"ATHLETE DISQUALIFIED (0/3 lifts valid)"`.
  - `test/e2e/e2e_test_harness.dart` maps routes `/competition/handling`, `/rankings`, and `/notifications` to widgets in `mock_views.dart` (lines 720-746).
- **Mock View Implementations**:
  - `test/e2e/mock_views.dart` defines `CompetitionHandlingPage` (lines 215-425) containing the hardcoded validation logic and UI components that standard E2E tests compile against.
- **Production Models and Files**:
  - Models for `Attempt`, `Flight`, `ScheduleItem`, and `SystemNotification` are missing from `lib/models/`.
  - Repository file `lib/repositories/notification_repository.dart` is missing.
  - State management methods for attempts, flight balancing, technical timer, judging rules, and VAR overrules are missing from `lib/providers/competition_provider.dart`.
  - Views for `CompetitionHandlingView` are missing from `lib/views/`.
- **Existing Test Execution**:
  - Running `flutter test` completes successfully with output `All tests passed! (103 tests passed)`.

---

## 2. Logic Chain
1. **Goal**: Create a technical design and implementation plan that fully realizes Phase 1, Phase 2, and Phase 5 features in production (`lib/`) while maintaining compilation and runtime behavior alignment with E2E boundary tests.
2. **UI Integration**: Because the E2E boundary tests target `CompetitionHandlingPage` via the `/competition/handling` route defined in the `E2ETestHarness`, the final production page `lib/views/competition_handling_view.dart` (or renaming the class to `CompetitionHandlingPage`) must use the exact same widget keys (`attempt_weight_input`, `judge_1_toggle`, `judge_submit`, etc.) and SnackBar text outcomes so the E2E tests can be transitioned seamlessly to production pages.
3. **Core Business Logic**: The judging rules, weight validations, and plate math should not be duplicated across the views. Instead, they must be separated into a central `StreetliftingRulesEngine` utility inside `lib/utils/` and exposed via the `CompetitionProvider` state management class.
4. **Data Models**: DB persistence requires creating models for `Attempt`, `Flight`, `ScheduleItem`, and `SystemNotification` under `lib/models/`, which map directly to expected JSON/Supabase rows.
5. **Actionability**: An implementer can take this plan, execute the model generation, update `CompetitionProvider`, develop the production UI widgets, redirect route mappings in `e2e_test_harness.dart`, and successfully verify using the test command.

---

## 3. Caveats
- The rules engine uses a standard greedy algorithm to calculate weight plate distribution. However, custom rulebooks may vary regarding whether equipment weights (such as belts or barbell weights) are included in the math. We assume attempt weights are raw added loads.
- The `test/e2e/mock_views.dart` code is currently referenced in `test/e2e/e2e_test_harness.dart`. Once the production pages are created, the test harness imports must be updated to refer to the real pages under `lib/views/`.

---

## 4. Conclusion
We have mapped all expectations from the E2E test files and identified the missing models, repository fallbacks, and state properties. A central `StreetliftingRulesEngine` class can fully handle attempt logic, plates distribution, and majority vs. unanimous judging criteria. Implementing this architecture ensures the system meets the PRD's functional criteria while remaining 100% compliant with existing E2E test suites.

---

## 5. Verification Method
1. Inspect `analysis.md` in the current folder (`.agents/explorer_m4/analysis.md`) for detailed field schemas and implementation steps.
2. Run the project tests using:
   ```bash
   flutter test test/e2e/tier2_boundary_test.dart
   ```
3. To confirm invalidation: the E2E boundary test will fail if any of the target keys (`attempt_weight_input`, `dq_status`, etc.) or validation texts are altered or removed.
