# Handoff Report — Milestone 3 (Explorer 3)

This handoff report summarizes the exploration and architectural design for **R5 (Competition Creation & Custom Fields)** to guide the implementation work.

---

## 1. Observation

- **Competition Model**: Located at `lib/models/competition.dart`. The model constructor (lines 24-45), `fromJson` (lines 47-72), and `toJson` (lines 74-97) do not currently implement the detailed schedule dates, registration limits, fees, payment setups, custom fields, volunteer configurations, disclaimer agreements, or safe zone parameters required by R5.
- **Provider Methods**: `CompetitionProvider` in `lib/providers/competition_provider.dart` handles creation logic (`createCompetition`, lines 724-788). It currently clones the competition object when resolving rulebooks and groups:
  ```dart
  compToCreate = Competition(
    id: competition.id,
    title: competition.title,
    // ...
  );
  ```
  This cloning construct will discard the new R5 parameters if not modified to forward them.
- **Mock Views**: `test/e2e/mock_views.dart` contains a stub `CreateCompetitionPage` (lines 132-213) with keys: `comp_name_field`, `comp_fees_toggle`, `comp_waitlist_toggle`, `comp_disclaimer`, and `comp_next_btn`.
- **E2E Routing**: `test/e2e/e2e_test_harness.dart` maps the `/competition/create` route to `CreateCompetitionPage` (line 725):
  ```dart
  if (settings.name == '/competition/create') {
    return MaterialPageRoute(builder: (_) => const CreateCompetitionPage());
  }
  ```
- **Test Suit Verification**: Run command `flutter test` completes successfully with:
  ```
  All tests passed!
  ```

---

## 2. Logic Chain

1. **Model Synchronization**: Since M3 R5 adds scheduling constraints, capacities, payment options, dynamic fields, and disclaimers, the database representation and Dart entity `Competition` must be upgraded. This means adding 27 fields with correct Dart signatures, parsing rules in `fromJson` (especially converting JSON `num` to `double` for fees), and serializing them in `toJson`.
2. **Data Preservation during Creation**: When `CompetitionProvider.createCompetition()` runs, it performs inheritance cloning. Without forwarding the new R5 properties in the cloning block, these properties would be reset to defaults or null. Forwarding them ensures that basic, date, fee, limits, custom field, and volunteer settings survive.
3. **Consistent UI Wizard Design**: `AssociationCreationPage` provides a successful template for multi-step form navigation using form validation per step, progress headers, and a bottom action bar. We can model `CreateCompetitionWizard` directly on this custom design to maintain consistency across the application.
4. **Dynamic Volunteer Flows**: A volunteer application needs multi-role selection and ordered preferences. Checking `volunteerPositions` from the competition and feeding them into checkboxes, which then populate a `ReorderableListView`, provides a native, highly interactive drag-and-drop ordering interface. Dynamic field generation via custom metadata maps ensures custom questions (like t-shirt sizes) are presented as correct form elements (`TextFormField` vs. `SwitchListTile` vs. `DropdownButtonFormField`).
5. **Route Integration**: By updating `/competition/create` in `test/e2e/e2e_test_harness.dart` to return the new `CreateCompetitionWizard` (and ensuring the input keys match the test keys of `CreateCompetitionPage`), E2E testing framework integration will remain clean and stable.

---

## 3. Caveats

- **Supabase Table Schema**: This design assumes the database backend supports a new `volunteer_applications` table. If a dedicated table is not added, fields can be serialized into a unified `applications` table with a `'type': 'volunteer'` field flag.
- **Dynamic Options Parsing**: We assume custom fields of type `'select'` provide options in a comma-separated format that is parsed into a list on the client side.
- **Explorer Restrictions**: This investigation was strictly read-only. No source code modifications were performed.

---

## 4. Conclusion

A full strategy and detailed implementation layout for the model fields, provider mutations, widget architectures, dynamic forms, and test coverage are prepared and written to `analysis.md` in the working directory. The implementer has a complete structural recipe to write the code.

---

## 5. Verification Method

1. **Review analysis.md**: Read `/Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update/.agents/explorer_m3_3/analysis.md` for exact Dart constructor parameter listings and UI step structure.
2. **Execute Tests**: Run `flutter test` in the root workspace to confirm that the existing test suites build and pass correctly.
3. **Verify Wizard Integration**: Inspect `test/competition_creation_wizard_test.dart` once written to confirm it tests:
   - Form field validators (e.g., date ordering).
   - Dynamic visibility (e.g., fee fields showing only if "Requires Fees" is true).
   - Reorderable list interactions and custom field submissions.
