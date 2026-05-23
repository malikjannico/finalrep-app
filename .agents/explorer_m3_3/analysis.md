# M3 R5 Analysis Report: Competition Creation Wizard & Custom Fields

This report analyzes the requirements for **R5 (Competition Creation & Custom Fields)** and proposes the implementation design for the `Competition` model, `CompetitionProvider`, the custom multi-step creation wizard, the volunteer application flow, routing integration, and testing strategy.

---

## 1. Competition Model Enhancements

To support the R5 requirements, the `Competition` model (`lib/models/competition.dart`) must be updated with fields for scheduling, payment settings, participant limits, volunteer configurations, custom field definitions, disclaimers, and organizer banner guides.

### Dart Field Signatures
The following fields will be added to the `Competition` class:

```dart
  // Scheduling & Deadlines
  final DateTime registrationStart;
  final DateTime registrationEnd;

  // Payments & Fees
  final bool requiresFees;
  final double? feeAmount;
  final String? feeCurrency;
  final String? bankDetails;
  final String? paymentDescription;
  final DateTime? paymentStart;
  final DateTime? paymentEnd;

  // Registration Rules & Limits
  final String registrationMode; // 'fcfs' (First-Come-First-Serve) or 'approval'
  final int? maxAthletes;
  final Map<String, int>? maxAthletesPerGroup; // e.g., {'Modern-Male-80kg': 10}
  final bool enableWaitlist;

  // Volunteer Needs & Shifts
  final bool volunteerNeeds;
  final List<String>? volunteerPositions; // e.g., ['Referee', 'Loader', 'Speaker']
  final Map<String, List<String>>? volunteerShifts; // e.g., {'Referee': ['Morning Shift', 'Afternoon Shift']}
  final int? maxVolunteers;
  final Map<String, int>? maxVolunteersPerPosition; // e.g., {'Referee': 3, 'Loader': 5}

  // Dynamic Custom Fields
  final List<Map<String, dynamic>>? customAthleteFields;
  final List<Map<String, dynamic>>? customVolunteerFields;

  // Disclaimers & Terms
  final String? disclaimerText;
  final String? disclaimerUrl;
  final String? disclaimerType; // 'text', 'link', 'both', or null

  // UI Guides
  final bool bannerSafeZoneGuide;
```

### Constructor Updates
The new parameters will be added to the constructor with sensible defaults where applicable:

```dart
  Competition({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    this.sportType = 'Streetlifting',
    required this.sportSubtype,
    this.compGroupName,
    this.status = 'upcoming',
    this.area,
    this.country,
    this.city,
    this.titleImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.associationId,
    this.competitionGroupId,
    this.athleteGroupIds,
    this.rulebookUrl,
    
    // New R5 Fields
    required this.registrationStart,
    required this.registrationEnd,
    this.requiresFees = false,
    this.feeAmount,
    this.feeCurrency,
    this.bankDetails,
    this.paymentDescription,
    this.paymentStart,
    this.paymentEnd,
    this.registrationMode = 'fcfs',
    this.maxAthletes,
    this.maxAthletesPerGroup,
    this.enableWaitlist = false,
    this.volunteerNeeds = false,
    this.volunteerPositions,
    this.volunteerShifts,
    this.maxVolunteers,
    this.maxVolunteersPerPosition,
    this.customAthleteFields,
    this.customVolunteerFields,
    this.disclaimerText,
    this.disclaimerUrl,
    this.disclaimerType,
    this.bannerSafeZoneGuide = false,
  });
```

### JSON Deserialization (`fromJson`)
The factory method will safely extract and cast values, using safe conversion for numeric values (`num` to `double`) and converting maps or lists from JSON structure:

```dart
      registrationStart: json['registration_start'] != null
          ? DateTime.parse(json['registration_start'] as String).toLocal()
          : DateTime.parse(json['start_date'] as String).toLocal().subtract(const Duration(days: 30)),
      registrationEnd: json['registration_end'] != null
          ? DateTime.parse(json['registration_end'] as String).toLocal()
          : DateTime.parse(json['start_date'] as String).toLocal().subtract(const Duration(days: 1)),
      requiresFees: json['requires_fees'] as bool? ?? false,
      feeAmount: (json['fee_amount'] as num?)?.toDouble(),
      feeCurrency: json['fee_currency'] as String?,
      bankDetails: json['bank_details'] as String?,
      paymentDescription: json['payment_description'] as String?,
      paymentStart: json['payment_start'] != null
          ? DateTime.parse(json['payment_start'] as String).toLocal()
          : null,
      paymentEnd: json['payment_end'] != null
          ? DateTime.parse(json['payment_end'] as String).toLocal()
          : null,
      registrationMode: json['registration_mode'] as String? ?? 'fcfs',
      maxAthletes: json['max_athletes'] as int?,
      maxAthletesPerGroup: json['max_athletes_per_group'] != null
          ? Map<String, int>.from(json['max_athletes_per_group'] as Map)
          : null,
      enableWaitlist: json['enable_waitlist'] as bool? ?? false,
      volunteerNeeds: json['volunteer_needs'] as bool? ?? false,
      volunteerPositions: json['volunteer_positions'] != null
          ? List<String>.from(json['volunteer_positions'] as List)
          : null,
      volunteerShifts: json['volunteer_shifts'] != null
          ? (json['volunteer_shifts'] as Map).map(
              (key, val) => MapEntry(key as String, List<String>.from(val as List)),
            )
          : null,
      maxVolunteers: json['max_volunteers'] as int?,
      maxVolunteersPerPosition: json['max_volunteers_per_position'] != null
          ? Map<String, int>.from(json['max_volunteers_per_position'] as Map)
          : null,
      customAthleteFields: json['custom_athlete_fields'] != null
          ? (json['custom_athlete_fields'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
          : null,
      customVolunteerFields: json['custom_volunteer_fields'] != null
          ? (json['custom_volunteer_fields'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
          : null,
      disclaimerText: json['disclaimer_text'] as String?,
      disclaimerUrl: json['disclaimer_url'] as String?,
      disclaimerType: json['disclaimer_type'] as String?,
      bannerSafeZoneGuide: json['banner_safe_zone_guide'] as bool? ?? false,
```

### JSON Serialization (`toJson`)
```dart
      'registration_start': registrationStart.toUtc().toIso8601String(),
      'registration_end': registrationEnd.toUtc().toIso8601String(),
      'requires_fees': requiresFees,
      if (feeAmount != null) 'fee_amount': feeAmount,
      if (feeCurrency != null) 'fee_currency': feeCurrency,
      if (bankDetails != null) 'bank_details': bankDetails,
      if (paymentDescription != null) 'payment_description': paymentDescription,
      if (paymentStart != null) 'payment_start': paymentStart?.toUtc().toIso8601String(),
      if (paymentEnd != null) 'payment_end': paymentEnd?.toUtc().toIso8601String(),
      'registration_mode': registrationMode,
      if (maxAthletes != null) 'max_athletes': maxAthletes,
      if (maxAthletesPerGroup != null) 'max_athletes_per_group': maxAthletesPerGroup,
      'enable_waitlist': enableWaitlist,
      'volunteer_needs': volunteerNeeds,
      if (volunteerPositions != null) 'volunteer_positions': volunteerPositions,
      if (volunteerShifts != null) 'volunteer_shifts': volunteerShifts,
      if (maxVolunteers != null) 'max_volunteers': maxVolunteers,
      if (maxVolunteersPerPosition != null) 'max_volunteers_per_position': maxVolunteersPerPosition,
      if (customAthleteFields != null) 'custom_athlete_fields': customAthleteFields,
      if (customVolunteerFields != null) 'custom_volunteer_fields': customVolunteerFields,
      if (disclaimerText != null) 'disclaimer_text': disclaimerText,
      if (disclaimerUrl != null) 'disclaimer_url': disclaimerUrl,
      if (disclaimerType != null) 'disclaimer_type': disclaimerType,
      'banner_safe_zone_guide': bannerSafeZoneGuide,
```

### Helper & Validation Utilities
We recommend adding helper properties to ensure correct client-side logic:
- `bool get isRegistrationOpen => DateTime.now().isAfter(registrationStart) && DateTime.now().isBefore(registrationEnd);`
- `bool get requiresPaymentWindow => paymentStart != null && paymentEnd != null;`
- `bool get hasDisclaimer => disclaimerType != null && disclaimerType != 'none';`

---

## 2. CompetitionProvider Logic Refinement

The `CompetitionProvider` must preserve the new R5 properties during competition creation and support volunteer application submissions.

### Rebuilding with Inherited Properties
In `createCompetition(Competition competition)`:
The provider clones the input object to fill in association rulebooks and athlete groups. This cloning constructor call (currently at lines 749-770) **must be updated to forward all the new R5 parameters**:

```dart
          compToCreate = Competition(
            id: competition.id,
            title: competition.title,
            description: competition.description,
            startDate: competition.startDate,
            endDate: competition.endDate,
            location: competition.location,
            sportType: competition.sportType,
            sportSubtype: competition.sportSubtype,
            compGroupName: competition.compGroupName,
            status: competition.status,
            area: competition.area,
            country: competition.country,
            city: competition.city,
            titleImageUrl: competition.titleImageUrl,
            createdAt: competition.createdAt,
            updatedAt: competition.updatedAt,
            associationId: competition.associationId,
            competitionGroupId: competition.competitionGroupId,
            athleteGroupIds: athleteGroupIds,
            rulebookUrl: rulebookUrl,
            // Forward M3 R5 parameters
            registrationStart: competition.registrationStart,
            registrationEnd: competition.registrationEnd,
            requiresFees: competition.requiresFees,
            feeAmount: competition.feeAmount,
            feeCurrency: competition.feeCurrency,
            bankDetails: competition.bankDetails,
            paymentDescription: competition.paymentDescription,
            paymentStart: competition.paymentStart,
            paymentEnd: competition.paymentEnd,
            registrationMode: competition.registrationMode,
            maxAthletes: competition.maxAthletes,
            maxAthletesPerGroup: competition.maxAthletesPerGroup,
            enableWaitlist: competition.enableWaitlist,
            volunteerNeeds: competition.volunteerNeeds,
            volunteerPositions: competition.volunteerPositions,
            volunteerShifts: competition.volunteerShifts,
            maxVolunteers: competition.maxVolunteers,
            maxVolunteersPerPosition: competition.maxVolunteersPerPosition,
            customAthleteFields: competition.customAthleteFields,
            customVolunteerFields: competition.customVolunteerFields,
            disclaimerText: competition.disclaimerText,
            disclaimerUrl: competition.disclaimerUrl,
            disclaimerType: competition.disclaimerType,
            bannerSafeZoneGuide: competition.bannerSafeZoneGuide,
          );
```

### Volunteer Application Submission API
The provider will add a method to register volunteer profiles with positional and shift preferences, alongside custom field values:

```dart
  Future<bool> submitVolunteerApplication({
    required String competitionId,
    required String userId,
    required List<String> rolePreferences,
    required Map<String, List<String>> shiftPreferences,
    required Map<String, dynamic> customFieldResponses,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'id': 'vol-app-${DateTime.now().millisecondsSinceEpoch}',
        'competition_id': competitionId,
        'user_id': userId,
        'status': 'pending',
        'role_preferences': rolePreferences,
        'shift_preferences': shiftPreferences,
        'custom_field_responses': customFieldResponses,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _repository.client
          .from('volunteer_applications')
          .insert(payload);
          
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

---

## 3. CreateCompetitionWizard UI Architecture

The creation wizard will be placed at `lib/views/competition_creation_wizard.dart`. Following the established project style of `AssociationCreationPage`, we will implement a custom wizard using separate forms per step, a progress stepper indicator, and structured navigation.

### Steps Layout Configuration

```
┌────────────────────────────────────────────────────────┐
│ [<-] Create Competition                                 │
├────────────────────────────────────────────────────────┤
│ (1) Basic  ─── (2) Dates  ─── (3) Limits  ─── (4) Fees ...│
├────────────────────────────────────────────────────────┤
│                                                        │
│                  STEP CONTENT SCROLL                   │
│                                                        │
├────────────────────────────────────────────────────────┤
│ [ BACK ]                                    [ NEXT ]   │
└────────────────────────────────────────────────────────┘
```

#### Step 1: Basic Info & Metadata
- **Fields**: Title, Description, Sport Type (default 'Streetlifting'), Sport Subtype ('Modern' or 'Classic'), Association dropdown (fetched from provider), Group Name (optional).
- **Location Fields**: Complete Address string, plus parsed inputs for Area (e.g. Europe), Country, and City to feed the map search filters.
- **Rulebook URL & Title Image URL**: text inputs with URL regex validation.
- **Banner Safe Zone Guide**: A switch to toggle visual guides when uploading imagery, checking safe limits for texts.

#### Step 2: Scheduling & Timelines
- **Fields**:
  - Competition Start Date + Time (Picker)
  - Competition End Date + Time (Picker)
  - Registration Start Date + Time (Picker)
  - Registration End Date + Time (Picker)
- **Validation**:
  - `endDate` >= `startDate`
  - `registrationEnd` <= `startDate`
  - `registrationEnd` >= `registrationStart`
  - Registration periods cannot overlap with the meet times.

#### Step 3: Access Mode & Athlete Capacity
- **Fields**:
  - Registration Mode: Toggle buttons or SegmentedControl for **First-Come-First-Serve (FCFS)** vs **Manual Approval**.
  - Capacity Limit: Switch to enable max athletes count + numerical input field.
  - Enable Waitlist: Switch (only available if capacity limit is set).
  - Max Athletes Per Category: Dynamic key-value inputs to partition slot limits (e.g., limits per weight class or gender division).

#### Step 4: Payments & Fees Configuration
- **Fields**:
  - Requires Fees: Switch.
  - *If enabled, display*:
    - Fee Amount (Numeric input)
    - Currency Dropdown (EUR, USD, etc.)
    - Bank Account Details / Payment Provider IBAN (Textarea, validated format)
    - Description & Invoice details
    - Payment Start Date / Payment End Date (validating window limits relative to registration).

#### Step 5: Volunteer Settings & Shifts
- **Fields**:
  - Needs Volunteers: Switch.
  - *If enabled, display*:
    - Positions: Input box + Wrap containing chips of active roles (e.g. Referee, Loader, Speaker, Spotter, Scorekeeper). Clicking 'x' on a chip removes it.
    - Limits: Optional input for maximum total volunteers, or per-position limits.
    - Shifts Builder: An expandable list per position allowing the builder to add shift tags (e.g. "Morning", "Afternoon", "Full Day").

#### Step 6: Disclaimers & Custom Fields Creation
- **Fields**:
  - Disclaimer Type: Dropdown ('none', 'text', 'link', 'both').
  - Disclaimer Content: Multiline Text input / URL link input (validated based on type).
  - Custom Athlete Fields Builder: Click "Add Custom Field" which adds a widget card defining:
    - Label (e.g. "T-Shirt Size")
    - Type Dropdown ("Text", "Number", "Dropdown", "Boolean")
    - Required switch
    - Options list (for dropdown types - comma-separated)
  - Custom Volunteer Fields Builder: Same structure as above.

---

## 4. Volunteer Application Preference Interface & Submission Flow

When a user clicks "Apply as Volunteer" on `CompetitionDetailPage`, they will open a `VolunteerApplicationSheet` bottom dialog:

```
┌────────────────────────────────────────────────────────┐
│ Apply to Volunteer                                 [X] │
├────────────────────────────────────────────────────────┤
│ Select roles you want to apply for:                    │
│ [X] Referee    [ ] Loader     [X] Speaker              │
│                                                        │
│ Arrange preferences (drag to order):                   │
│ =====================================                  │
│ =: 1st Choice: Referee                                 │
│ =: 2nd Choice: Speaker                                 │
│ =====================================                  │
│                                                        │
│ Preferences & Shifts:                                  │
│ - Referee Shifts: [X] Morning   [ ] Afternoon          │
│ - Speaker Shifts: [X] Full Day                         │
│                                                        │
│ Dynamic Fields:                                        │
│ Years of experience: [ 3         ]                     │
│                                                        │
│ Disclaimer: [X] I agree to the volunteer release terms │
├────────────────────────────────────────────────────────┤
│                                        [ SUBMIT APP ]  │
└────────────────────────────────────────────────────────┘
```

### Components and Widgets
1. **Role Select Checkboxes / FilterChips**:
   Populated from `competition.volunteerPositions`.
2. **Reorderable Preference List**:
   Uses Flutter's `ReorderableListView` containing the subset of selected roles. Each item features a leading handle icon `Icons.drag_handle`. Reordering updates a list tracking role priority:
   ```dart
   onReorder: (oldIndex, newIndex) {
     setState(() {
       if (newIndex > oldIndex) newIndex -= 1;
       final item = selectedRoles.removeAt(oldIndex);
       selectedRoles.insert(newIndex, item);
     });
   }
   ```
3. **Shift Selectors**:
   Underneath the reordered items, display nested checkboxes or segmented controls mapping shift choices (retrieved from `competition.volunteerShifts`) per selected position.
4. **Dynamic Custom Form Fields**:
   Constructed iteratively by checking `competition.customVolunteerFields`:
   - If type is `'text'`: `TextFormField`
   - If type is `'number'`: `TextFormField(keyboardType: TextInputType.number)`
   - If type is `'select'`: `DropdownButtonFormField`
   - If type is `'boolean'`: `SwitchListTile`
5. **Disclaimer Checkbox**:
   Rendered if `competition.disclaimerType` indicates terms exist. Checking it sets a boolean flag that enables the "Submit" action button.

---

## 5. Router Integration Strategy

To transition from mock routes to the production layout while maintaining test compliance:

1. **Production Routing Setup**:
   Add Route mappings inside `lib/main.dart` or a routing class. Update the navigation in `lib/views/search_feed_page.dart` (or from the user profile where organizers create meets) to navigate to the new wizard page:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(builder: (context) => const CreateCompetitionWizard()),
   );
   ```

2. **Harness & Mock Compatibility**:
   In `test/e2e/e2e_test_harness.dart` under the route interceptor, replace the mock view:
   ```dart
   if (settings.name == '/competition/create') {
     return MaterialPageRoute(builder: (_) => const CreateCompetitionWizard());
   }
   ```
   *Note on Test Stability*: If future E2E tests are added that expect the mock keys, the new `CreateCompetitionWizard` must provide appropriate key bindings or the test harness will need to point to a test wrapper. For maximum flexibility, the wizard fields will directly utilize test keys (e.g. `Key('comp_name_field')` for the title text field, `Key('comp_fees_toggle')` for the payment switch, `Key('comp_waitlist_toggle')` for waitlist, `Key('comp_disclaimer')` for the checkbox, and `Key('comp_next_btn')` for progress button).

---

## 6. Verification and Testing Plan

Tests will be added under `test/competition_creation_wizard_test.dart` to cover both local unit calculations and full UI step navigation:

### Unit Test Cases
1. **Model Deserialization**:
   - Verify parsing of custom fields configurations.
   - Verify parsing of volunteer shifts maps.
   - Check dates fallback calculations when registration dates are not specified in the database.
2. **Provider Action Propagation**:
   - Verify `createCompetition` preserves properties throughout rulebook and group inheritance.
   - Verify validations fail when creating a competition with registration start dates in the past or after the start date of the tournament.
   - Test mock insertions into the database for volunteer applications:
     ```dart
     final success = await provider.submitVolunteerApplication(
       competitionId: 'comp-1',
       userId: 'user-1',
       rolePreferences: ['Referee', 'Speaker'],
       shiftPreferences: {'Referee': ['Morning Shift']},
       customFieldResponses: {'Experience': '2 years'},
     );
     expect(success, isTrue);
     ```

### Widget Test Cases
1. **Wizard Form Validation and Navigation**:
   - Ensure the user cannot proceed to Step 2 if Step 1 form fields (e.g., Title, Location) fail validation.
   - Verify warning displays and "NEXT" is blocked if `registrationEnd` is configured after `startDate`.
2. **Dynamic Conditional Visibility**:
   - Enable "Requires Fees" -> assert IBAN, currency, and amount inputs are displayed.
   - Disable "Requires Fees" -> assert payment forms are hidden.
3. **Chip Input and Shift Builder Verification**:
   - Select positions and verify they appear as chips.
   - Enter volunteer shifts and check they are bound to the correct position maps.
4. **Reorderable Drag-and-Drop Tests**:
   - Render the volunteer bottom sheet.
   - Simulate role selection and arrange them using gesture simulations (drag from index 1 to 0).
   - Click submit and verify the resulting preference payload is correctly structured as `['Referee', 'Speaker']`.
5. **Disclaimer Guarding**:
   - Attempt submission without checking the disclaimer -> verify validation warning and submission prevention.
   - Check the box -> verify successful submission and pop response.
