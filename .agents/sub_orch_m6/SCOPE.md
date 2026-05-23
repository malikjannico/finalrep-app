# Scope: Milestone 6 - E2E Testing Track

## Architecture
- **E2E Test Suite**: Located in `test/e2e/`. Organized by tier:
  - `test/e2e/tier1_feature_coverage_test.dart`
  - `test/e2e/tier2_boundary_test.dart`
  - `test/e2e/tier3_combination_test.dart`
  - `test/e2e/tier4_real_world_test.dart`
- **Opaque-Box Design**: The tests interact with the application using generic widget finders, text fields, keys, and button taps. They do not import non-existent views or models to prevent compilation failures before the Implementation Track is complete.
- **Test Harness**: Located in `test/e2e/e2e_test_harness.dart`. It provides mock providers, mock Supabase clients, and standard routing configuration to execute tests in an isolated sandbox.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | Design E2E Test Infra & Harness | Create `test/e2e/e2e_test_harness.dart` with mock state and custom helpers | None | DONE (Worker: 133002c8-63a5-4d62-9919-14f192438f05) |
| 2 | Implement Tier 1 Tests | Write feature coverage tests (5+ tests per feature) for all requirements | M1 | DONE (Worker: 133002c8-63a5-4d62-9919-14f192438f05) |
| 3 | Implement Tier 2 Tests | Write boundary/corner case tests (5+ tests per feature) | M2 | DONE (Worker: 133002c8-63a5-4d62-9919-14f192438f05) |
| 4 | Implement Tier 3 Tests | Write pairwise cross-feature combination tests | M3 | DONE (Worker: 133002c8-63a5-4d62-9919-14f192438f05) |
| 5 | Implement Tier 4 Tests | Write high-level real-world scenario tests | M4 | DONE (Worker: 133002c8-63a5-4d62-9919-14f192438f05) |
| 6 | Verify Test Runner & Publish | Execute the test runner, check compilation, publish `TEST_INFRA.md` and `TEST_READY.md` | M5 | DONE (Worker: c1748433-19cb-4b5d-88c6-5550ebf5505c, Auditor: ac5c5b87-596d-4ea6-9718-9f15965e4de6) |

## Interface Contracts
### Test Harness ↔ E2E Tests
- `Future<void> pumpE2EApp(WidgetTester tester, {MockAuthProvider? auth, FakeCompetitionRepository? repo})`: Sets up the widget tree with mock providers and runs the app.
- Keys and Identifiers used:
  - Login Page: `Key('login_username_field')`, `Key('login_password_field')`, `Key('login_button')`, `Key('forgot_password_button')`
  - Profile Page: `Key('profile_settings_button')`, `Key('profile_edit_button')`, `Key('profile_username_header')`
  - Admin Panel: `Key('admin_panel_tab')`, `Key('promote_user_button')`
  - Association Wizard: `Key('association_wizard_stepper')`
  - Competition Wizard: `Key('competition_wizard_stepper')`
  - Judging Panel: `Key('judging_vote_good')`, `Key('judging_vote_no')`
