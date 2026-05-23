# Quality & Adversarial Review Report

## Review Summary

**Verdict**: APPROVE

Overall, the implementation of R5 fixes (Competition Creation Wizard & Custom Fields) is of very high quality. It cleanly resolves all identified bugs, conforms to clean-code guidelines, is completely free of static analysis issues in the modified files, and passes the entire project test suite (103/103 tests passing).

---

## Findings

### [Minor] Finding 1: Acceptance of Negative Fee Amounts

- **What**: The registration fee input validator allows users to enter negative values (e.g., `-20.0`).
- **Where**: `lib/views/competition_creation_wizard.dart`, line 699
- **Why**: The validator only checks if the input is parseable as a double: `double.tryParse(value) == null`. However, negative fee amounts are logical nonsense for a competition registration fee.
- **Suggestion**: Update the validator to check if the parsed fee is greater than or equal to zero:
  ```dart
  validator: (value) {
    if (!_requiresFees) return null;
    if (value == null) return 'Provide valid fee amount';
    final amount = double.tryParse(value);
    if (amount == null || amount < 0) return 'Fee amount must be a positive number';
    return null;
  }
  ```

---

## Verified Claims

- **All 103 tests pass** → verified via running `flutter test` → **PASS** (103 tests passed successfully, including combination, integration, and UI tests).
- **Zero static analysis errors/warnings in modified files** → verified via running `flutter analyze` targeting the modified files → **PASS** (Analyzed 7 items; no issues found).
- **Wizard Step 4: Validation Order Bug is resolved** → verified via tracing code in `_nextStep()` in `lib/views/competition_creation_wizard.dart` where `_updatePaymentDescription()` is called before validating `_formKey4` → **PASS**.
- **Wizard Step 4: Default Payment Dates Null State is resolved** → verified via checking the switch `onChanged` handler which initializes `_paymentStartDate` and `_paymentEndDate` to non-null values when fees are enabled → **PASS**.
- **Wizard Step 5: State Leak of Volunteer Capacity is resolved** → verified via checking `_submitCompetition()` which conditionally sets `maxVolunteers` to `null` if `_volunteerNeeds` is disabled → **PASS**.
- **Volunteer Application: Empty Preferred Roles Submission is prevented** → verified via verifying in `competition_detail_page.dart` that the submit button's `onPressed` is disabled if `_selectedRoles.isEmpty` → **PASS**.
- **Volunteer Application: Shift Availability State Leak is resolved** → verified via verifying that `_shiftAvailability` is cleared for a role on chip deselection and only active selected roles shifts are kept during application submission → **PASS**.
- **Volunteer Application: Dropdown Duplication Crash is resolved** → verified via verifying that custom volunteer fields dropdown items are deduplicated using `.toSet().toList()` → **PASS**.

---

## Coverage Gaps

- **Association Management Layout and Profile Page Deprecation Warnings** — risk level: **low** — recommendation: **accept risk**. There are other files in the project (e.g. `association_management_page.dart` and `profile_page.dart`) that trigger warnings about using the deprecated `value` parameter or `withOpacity`. However, these are outside the R5 features scope and do not cause regressions.
- **Negative Fee Amount validation** — risk level: **low** — recommendation: **accept risk** or apply the suggested validator fix in a future minor refactoring.

---

## Unverified Items

- None. All R5 related features and assertions were fully verified through direct code inspection and automated testing.

---

# Adversarial Challenge Report

## Challenge Summary

**Overall risk assessment**: LOW

The wizard creation flow and volunteer application forms have been stress-tested and found to be robust against null states, empty forms, duplicate configuration properties, and basic navigation sequence manipulation.

---

## Challenges

### [Low] Challenge 1: Invalid Disclaimer URL input

- **Assumption challenged**: Users will enter valid terms/conditions URLs when configuring a disclaimer link.
- **Attack scenario**: A user inserts a random string like `not_a_valid_url` into the disclaimer URL text field.
- **Blast radius**: If the system saves it without validation, the application page could crash or attempt to launch an invalid URI when clicked by an applicant.
- **Mitigation**: The wizard employs `Uri.tryParse(value)` and checks `uri.hasAbsolutePath` to reject invalid URLs at input-time, which successfully mitigates this risk.

### [Low] Challenge 2: Re-entry and State Leak of Volunteer Needs

- **Assumption challenged**: Toggling volunteer needs off will clear any entered limit in the wizard before database submission.
- **Attack scenario**: User enables volunteer needs, sets `maxVolunteers` to `15`, toggles volunteer needs off, and submits.
- **Blast radius**: The database record could store `maxVolunteers` as `15` even though `volunteerNeeds` is recorded as `false`, causing confusion or reports discrepancies.
- **Mitigation**: The submission handler explicitly nullifies capacity limits if the needs toggle is off, which successfully prevents this data leak.

---

## Stress Test Results

- **Payment Dates Null State** → Verify payment start/end dates are populated on submission when toggled on → **PASS**.
- **Dropdown Duplication Options** → Verify dropdown field builds successfully without crash on duplicate options configuration → **PASS**.
- **Empty Preferred Roles Submission** → Verify submit button is disabled when no preferred roles chip is chosen → **PASS**.
- **Back-and-forth wizard step navigation** → Verify state holds and disciplines correctly update when switching modern/classic subtypes → **PASS**.
- **Deselected Role shifts state leak** → Verify deselected roles shifts are cleared and not included in final payload → **PASS**.

---

## Unchallenged Areas

- **Backend validation constraints** — reason not challenged: The review was focused entirely on client-side Flutter models, widgets, and state behaviors matching the scope of R5. Supabase direct DB rules and policy validations were not challenged due to being out of scope.
