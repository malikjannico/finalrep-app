# R5 Requirement Analysis & Design: Competition Creation & Custom Fields

This report analyzes the requirements for **R5 (Competition Creation & Custom Fields)** and designs the implementation strategy for the data models, state providers, wizard views, volunteer registration flows, and verification suites.

---

## 1. Competition Model Properties & JSON Serialization

To support the advanced scheduling, payment, registration, limit control, customization, and disclaimer configuration required by R5, `Competition` (in `lib/models/competition.dart`) will be expanded.

### Backward-Compatible Field Signatures

To avoid breaking existing E2E tests and code that instantiate `Competition` with standard parameters, all new fields are either nullable or have default values. Required fields like `registrationStart` and `registrationEnd` fallback to `startDate` and `endDate` inside the constructor initializer list.

```dart
// Field declarations to add to class Competition:

final DateTime registrationStart;
final DateTime registrationEnd;
final bool requiresFees;
final double? feeAmount;
final String? feeCurrency;
final String? bankDetails;
final String? paymentDescription;
final DateTime? paymentStart;
final DateTime? paymentEnd;
final String registrationMode; // 'fcfs' (First-Come-First-Served) or 'approval'
final String? websiteUrl;
final String? ticketShopUrl;
final Map<String, String>? socials;
final int? maxAthletes;
final Map<String, int>? maxAthletesPerGroup; // maps group ID -> max count
final int? maxVolunteers;
final Map<String, int>? maxVolunteersPerPosition; // maps position -> max count
final bool enableWaitlist;
final bool volunteerNeeds;
final List<String>? volunteerPositions;
final Map<String, List<String>>? volunteerShifts; // maps position -> list of shifts
final List<Map<String, dynamic>>? customAthleteFields; // schema list
final List<Map<String, dynamic>>? customVolunteerFields; // schema list
final String? disclaimerText;
final String? disclaimerUrl;
final String? disclaimerType; // 'text', 'link', 'both', or null
final bool bannerSafeZoneGuide;
```

### Constructor Signature Update

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
  // R5 Fields
  DateTime? registrationStart,
  DateTime? registrationEnd,
  this.requiresFees = false,
  this.feeAmount,
  this.feeCurrency = 'EUR',
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
})  : this.registrationStart = registrationStart ?? startDate,
      this.registrationEnd = registrationEnd ?? endDate;
```

### JSON Serialization (`fromJson` and `toJson`)

```dart
// Inside Competition.fromJson:
registrationStart: json['registration_start'] != null
    ? DateTime.parse(json['registration_start'] as String).toLocal()
    : DateTime.parse(json['start_date'] as String).toLocal(),
registrationEnd: json['registration_end'] != null
    ? DateTime.parse(json['registration_end'] as String).toLocal()
    : DateTime.parse(json['end_date'] as String).toLocal(),
requiresFees: json['requires_fees'] as bool? ?? false,
feeAmount: (json['fee_amount'] as num?)?.toDouble(),
feeCurrency: json['fee_currency'] as String? ?? 'EUR',
bankDetails: json['bank_details'] as String?,
paymentDescription: json['payment_description'] as String?,
paymentStart: json['payment_start'] != null
    ? DateTime.parse(json['payment_start'] as String).toLocal()
    : null,
paymentEnd: json['payment_end'] != null
    ? DateTime.parse(json['payment_end'] as String).toLocal()
    : null,
registrationMode: json['registration_mode'] as String? ?? 'fcfs',
websiteUrl: json['website_url'] as String?,
ticketShopUrl: json['ticket_shop_url'] as String?,
socials: json['socials'] != null
    ? Map<String, String>.from(json['socials'] as Map)
    : null,
maxAthletes: json['max_athletes'] as int?,
maxAthletesPerGroup: json['max_athletes_per_group'] != null
    ? Map<String, int>.from(json['max_athletes_per_group'] as Map)
    : null,
maxVolunteers: json['max_volunteers'] as int?,
maxVolunteersPerPosition: json['max_volunteers_per_position'] != null
    ? Map<String, int>.from(json['max_volunteers_per_position'] as Map)
    : null,
enableWaitlist: json['enable_waitlist'] as bool? ?? false,
volunteerNeeds: json['volunteer_needs'] as bool? ?? false,
volunteerPositions: json['volunteer_positions'] != null
    ? List<String>.from(json['volunteer_positions'] as List)
    : null,
volunteerShifts: json['volunteer_shifts'] != null
    ? (json['volunteer_shifts'] as Map).map((k, v) => MapEntry(k as String, List<String>.from(v as List)))
    : null,
customAthleteFields: json['custom_athlete_fields'] != null
    ? (json['custom_athlete_fields'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
    : null,
customVolunteerFields: json['custom_volunteer_fields'] != null
    ? (json['custom_volunteer_fields'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
    : null,
disclaimerText: json['disclaimer_text'] as String?,
disclaimerUrl: json['disclaimer_url'] as String?,
disclaimerType: json['disclaimer_type'] as String?,
bannerSafeZoneGuide: json['banner_safe_zone_guide'] as bool? ?? false,
```

```dart
// Inside Competition.toJson:
'registration_start': registrationStart.toUtc().toIso8601String(),
'registration_end': registrationEnd.toUtc().toIso8601String(),
'requires_fees': requiresFees,
'fee_amount': feeAmount,
'fee_currency': feeCurrency,
'bank_details': bankDetails,
'payment_description': paymentDescription,
'payment_start': paymentStart?.toUtc().toIso8601String(),
'payment_end': paymentEnd?.toUtc().toIso8601String(),
'registration_mode': registrationMode,
'website_url': websiteUrl,
'ticket_shop_url': ticketShopUrl,
'socials': socials,
'max_athletes': maxAthletes,
'max_athletes_per_group': maxAthletesPerGroup,
'max_volunteers': maxVolunteers,
'max_volunteers_per_position': maxVolunteersPerPosition,
'enable_waitlist': enableWaitlist,
'volunteer_needs': volunteerNeeds,
'volunteer_positions': volunteerPositions,
'volunteer_shifts': volunteerShifts,
'custom_athlete_fields': customAthleteFields,
'custom_volunteer_fields': customVolunteerFields,
'disclaimer_text': disclaimerText,
'disclaimer_url': disclaimerUrl,
'disclaimer_type': disclaimerType,
'banner_safe_zone_guide': bannerSafeZoneGuide,
```

---

## 2. State Management & Provider Updates

The `CompetitionProvider` (in `lib/providers/competition_provider.dart`) requires modifications to support:
1. Copying R5 fields during competition creation.
2. Managing volunteer applications and preferred roles.

### Preserving R5 Fields in `createCompetition`

The current code in `createCompetition` recreates the `Competition` model object explicitly using positional and named parameters if association details are retrieved. It must be updated to copy over all the R5 fields:

```dart
// Inside createCompetition in CompetitionProvider (after retrieving assoc details):
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
  
  // R5 Fields to preserve:
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
  websiteUrl: competition.websiteUrl,
  ticketShopUrl: competition.ticketShopUrl,
  socials: competition.socials,
  maxAthletes: competition.maxAthletes,
  maxAthletesPerGroup: competition.maxAthletesPerGroup,
  maxVolunteers: competition.maxVolunteers,
  maxVolunteersPerPosition: competition.maxVolunteersPerPosition,
  enableWaitlist: competition.enableWaitlist,
  volunteerNeeds: competition.volunteerNeeds,
  volunteerPositions: competition.volunteerPositions,
  volunteerShifts: competition.volunteerShifts,
  customAthleteFields: competition.customAthleteFields,
  customVolunteerFields: competition.customVolunteerFields,
  disclaimerText: competition.disclaimerText,
  disclaimerUrl: competition.disclaimerUrl,
  disclaimerType: competition.disclaimerType,
  bannerSafeZoneGuide: competition.bannerSafeZoneGuide,
);
```

### Volunteer Application Submission Support

The provider will expose a method to save a volunteer's multi-role application and preference settings to the db:

```dart
Future<bool> submitVolunteerApplication({
  required String competitionId,
  required String userId,
  required List<String> preferredRoles, // ordered: first element = 1st choice
  required Map<String, List<String>> shiftAvailability, // position -> shift list
  required Map<String, dynamic> customFieldAnswers,
  required bool disclaimerAccepted,
}) async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();
  
  try {
    final applicationData = {
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
    
    // Insert into Supabase table
    final response = await _repository.client
        .from('volunteer_applications')
        .insert(applicationData)
        .select()
        .maybeSingle();
        
    return response != null;
  } catch (e) {
    _errorMessage = 'Failed to submit volunteer application: $e';
    debugPrint(_errorMessage);
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

---

## 3. Create Competition Wizard UI & Layout Design

The file `lib/views/competition_creation_wizard.dart` will implement a multi-step form to collect R5 configuration parameters cleanly. Rather than Flutter's standard `Stepper`, a custom step layout (similar to `AssociationCreationPage`) is proposed to maximize UI space and custom rendering control.

### Layout Structure
- **Top progress indicator bar**: Shows numbers/labels representing steps: Basic Info, Scheduling & Mode, Fees & Finance, Caps & Waitlist, Volunteers & Customization.
- **Middle content block**: Utilizes a `Form` per step. Content is wrapped in a `SingleChildScrollView` to prevent keyboard overflow issues on smaller devices.
- **Bottom action panel**: Back / Next buttons. If it's the final step, Next turns into **Create Competition**.

### Step Breakdown and Input Fields

#### Step 1: Basic Info & Subtypes
*   **Meet Title**: TextFormField with Validator (required).
*   **Description**: TextFormField (multiline, optional).
*   **Location/Venue**: TextFormField with Validator (required).
*   **City & Country**: TextFormFields (used for coordinates calculation).
*   **Sport Type**: Dropdown/Select (defaults to "Streetlifting").
*   **Sport Subtype**: ToggleButtons or SegmentedButton ('Modern' (4 Lifts) or 'Classic' (2 Lifts)).
*   **Title Image URL**: TextFormField with image validation.
*   **Banner Safe Zone Guide**: Switch tile (shows guidelines on the cover image preview).

#### Step 2: Scheduling & Registration Date-Times
*   **Meet Date Range**: Start Date and End Date picker fields. Validation: `endDate >= startDate`.
*   **Registration Date Range**: Start Date and End Date picker fields. Validation: `registrationEnd >= registrationStart` and `registrationEnd <= startDate`.
*   **Registration Mode**: SegmentedButton/Radio list:
    *   `First-Come, First-Served (FCFS)`: Automatic approval upon entry.
    *   `Approval Mode`: Applications remain pending until reviewed by the association admin.

#### Step 3: Fees & Payment Configurations
*   **Requires Entry Fees**: SwitchListTile.
*   **Conditional Fields** (rendered only if `Requires Entry Fees` is true):
    *   **Fee Amount**: TextFormField (numeric input with validator).
    *   **Currency**: DropdownButton (EUR, USD, GBP, etc.).
    *   **Bank details / IBAN**: TextFormField (required if fees active).
    *   **Payment Description**: TextFormField.
    *   **Payment Window**: Date pickers for Payment Start & Payment End dates.

#### Step 4: Participant Limits & Waitlist
*   **Max Athlete Slots**: TextFormField (numeric, optional).
*   **Max Athletes Per Athlete Group**: Dynamic Map Editor list where the admin select an Athlete Group (retrieved from association) and sets a max limit for that group.
*   **Max Volunteer Slots**: TextFormField (numeric, optional).
*   **Max Volunteers Per Position**: Dynamic list of custom position fields mapping to numeric limits.
*   **Enable Waitlist**: SwitchListTile (active when athlete limits are set).

#### Step 5: Volunteer Setup, Custom Fields, & Disclaimers
*   **Volunteer Needs**: SwitchListTile. If active, shows:
    *   *Position Chips*: Input field to add roles (e.g. Judge, Loader) which render as removable `Chip` widgets.
    *   *Shift Manager*: For each added position, input fields to add available shifts (e.g. "Morning", "Afternoon").
*   **Custom Fields Editor**: Dynamic list builders for Athletes and Volunteers. Enables admins to build custom questions:
    *   *Add Field Button*: Choice of field type (Text, Boolean checkbox, Dropdown select).
    *   *Configuration*: Field Name, Required state, and Select Options (if dropdown is selected).
*   **Disclaimers**:
    *   *Disclaimer Type*: Dropdown ('None', 'Text Only', 'Link Only', 'Both Text and Link').
    *   *Disclaimer Text*: Multiline TextFormField (visible if type is 'Text Only' or 'Both').
    *   *Disclaimer URL*: TextFormField (validated URL, visible if type is 'Link Only' or 'Both').

---

## 4. Volunteer Application Preference Interface & Flow

When a user selects **Apply as Volunteer** on the `CompetitionDetailPage`, they should be directed to a custom modal bottom sheet or page: `VolunteerApplicationPage`.

### Widget Structure & UX Flow

```
+-----------------------------------------------------------+
|               Apply as Volunteer                          |
+-----------------------------------------------------------+
| 1. Select Roles (Choose all that apply)                   |
|    [X] Judge    [X] Spotter/Loader   [ ] Scorekeeper      |
|                                                           |
| 2. Order of Preference (Drag to prioritize)                |
|    = 1st Choice: Judge                                    |
|    = 2nd Choice: Spotter/Loader                           |
|                                                           |
| 3. Shift Availability                                      |
|    * Judge:                                               |
|      [X] Morning Shift  [ ] Afternoon Shift               |
|    * Spotter/Loader:                                      |
|      [X] Morning Shift  [X] Afternoon Shift               |
|                                                           |
| 4. Custom Volunteer Fields                                |
|    T-Shirt Size: [ Dropdown v: L ]                        |
|    Prior Experience (years): [ TextFormField: 2 ]         |
|                                                           |
| 5. Disclaimer & Consent                                   |
|    "I agree to volunteer terms..."                        |
|    [X] I accept the terms                                 |
|                                                           |
| +-------------------------------------------------------+ |
| |                        SUBMIT                         | |
| +-------------------------------------------------------+ |
+-----------------------------------------------------------+
```

### Multi-Role Reordering Strategy

1.  **Selection Chips**: The user checks which volunteer roles they are willing to perform.
2.  **Reorderable Preference List**: We use a `ReorderableListView.builder` listing the selected roles. Users drag them to adjust priority order. Preference ranking maps to the list's index order (e.g. index 0 is first priority).
3.  **Dynamic Shifts Selection**: Displays availability checkboxes for each chosen role based on `competition.volunteerShifts[role]`.
4.  **Dynamic Custom Forms**: Loops through `competition.customVolunteerFields`. Renders inputs dynamically:
    *   If `type == 'text'`, displays a `TextFormField`.
    *   If `type == 'select'`, displays a `DropdownButtonFormField` with the configured options list.
    *   If `type == 'checkbox'`, displays a `CheckboxListTile`.
5.  **Terms Agreement**: Checkbox mapping validation. The **Submit** button is disabled until the disclaimer checkbox is checked.

---

## 5. Integration and Routing Strategy

The mock views and routing currently live in the E2E testing framework. We need to integrate the new page and features cleanly into the routing mechanism.

### Updating E2E Harness Routing (`test/e2e/e2e_test_harness.dart`)
Replace the mock route mapping in the `MaterialApp` inside `buildApp()` (lines 724-726):

```dart
// Old
if (settings.name == '/competition/create') {
  return MaterialPageRoute(builder: (_) => const CreateCompetitionPage());
}

// New Proposed Integration:
if (settings.name == '/competition/create') {
  // We can pass associationId inside arguments if launched from association dashboard
  final String? associationId = settings.arguments as String?;
  return MaterialPageRoute(
    builder: (_) => CreateCompetitionWizard(associationId: associationId),
  );
}
```

### Real Application Router Integration
For production, the route should be registered in the central router (e.g. `lib/main.dart` or routing module) mapping `/competition/create` to `CreateCompetitionWizard`.
Access to `/competition/create` must be restricted to authorized users (Admins or Association Creators) matching the permission check pattern:

```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);
if (!authProvider.isAssociationCreator && !authProvider.isAdmin) {
  return const AccessDeniedView();
}
```

---

## 6. Verification and Testing Plan

To ensure all new features are robust, unit tests and widget tests will be implemented in `test/competition_creation_wizard_test.dart`.

### Part A: Unit Tests (`Competition` Model & Provider)

1.  **JSON Serialization Test**:
    *   *Input*: Map containing all new R5 fields (dates, fees, limits, custom fields, shifts).
    *   *Action*: Invoke `Competition.fromJson` and then `toJson`.
    *   *Assertion*: Assert that all serialized properties match the original input and are correctly cast (e.g., date formats, map types).
2.  **Inheritance Fallback Test**:
    *   *Action*: Instantiate `Competition` without custom `registrationStart` or `registrationEnd` dates.
    *   *Assertion*: Confirm they automatically inherit `startDate` and `endDate` from the constructor helper logic.
3.  **Provider Save Integrity Test**:
    *   *Action*: Execute `createCompetition` via the provider using a mock `CompetitionRepository`.
    *   *Assertion*: Verify that the repository's insert payload retains the exact R5 fields.
4.  **Volunteer Application Submission Test**:
    *   *Action*: Execute `submitVolunteerApplication` in `CompetitionProvider` with test data.
    *   *Assertion*: Verify that the underlying network builder constructs a query payload targeting the `volunteer_applications` table with correctly structured JSON variables.

### Part B: Widget Tests (`CreateCompetitionWizard` & Volunteer Flow)

1.  **Wizard Step Progression & Validation**:
    *   *Action*: Pump `CreateCompetitionWizard`. Type empty title and press Next.
    *   *Assertion*: Assert error validator message is shown. Fill name, select subtype, press Next. Assert step indicator updates to Step 2.
2.  **Payment Field Conditional Visibility**:
    *   *Action*: Navigate to the "Fees & Finance" step (Step 3). Verify fee amount field is absent. Toggle "Requires Entry Fees" switch to true.
    *   *Assertion*: Confirm that the "Fee Amount", "Currency", and "Bank Details" fields appear dynamically.
3.  **Volunteer Preferences UI Drag-and-Drop & Submission**:
    *   *Action*: Launch `VolunteerApplicationPage` for a mock competition with volunteer positions `['Judge', 'Loader']`. Check both positions.
    *   *Assertion*: Verify `ReorderableListView` contains both options. Simulate dragging 'Loader' to index 0. Check disclaimer checkbox and submit.
    *   *Result Verification*: Verify `submitVolunteerApplication` is called with `preferredRoles: ['Loader', 'Judge']`.
