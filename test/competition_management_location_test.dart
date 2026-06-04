import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mocks/supabase_dummies.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/views/competition_management_page.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('Competition Management - Location Autocomplete & Verification Tests', () {
    testWidgets(
      'Metadata edit mode allows location verification and saves new coordinates to DB',
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
          harness.dispose();
        });

        // 1. Seed a competition with initial coordinates (Berlin)
        final comp = Competition(
          id: 'comp-test-123',
          title: 'Location Test Meet',
          startDate: DateTime.now().add(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          location: 'Berlin, Germany',
          city: 'Berlin',
          country: 'Germany',
          latitude: 52.5200,
          longitude: 13.4050,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          sportSubtype: 'Modern',
        );
        harness.db.competitions[comp.id] = comp;

        // Authenticate standard user
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
        harness.mockAuth.triggerAuthStateChange(AuthChangeEvent.signedIn, session);
        await harness.waitForAuthSettle(tester);

        // Load the competition management page for comp-test-123
        await tester.pumpWidget(
          harness.buildApp(CompetitionManagementPage(competitionId: 'comp-test-123')),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Check that initial location is shown in TextFormField and Verified badge shows verified
        final locationFieldFinder = find.byKey(const Key('comp_location_field'));
        expect(locationFieldFinder, findsOneWidget);
        final locationField = tester.widget<TextFormField>(locationFieldFinder);
        expect(locationField.controller!.text, 'Berlin, Germany');

        expect(find.text('Verified'), findsOneWidget);

        // Click EDIT button
        final editButton = find.widgetWithText(ElevatedButton, 'EDIT');
        expect(editButton, findsOneWidget);
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // Enter a new location (triggers location to become unverified)
        await tester.enterText(locationFieldFinder, 'Marienplatz 1, 80331 Munich, Germany');
        await tester.pumpAndSettle();

        // Suggestions should be shown (since query is entered)
        // Wait for debounce timer to fire in test environment
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pumpAndSettle();

        // Tap the suggestion list to select a suggestion
        // (Marienplatz 1, 80331 Munich, Germany suggestion should show up in testing mode)
        final suggestionFinder = find.text('Marienplatz 1, 80331 Munich, Germany');
        expect(suggestionFinder, findsWidgets);
        await tester.tap(suggestionFinder.first);
        await tester.pumpAndSettle();

        // Now, location is unverified, so "Verified" text badge is NOT shown, but "Verify Location" button is enabled
        expect(find.text('Verified'), findsNothing);

        // Tap "Verify Location" manually
        final verifyBadgeFinder = find.byKey(const Key('comp_location_verify_badge'));
        expect(verifyBadgeFinder, findsOneWidget);

        final verifyButtonFinder = find.descendant(
          of: verifyBadgeFinder,
          matching: find.byType(ElevatedButton),
        );
        expect(verifyButtonFinder, findsOneWidget);
        await tester.ensureVisible(verifyButtonFinder);
        await tester.pumpAndSettle();
        await tester.tap(verifyButtonFinder);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Location should now be verified
        final verifiedTextFinder = find.text('Location verified successfully! coordinates set.');
        expect(verifiedTextFinder, findsOneWidget);
        expect(find.text('Verified'), findsOneWidget);

        // Dismiss the first snackbar to allow the next one to show
        ScaffoldMessenger.of(tester.element(verifiedTextFinder)).removeCurrentSnackBar();
        await tester.pumpAndSettle();

        // Scroll SAVE button into view and tap it
        final saveButton = find.widgetWithText(ElevatedButton, 'SAVE');
        expect(saveButton, findsOneWidget);
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Snack bar for success should show up
        expect(find.text('Competition metadata updated successfully!'), findsOneWidget);

        // Verify that the database is updated with geocoded coordinates (Munich coords in mock is 53.5511, 9.9937)
        final savedComp = harness.db.competitions['comp-test-123']!;
        expect(savedComp.location, 'Marienplatz 1, 80331 Munich, Germany');
        expect(savedComp.latitude, 53.5511);
        expect(savedComp.longitude, 9.9937);
        expect(savedComp.city, 'Munich');
        expect(savedComp.country, 'Germany');
      },
    );

    testWidgets(
      'On-save automatic verification triggers if location is not verified and blocks saving on failure',
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
          harness.dispose();
        });

        // Seed a competition
        final comp = Competition(
          id: 'comp-test-123',
          title: 'Location Test Meet',
          startDate: DateTime.now().add(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          location: 'Berlin, Germany',
          city: 'Berlin',
          country: 'Germany',
          latitude: 52.5200,
          longitude: 13.4050,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          sportSubtype: 'Modern',
        );
        harness.db.competitions[comp.id] = comp;

        // Authenticate
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
        harness.mockAuth.triggerAuthStateChange(AuthChangeEvent.signedIn, session);
        await harness.waitForAuthSettle(tester);

        await tester.pumpWidget(
          harness.buildApp(CompetitionManagementPage(competitionId: 'comp-test-123')),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Enter EDIT mode
        await tester.tap(find.widgetWithText(ElevatedButton, 'EDIT'));
        await tester.pumpAndSettle();

        // Change location to something else but do NOT click verify button
        await tester.enterText(find.byKey(const Key('comp_location_field')), 'Rütersbarg 50, Hamburg');
        await tester.pumpAndSettle();

        // Tapping SAVE should automatically trigger location verification first
        final saveButton = find.widgetWithText(ElevatedButton, 'SAVE');
        expect(saveButton, findsOneWidget);
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Should successfully verify and save (mock always succeeds in test harness for defined addresses)
        final verifiedTextFinder = find.text('Location verified successfully! coordinates set.');
        expect(verifiedTextFinder, findsOneWidget);

        // Dismiss the first snackbar to allow the next one to show
        ScaffoldMessenger.of(tester.element(verifiedTextFinder)).removeCurrentSnackBar();
        await tester.pumpAndSettle();

        expect(find.text('Competition metadata updated successfully!'), findsOneWidget);

        final savedComp = harness.db.competitions['comp-test-123']!;
        expect(savedComp.location, 'Rütersbarg 50, Hamburg');
        expect(savedComp.latitude, 53.5511);
        expect(savedComp.longitude, 9.9937);
      },
    );
  });
}
