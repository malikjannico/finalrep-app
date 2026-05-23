# Handoff Report: R5 Design (Milestone 3 Explorer 1)

## 1. Observation
- **Model Signature**: `lib/models/competition.dart` contains the `Competition` class. The current constructor (lines 24-45) and serializations (`fromJson` on lines 47-72; `toJson` on lines 74-97) do not contain R5 properties (such as payment, volunteer, waitlist, disclaimers, or custom fields).
- **State management field drops**: In `lib/providers/competition_provider.dart`, the `createCompetition` method (lines 724-788) copies inherited properties when an association ID is present by manually reconstructing the `Competition` instance (lines 749-770):
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
  );
  ```
- **Harness routing**: `test/e2e/e2e_test_harness.dart` configures route navigation for `/competition/create` on line 725:
  ```dart
  if (settings.name == '/competition/create') {
    return MaterialPageRoute(builder: (_) => const CreateCompetitionPage());
  }
  ```
- **Volunteer Application Details**: In `lib/views/competition_detail_page.dart` (lines 338-366), the "Apply as Volunteer" button is currently a mock action that triggers a SnackBar:
  ```dart
  OutlinedButton(
    onPressed: () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you for your interest! Volunteer applications for ${competition.title} will open soon.',
          ),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
    },
    ...
  )
  ```

## 2. Logic Chain
1. Since the `createCompetition` method in `CompetitionProvider` creates a brand new instance of `Competition` on lines 749-770 when association details are inherited, any fields on the passed `competition` parameter that are not explicitly passed to this constructor will be dropped.
2. To avoid dropping any fields now or in the future, the `Competition` model should define a `copyWith(...)` method, allowing `createCompetition` to simply call `compToCreate = competition.copyWith(athleteGroupIds: athleteGroupIds, rulebookUrl: rulebookUrl)`.
3. In `e2e_test_harness.dart` (line 725), route `/competition/create` targets `CreateCompetitionPage`. Thus, once `CreateCompetitionWizard` is implemented, we can directly swap it there to integrate the production widget into E2E verification tests.
4. The volunteer application is currently a mock SnackBar. Supporting role preferences requires navigating the user from the "Apply as Volunteer" button to a page/dialog where they can select roles, reorder them using `ReorderableListView`, fill out dynamic custom fields, and submit to the provider using a new database method `applyAsVolunteer`.

## 3. Caveats
- Checked local filesystem and database interfaces only; external authentication provider integrations (beyond Supabase) or external payment providers are assumed to be handled asynchronously via database webhook structures and are not explicitly modeled in our Flutter code.

## 4. Conclusion
We have established a robust design strategy for R5:
1. Extend `Competition` model fields and JSON serialization, including a `copyWith` helper to ensure state integrity during creation.
2. Adapt `CompetitionProvider.createCompetition` to utilize `copyWith`, and implement `applyAsVolunteer`.
3. Implement `CreateCompetitionWizard` as a 6-step form.
4. Design the volunteer application flow featuring checkboxes, list reordering via `ReorderableListView`, and dynamic field inputs.
5. Swap the routing target in `test/e2e/e2e_test_harness.dart` and add navigation entry points.
6. Verify via dedicated unit and widget test suites in `test/competition_creation_wizard_test.dart`.

The complete design is written to `/Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/explorer_m3_1/analysis.md`.

## 5. Verification Method
1. Verify the location of files and proposed updates described in `/Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/explorer_m3_1/analysis.md`.
2. Run standard project tests using `flutter test` to ensure existing tests pass cleanly before Milestone 3 implementations start.
