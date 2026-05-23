# Milestone 7, Phase 1: Test Verification Tiers 1-4 Analysis & Execution Strategy

This report provides a comprehensive analysis of the existing test suites (both E2E and Unit/Widget tests) in the FinalRep repository and details a structured strategy to execute and verify them.

---

## 1. Observation

### Test Directory Layout
An inspection of the workspace revealed a total of 23 `.dart` files within the `test/` directory, divided into E2E Integration tests and Unit/Widget tests.

#### E2E Integration Suite (`test/e2e/`):
1. **`test/e2e/e2e_test_harness.dart`** (Infrastructure Helper)
   - *Purpose*: Implements `E2ETestHarness` to mock authentication state (`MockGoTrueClient`), mock Supabase databases (`MockSupabaseClient` via dynamic forwarding), and provide an in-memory database (`InMemoryDatabase`) for profiles, competitions, attempts, associations, and storage.
2. **`test/e2e/mock_views.dart`** (Infrastructure Helper)
   - *Purpose*: Provides mock UI pages/widgets for sections of the app that are/were under development (e.g., `AdminDashboardPage`, `CreateAssociationPage`, `CreateCompetitionPage`, `RankingsPage`, `NotificationsPage`) to ensure E2E tests compile and run reliably in parallel.
3. **`test/e2e/image_test.dart`** (1 test)
   - *Purpose*: Widget test verifying that 1x1 PNG asset (`assets/images/comp_berlin.png`) resolves and decodes successfully using `MemoryImage` (line 7: `testWidgets('Test decoding 1x1 PNG', (WidgetTester tester) async { ... })`).
4. **`test/e2e/tier1_feature_coverage_test.dart`** (15 tests)
   - *Purpose*: Verifies critical user flows: login username lowercasing, email-password login, forgot password recovery, editing profiles, feed list/grid/map layout selection, sorting and filter chips.
5. **`test/e2e/tier2_boundary_test.dart`** (9 tests)
   - *Purpose*: Validates input constraints (whitespace trimming, password strength check, invalid forgot-password email formats, profile fetch retry latency) and strict Streetlifting rules (1.25kg and 2.5kg plate increments, ascending weight order, 2:1 majority vs 3:0 unanimous judging, VAR video review overrules, and 3-strike disqualification).
6. **`test/e2e/tier3_combination_test.dart`** (3 tests)
   - *Purpose*: Covers cross-feature paths (registration -> login -> profile customization flow, auth synchronization & theme persistence, and deep-link auth interception).
7. **`test/e2e/tier4_real_world_test.dart`** (2 tests)
   - *Purpose*: Validates multi-step journeys (Guest Spectator Competition Discovery Journey, New Athlete Onboarding & Setup Journey).

#### Unit and Widget Test Suite (`test/`):
8. **`test/auth_provider_test.dart`**
   - *Purpose*: Unit test coverage for `AuthProvider` (login with email/username, password rules validation, profile updates, and permissions).
9. **`test/competition_creation_wizard_diag_test.dart`**
   - *Purpose*: Diagnostic widget testing of the Competition Creation Wizard form fields.
10. **`test/competition_creation_wizard_stress_test.dart`**
    - *Purpose*: Advanced testing for wizard edge cases, such as negative entry fees, empty inputs, validation triggers, and navigation states.
11. **`test/competition_creation_wizard_test.dart`**
    - *Purpose*: Core widget test verifying UI rendering, navigation steps, and registration status transitions.
12. **`test/competition_model_test.dart`**
    - *Purpose*: Unit tests for parsing `Competition` models from JSON data.
13. **`test/competition_provider_test.dart`**
    - *Purpose*: Unit tests for `CompetitionProvider` state management (feed loading, filters, search scope settings).
14. **`test/map_view_test.dart`**
    - *Purpose*: Widget test verifying that `WorldMapView` handles resizing, orientation, and theme switches without assertions.
15. **`test/milestone2_test.dart`**
    - *Purpose*: Unit/Widget tests for permissions, global sport configurations, association CRUD, and athlete weight group creation.
16. **`test/notification_adversarial_test.dart`**
    - *Purpose*: Adversarial test cases for notifications to find coverage gaps and stress boundary values.
17. **`test/notification_integration_test.dart`**
    - *Purpose*: Integration tests of real notification delivery events.
18. **`test/notification_stress_test.dart`**
    - *Purpose*: Performance and UI filtration stress tests for notifications.
19. **`test/notification_system_test.dart`**
    - *Purpose*: Core notification page and preference panel widget tests.
20. **`test/profile_model_test.dart`**
    - *Purpose*: Unit tests covering parsing and serialization of `Profile` models (including social links and preferences).
21. **`test/widget_test.dart`**
    - *Purpose*: Massive widget test file (1,309 lines) checking views, layout switches (Grid/Compact/Map), multi-step registration forms, password checklists, settings pages, and profile pages.

#### Database Inspection / Utility Scripts (`test/`):
22. **`test/db_inspect_test.dart`**
    - *Purpose*: Connects to the real remote Supabase URL and queries the schema of the `profiles` table.
23. **`test/test_db.dart`**
    - *Purpose*: Connects to the real remote Supabase URL and inspects profiles table schema.

---

## 2. Logic Chain

1. **Isolation from Backend**: The E2E tests (`test/e2e/`) rely on `E2ETestHarness` and `InMemoryDatabase` to mock all authentication and Supabase database requests. In addition, the unit and widget tests in `test/` use self-contained mock repositories (e.g. `MockProfileRepository`, `FakeCompetitionRepository`) or fallback in-memory databases (e.g. `AdminRepository(null)`, `AssociationRepository(null)`).
2. **Compile-time and Runtime Safety**: By using `mock_views.dart`, the E2E integration track decoupled test stability from components still under development by referencing predefined widgets/keys rather than fragile UI hierarchies.
3. **Remote Schema Inspection Exception**: Two files, `db_inspect_test.dart` and `test_db.dart`, contain code that accesses the live Supabase API endpoint (`https://vnseudpajhkicezdcsuj.supabase.co`). When running in a network-restricted or sandbox environment (such as `CODE_ONLY` mode), these tests will attempt HTTP queries and fail or time out.
4. **Expected Test Counts**: The E2E suite contains exactly 30 test cases matching `TEST_READY.md`:
   - Tier 1: 15 tests
   - Tier 2: 9 tests
   - Tier 3: 3 tests
   - Tier 4: 2 tests
   - Image Helper: 1 test
   - *Total*: 30 tests.
5. **Execution Strategy Formulation**: To verify the entire suite successfully, subsequent agents must execute the isolated mock tests separately from the network-dependent database inspectors. 

---

## 3. Caveats

- **Network Constraints**: `db_inspect_test.dart` and `test_db.dart` require external network connectivity and correct Supabase keys. In offline/sandbox environments, these two files must be run separately or skipped to avoid timing out the test suite runner.
- **Flutter Environment Assumptions**: It is assumed that the execution system has the Flutter SDK installed and configured, and that dependencies have been resolved via `flutter pub get`.
- **Read-Only Restriction**: The Explorer agent did not execute any commands or run the tests, and did not modify any source code files.

---

## 4. Conclusion

The codebase contains a robust, highly modular test suite. 21 out of 23 test files are completely offline and self-contained, utilizing in-memory mock databases and mock providers. Running the test suite is straightforward but requires separating the offline tests from the online database schema inspectors to ensure a clean build and pass verdict in isolated runners.

---

## 5. Verification Method

To verify the test suite and confirm that all tests pass, the following commands should be executed:

### Step 1: Resolve Dependencies
Ensure all project dependencies are updated and local files compile correctly:
```bash
flutter pub get
```

### Step 2: Run the E2E Test Suite (30 Tests)
Execute all tests in the E2E suite. They run completely in-memory using the `E2ETestHarness`:
```bash
flutter test test/e2e/
```
*Expected Output*: "All tests passed!" with 30 tests completed successfully.

### Step 3: Run the Unit & Widget Test Suite (Offline files)
Execute the offline provider, model, and UI tests. Specify individual files or run the directory while ignoring the database inspection scripts:
```bash
flutter test $(find test -name "*_test.dart" ! -name "db_inspect_test.dart") test/widget_test.dart test/milestone2_test.dart
```
Alternatively, run them one by one to ensure isolated diagnostics:
```bash
flutter test test/auth_provider_test.dart
flutter test test/competition_creation_wizard_test.dart
flutter test test/competition_creation_wizard_diag_test.dart
flutter test test/competition_creation_wizard_stress_test.dart
flutter test test/competition_model_test.dart
flutter test test/competition_provider_test.dart
flutter test test/map_view_test.dart
flutter test test/milestone2_test.dart
flutter test test/notification_adversarial_test.dart
flutter test test/notification_integration_test.dart
flutter test test/notification_stress_test.dart
flutter test test/notification_system_test.dart
flutter test test/profile_model_test.dart
flutter test test/widget_test.dart
```

### Step 4: Run Remote Database Inspectors (Network Access Required)
If external network access is available, verify the live schema integrity:
```bash
flutter test test/test_db.dart
flutter test test/db_inspect_test.dart
```
