# Analysis Report: Competition Creation Wizard & Custom Fields (R5)

## Executive Summary
This report defines the architecture and design strategy for implementing Milestone 3, R5 (Competition Creation & Custom Fields). It covers data model additions, state management provider changes, a step-by-step wizard UI design, the volunteer preference selection flow, routing integration, and verification test cases.

---

## 1. Competition Model Extensions (R5)
To support rich competition registration and configurations, the `Competition` model in `lib/models/competition.dart` must be expanded. 

### Recommended Dart Field Signatures
Add the following fields to the `Competition` class:

```dart
  // Registration Dates
  final DateTime? registrationStart;
  final DateTime? registrationEnd;

  // Fee Details
  final bool requiresFees;
  final double? feeAmount;
  final String? feeCurrency;
  final String? bankDetails;
  final String? paymentDescription;
  final DateTime? paymentStart;
  final DateTime? paymentEnd;

  // Registration Mode
  final String registrationMode; // 'fcfs' or 'approval'

  // Links
  final String? websiteUrl;
  final String? ticketShopUrl;
  final Map<String, String>? socials; // Platform name -> URL/handle

  // Athlete limits
  final int? maxAthletes;
  final Map<String, int>? maxAthletesPerGroup; // AthleteGroupId -> limit

  // Volunteer settings
  final int? maxVolunteers;
  final Map<String, int>? maxVolunteersPerPosition; // Position -> limit
  final bool enableWaitlist;
  final bool volunteerNeeds;
  final List<String>? volunteerPositions; // Available roles
  final Map<String, List<String>>? volunteerShifts; // Position -> list of shift names/ranges

  // Custom Fields (Text or dropdown answers)
  final List<Map<String, dynamic>>? customAthleteFields;
  final List<Map<String, dynamic>>? customVolunteerFields;

  // Disclaimers
  final String? disclaimerText;
  final String? disclaimerUrl;
  final String? disclaimerType; // 'text', 'link', 'both', or null

  // Media parameters
  final bool bannerSafeZoneGuide;
```

### Constructor Updates
The constructor must support these parameters, defaulting booleans to `false` and registration mode to `'fcfs'` to prevent breaking existing tests and fixtures:

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
    this.registrationStart,
    this.registrationEnd,
    this.requiresFees = false,
    this.feeAmount,
    this.feeCurrency,
    this.bankDetails,
    this.paymentDescription,
    this.paymentStart,
    this.paymentEnd,
    this.registrationMode = 'fcfs',
    this.websiteUrl,
    this.ticketShopUrl,
    this.socials,
    this.maxAthletes,
    this.maxAthletesPerGroup,
    this.maxVolunteers,
    this.maxVolunteersPerPosition,
    this.enableWaitlist = false,
    this.volunteerNeeds = false,
    this.volunteerPositions,
    this.volunteerShifts,
    this.customAthleteFields,
    this.customVolunteerFields,
    this.disclaimerText,
    this.disclaimerUrl,
    this.disclaimerType,
    this.bannerSafeZoneGuide = false,
  });
```

### JSON Serialization Updates

#### Deserialization (`fromJson`):
Ensure lists and maps are safely cast and handle date conversions.
```dart
      registrationStart: json['registration_start'] != null ? DateTime.parse(json['registration_start'] as String).toLocal() : null,
      registrationEnd: json['registration_end'] != null ? DateTime.parse(json['registration_end'] as String).toLocal() : null,
      requiresFees: json['requires_fees'] as bool? ?? false,
      feeAmount: (json['fee_amount'] as num?)?.toDouble(),
      feeCurrency: json['fee_currency'] as String?,
      bankDetails: json['bank_details'] as String?,
      paymentDescription: json['payment_description'] as String?,
      paymentStart: json['payment_start'] != null ? DateTime.parse(json['payment_start'] as String).toLocal() : null,
      paymentEnd: json['payment_end'] != null ? DateTime.parse(json['payment_end'] as String).toLocal() : null,
      registrationMode: json['registration_mode'] as String? ?? 'fcfs',
      websiteUrl: json['website_url'] as String?,
      ticketShopUrl: json['ticket_shop_url'] as String?,
      socials: json['socials'] != null ? Map<String, String>.from(json['socials'] as Map) : null,
      maxAthletes: json['max_athletes'] as int?,
      maxAthletesPerGroup: json['max_athletes_per_group'] != null ? Map<String, int>.from(json['max_athletes_per_group'] as Map) : null,
      maxVolunteers: json['max_volunteers'] as int?,
      maxVolunteersPerPosition: json['max_volunteers_per_position'] != null ? Map<String, int>.from(json['max_volunteers_per_position'] as Map) : null,
      enableWaitlist: json['enable_waitlist'] as bool? ?? false,
      volunteerNeeds: json['volunteer_needs'] as bool? ?? false,
      volunteerPositions: json['volunteer_positions'] != null ? List<String>.from(json['volunteer_positions'] as List) : null,
      volunteerShifts: json['volunteer_shifts'] != null
          ? (json['volunteer_shifts'] as Map<String, dynamic>).map((k, v) => MapEntry(k, List<String>.from(v as List)))
          : null,
      customAthleteFields: json['custom_athlete_fields'] != null
          ? (json['custom_athlete_fields'] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : null,
      customVolunteerFields: json['custom_volunteer_fields'] != null
          ? (json['custom_volunteer_fields'] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : null,
      disclaimerText: json['disclaimer_text'] as String?,
      disclaimerUrl: json['disclaimer_url'] as String?,
      disclaimerType: json['disclaimer_type'] as String?,
      bannerSafeZoneGuide: json['banner_safe_zone_guide'] as bool? ?? false,
```

#### Serialization (`toJson`):
```dart
      'registration_start': registrationStart?.toUtc().toIso8601String(),
      'registration_end': registrationEnd?.toUtc().toIso8601String(),
      'requires_fees': requiresFees,
      if (feeAmount != null) 'fee_amount': feeAmount,
      if (feeCurrency != null) 'fee_currency': feeCurrency,
      if (bankDetails != null) 'bank_details': bankDetails,
      if (paymentDescription != null) 'payment_description': paymentDescription,
      'payment_start': paymentStart?.toUtc().toIso8601String(),
      'payment_end': paymentEnd?.toUtc().toIso8601String(),
      'registration_mode': registrationMode,
      if (websiteUrl != null) 'website_url': websiteUrl,
      if (ticketShopUrl != null) 'ticket_shop_url': ticketShopUrl,
      if (socials != null) 'socials': socials,
      if (maxAthletes != null) 'max_athletes': maxAthletes,
      if (maxAthletesPerGroup != null) 'max_athletes_per_group': maxAthletesPerGroup,
      if (maxVolunteers != null) 'max_volunteers': maxVolunteers,
      if (maxVolunteersPerPosition != null) 'max_volunteers_per_position': maxVolunteersPerPosition,
      'enable_waitlist': enableWaitlist,
      'volunteer_needs': volunteerNeeds,
      if (volunteerPositions != null) 'volunteer_positions': volunteerPositions,
      if (volunteerShifts != null) 'volunteer_shifts': volunteerShifts,
      if (customAthleteFields != null) 'custom_athlete_fields': customAthleteFields,
      if (customVolunteerFields != null) 'custom_volunteer_fields': customVolunteerFields,
      if (disclaimerText != null) 'disclaimer_text': disclaimerText,
      if (disclaimerUrl != null) 'disclaimer_url': disclaimerUrl,
      if (disclaimerType != null) 'disclaimer_type': disclaimerType,
      'banner_safe_zone_guide': bannerSafeZoneGuide,
```

### Recommendation: Add `copyWith`
Adding a `copyWith` helper method to the `Competition` model is critical. It simplifies copying/modifying parameters in providers and prevents dropping existing properties when performing inline constructors.

---

## 2. CompetitionProvider Updates & Volunteer Logic
The state provider (`lib/providers/competition_provider.dart`) must be updated to preserve the new properties and handle the new volunteer workflow.

### Preservation in `createCompetition`
Inside `createCompetition`, the provider instantiates a new `Competition` object when inheriting association details (to resolve rulebook URLs or required athlete groups):
```dart
// Currently:
compToCreate = Competition(
  id: competition.id,
  title: competition.title,
  ...
  athleteGroupIds: athleteGroupIds,
  rulebookUrl: rulebookUrl,
);
```
**Fix:** With `copyWith` implemented, we can securely inherit fields without dropping the new properties:
```dart
compToCreate = competition.copyWith(
  athleteGroupIds: athleteGroupIds,
  rulebookUrl: rulebookUrl,
);
```

### Volunteer Application Integration
We must add a new method to `CompetitionProvider` to submit volunteer applications:
```dart
  Future<bool> applyAsVolunteer({
    required String competitionId,
    required String userId,
    required List<String> preferredPositions,
    required Map<String, dynamic> customFieldsAnswers,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final payload = {
        'id': 'vol-app-${DateTime.now().millisecondsSinceEpoch}',
        'competition_id': competitionId,
        'user_id': userId,
        'preferred_positions': preferredPositions,
        'custom_fields': customFieldsAnswers,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _repository.client.from('volunteer_applications').insert(payload);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error applying as volunteer: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
```

---

## 3. CreateCompetitionWizard Layout and Widget Structure
The creation UI will be located in `lib/views/competition_creation_wizard.dart`. We propose a structured 6-step form. 

To mirror the design of `AssociationCreationPage`, we will implement:
- A custom horizontal stepper widget displaying step titles (`General`, `Dates`, `Limits`, `Fees`, `Volunteers`, `Finalize`).
- A `Form` wrapper per step, combined with validation checks inside the action buttons.
- Bottom actions: `BACK` and `NEXT`/`SUBMIT` buttons.

### Wizard Step Breakdown
1. **Step 1: General & Location**
   - **Title Input**: `TextFormField` (required).
   - **Description**: Standard `TextFormField` with `maxLines: 6` (supports entering markdown/styled text or formatting shortcuts).
   - **Location Picker**: Integrated Country, City, and Address inputs, with a "Verify Location" button which simulates resolving geolocated coordinates (latitude & longitude) based on the inputs.
2. **Step 2: Dates, Formats & Groups**
   - **Competition dates**: Custom datetime field with dialog widgets (`showDatePicker` & `showTimePicker`).
   - **Registration dates**: Datetime pickers for registration start & end.
   - **Sport selection**: Sport type (locked to 'Streetlifting') and format dropdown (Modern vs. Classic).
   - **Association dropdown**: List of associations owned/edited by the current user. If selected:
     - Automatically query active `AthleteGroups` and `CompetitionGroups` for the chosen format.
     - Automatically inherit/prefill the Rulebook URL.
3. **Step 3: Limits & Waitlists**
   - **Registration Mode**: Dropdown to select First-Come-First-Serve (`fcfs`) vs Manual Approval (`approval`).
   - **Limit Toggle**: Select if limits apply to "Overall Competition" or "Per Athlete Group".
   - **Athlete Count Fields**: Number fields to enter limits. If "Per Athlete Group" is active, render dynamic fields for each active group.
   - **Waitlist Toggle**: Switch to enable/disable waiting list for overall or group limits.
4. **Step 4: Fees & Payments**
   - **Fee Toggle**: Switch to configure fees.
   - **Fee Amount & Currency**: Numeric input for fee amount, dropdown for currency selection.
   - **Recipient Bank Details**: Text fields for Recipient Name, Bank Name, IBAN, and BIC.
   - **Generated Description Code**: A read-only preview of the generated description code template (e.g., `FR-{COMP_ID}-{USER_ID}`) to automatically assign to accepted athletes.
   - **Payment Period**: Start & End Date picker for registration payments.
5. **Step 5: Volunteers**
   - **Volunteer Needs Toggle**: Switch to enable/disable volunteer applications.
   - **Volunteer Positions**: Checkbox list of roles (`Judges`, `Spotters`, `Livestream`, `Media`, `Commentators`, `Administration`).
   - **Volunteers Limits**: Numeric input for max volunteers count. Toggle between "Overall limit" vs. "Limit per Position".
   - **Volunteer Registration Dates**: Start & End dates for volunteering signup.
6. **Step 6: Custom Fields, Disclaimers & Media**
   - **Custom Fields Manager**: Lists custom fields to capture. Let users click "+ Add Field" to append text/select fields for athletes or volunteers.
   - **Disclaimers Config**: Select disclaimer type (Text, Link, Both, or Null). Add inputs for Disclaimer Text and/or URL.
   - **Banner Media**: Recommended banner size box (1200x400) showing crop boundaries for desktop and mobile screen layouts, with a switch for displaying safe-zone overlay guides.

---

## 4. Volunteer Application Preference Interface & Multi-Role Submission Flow
On `lib/views/competition_detail_page.dart`, if the competition requires volunteers (`volunteerNeeds` is true), the "Apply as Volunteer" button redirects the user to the Volunteer Application screen/dialog.

### Interface Details
1. **Multi-Role Preference Selector:**
   - Display checkboxes or filter chips for all positions configured by the organizer (e.g. `volunteerPositions` in the model).
   - Once a position is checked, it is added to a dynamic list.
2. **Reordering List (`ReorderableListView`):**
   - Renders the selected positions.
   - Includes a drag handle on the right of each item (`Icons.drag_handle`).
   - Dragging items changes their position in the list. The top item represents the volunteer's 1st priority preference, followed by 2nd, etc.
3. **Dynamic Custom Fields:**
   - Evaluates the competition's `customVolunteerFields` (e.g. `[{"label": "Shirt Size", "type": "select", "options": ["S", "M", "L"], "required": true}]`).
   - Dynamically instantiates input form fields (`TextFormField` or `DropdownButtonFormField`) and binds validation rules.
4. **Multi-Role Submission:**
   - Validates that at least one role is selected.
   - Invokes `CompetitionProvider.applyAsVolunteer(...)` passing the preferences list, custom field answers, and user profile ID.

---

## 5. Routing & Integration Points
1. **Mock Screen Replacement:**
   - In `test/e2e/e2e_test_harness.dart` (line 724):
     ```dart
     // Replace
     if (settings.name == '/competition/create') {
       return MaterialPageRoute(builder: (_) => const CreateCompetitionPage());
     }
     // With
     if (settings.name == '/competition/create') {
       return MaterialPageRoute(builder: (_) => const CreateCompetitionWizard());
     }
     ```
2. **Feed Access Integration:**
   - On `lib/views/search_feed_page.dart`, we should render a Floating Action Button (FAB) at the bottom-right of the screen if the user is authorized:
     ```dart
     floatingActionButton: (authProvider.isCompetitionCreator || authProvider.isAdmin)
         ? FloatingActionButton(
             key: const Key('create_comp_fab'),
             tooltip: 'Create Competition',
             onPressed: () => Navigator.of(context).pushNamed('/competition/create'),
             child: const Icon(Icons.add),
           )
         : null,
     ```
3. **Association Creation Integration:**
   - On `lib/views/association_management_page.dart`, render a button/card inside the dashboard screen labeled "Create Competition", which navigates to `/competition/create` passing the current association ID.

---

## 6. Testing Strategy
We will implement the tests in a new verification suite at `test/competition_creation_wizard_test.dart`.

### 1. Unit Verification
- **Deserialization/Serialization Tests:**
  - Verify mapping of nested Maps (e.g., `socials`, `maxAthletesPerGroup`, `volunteerShifts`) and Lists of Maps (`customAthleteFields`).
  - Verify default values for missing JSON fields (e.g., `requiresFees` defaulting to `false`).
- **`copyWith` Assertions:**
  - Verify all properties copy correctly, especially fields with nested structures like `volunteerShifts`.
- **`applyAsVolunteer` Network/Provider Mock:**
  - Verify invoking `applyAsVolunteer` triggers client database operations with correct parameters and updates state error/loading fields.

### 2. Widget & Validation Tests
- **Wizard Stepper Flow Test:**
  - Ensure users cannot advance to step 2 if the title or location inputs are empty.
  - Test date validators: check error output when registration dates are set after competition start date.
  - Test conditional fees section: toggle fees switch, verify inputs are rendered, and test IBAN/BIC format validation.
- **Volunteer Preference Reordering Test:**
  - Build `VolunteerApplicationForm` in isolation.
  - Find roles selection chips, tap "Judges" and "Spotters".
  - Verify they are added to the reorder list.
  - Call `tester.drag` on "Spotters" drag handle to move it above "Judges". Assert that "Spotters" is now at index 0 of the favorite preference order.
- **Custom Fields Dynamic Generation Test:**
  - Inject custom athlete fields definition in mock competition: `[{"label": "Emergency Phone", "type": "text", "required": true}]`.
  - Open registration form, look for input labeled "Emergency Phone".
  - Attempt to submit with empty value, assert validation error. Fill in number, assert form validates successfully.
