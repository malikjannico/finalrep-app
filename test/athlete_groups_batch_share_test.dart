import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mocks/supabase_dummies.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('Athlete Groups Batch Share Tests', () {
    testWidgets(
      'Verify checkboxes and batch share button on gender header',
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

        // 1. Seed association & athlete groups
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

        final g1 = AthleteGroup(
          id: 'g-1',
          associationId: 'assoc-test-1',
          name: 'Group 1',
          sport: 'Streetlifting',
          format: 'Modern',
          gender: 'men',
          isActive: true,
        );
        final g2 = AthleteGroup(
          id: 'g-2',
          associationId: 'assoc-test-1',
          name: 'Group 2',
          sport: 'Streetlifting',
          format: 'Modern',
          gender: 'men',
          isActive: true,
        );
        await harness.competitionProvider.createAthleteGroup(g1);
        await harness.competitionProvider.createAthleteGroup(g2);

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

        // Render Association Management Page
        await tester.pumpWidget(
          harness.buildApp(AssociationManagementPage(associationId: 'assoc-test-1')),
        );
        await tester.pumpAndSettle();

        // Switch to the Athlete Groups tab (index 3)
        await tester.tap(find.text('Athlete Groups'));
        await tester.pumpAndSettle();

        // Verify that no checkboxes are rendered on the main screen, but the groups are visible
        expect(find.text('Group 1'), findsOneWidget);
        expect(find.text('Group 2'), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);

        // Find and tap the options button in the top header, then tap "Share Groups"
        final optionsBtn = find.byTooltip('Athlete Groups Options');
        expect(optionsBtn, findsOneWidget);
        await tester.tap(optionsBtn);
        await tester.pumpAndSettle();

        final shareBtn = find.text('Share Groups');
        expect(shareBtn, findsOneWidget);
        await tester.tap(shareBtn);
        await tester.pumpAndSettle();

        // Verify the ShareResourceMultiDialog is open
        expect(find.text('Share Athlete Groups'), findsOneWidget);
        expect(find.byType(Checkbox), findsNWidgets(3)); // Select All shown, Group 1, Group 2

        // Select the items inside the dialog
        await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Group 1')));
        await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Group 2')));
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);

        // Tap the NEXT button to open the configuration step
        final nextBtn = find.text('NEXT');
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        // Verify Step 2 is shown
        expect(find.text('Set Sharing Mode & Targets'), findsOneWidget);
        expect(find.text('Sharing Mode'), findsOneWidget);

        // Close the dialog
        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();

        harness.dispose();
      },
    );
  });
}
