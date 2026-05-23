# Handoff Report — Phase 2: Adversarial Coverage Hardening

This report details the adversarial testing coverage, findings, and empirical bugs identified in the finalrep-app codebase.

---

## 1. Observation

During execution and refinement of adversarial tests, we observed the following behavior across two distinct test suites (`test/rules_adversarial_test.dart` and `test/wizard_adversarial_test.dart`):

### A. Rules & Competition Handling Failures (`test/rules_adversarial_test.dart`)

* **Adversarial Test 1 (VAR Overrule State Pollution)**:
  * Command: `flutter test test/rules_adversarial_test.dart`
  * Verbatim failure output:
    ```
    ACTIVE DISCIPLINE: Pull Up
    ATTEMPT NUM: 1
    SUBMITTED ATTEMPTS: [20.0]
    00:00 +0 -1: Streetlifting Rules & Competition Handling Adversarial Tests Adversarial Test 1: VAR overrule of failed 3rd attempt causes state corruption when prior attempt succeeded [E]
      Expected: empty
        Actual: [20.0]
      Overruled weight from prior discipline must not pollute next discipline
    ```
  * Location: `test/rules_adversarial_test.dart:75`

* **Adversarial Test 2 (Decreasing Weights Accepted)**:
  * Command: `flutter test test/rules_adversarial_test.dart`
  * Verbatim failure output:
    ```
    ERROR FOR LIGHTER ATTEMPT: null
    00:00 +0 -2: Streetlifting Rules & Competition Handling Adversarial Tests Adversarial Test 2: Decreasing weight attempts after failed attempts are permitted [E]
      Expected: not null
        Actual: <null>
      Lighter attempt after failed attempt must be blocked
    ```
  * Location: `test/rules_adversarial_test.dart:96`

### B. Wizard & Registration Failures (`test/wizard_adversarial_test.dart`)

* **Adversarial Test 3 (Capacity Limit Bypass on Registration)**:
  * Command: `flutter test test/wizard_adversarial_test.dart`
  * Verbatim failure output:
    ```
    REGISTRATION 3 SUCCESS: true
    00:02 +1 -3: Competition Creation & Registration Adversarial Tests Adversarial Test 3: Capacity limits ignored during athlete registration [E]
      Expected: false
        Actual: true
      Registration must fail when capacity limit is exceeded
    ```
  * Location: `test/wizard_adversarial_test.dart:58`

* **Adversarial Test 4 (Negative Entry Fees Permitted)**:
  * Command: `flutter test test/wizard_adversarial_test.dart`
  * Verbatim failure output:
    ```
    Expected: no matching candidates
      Actual: _TextWidgetFinder:<Found 1 widget with text "Step 5: Volunteer Setup": ...>
       Which: means one was found but none were expected
      Negative fee amount must be blocked by validation
    ```
  * Location: `test/wizard_adversarial_test.dart:108`

* **Adversarial Test 5 (Waitlist Allowed Without Capacity)**:
  * Command: `flutter test test/wizard_adversarial_test.dart`
  * Verbatim failure output:
    ```
    Expected: no matching candidates
      Actual: _TextWidgetFinder:<Found 1 widget with text "Step 4: Fees & Payment Config": ...>
       Which: means one was found but none were expected
      Waitlist should not be enabled without a capacity limit
    ```
  * Location: `test/wizard_adversarial_test.dart:148`

* **Adversarial Test 6 (Negative Capacity Bounds Permitted)**:
  * Command: `flutter test test/wizard_adversarial_test.dart`
  * Verbatim failure output:
    ```
    Expected: no matching candidates
      Actual: _TextWidgetFinder:<Found 1 widget with text "Step 4: Fees & Payment Config": ...>
       Which: means one was found but none were expected
      Negative capacity limit must be blocked by validation
    ```
  * Location: `test/wizard_adversarial_test.dart:188`

---

## 2. Logic Chain

The step-by-step reasoning from codebase structure to the conclusions is detailed below:

1. **VAR State Pollution Bug**:
   * *Observation*: The test outputs show `SUBMITTED ATTEMPTS: [20.0]` on active discipline `Pull Up` after overruling attempt 3 (which was 20.0kg) on `Muscle Up`.
   * *Code Analysis (`lib/providers/competition_provider.dart:1003`)*: When a competitor fails their 3rd attempt but had an earlier success, the system immediately advances the discipline (Muscle Up -> Pull Up), resets `_attemptNum` to 1, and clears `_submittedAttempts`.
   * *Code Analysis (`lib/providers/competition_provider.dart:1031`)*: When `resolveVARReview(true)` is subsequently called, it checks if `!_submittedAttempts.contains(_attemptWeight)` and adds it. Since the discipline was already updated to Pull Up and `_submittedAttempts` cleared, the weight is appended to the Pull Up list. Furthermore, `_attemptNum == 3` is evaluated as false (it is now 1), meaning the discipline does not advance.
   * *Conclusion*: This represents a critical state corruption bug.

2. **Lighter Lifts Accepted**:
   * *Observation*: Attempt 2 with 15kg was accepted (returned `null` error) after Attempt 1 with 20kg failed.
   * *Code Analysis (`lib/providers/competition_provider.dart:967`)*: The ascending check relies on `_submittedAttempts.last`. If an attempt fails, it is not appended to `_submittedAttempts`. Hence, `_submittedAttempts.last` is either null or a previous successful lift (which might be lighter than the failed attempt), bypassing the ascending order enforcement.
   * *Conclusion*: Logic check fails to account for failed lift weights in ascending validation.

3. **Athlete Registration Capacity Limits Ignored**:
   * *Observation*: A 3rd athlete successfully registered on a competition initialized with `maxAthletes: 2`.
   * *Code Analysis (`lib/providers/competition_provider.dart:820` and `lib/repositories/competition_repository.dart:240`)*: Neither the provider method `registerAthlete` nor the repository checks current registrations against `maxAthletes` or `maxAthletesPerGroup`.
   * *Conclusion*: Capacity limits are completely ignored during athlete registration.

4. **Creation Wizard Boundary Violations**:
   * *Observation*: Steps 4 and 3 in the creation wizard allowed moving forward with a negative entry fee (-50.0), a waitlist enabled without capacity limit, and a negative athlete capacity limit (-5).
   * *Code Analysis (`lib/views/competition_creation_wizard.dart`)*:
     * Line 699: The validator for `_feeAmountController` only validates that a value is a double, without ensuring it is non-negative.
     * Line 574: There is no validation on `_maxAthletesController` to block negative values or to require a limit when `_enableWaitlist` is toggled.
   * *Conclusion*: Creation wizard lacks basic boundary checks and input validation filters.

---

## 3. Caveats

* We strictly adhered to the `review-only` constraint and did not modify the implementation code in `lib/`.
* The tests rely on the `InMemoryDatabase` mock implemented within `test/e2e/e2e_test_harness.dart`. While it accurately models Supabase behavior, actual server-side constraints (such as PostgreSQL RLS or check constraints) were not tested in isolation.

---

## 4. Conclusion

The application logic has substantial coverage gaps and business logic vulnerabilities:
1. **VAR reviews** corrupt the lift records of subsequent disciplines if a competitor fails their 3rd attempt but passes a prior one.
2. **Ascending attempt weight enforcement** is bypassed following any failed attempt.
3. **Registration capacity limits** are ignored.
4. **Wizard creation parameters** allow negative values (fees, capacity bounds) and logical inconsistencies (waitlists without capacity limits).

These must be addressed by a Worker agent modifying the validation and state machine logic under `lib/`.

---

## 5. Verification Method

To verify these bugs and ensure they are fixed, run the following test commands:

```bash
# Verify rules & state corruption bugs
flutter test test/rules_adversarial_test.dart

# Verify wizard validation bounds & capacity limits bugs
flutter test test/wizard_adversarial_test.dart
```

* **Invalidation Condition**: The verification fails if these tests pass on the codebase without code modification. Once the implementation code under `lib/` is corrected, both test commands must compile and pass cleanly (`exit code: 0`).
