## 2026-05-23T14:33:57Z
You are a Worker agent.
Your working directory is /Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/worker_m7_phase2_fix/
Your task is to fix 6 identified bugs in the platform features implementation, update the corresponding adversarial unit tests, and verify that the entire test suite passes.

### Target Files to Modify
1. `lib/utils/streetlifting_rules_engine.dart`
2. `lib/providers/competition_provider.dart`
3. `lib/views/competition_creation_wizard.dart`
4. `test/streetlifting_rules_engine_adversarial_test.dart`
5. `test/competition_handling_adversarial_test.dart`

---

### Description of the 6 Bugs and Required Fixes

1. **NaN/Infinity Crashes in Rules Engine**:
   - **Location**: `lib/utils/streetlifting_rules_engine.dart` (`validateIncrement` and `calculateAllPlates` / `calculateOtherPlatesString` etc.)
   - **Bug**: Calling `.round()` on `double.nan` or `double.infinity` throws `UnsupportedError`. Negative weights are also processed.
   - **Fix**: 
     - In `validateIncrement`, check if `weight.isNaN || weight.isInfinite || weight <= 0` and return an error string like `'Weight must be positive and valid!'`.
     - In `calculateAllPlates`, check if `weight.isNaN || weight.isInfinite || weight <= 0` and return a map with all plate counts set to 0.
     - Update the rules engine evaluation logic in `evaluateJudging` to support any panel size (unanimous for all true, and majority check using `(votes.length / 2).ceil()`).

2. **Double-Submission State Corruption**:
   - **Location**: `lib/providers/competition_provider.dart` (`submitJudgingVotes`)
   - **Bug**: Submitting votes multiple times in a row without a new weight selection adds duplicate weights to `_submittedAttempts` and increments attempt counts beyond bounds.
   - **Fix**: Check `if (_judgingComplete) return;` at the very beginning of `submitJudgingVotes`. Note that `selectAttemptWeight` resets `_judgingComplete = false`.

3. **Lighter Lifts Accepted**:
   - **Location**: `lib/providers/competition_provider.dart` (`selectAttemptWeight`)
   - **Bug**: Ascending weight validation only checks `_submittedAttempts.last`. If an attempt fails, it is not added to `_submittedAttempts`, allowing the user to select a lighter weight on subsequent attempts.
   - **Fix**:
     - Declare a state variable `double? _lastAttemptWeight` in the provider to track the last attempted weight in the current discipline (regardless of pass/fail).
     - When initializing handling (`initCompetitionHandling`) or transitioning to a new discipline in `submitJudgingVotes` / `resolveVARReview`, reset `_lastAttemptWeight = null;`.
     - In `selectAttemptWeight`, check ascending order against `_lastAttemptWeight`. If the selected weight is valid, set `_lastAttemptWeight = weight;`. (Or track it when the attempt is made/submitted, but verifying at `selectAttemptWeight` is clean).

4. **VAR Overrule State Pollution**:
   - **Location**: `lib/providers/competition_provider.dart` (`resolveVARReview` / `selectAttemptWeight`)
   - **Bug**: When attempt 3 fails, the provider immediately advances the discipline to the next one and clears `_submittedAttempts`. When the failed attempt 3 is subsequently overruled via VAR, `resolveVARReview` appends the overruled weight to `_submittedAttempts` (which is now the next discipline's list!).
   - **Fix**:
     - Declare a state variable `String? _attemptDiscipline` in the provider.
     - In `selectAttemptWeight`, set `_attemptDiscipline = discipline;`. Reset it to `null` in `initCompetitionHandling`.
     - In `resolveVARReview`, only add `_attemptWeight` to `_submittedAttempts` and handle discipline advancement if `_attemptDiscipline == _activeDiscipline`.

5. **Registration Capacity Limit Bypass**:
   - **Location**: `lib/providers/competition_provider.dart` (`registerAthlete`)
   - **Bug**: `registerAthlete` does not check current registrations against `maxAthletes` before registering.
   - **Fix**: Query the competition via `_repository.getCompetitionById(competitionId)`. If it has a non-null `maxAthletes`, fetch current registrations using `_repository.getRegisteredAthleteIds(competitionId)`. If current count >= `maxAthletes`, set `_errorMessage = 'Competition capacity limit reached!';` and return `false`.

6. **Wizard Creation Boundary Gaps (Negative limits & Waitlist inconsistencies)**:
   - **Location**: `lib/views/competition_creation_wizard.dart` (Step 3 Registration Form & Step 4 Fees Form)
   - **Bug**: Accepts negative capacity limits, negative entry fees, and waitlist enabled without capacity.
   - **Fix**:
     - In Step 3 (Registration), add a validator to `_maxAthletesController`:
       - If not empty, parse as integer; if `<= 0` return `'Capacity limit must be positive'`.
       - If `_enableWaitlist` is true, require the capacity limit: if empty, return `'Capacity limit is required to enable waitlist'`.
     - In Step 4 (Fees), update the validator for `_feeAmountController`:
       - If `_requiresFees` is true, parse as double; if null or `< 0`, return `'Fee amount cannot be negative'`.

---

### Update Adversarial Tests
Update `test/streetlifting_rules_engine_adversarial_test.dart` and `test/competition_handling_adversarial_test.dart` to assert the corrected, secure behaviors (instead of asserting that the bugs occur):
- Expect NaN/Infinity rules engine calls to return error strings or zero plates without throwing.
- Expect negative weights to return validation errors.
- Expect 5:0 unanimous panel to return true.
- Expect double-submission to be prevented (no duplicates added).
- Expect negative bodyweight weigh-in to throw `ArgumentError` (make sure to throw it in `recordWeighIn` if weight <= 0).

---

### Verification Requirements
1. Run `flutter analyze` to ensure 0 errors or warnings.
2. Run the full test suite using `flutter test`. Make sure all tests compile and pass cleanly (especially `test/rules_adversarial_test.dart`, `test/wizard_adversarial_test.dart`, and the other adversarial test files, plus all existing E2E/unit tests).
3. Document the command outputs and the files you modified in your handoff report (`handoff.md` in your working directory).
