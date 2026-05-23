# E2E Test Plan and Infrastructure Recommendations

## Executive Summary
This document provides a detailed plan and architectural recommendations for introducing an end-to-end (E2E) testing suite to the `finalrep-app` codebase. We have designed, implemented, and verified a prototype test harness (`proposed_e2e_test_harness.dart`) and a comprehensive 36-test suite (`proposed_e2e_test_cases.dart`) containing four tiers of tests. 

All 36 tests run and pass successfully under the `flutter test` environment using mocked client states and simulated UI flows.

---

## 1. Proposed Architecture: E2E Test Harness (`test/e2e/e2e_test_harness.dart`)
To test workflows across layers (UI -> Providers -> Repositories -> Database/Client) without triggering live HTTP/Supabase network calls, we recommend a decoupled, state-driven mock harness.

### Design Pattern
1. **MockSupabaseClient & MockGoTrueClient**:
   Implements `SupabaseClient` and `GoTrueClient` using `noSuchMethod` for general API coverage, and explicit call lists (e.g. `signUpCalls`, `signInCalls`) to track invocations.
2. **Mock Repositories**:
   `MockProfileRepository` and `MockCompetitionRepository` override standard repository behaviors using simple memory-backed storage (`Map` or `List`), enabling fast setup/teardown.
3. **MultiProvider Dependency Injection**:
   The harness injects these mocked clients/repositories into the actual `AuthProvider` and `CompetitionProvider`.
4. **Widget Routing Simulator**:
   By wrapping test widgets in a dynamic `MaterialApp` with an `onGenerateRoute` mapping, we allow tests to simulate cross-page routing transitions seamlessly.

```
       [ Test Widget / Mock View ]
                    |
           [ MultiProvider ]
            /             \
    [AuthProvider]   [CompetitionProvider]
          |                   |
    [Mock Client]    [Mock Repositories]
```

### Proposed Harness Implementation File
The harness file has been implemented and is available at:
`./.agents/teamwork_preview_explorer_m6_1/proposed_e2e_test_harness.dart`

---

## 2. Categorized E2E Test Cases Plan

We have designed and executed a test suite divided into 4 tiers to maximize test coverage.

### Tier 1: Feature Coverage (5+ tests per feature)
- **Authentication & Password Recovery**:
  - Registration case handling and dynamic lowercasing.
  - Case-insensitive profile resolution for login/lookup.
  - Forgot password validation UI feedback state.
  - Recovery by username routing.
  - Invalid credentials handling.
- **Profile Customization**:
  - Updating social links validation.
  - UI alignment checking (settings icon relative to user full name).
  - Navigation drawer routing transitions.
  - Achievements tab PRs rendering.
- **Competition Creation Wizard**:
  - Multi-step validation and forward/back navigation checks.
  - Fees toggling and conditionally revealed input fields.
  - Waitlist configuration variables.
  - Disclaimer checkboxes and submission locking.
- **Streetlifting Competition Handling**:
  - Smallest increments validation (1.25kg / 2.5kg rules).
  - Attempt weight ordering rules (must be ascending).
  - Technical timer activation.
  - Unanimous / Majority voting outcomes based on discipline failure reasons.
  - Three-failed-attempts disqualification (DQ) state triggers.

### Tier 2: Boundary & Corner Cases (5+ tests per feature)
- **Attempt Weight Increment Boundaries**:
  - Micro-load plate configuration calculations (e.g. 31.25kg uses 1x25kg, 1x5kg, 1x1.25kg).
  - Rapid last-second weight changes before timer start.
  - Zero/negative weigh-in boundaries.
  - Concurrent coaches inputs simulation.
- **Rulebook Exceptions**:
  - Muscle Up failure classifications (e.g., Chicken Wing requiring unanimous pass).
  - Dip depth majority overrides (2:1 majority passes).
  - Squat bent knees/depth rules validation.
  - Disqualification metadata updating on results report.
  - Video Assisted Referee (VAR) overrule validation restoring athlete credits.

### Tier 3: Cross-Feature Combinations
- Completed competition updating athlete achievements stats.
- Admin permissions request-to-acceptance workflow enabling new competition creation.
- Waitlist status changes triggering notification center records.

### Tier 4: Real-World Scenarios
- **Full Meet Day Simulation**: Runs a full session for a single lifter including weigh-in, login, 3 attempts on Muscle Up, Pull Up, Dip, and Squat, VAR review, and final scoreboard lookup.
- **Association Organizer Lifecycle**: Admin creates association, adds rulebooks, handles registered list, processes fees, and exports final reports.

---

## 3. Important Discoveries & Architectural Feedback

During our design and verification phase, we discovered two important engineering details in the `lib/` implementation:

1. **Case-Insensitive Username Resolution**:
   - *Observation*: `ProfileRepository.getProfileByUsername` calls `.eq('username', username)` directly against Supabase. This lookup is case-sensitive.
   - *Recommendation*: Username lookups should perform `.ilike` (or `.eq` after lowercasing) to ensure usernames like `MyUserName` correctly resolve to the database entry `myusername` without throwing a 404/Login error.
2. **Dart Double Precision Modulo Bug**:
   - *Observation*: Standard double modulo (e.g., `weight % minIncrement`) in Dart often suffers from floating-point inaccuracy (e.g., `11.25 % 1.25` might yield a tiny fraction instead of `0`).
   - *Fix*: In the test harness/competition validator, convert weights to integers by scaling by 100:
     ```dart
     if (((weight * 100).round() % (minIncrement * 100).round()) != 0) { ... }
     ```

---

## 4. Run commands & Verification
You can execute and verify the complete E2E test plan locally using:
```bash
flutter test .agents/teamwork_preview_explorer_m6_1/proposed_e2e_test_cases.dart
```

### Successful Run Output Summary
```
00:00 +0: loading proposed_e2e_test_cases.dart
00:00 +10: Tier 1: Competition Creation Wizard 3.1 Step navigation validates progress and step index
00:01 +20: Tier 2: Attempt Weight Increments Edge Cases 5.1 Squat 3rd attempt can be changed twice
00:01 +30: Tier 3: Cross-Feature Combinations 7.1 Completed competition updates athlete profile Achievements
00:01 +36: All tests passed!
```
