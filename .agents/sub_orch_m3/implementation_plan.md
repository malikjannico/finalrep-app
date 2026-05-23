# Implementation Plan: Milestone 3 - Competition Creation Wizard & Custom Fields (R5)

This document describes the steps for the Implementation Worker to complete R5.

## 1. Update Competition Model
File: `lib/models/competition.dart`

Add the following fields:
* `registrationStart` (DateTime) - defaults to `startDate` if null.
* `registrationEnd` (DateTime) - defaults to `endDate` if null.
* `requiresFees` (bool) - defaults to `false`.
* `feeAmount` (double?)
* `feeCurrency` (String?)
* `bankDetails` (String?)
* `paymentDescription` (String?)
* `paymentStart` (DateTime?)
* `paymentEnd` (DateTime?)
* `registrationMode` (String) - defaults to `'fcfs'`. Must be `'fcfs'` or `'approval'`.
* `websiteUrl` (String?)
* `ticketShopUrl` (String?)
* `socials` (Map<String, String>?)
* `maxAthletes` (int?)
* `maxAthletesPerGroup` (Map<String, int>?)
* `maxVolunteers` (int?)
* `maxVolunteersPerPosition` (Map<String, int>?)
* `enableWaitlist` (bool) - defaults to `false`.
* `volunteerNeeds` (bool) - defaults to `false`.
* `volunteerPositions` (List<String>?)
* `volunteerShifts` (Map<String, List<String>>?)
* `customAthleteFields` (List<Map<String, dynamic>>?)
* `customVolunteerFields` (List<Map<String, dynamic>>?)
* `disclaimerText` (String?)
* `disclaimerUrl` (String?)
* `disclaimerType` (String?) - 'text', 'link', 'both', or null.
* `bannerSafeZoneGuide` (bool) - defaults to `false`.

Update the constructor:
* Include all the new fields.
* Add initializer assertions/fallbacks:
  ```dart
  DateTime? registrationStart,
  DateTime? registrationEnd,
  // other fields...
  ```
  with initializer list:
  ```dart
  this.registrationStart = registrationStart ?? startDate,
  this.registrationEnd = registrationEnd ?? endDate;
  ```

Update `fromJson` and `toJson`:
* Read/write all fields using appropriate JSON keys (e.g. `registration_start`, `requires_fees`, `fee_amount`, etc.).
* Handle double conversion from num safely.
* Cast lists and maps appropriately (e.g. `Map<String, String>.from(...)`, `List<Map<String, dynamic>>.from(...)`, etc.).

Implement a `copyWith` helper method on the `Competition` model:
```dart
Competition copyWith({
  String? id,
  String? title,
  String? description,
  DateTime? startDate,
  DateTime? endDate,
  String? location,
  String? sportType,
  String? sportSubtype,
  String? compGroupName,
  String? status,
  String? area,
  String? country,
  String? city,
  String? titleImageUrl,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? associationId,
  String? competitionGroupId,
  List<String>? athleteGroupIds,
  String? rulebookUrl,
  DateTime? registrationStart,
  DateTime? registrationEnd,
  bool? requiresFees,
  double? feeAmount,
  String? feeCurrency,
  String? bankDetails,
  String? paymentDescription,
  DateTime? paymentStart,
  DateTime? paymentEnd,
  String? registrationMode,
  String? websiteUrl,
  String? ticketShopUrl,
  Map<String, String>? socials,
  int? maxAthletes,
  Map<String, int>? maxAthletesPerGroup,
  int? maxVolunteers,
  Map<String, int>? maxVolunteersPerPosition,
  bool? enableWaitlist,
  bool? volunteerNeeds,
  List<String>? volunteerPositions,
  Map<String, List<String>>? volunteerShifts,
  List<Map<String, dynamic>>? customAthleteFields,
  List<Map<String, dynamic>>? customVolunteerFields,
  String? disclaimerText,
  String? disclaimerUrl,
  String? disclaimerType,
  bool? bannerSafeZoneGuide,
}) {
  return Competition(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    location: location ?? this.location,
    sportType: sportType ?? this.sportType,
    sportSubtype: sportSubtype ?? this.sportSubtype,
    compGroupName: compGroupName ?? this.compGroupName,
    status: status ?? this.status,
    area: area ?? this.area,
    country: country ?? this.country,
    city: city ?? this.city,
    titleImageUrl: titleImageUrl ?? this.titleImageUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    associationId: associationId ?? this.associationId,
    competitionGroupId: competitionGroupId ?? this.competitionGroupId,
    athleteGroupIds: athleteGroupIds ?? this.athleteGroupIds,
    rulebookUrl: rulebookUrl ?? this.rulebookUrl,
    registrationStart: registrationStart ?? this.registrationStart,
    registrationEnd: registrationEnd ?? this.registrationEnd,
    requiresFees: requiresFees ?? this.requiresFees,
    feeAmount: feeAmount ?? this.feeAmount,
    feeCurrency: feeCurrency ?? this.feeCurrency,
    bankDetails: bankDetails ?? this.bankDetails,
    paymentDescription: paymentDescription ?? this.paymentDescription,
    paymentStart: paymentStart ?? this.paymentStart,
    paymentEnd: paymentEnd ?? this.paymentEnd,
    registrationMode: registrationMode ?? this.registrationMode,
    websiteUrl: websiteUrl ?? this.websiteUrl,
    ticketShopUrl: ticketShopUrl ?? this.ticketShopUrl,
    socials: socials ?? this.socials,
    maxAthletes: maxAthletes ?? this.maxAthletes,
    maxAthletesPerGroup: maxAthletesPerGroup ?? this.maxAthletesPerGroup,
    maxVolunteers: maxVolunteers ?? this.maxVolunteers,
    maxVolunteersPerPosition: maxVolunteersPerPosition ?? this.maxVolunteersPerPosition,
    enableWaitlist: enableWaitlist ?? this.enableWaitlist,
    volunteerNeeds: volunteerNeeds ?? this.volunteerNeeds,
    volunteerPositions: volunteerPositions ?? this.volunteerPositions,
    volunteerShifts: volunteerShifts ?? this.volunteerShifts,
    customAthleteFields: customAthleteFields ?? this.customAthleteFields,
    customVolunteerFields: customVolunteerFields ?? this.customVolunteerFields,
    disclaimerText: disclaimerText ?? this.disclaimerText,
    disclaimerUrl: disclaimerUrl ?? this.disclaimerUrl,
    disclaimerType: disclaimerType ?? this.disclaimerType,
    bannerSafeZoneGuide: bannerSafeZoneGuide ?? this.bannerSafeZoneGuide,
  );
}
```

## 2. Update CompetitionProvider
File: `lib/providers/competition_provider.dart`

1. Update the `createCompetition` cloning logic (around lines 749-770) to preserve all R5 fields by using `competition.copyWith(...)` or copying the fields manually in the `Competition` constructor call.
2. Implement `submitVolunteerApplication`:
   ```dart
   Future<bool> submitVolunteerApplication({
     required String competitionId,
     required String userId,
     required List<String> preferredRoles,
     required Map<String, List<String>> shiftAvailability,
     required Map<String, dynamic> customFieldAnswers,
     required bool disclaimerAccepted,
   }) async {
     _isLoading = true;
     _errorMessage = null;
     notifyListeners();
     try {
       final payload = {
         'id': 'vol-app-${DateTime.now().millisecondsSinceEpoch}',
         'competition_id': competitionId,
         'user_id': userId,
         'preferred_roles': preferredRoles,
         'shift_availability': shiftAvailability,
         'custom_field_answers': customFieldAnswers,
         'disclaimer_accepted': disclaimerAccepted,
         'status': 'pending',
         'created_at': DateTime.now().toUtc().toIso8601String(),
       };
       
       await _repository.client.from('volunteer_applications').insert(payload);
       return true;
     } catch (e) {
       _errorMessage = e.toString();
       debugPrint('Error submitting volunteer application: $e');
       return false;
     } finally {
       _isLoading = false;
       notifyListeners();
     }
   }
   ```

## 3. Create Competition Stepper Wizard
File: `lib/views/competition_creation_wizard.dart`

Implement a 6-step form wizard using a Scrollable body:
* **Step 1: General Info & Subtypes**
  - TextFields for Title, Description, Location/Venue, Area, Country, City.
  - Verification check: A button to "Verify Location" simulating geocoding coordinates (setting lat/long values).
  - Selectors for Sport Type (locked to 'Streetlifting') and Sport Subtype ('Modern' or 'Classic').
  - Image URL field and "Banner Safe Zone Guide" toggle switch.
* **Step 2: Dates & Deadlines**
  - Datetime Pickers for Competition Start/End, and Registration Start/End.
  - Validation:
    - End Date >= Start Date
    - Registration End <= Start Date
    - Registration End >= Registration Start
* **Step 3: Registration Mode & Capacity Limits**
  - Toggle between FCFS (`fcfs`) vs Manual Approval (`approval`).
  - Total athlete capacity (number field) and Toggle for Waitlist.
  - Category Capacity Editor: list of athlete groups (e.g. by weight class/division) with limits.
* **Step 4: Fees & Payment Config**
  - Requires Fees switch. If enabled, show:
    - Fee amount (numeric field)
    - Currency (dropdown: EUR, USD, GBP, etc.)
    - IBAN/Bank Details field
    - Payment Description (defaults to auto-generated string `<=140` characters containing competition and user references)
    - Payment Window Pickers (Start/End dates).
* **Step 5: Volunteer Setup**
  - Volunteer Needs switch. If enabled, show:
    - Position Chips Input: add roles (rendered as Chips with remove icons).
    - Shift period manager for each role (e.g. morning, afternoon shifts).
    - Max Volunteer Limits (total count or per role).
* **Step 6: Disclaimers & Custom Fields**
  - Disclaimer Type (None, Text, Link, Both).
  - Disclaimer Text and URL fields (validated if active).
  - Custom Athlete Fields & Custom Volunteer Fields builder cards. Lets organizers define custom questions with field type (Text, Boolean checkbox, Dropdown select).
* **Step Indicators**:
  - Horizontal progress bar with numbers/labels (Step 1, Step 2, etc.) at the top.
* **Compatibility Key bindings**:
  - Assign key values to match test expectations if any exist, e.g. `Key('comp_name_field')` for name, `Key('comp_fees_toggle')` for fees switch, `Key('comp_waitlist_toggle')` for waitlist switch, `Key('comp_disclaimer')` for disclaimer acceptance, and `Key('comp_next_btn')` for the wizard navigation button to proceed or submit.

## 4. Volunteer Application UI
File: `lib/views/competition_detail_page.dart` (or new page/dialog)

* If `volunteerNeeds` is true, the "Apply as Volunteer" button should open the volunteer application flow (as a bottom sheet or new page).
* **Volunteer Application Flow UI**:
  - Checkboxes/FilterChips for roles from `competition.volunteerPositions`.
  - Reorderable list (`ReorderableListView`) of the selected roles with drag-and-drop handles (`Icons.drag_handle`) to define the preference priority order.
  - Shift availability selectors per selected role.
  - Dynamic Custom fields generation based on `competition.customVolunteerFields` (Text, Number, Dropdown, Checkbox inputs).
  - Terms/Disclaimer checkbox (if `disclaimerType != null`).
  - Submission Guard: The "Submit Application" button must remain disabled until the disclaimer checkbox is checked. On tap, call `CompetitionProvider.submitVolunteerApplication(...)` and close the form.

## 5. E2E Test Harness and Routing Updates
File: `test/e2e/e2e_test_harness.dart`

1. Update `InMemoryDatabase`:
   - Add `final List<Map<String, dynamic>> volunteerApplications = [];`
   - In `reset()`, add `volunteerApplications.clear();`
   - In `getTable()`, return `volunteerApplications` when query targets `'volunteer_applications'`.
2. In `MaterialApp` onGenerateRoute route bindings:
   - Import the new `CreateCompetitionWizard` widget.
   - For path `/competition/create`, return `MaterialPageRoute` builder targeting `CreateCompetitionWizard`.

## 6. Verification Tests
File: `test/competition_creation_wizard_test.dart`

Write unit and widget tests:
1. **Unit tests**:
   - Verify model JSON serialization & deserialization for R5 fields.
   - Verify date validation logic and date helper fallbacks.
   - Verify `copyWith` preserves nested lists/maps correctly.
   - Verify `submitVolunteerApplication` in `CompetitionProvider` makes the correct Supabase client insert call.
2. **Widget tests**:
   - Pump `CreateCompetitionWizard`. Test step navigation and field validation (e.g. empty name fails, invalid dates fail).
   - Test conditional fees panel visibility toggles.
   - Pump Volunteer Application form. Check multi-role checkboxes, verify role items appear in `ReorderableListView`.
   - Simulate drag-and-drop gesture in `ReorderableListView` to reorder role preference list.
   - Verify disclaimer checkbox guards form submission.
   - Click submit and verify the correct database payload is triggered.
