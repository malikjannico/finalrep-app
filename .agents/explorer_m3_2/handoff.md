# Handoff Report: R5 (Competition Creation & Custom Fields) Analysis

## 1. Observation

Direct observations made in the codebase:
- **Scope Definition**: The `SCOPE.md` file at `.agents/sub_orch_m3/SCOPE.md` lists 11 categories of fields to add to the `Competition` model, including dates (`registrationStart`, `registrationEnd`), payment configuration (`requiresFees`, `feeAmount`, `feeCurrency`, `bankDetails`, etc.), participant limits (`maxAthletes`, `maxVolunteers`), volunteer positions and shifts, custom athlete/volunteer field definitions, disclaimers, and a banner guide toggle.
- **Competition Model**: `lib/models/competition.dart` contains:
  ```dart
  class Competition {
    final String id;
    final String title;
    ...
  ```
  It has standard JSON serialization helpers (`fromJson` and `toJson`).
- **Competition Provider**: `lib/providers/competition_provider.dart` defines `createCompetition(Competition competition)` which builds a new `Competition` explicitly line-by-line (lines 749-770), which will drop any R5 fields if not manually populated there:
  ```dart
  compToCreate = Competition(
    id: competition.id,
    title: competition.title,
    ...
  ```
- **Existing Mock Routing**: `test/e2e/e2e_test_harness.dart` maps the path `/competition/create` to `CreateCompetitionPage()` (lines 724-726):
  ```dart
  if (settings.name == '/competition/create') {
    return MaterialPageRoute(builder: (_) => const CreateCompetitionPage());
  }
  ```
- **Mock View**: `test/e2e/mock_views.dart` defines a basic form stepper `CreateCompetitionPage` with basic controls (lines 132-213).

## 2. Logic Chain

1. **Model Expansion**: R5 requires adding 27 fields to `Competition`. To ensure compilation does not break in existing tests and usages (such as in `e2e_test_harness.dart`), these fields must be optional or fall back to sensible defaults. Specifically, `registrationStart` and `registrationEnd` can be initialized to `startDate` and `endDate` inside the constructor's initializer list if they are null.
2. **Provider Update**: The provider's `createCompetition` function currently recreates `Competition` instances when resolving association details. If the new R5 fields are not added to this instantiation call, they will be lost. Therefore, we must map all 27 new R5 fields there.
3. **Volunteer Applications**: No state model or logic for volunteer applications is implemented. We need to introduce `submitVolunteerApplication` in `CompetitionProvider` that writes directly to a database table `volunteer_applications` via the Supabase client.
4. **UI Stepper Choice**: Rather than using Flutter's restrictive `Stepper`, a custom step layout modeled after `AssociationCreationPage` provides a more customizable, scalable experience for form validation and dynamically rendered fields (like payment config and custom field builders).
5. **Integration**: Replacing the E2E route `/competition/create` with the new `CreateCompetitionWizard` integrates the production wizard in tests while maintaining compatibility with routing expectations.

## 3. Caveats

- We assume that the target database schema matches the design (i.e. table `volunteer_applications` exists or is created in a migration with columns for `preferred_roles`, `shift_availability`, etc.). If the table structure differs, the JSON keys in the serialization/insertion logic must be adjusted accordingly.

## 4. Conclusion

The analysis and design strategy for R5 is fully outlined in `analysis.md` in this directory. We have provided:
- Fully defined field signatures and JSON mappings for the `Competition` model.
- Updates to `createCompetition` and a new `submitVolunteerApplication` API for the `CompetitionProvider`.
- A 5-step custom wizard layout mapping all R5 fields.
- A volunteer preference reordering interface using `ReorderableListView`.
- An integration routing proposal and a detailed test suite design (unit + widget tests).

## 5. Verification Method

To verify the proposed changes:
1. Compile the app and ensure all existing tests pass:
   ```zsh
   flutter test
   ```
2. Verify model serialization: Run the unit tests designed in `test/competition_creation_wizard_test.dart` (created in Milestone 3, step 3).
3. Inspect `analysis.md` for exact code changes.
