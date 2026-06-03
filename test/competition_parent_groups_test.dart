import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/views/competition_creation_page.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('Competition Creation Page - Parent Association Enhancements', () {
    testWidgets(
      'Label text does not contain (Optional)',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();

        await tester.pumpWidget(
          harness.buildApp(const CompetitionCreationPage()),
        );
        await tester.pumpAndSettle();

        // Verify Step 1: Info renders the "Parent Association" label
        // and does NOT contain "Parent Association (Optional)"
        expect(find.text('Parent Association'), findsOneWidget);
        expect(find.text('Parent Association (Optional)'), findsNothing);

        harness.dispose();
      },
    );

    testWidgets(
      'Apply Parent Groups button disabled when no association selected, and loads groups when selected',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();

        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
        });

        // 1. Seed association & athlete groups in mock DB via provider
        final assoc = Association(
          id: 'assoc-test-1',
          name: 'Olympic Federation',
          description: 'Testing parent association',
          scope: 'national',
          ownerId: 'user-1',
          rulebooks: {},
          socialChannels: {},
        );
        await harness.competitionProvider.createAssociation(assoc);

        final matchGroup = AthleteGroup(
          id: 'g-1',
          associationId: 'assoc-test-1',
          name: '-80kg Men',
          sport: 'Streetlifting',
          format: 'Modern',
          gender: 'men',
          isActive: true,
        );
        final nonMatchGroup = AthleteGroup(
          id: 'g-2',
          associationId: 'assoc-test-1',
          name: 'Pull & Dip Women',
          sport: 'Calisthenics',
          format: 'Classic',
          gender: 'women',
          isActive: true,
        );
        await harness.competitionProvider.createAthleteGroup(matchGroup);
        await harness.competitionProvider.createAthleteGroup(nonMatchGroup);

        // Authenticate as owner
        final session = Session(
          accessToken: 'token-user-1',
          tokenType: 'bearer',
          user: User(
            id: 'user-1',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: '',
            email: 'john@example.com',
          ),
        );
        harness.mockAuth.triggerAuthStateChange(
          AuthChangeEvent.signedIn,
          session,
        );
        await harness.waitForAuthSettle(tester);

        // Build widget
        await tester.pumpWidget(
          harness.buildApp(const CompetitionCreationPage()),
        );
        await tester.pumpAndSettle();

        // Step 1: Fill title
        await tester.enterText(
          find.byKey(const Key('comp_name_field')),
          'State Championship',
        );
        await tester.pumpAndSettle();

        // Navigate to Step 7 (Athlete Groups) without selecting a parent association to check disabled button
        final nextButton = find.byKey(const Key('comp_next_btn'));

        // Step 1 -> Step 2
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Step 2: Location
        await tester.enterText(
          find.byKey(const Key('comp_location_field')),
          'Rütersbarg 50, 22529 Hamburg, Germany',
        );
        // Step 2 -> Step 3 (automatic verification triggered on NEXT tap)
        await tester.tap(nextButton);
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pumpAndSettle();
        ScaffoldMessenger.of(tester.element(nextButton)).clearSnackBars();
        await tester.pumpAndSettle();

        // Step 3: Sport & Format (Defaults to Streetlifting & Modern)
        // Step 3 -> Step 4
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Step 4: Banner
        // Step 4 -> Step 5
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Step 5: Dates
        // Step 5 -> Step 6
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Step 6: Registration Settings
        // Step 6 -> Step 7 (Competition Group)
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Step 7 -> Step 8 (Athlete Groups)
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // We are at Step 8: Athlete Groups. Verify "Apply Parent Groups" button is disabled (onPressed is null)
        final applyBtnFinder = find.byKey(const Key('apply_parent_groups_btn'));
        expect(applyBtnFinder, findsOneWidget);
        OutlinedButton applyBtn = tester.widget<OutlinedButton>(applyBtnFinder);
        expect(applyBtn.onPressed, isNull);

        // Go back to Step 1 to select the Parent Association
        for (int i = 0; i < 7; i++) {
          await tester.tap(find.widgetWithText(OutlinedButton, 'BACK'));
          await tester.pumpAndSettle();
        }

        // We are back at Step 1: Info. Select "Olympic Federation"
        await tester.tap(find.text('None'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Olympic Federation'));
        await tester.pumpAndSettle();

        // Go forward to Step 8 again
        // Step 1 -> Step 2
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
        // Step 2 -> Step 3
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
        // Step 3 -> Step 4
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
        // Step 4 -> Step 5
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
        // Step 5 -> Step 6
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
        // Step 6 -> Step 7
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
        // Step 7 -> Step 8
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Now button should be enabled
        applyBtn = tester.widget<OutlinedButton>(applyBtnFinder);
        expect(applyBtn.onPressed, isNotNull);

        // Tap the button
        await tester.tap(applyBtnFinder);
        await tester.pumpAndSettle();

        // Verify the matched group "-80kg Men" is added and rendered, but "Pull & Dip Women" is not (different sport/format)
        expect(find.text('-80kg Men'), findsOneWidget);
        expect(find.text('Pull & Dip Women'), findsNothing);

        harness.dispose();
      },
    );
  });
}
