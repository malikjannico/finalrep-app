# Review Report — Competition Creation Wizard & Custom Fields (R5)

## Review Summary

**Verdict**: REQUEST_CHANGES (due to Critical compilation/static analysis errors in the project, and several Major/Minor bugs related to state preservation, input validation, and payload leaks).

Overall, the core implementation of the 6-step Competition Creation Wizard, custom athlete/volunteer fields, and the volunteer application flow in the FinalRep Streetlifting application is functionally complete and aligns with the product requirements. However, there are compile-time errors in the newly added stress test file, and multiple state leaks/validation flaws in the wizard and volunteer sheet.

---

## Findings

### [Critical] Finding 1: Compilation / Static Analysis Errors in `test/competition_creation_wizard_stress_test.dart`
- **What**: The stress test file `test/competition_creation_wizard_stress_test.dart` fails compilation, preventing `flutter analyze` from succeeding.
- **Where**: `test/competition_creation_wizard_stress_test.dart` (Lines 84, 85, 113)
- **Why**: 
  - Line 84: `prefixedBy` is not a defined method on `Finder`.
  - Line 85: `matches` expects 2 positional arguments, but only 1 was provided.
  - Line 113: The private class name `_CreateCompetitionWizardState` is referenced as a type argument. Because it is library-private (prefixed with `_`), it cannot be resolved outside of `lib/views/competition_creation_wizard.dart`.
- **Suggestion**: 
  - Do not reference library-private state classes in tests. Interact with state via public widgets/keys or finders.
  - Avoid using non-existent finder extensions like `prefixedBy`. Use standard Flutter `find` methods (e.g. `find.descendant`).

### [Major] Finding 2: Negative Fee Amounts Accepted by Wizard Validator
- **What**: Organizers can enter a negative registration fee (e.g., `-20.00`) in Step 4, and the wizard proceeds without throwing a validation error.
- **Where**: `lib/views/competition_creation_wizard.dart` (Line 690)
- **Why**: The field validator checks if the parsed double is null (`double.tryParse(value) == null`), but does not verify that the value is non-negative.
- **Suggestion**: Update the validator to check that the fee is positive/zero, e.g., `double.tryParse(value)! >= 0`.

### [Major] Finding 3: State Leak of Volunteer Capacity on Disable
- **What**: When the "Enable Volunteer Needs" toggle in Step 5 is turned ON, a limit (e.g. `10`) is entered, and then the toggle is turned OFF, the old limit `maxVolunteers: 10` is still transmitted in the final creation payload.
- **Where**: `lib/views/competition_creation_wizard.dart` (Line 221)
- **Why**: The controller values are not cleared/ignored when the switch is disabled.
- **Suggestion**: Conditionally set the capacity field to null in the creation payload if volunteer needs are disabled: `maxVolunteers: _volunteerNeeds ? int.tryParse(_maxVolunteersController.text) : null`.

### [Minor] Finding 4: Empty Roles Allowed in Volunteer Applications
- **What**: A user can submit a volunteer application without selecting any preferred roles.
- **Where**: `lib/views/competition_detail_page.dart` (Lines 769-783)
- **Why**: The submit button only checks if the disclaimer is accepted, allowing empty `preferred_roles` lists to be stored in the database.
- **Suggestion**: Disable the submit button unless at least one preferred role is selected: `_selectedRoles.isNotEmpty`.

### [Minor] Finding 5: Shift Availability State Leak on Role Deselection
- **What**: When a user selects a volunteer role (e.g., "Judge"), selects a shift, and then deselects "Judge" to select "Loader" instead, the shift availability for "Judge" remains in the final payload `shift_availability`.
- **Where**: `lib/views/competition_detail_page.dart` (Lines 603-614)
- **Why**: Deselecting a role removes it from `_selectedRoles` but does not prune the `_shiftAvailability` map.
- **Suggestion**: Clear shift availability for a role when it is deselected in the FilterChip's `onSelected` callback: `_shiftAvailability.remove(pos)` or `_shiftAvailability[pos] = []`.

### [Minor] Finding 6: Deprecated UI Widget Usage
- **What**: Multiple deprecation info lints are reported by `flutter analyze`.
- **Where**:
  - `lib/views/competition_creation_wizard.dart` (Lines 463, 477, 558, 694, 911): Deprecated `value` parameter on `DropdownButtonFormField`.
  - `lib/views/competition_detail_page.dart` (Line 631): Deprecated `onReorder` callback on `ReorderableListView`.
- **Why**: Using deprecated parameters increases long-term maintenance overhead.
- **Suggestion**:
  - Replace `value` with `initialValue` on `DropdownButtonFormField`.
  - Replace `onReorder` with `onReorderItem` on `ReorderableListView` or update to standard signature.

---

## Verified Claims

- **Core R5 changes compile successfully**: **PASS** (excluding the stress test file, the core app files and original tests build and run cleanly).
- **All tests pass successfully**: **PASS** (All 93 tests in the suite pass, including the 4 new R5 tests in `test/competition_creation_wizard_test.dart`).
  - Command: `flutter test test/competition_creation_wizard_test.dart` -> `All tests passed!`
  - Command: `flutter test` -> `All tests passed!`
- **Location verification mock correctness**: **PASS** (Tapping "Verify Location" successfully updates context state and simulates geocoding coordinates).
- **Fee Configuration panel visibility**: **PASS** (Toggling the fees switch correctly reveals/hides fee amount and banking fields).

---

## Coverage Gaps

- **Integration with real Supabase Auth/Database**: **Medium Risk** — All DB inserts are mocked using the `E2ETestHarness` and `InMemoryDatabase`. Real database schema constraints (such as RLS rules or foreign key constraints on the `volunteer_applications` table) have not been verified. 
  - *Recommendation*: Perform manual or staging integration verification to ensure the real Supabase schema matches the mock inserts.

---

## Unverified Items

- **Visual correctness of Banner Safe Zone Guide**: Not verified as widget testing does not render pixel-perfect overlays.

---

## Adversarial Stress-Testing Challenge Report

### [High] Challenge 1: Invalid Date Range Permutations
- **Assumption challenged**: Start/End registration dates are sequential and valid.
- **Attack scenario**: Setting registration start to be after the competition start date, or registration end before registration start.
- **Blast radius**: The wizard prevents proceeding via `_validateDates()`, showing a snackbar error. However, if dates are set programmatically via state bypass, the model constructor enforces no validations, creating an invalid competition object.
- **Mitigation**: Add assertions inside `Competition` constructor to throw on invalid date ranges (e.g. `assert(registrationEnd.isBefore(startDate))`).

### [Medium] Challenge 2: Currency/Decimal Precision Vulnerabilities
- **Assumption challenged**: Fee amount is stored as a clean double value.
- **Attack scenario**: Inputting extreme floating point values (e.g. `0.00000001` or very large numbers) into `feeAmount`.
- **Blast radius**: Double parsing handles these in Dart, but they might fail database numeric column precision constraints or cause display rounding bugs in the UI.
- **Mitigation**: Implement input mask/regex constraint on `feeAmount` text field to enforce 2 decimal places.
