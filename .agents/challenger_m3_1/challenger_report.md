## Challenge Summary

**Overall risk assessment**: MEDIUM

Based on our empirical stress testing, the R5 Competition Creation Wizard and Custom Fields features are mostly functional, but exhibit critical state leak and input validation vulnerabilities. A state leak exists in Step 5 (Volunteer Setup) where maximum volunteers configuration is preserved and submitted even after volunteer needs are disabled. Additionally, the wizard validator does not restrict fee amounts to non-negative values, allowing negative fees to be submitted and stored in the database.

---

## Challenges

### [Medium] Challenge 1: State Leak in Step 5 (Volunteer Setup)

- **Assumption challenged**: Disabling volunteer needs via the switch will clear or ignore volunteer configuration parameters during submission.
- **Attack scenario**: A user enables volunteer needs, sets the total volunteer limit to `15`, then changes their mind and toggles volunteer needs off. They complete the wizard and submit the competition.
- **Blast radius**: The database is polluted with stale configurations (e.g. `max_volunteers = 15` and potential positions/shifts) for a competition that has `volunteer_needs = false`. This creates inconsistencies and potential UI rendering issues in parts of the app that look at `max_volunteers` without checking `volunteer_needs`.
- **Mitigation**: In the wizard submit handler `_submitCompetition()`, ensure `maxVolunteers`, `volunteerPositions`, and `volunteerShifts` are explicitly set to `null` if `_volunteerNeeds` is `false`.

### [High] Challenge 2: Negative Fee Amounts Accepted by Validator

- **Assumption challenged**: The fee amount field validator only allows logical, non-negative fee values.
- **Attack scenario**: A user enables registration fees, inputs a negative amount (e.g. `-20.00`), and submits the competition.
- **Blast radius**: The competition is successfully created with a negative fee. This can break downstream payment processing, transaction logs, and payout calculations, or even lead to exploit scenarios where users are paid to register.
- **Mitigation**: Update the `TextFormField` validator in Step 4 to ensure the parsed double is greater than or equal to 0:
  ```dart
  validator: (value) {
    if (!_requiresFees) return null;
    if (value == null || value.trim().isEmpty) return 'Provide valid fee amount';
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) return 'Provide valid fee amount';
    return null;
  }
  ```

---

## Stress Test Results

- **1. Confusing payment dates null state** → Confirm that default payment start/end dates are persisted and not null when fees are enabled → **PASS** (dates are initialized correctly on toggle)
- **2. Custom volunteer dropdown duplicate options** → Verify bottom sheet does not crash on duplicate dropdown options → **PASS** (handles duplicates gracefully via `.toSet().toList()`)
- **3. Empty volunteer application submission** → Verify that volunteer application cannot be submitted with empty preferred roles → **PASS** (Submit button is disabled under this condition)
- **4. Disclaimer text & URL validators** → Verify validation of disclaimer text and URL format on Step 6 → **PASS** (invalid URLs and empty fields are successfully blocked)
- **5. Back-and-forth wizard navigation** → Verify that changing subtype disciplines during wizard navigation updates correctly → **PASS** (subtype updates correctly and persists)
- **6. Step 5 Volunteer Setup State Leak** → Verify that disabling volunteer needs clears maximum volunteer limit → **FAIL** (confirmed leak: `maxVolunteers` remains `15` in the database)
- **7. Volunteer Application Deselected Role Shifts Cleanup** → Verify that deselecting a volunteer role clears its shifts → **PASS** (properly calls `_shiftAvailability.remove(pos)`)
- **8. Fee Config Validation & Non-Numeric/Negative Fee Amounts** → Verify rejection of non-numeric and negative fee amounts → **FAIL** (negative amounts are bypassed and accepted by the validator)
- **9. Date Constraints Validation & SnackBar Alerts** → Verify that date picker constraints trigger standard SnackBar alerts → **PASS** (validates end dates and registration end dates successfully)

---

## Unchallenged Areas

- **Supabase Authentication state mapping** — Out of scope.
- **Payment processing logic integration** — Out of scope (not yet implemented in R5).
