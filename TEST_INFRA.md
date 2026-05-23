# E2E Test Infra: FinalRep Streetlifting App

## Test Philosophy
- **Opaque-box, requirement-driven**: Tests derive from the user-facing specifications in `ORIGINAL_REQUEST.md` (and related PRD details) rather than the internal implementation code layout.
- **Independent from Implementation State**: To prevent compilation blockages while views are under construction, the test suite interfaces through generic widget keys and includes mock view pages that stand in for screens still being implemented by the Implementation track.
- **Verification methodology**: Category-Partition + Boundary Value Analysis + Pairwise Combinatorial Testing + Real-World Workload Journeys.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|---------------------|:------:|:------:|:------:|
| 1 | Login & Forgot Password | ORIGINAL_REQUEST §1 | 5      | 4      | ✓      |
| 2 | Profile Customization | ORIGINAL_REQUEST §2 | 5      | 0      | ✓      |
| 3 | Competitions Feed & Details | ORIGINAL_REQUEST §3 | 5      | 0      | ✓      |
| 4 | Streetlifting & Competition Wizard / Scoreboard | ORIGINAL_REQUEST §4/5 | 0      | 5      | ✓      |

## Test Architecture
- **Test Runner**: executed via `flutter test test/e2e/`.
- **Test Case Format**: Widget tests executing in an isolated local Flutter tester harness.
- **Directory Layout**:
  - `test/e2e/e2e_test_harness.dart`: provides mock authentication state, mock Supabase database operations (`MockSupabaseClient` via dynamic `noSuchMethod` forwarding), and fake/in-memory repositories (`InMemoryDatabase`) for profiles, competitions, attempts, and associations.
  - `test/e2e/mock_views.dart`: contains mock widgets/pages for screens under development (such as wizards, rankings, competition score sheets, admin panels) to allow the testing track to run in parallel.
  - `test/e2e/tier1_feature_coverage_test.dart`: verifies essential feature paths (login lowercasing, email password credentials, edit profiles, switching feed grid/list/map layouts, filter chips, and sorting).
  - `test/e2e/tier2_boundary_test.dart`: validates border inputs (trimming input fields, password strength constraints, forgot password invalid formats) and strict Streetlifting competition rules (1.25kg increments for muscle up/pull up/dip, 2.5kg for squat, ascending order, majority 2:1 vs unanimous judging, VAR credit rules, and 3-strike disqualification).
  - `test/e2e/tier3_combination_test.dart`: covers cross-feature scenarios (e.g., registration to profile customization, auth state synchronization, theme preferences persistence, and deep link auth interceptions).
  - `test/e2e/tier4_real_world_test.dart`: simulates user journeys (guest spectator competition discovery and new athlete registration, profile wizard onboarding, and setup).

## Real-World Application Scenarios (Tier 4)
- **Guest Spectator Discovery**: A guest logs in, accesses the competitions feed, switches layouts, applies classic/modern format filters, sorts, and checks the details page.
- **Athlete Registration & Onboarding**: A new athlete signs up, goes through the onboarding wizard (profile, avatar upload), modifies settings, and updates their profile details.

## Coverage Thresholds
- **Tier 1 (Feature Coverage)**: ≥5 tests per covered feature (Total: 15 tests)
- **Tier 2 (Boundary & Corner)**: Focuses on validation and business rule limits (Total: 9 tests)
- **Tier 3 (Cross-Feature Combinations)**: Multi-flow integrations (Total: 3 tests)
- **Tier 4 (Real-World Application)**: Multi-step spectator/athlete journeys (Total: 2 tests)
