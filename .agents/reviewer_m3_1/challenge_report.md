# Adversarial Challenge Report — Competition Creation Wizard & Custom Fields (R5)

## Challenge Summary

**Overall risk assessment**: LOW

The overall risk is low because validation is strictly handled for essential data (like dates and fees) before transitions and final submission. The custom fields and volunteer preference ranking operate fully in-memory and are pushed to the database in single atomic transactions. However, there are minor logic holes around date bounds and payload structures that could allow inconsistent inputs.

---

## Challenges

### [Low] Challenge 1: Empty Date/Time Inputs and Incomplete Validation
- **Assumption challenged**: Dates/times chosen by the user are always fully valid.
- **Attack scenario**: In `CreateCompetitionWizard`, `_paymentStartDate` and `_paymentEndDate` default to `null` and are not required or validated when `requiresFees` is set to `true`, unless BOTH dates are non-null. If a user sets `_paymentEndDate` but leaves `_paymentStartDate` null, or vice versa, the wizard proceeds without validating the date ordering.
- **Blast radius**: Low data consistency issue. Null payment window dates are saved into the competition database, which might cause client-side errors when rendering the payment period or processing fees.
- **Mitigation**: If `requiresFees` is true, enforce that either both payment window dates are selected (and satisfy `paymentEnd >= paymentStart`), or both are null.

### [Low] Challenge 2: Duplicate Custom Field Identifiers
- **Assumption challenged**: Custom field labels/questions are unique.
- **Attack scenario**: Organizers can add multiple custom fields with identical names in Step 6 (e.g., two text fields both named "T-Shirt Size" or "Medical Conditions").
- **Blast radius**: Form data collision. In `VolunteerApplicationBottomSheet`, both text fields write their answers to `_customFieldAnswers[name]`. A volunteer answering the second field will silently overwrite their answer to the first field.
- **Mitigation**: Add a validation check in `CreateCompetitionWizard` to prevent adding custom fields with labels that are already present in the list.

### [Low] Challenge 3: Unhandled Input Types for Number Fields
- **Assumption challenged**: Custom field answers for fields of type `number` are always parsed or structured as numbers.
- **Attack scenario**: If a custom field is of type `number`, it is rendered as a `TextFormField` with `keyboardType: TextInputType.number`. On desktop, web browsers, or physical keyboard simulators, the user can still type arbitrary non-numeric text.
- **Blast radius**: The non-numeric text is sent to the backend under `custom_field_answers` (since no integer/double parsing is done on the value before saving).
- **Mitigation**: Add a numeric validator to `TextFormField` when the custom field type is `number`.

---

## Stress Test Results

- **Scenario 1**: Set Competition End Date before Competition Start Date.
  - *Expected behavior*: Wizard fails step 2 navigation and displays a SnackBar validation error.
  - *Actual behavior*: Blocked correctly. Displays: "End date must be on or after start date".
  - *Result*: **PASS**

- **Scenario 2**: Set Registration End Date after Competition Start Date.
  - *Expected behavior*: Wizard fails step 2 navigation and displays a SnackBar validation error.
  - *Actual behavior*: Blocked correctly. Displays: "Registration end date must be on or before competition start date".
  - *Result*: **PASS**

- **Scenario 3**: Submit volunteer application with disclaimer checkbox unchecked (when disclaimer text or link is active).
  - *Expected behavior*: Submit button is disabled and tapping it has no effect.
  - *Actual behavior*: Submit button is disabled (`onPressed` is `null`).
  - *Result*: **PASS**

- **Scenario 4**: Drag and drop reordering of volunteer roles.
  - *Expected behavior*: Order changes and updates state without throwing exceptions.
  - *Actual behavior*: Checked using the automated widget test. Preference ranks are updated correctly in-memory and in database payload.
  - *Result*: **PASS**

---

## Unchallenged Areas

- **Concurrency/Capacity Overrun** — The logic for checking capacity limits (`maxAthletes`, `maxVolunteers`) before accepting a new submission is executed backend/database-side via transactions or API checks, which is out of scope of these UI/model components.
