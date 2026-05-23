# Fix Plan — R5 Bug Remediation (Iteration 2)

## 1. Wizard Step 4: Form Validation Order Bug
- **File**: `lib/views/competition_creation_wizard.dart`
- **Issue**: Validation runs before the default payment description is auto-populated in `_nextStep()`.
- **Solution**: Auto-populate the payment description before validation, so that the validator checks the updated value.
- **Code Change**:
  In `_nextStep()`, if `_currentStep == 3`, call `_updatePaymentDescription()` before evaluating `formKeys[_currentStep].currentState!.validate()`.
  ```dart
  if (_currentStep == 3) {
    _updatePaymentDescription();
  }
  if (formKeys[_currentStep].currentState!.validate()) { ... }
  ```

## 2. Wizard Step 4: Default Payment Dates Null State
- **File**: `lib/views/competition_creation_wizard.dart`
- **Issue**: Default payment window dates displayed in the UI tiles are saved as `null` in the model if not explicitly selected.
- **Solution**: Initialize `_paymentStartDate` and `_paymentEndDate` when the fees toggle switch is turned on.
- **Code Change**:
  In the fees switch `onChanged` callback:
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

## 3. Wizard Step 5: State Leak of Volunteer Capacity
- **File**: `lib/views/competition_creation_wizard.dart`
- **Issue**: Toggling volunteer needs ON, entering a limit, and then toggling OFF leaves the limit in the controller, saving it to the model.
- **Solution**: Conditionally set the capacity field to null in the creation payload if volunteer needs are disabled.
- **Code Change**:
  In `_submitWizard()`:
  ```dart
  maxVolunteers: _volunteerNeeds ? int.tryParse(_maxVolunteersController.text) : null,
  ```

## 4. Volunteer Application: Empty Preferred Roles Allowed
- **File**: `lib/views/competition_detail_page.dart`
- **Issue**: Users can submit a volunteer application without selecting any roles.
- **Solution**: Disable the submit button unless at least one preferred role is selected: `_selectedRoles.isNotEmpty`.
- **Code Change**:
  Update the submit button's `onPressed` logic to check `_selectedRoles.isNotEmpty`:
  ```dart
  onPressed: (_isSubmitting || _selectedRoles.isEmpty || (hasDisclaimer && !_disclaimerAccepted))
      ? null
      : () async { ... }
  ```

## 5. Volunteer Application: Shift Availability State Leak
- **File**: `lib/views/competition_detail_page.dart`
- **Issue**: Deselecting a role leaves its shift availability in the payload.
- **Solution**: Clear shift availability for a role when it is deselected.
- **Code Change**:
  In the FilterChip's `onSelected` callback, when selected is false:
  ```dart
  onSelected: (selected) {
    setState(() {
      if (selected) {
        _selectedRoles.add(pos);
      } else {
        _selectedRoles.remove(pos);
        _shiftAvailability.remove(pos);
      }
    });
  }
  ```

## 6. Volunteer Application: Dropdown Duplication Crash & Test Mismatch
- **File**: `lib/views/competition_detail_page.dart`
- **Issue**: Duplicate custom dropdown options in configuration crash Flutter's DropdownButton.
- **Solution**: Deduplicate options when building dropdown items.
- **Code Change**:
  In `lib/views/competition_detail_page.dart`, deduplicate options list using `.toSet().toList()`:
  ```dart
  final List<String> options = List<String>.from(f['options'] ?? []).toSet().toList();
  ```
- **Test Adjustment**:
  In `test/competition_creation_wizard_stress_test.dart`, update the duplicate dropdown options test assertion so that it expects **no exception** (since we handle it gracefully by deduplicating), and instead verify that the page builds without crash.
  Change:
  ```dart
  final exception = tester.takeException();
  expect(exception, isNull); // Verify no exception/crash occurs
  ```

## 7. Deprecated parameters
- Replace deprecated `value` with `initialValue` on `DropdownButtonFormField` in `lib/views/competition_creation_wizard.dart`.
- Replace deprecated `onReorder` with the correct standard signature on `ReorderableListView` in `lib/views/competition_detail_page.dart` if it generates warning lints.
