import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/views/competition_creation_wizard.dart';
import 'package:finalrep_app/views/competition_detail_page.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('R5 Competition Creation Wizard & Custom Fields Tests', () {
    test('Competition Model - JSON Serialization/Deserialization for R5 Fields', () {
      final json = {
        'id': 'comp-r5-1',
        'title': 'R5 Streetlifting Championship',
        'description': 'Lifting with new R5 features',
        'start_date': '2026-06-15T09:00:00Z',
        'end_date': '2026-06-15T18:00:00Z',
        'location': 'Hamburg, Germany',
        'sport_type': 'Streetlifting',
        'sport_subtype': 'Modern',
        'status': 'upcoming',
        'created_at': '2026-05-20T20:00:00Z',
        'updated_at': '2026-05-20T20:00:00Z',
        'registration_start': '2026-06-01T00:00:00Z',
        'registration_end': '2026-06-10T23:59:59Z',
        'requires_fees': true,
        'fee_amount': 35.0,
        'fee_currency': 'EUR',
        'bank_details': 'DE1234567890',
        'payment_description': 'Ref-123',
        'registration_mode': 'approval',
        'max_athletes': 40,
        'enable_waitlist': true,
        'volunteer_needs': true,
        'volunteer_positions': ['Loader', 'Judge'],
        'volunteer_shifts': {
          'Loader': ['Morning'],
        },
        'custom_athlete_fields': [
          {'name': 'Shirt Size', 'type': 'dropdown', 'options': ['S', 'M', 'L']}
        ],
        'disclaimer_type': 'text',
        'disclaimer_text': 'Accept terms',
        'banner_safe_zone_guide': true,
      };

      final comp = Competition.fromJson(json);
      expect(comp.registrationStart, isNotNull);
      expect(comp.requiresFees, true);
      expect(comp.feeAmount, 35.0);
      expect(comp.feeCurrency, 'EUR');
      expect(comp.bankDetails, 'DE1234567890');
      expect(comp.paymentDescription, 'Ref-123');
      expect(comp.registrationMode, 'approval');
      expect(comp.maxAthletes, 40);
      expect(comp.enableWaitlist, true);
      expect(comp.volunteerNeeds, true);
      expect(comp.volunteerPositions, containsAll(['Loader', 'Judge']));
      expect(comp.volunteerShifts?['Loader'], contains('Morning'));
      expect(comp.customAthleteFields?.first['name'], 'Shirt Size');
      expect(comp.disclaimerType, 'text');
      expect(comp.disclaimerText, 'Accept terms');
      expect(comp.bannerSafeZoneGuide, true);

      final serialized = comp.toJson();
      expect(serialized['requires_fees'], true);
      expect(serialized['fee_amount'], 35.0);
      expect(serialized['registration_mode'], 'approval');
    });

    test('Competition Model - copyWith copies R5 fields correctly', () {
      final comp1 = Competition(
        id: 'comp-1',
        title: 'Original Title',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        location: 'Hamburg',
        sportSubtype: 'Modern',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        requiresFees: false,
        registrationMode: 'fcfs',
      );

      final comp2 = comp1.copyWith(
        title: 'Updated Title',
        requiresFees: true,
        feeAmount: 20.0,
        registrationMode: 'approval',
        customAthleteFields: [{'name': 'Question 1', 'type': 'text'}],
      );

      expect(comp2.title, 'Updated Title');
      expect(comp2.requiresFees, true);
      expect(comp2.feeAmount, 20.0);
      expect(comp2.registrationMode, 'approval');
      expect(comp2.customAthleteFields?.first['name'], 'Question 1');
    });

    testWidgets('Widget Test - Competition Creation Wizard navigation and validation', (tester) async {
      final harness = E2ETestHarness();
      await harness.initialize();

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(harness.buildApp(const CreateCompetitionWizard()));
      await tester.pumpAndSettle();

      // We are at Step 1: Info. Try to click Next without filling title - validation should fail
      final nextButton = find.byKey(const Key('comp_next_btn'));
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Should show 'Title is required' validation error
      expect(find.text('Title is required'), findsOneWidget);

      // Fill in title & location
      await tester.enterText(find.byKey(const Key('comp_name_field')), 'Mega Streetlifting Meet');
      await tester.enterText(find.byKey(const Key('comp_location_field')), 'Hamburg Gym');
      await tester.pumpAndSettle();

      // Verify location button test
      final verifyLocBtn = find.widgetWithText(ElevatedButton, 'Verify Location');
      expect(verifyLocBtn, findsOneWidget);
      await tester.tap(verifyLocBtn);
      await tester.pumpAndSettle();
      expect(find.text('Location verified successfully! coordinates set.'), findsOneWidget);

      // Dismiss the SnackBar so it doesn't obscure the next button at the bottom of the screen
      final context = tester.element(find.byKey(const Key('comp_next_btn')));
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();

      // Now click Next again to proceed to Step 2: Dates
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.text('Step 2: Dates & Deadlines'), findsOneWidget);

      // Go to Step 3: Registration
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
      expect(find.text('Step 3: Registration Mode & Capacity Limits'), findsOneWidget);

      // Find and tap waitlist toggle Switch
      final waitlistToggle = find.byKey(const Key('comp_waitlist_toggle'));
      expect(waitlistToggle, findsOneWidget);
      await tester.tap(find.descendant(of: waitlistToggle, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      // Enter capacity limit since waitlist is enabled
      final maxAthletesField = find.widgetWithText(TextFormField, 'Total Athlete Capacity Limit');
      await tester.enterText(maxAthletesField, '50');
      await tester.pumpAndSettle();

      // Go to Step 4: Fees
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
      expect(find.text('Step 4: Fees & Payment Config'), findsOneWidget);

      // Fees switch toggle Switch
      final feesToggle = find.byKey(const Key('comp_fees_toggle'));
      expect(feesToggle, findsOneWidget);
      await tester.tap(find.descendant(of: feesToggle, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      // Fee amount field and IBAN field should now be visible and required
      expect(find.text('Fee Amount *'), findsOneWidget);
      expect(find.text('IBAN / Bank Details *'), findsOneWidget);

      harness.dispose();
    });

    testWidgets('Widget Test - Volunteer Application flow on detail page', (tester) async {
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

      // Seed a competition with volunteer positions & needs enabled
      final comp = Competition(
        id: 'comp-v1',
        title: 'Volunteer Comp',
        startDate: DateTime.now().add(const Duration(days: 2)),
        endDate: DateTime.now().add(const Duration(days: 3)),
        location: 'Berlin',
        sportSubtype: 'Classic',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        volunteerNeeds: true,
        volunteerPositions: ['Judge', 'Loader', 'Scorekeeper'],
        volunteerShifts: {
          'Judge': ['Morning', 'Afternoon'],
        },
        disclaimerType: 'text',
        disclaimerText: 'Do not sue us.',
      );
      harness.db.competitions[comp.id] = comp;

      await tester.pumpWidget(harness.buildApp(CompetitionDetailPage(competition: comp)));
      await tester.pumpAndSettle();

      // Click "Apply as Volunteer"
      final applyButton = find.widgetWithText(OutlinedButton, 'Apply as Volunteer');
      expect(applyButton, findsOneWidget);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Bottom sheet should open with Title
      expect(find.text('Apply as Volunteer'), findsWidgets); // widget title
      expect(find.text('Select Preferred Roles'), findsOneWidget);

      // Verify that chips for roles are visible
      expect(find.text('Judge'), findsWidgets);
      expect(find.text('Loader'), findsWidgets);
      expect(find.text('Scorekeeper'), findsWidgets);

      // Select 'Judge' and 'Loader'
      await tester.tap(find.text('Judge').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loader').first);
      await tester.pumpAndSettle();

      // Reorderable preference list should show the selected roles
      expect(find.text('Rank Preference (Drag to Reorder)'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);

      // Simulate drag and drop gesture in ReorderableListView
      final judgeTile = find.text('Judge').last;
      final gesture = await tester.startGesture(tester.getCenter(judgeTile));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.moveBy(const Offset(0.0, 100.0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify disclaimer guards submit button
      final submitBtn = find.widgetWithText(ElevatedButton, 'Submit Application');
      expect(submitBtn, findsOneWidget);
      
      // Submit button should be disabled because disclaimer is not accepted
      ElevatedButton buttonWidget = tester.widget<ElevatedButton>(submitBtn);
      expect(buttonWidget.onPressed, isNull);

      // Tap disclaimer checkbox key comp_disclaimer
      final disclaimerCheckbox = find.byKey(const Key('comp_disclaimer'));
      expect(disclaimerCheckbox, findsOneWidget);
      await tester.tap(disclaimerCheckbox);
      await tester.pumpAndSettle();

      // Submit button should now be enabled
      buttonWidget = tester.widget<ElevatedButton>(submitBtn);
      expect(buttonWidget.onPressed, isNotNull);

      // Tap submit and verify it calls submitVolunteerApplication and inserts to fake DB
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // The sheet should close
      expect(find.text('Select Preferred Roles'), findsNothing);

      // Verify the application has been inserted into DB
      expect(harness.db.volunteerApplications.length, 1);
      final app = harness.db.volunteerApplications.first;
      expect(app['competition_id'], 'comp-v1');
      expect(app['preferred_roles'], containsAll(['Judge', 'Loader']));
      expect(app['disclaimer_accepted'], true);

      harness.dispose();
    });
  });
}
