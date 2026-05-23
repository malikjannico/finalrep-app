# Adversarial Review Report — R5 Implementation Verification

## Challenge Summary

**Overall risk assessment**: MEDIUM

While the R5 implementation matches the general layout of the 6-step wizard and the volunteer detail bottom sheet, several critical state management issues, validation loopholes, and UI mismatches were uncovered through empirical stress testing. If unmitigated, these issues could lead to database inconsistencies, application crashes for volunteers, and confusing user experiences.

---

## Challenges

### [High] Challenge 1: Custom Field Dropdown Option Duplicates Crash Bottom Sheet
- **Assumption challenged**: Assumed custom field dropdown options added in Step 6 of the wizard are valid and unique.
- **Attack scenario**: An administrator enters duplicate options (e.g. `Beginner, Beginner` or trailing commas generating empty/duplicate options) during custom field configuration in the wizard. The wizard stores these options exactly as typed. When a volunteer opens the application bottom sheet and selects an option from that custom field dropdown, Flutter's `DropdownButton` throws an assertion exception (`There should be exactly one item with the corresponding value...`) which crashes the entire widget tree, producing a red screen.
- **Blast radius**: High. Any volunteer attempting to apply to a competition with duplicate custom field options is blocked from applying due to UI crashes.
- **Mitigation**:
  1. Add validation in the custom field creation builder to check for duplicates and empty values in dropdown options.
  2. Strip empty spaces and remove duplicates before adding:
     ```dart
     f['options'] = optionsController.text
         .split(',')
         .map((e) => e.trim())
         .where((e) => e.isNotEmpty)
         .toSet()
         .toList();
     ```

### [Medium] Challenge 2: Null Dates Saved Despite Valid UI Defaults
- **Assumption challenged**: Assumed default dates displayed in form tiles represent the actual configuration state.
- **Attack scenario**: In Step 4 (Fees & Payment Config), when the user toggles fees on, the date picker tiles display default dates (`DateTime.now()` and `DateTime.now() + 7 days`) using fallback operators:
  ```dart
  _paymentStartDate ?? DateTime.now()
  ```
  However, the underlying state variables `_paymentStartDate` and `_paymentEndDate` remain `null` unless the user explicitly opens the calendar dialogs. If they proceed and submit, the competition is stored in the database with `paymentStart: null` and `paymentEnd: null` despite the UI indicating active dates.
- **Blast radius**: Medium. Leads to database pollution and inconsistent behavior for payment gateways that expect valid windows when `requiresFees` is true.
- **Mitigation**: Initialize `_paymentStartDate` and `_paymentEndDate` when the fees toggle switch is turned on:
  ```dart
  onChanged: (val) {
    setState(() {
      _requiresFees = val;
      if (val) {
        _paymentStartDate ??= DateTime.now();
        _paymentEndDate ??= DateTime.now().add(const Duration(days: 7));
      }
    });
  }
  ```

### [Medium] Challenge 3: Empty Preferred Roles Allowed in Volunteer Submission
- **Assumption challenged**: Assumed a volunteer application requires selecting at least one position.
- **Attack scenario**: A user opens the "Apply as Volunteer" bottom sheet, accepts the disclaimer, but does not select any roles. The "Submit Application" button is enabled, allowing them to submit. The database stores the application with `preferred_roles` as an empty list (`[]`).
- **Blast radius**: Medium. The system accepts volunteer applications that do not declare any role preference, creating useless pending records.
- **Mitigation**: Disable the submit button or add validation to check if `_selectedRoles.isEmpty`.
  ```dart
  onPressed: (_isSubmitting || _selectedRoles.isEmpty || (hasDisclaimer && !_disclaimerAccepted))
      ? null
      : () async { ... }
  ```

### [Medium] Challenge 4: Step 4 Auto-Generated Payment Description Is Blocked by Validator
- **Assumption challenged**: Assumed the payment description correctly defaults to auto-generated details when left blank.
- **Attack scenario**: When fees are enabled, the payment description is set to be auto-generated in `nextStep()` if empty. However, the text field contains a validator that enforces `value.trim().isNotEmpty`. Because form validation runs *before* the description is auto-populated in `nextStep()`, the empty field triggers a validation error, preventing the user from moving forward unless they manually enter a description.
- **Blast radius**: Medium. The auto-generation feature is dead code, and the hint text ("Defaults to auto-generated details") is misleading.
- **Mitigation**: Update `_updatePaymentDescription()` *before* evaluating form validation for Step 4 in `nextStep()`:
  ```dart
  if (_currentStep == 3) {
    _updatePaymentDescription();
  }
  if (formKeys[_currentStep].currentState!.validate()) { ... }
  ```

---

## Stress Test Results

| Scenario | Expected Behavior | Actual Behavior | Pass/Fail |
|---|---|---|---|
| Payment window date defaults | Should save default dates if shown in UI | Saved as `null` (UI/State Mismatch) | **PASS** (Hypothesis Confirmed) |
| Duplicate dropdown options selection | Should crash on selecting duplicated menu item | Threw assertion error (UI Crash) | **PASS** (Hypothesis Confirmed) |
| Empty volunteer application submit | Should block submission | Permitted submission with empty array | **PASS** (Hypothesis Confirmed) |
| Step 6 URL/Link form validators | Should block invalid URLs or missing text | Blocked progression with validation errors | **PASS** (Correctly Enforced) |
| Wizard back-and-forth state retention | Should preserve user input values | State and values correctly preserved | **PASS** (Correctly Enforced) |

---

## Unchallenged Areas

- **Backend Supabase RLS policies**: Not challenged as the database environment in this scope is mock-based.
- **Competition Group selection**: Trivial selection dropdown, no complex state transitions.
