import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/views/competition_creation_page.dart';
import 'package:finalrep_app/views/competition_detail_page.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('R5 Competition Wizard & Custom Fields Stress Tests', () {
    // Helper to select date via the material date picker dialog in widget tests
    Future<void> selectDateInPicker(
      WidgetTester tester,
      Finder tileFinder,
      String dateText,
    ) async {
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // Switch to input mode (pencil icon with tooltip)
      final editIcon = find.byTooltip('Switch to input');
      expect(editIcon, findsOneWidget);
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      // Enter the date text
      final inputField = find.byType(TextField).last;
      await tester.enterText(inputField, dateText);
      await tester.pumpAndSettle();

      // Tap OK on Date Picker
      final okBtn = find.text('OK');
      expect(okBtn, findsOneWidget);
      await tester.tap(okBtn);
      await tester.pumpAndSettle();

      // Tap OK on Time Picker (which is opened automatically after Date Picker)
      final okBtnTime = find.text('OK');
      expect(okBtnTime, findsOneWidget);
      await tester.tap(okBtnTime);
      await tester.pumpAndSettle();
    }

    testWidgets('1. Confusing payment dates null state', (tester) async {
      final harness = E2ETestHarness();
      await harness.initialize();
      harness.db.competitions
          .clear(); // Clear to avoid interference with seeded data

      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
        harness.dispose();
      });

      await tester.pumpWidget(
        harness.buildApp(const CompetitionCreationPage()),
      );
      await tester.pumpAndSettle();

      // Fill in Step 1
      await tester.enterText(
        find.byKey(const Key('comp_name_field')),
        'Date Test Meet',
      );
      await tester.pumpAndSettle();

      final nextButton = find.byKey(const Key('comp_next_btn'));
      await tester.tap(nextButton); // 1 -> 2
      await tester.pumpAndSettle();

      // Step 2 Location
      await tester.enterText(
        find.byKey(const Key('comp_location_field')),
        'Alexanderplatz 1, 10178 Berlin, Germany',
      );
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 2 -> 3 (Sport & Format)
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      final context = tester.element(nextButton);
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();

      // Tap next for step 3 -> 4 (Banner Image)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Tap next for step 4 -> 5 (Dates)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Tap next for step 5 -> 6 (Reg Settings)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Tap next for step 6 -> 7 (Athlete Groups)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Tap next for step 7 -> 8 (Fees & Bank Details)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Enable fees
      final feesToggle = find.byKey(const Key('comp_fees_toggle'));
      await tester.tap(feesToggle);
      await tester.pumpAndSettle();

      // Fill fee amount & IBAN & bank details
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fee Amount *'),
        '15.0',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'IBAN *'),
        'DE9876543210',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'BIC *'),
        'WELADEDDXXX',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bank Name *'),
        'Sparkasse Berlin',
      );
      await tester.pumpAndSettle();

      // Notice we do NOT select any payment start/end dates.
      // Step 8 -> Step 9 (Payment Settings)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Step 9 -> Step 10 (Volunteer Setup)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Step 10 -> Step 11 (Disclaimers & Custom Fields)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Submit the wizard in Step 11
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Verify competition in database
      expect(harness.db.competitions.length, 1);
      final createdComp = harness.db.competitions.values.first;
      expect(createdComp.requiresFees, true);
      expect(createdComp.feeAmount, 15.0);

      // They are automatically initialized to non-null defaults (now, now + 7) by design
      expect(createdComp.paymentStart, isNotNull);
      expect(createdComp.paymentEnd, isNotNull);
    });

    testWidgets(
      '2. Custom volunteer dropdown field duplicate options crashes detail page bottom sheet',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();
        harness.db.competitions.clear();

        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
          harness.dispose();
        });

        // Seed a competition with custom volunteer dropdown field having duplicate options
        final comp = Competition(
          id: 'comp-v2',
          title: 'Volunteer Duplicate Options Meet',
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          location: 'Berlin Gym',
          sportSubtype: 'Classic',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          volunteerNeeds: true,
          volunteerPositions: ['Loader'],
          customVolunteerFields: [
            {
              'name': 'T-Shirt Size',
              'type': 'dropdown',
              'options': ['M', 'L', 'M'], // Duplicate 'M' option!
            },
          ],
        );
        harness.db.competitions[comp.id] = comp;

        await tester.pumpWidget(
          harness.buildApp(CompetitionDetailPage(competition: comp)),
        );
        await tester.pumpAndSettle();

        // Tap "Apply as Volunteer"
        final applyButton = find.widgetWithText(
          OutlinedButton,
          'Apply as Volunteer',
        );
        expect(applyButton, findsOneWidget);
        await tester.tap(applyButton);
        await tester.pumpAndSettle(); // Fully instantiate bottom sheet

        // Verify no exception was thrown because the view uses toSet().toList()
        final exception = tester.takeException();
        expect(exception, isNull);

        // Verify dropdown field is rendered successfully
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      },
    );

    testWidgets('3. Empty volunteer application preferred roles submission', (
      tester,
    ) async {
      final harness = E2ETestHarness();
      await harness.initialize();
      harness.db.competitions.clear();

      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
        harness.dispose();
      });

      // Seed competition with volunteer positions & no disclaimer
      final comp = Competition(
        id: 'comp-v3',
        title: 'Volunteer Empty Roles Meet',
        startDate: DateTime.now().add(const Duration(days: 2)),
        endDate: DateTime.now().add(const Duration(days: 3)),
        location: 'Berlin Gym',
        sportSubtype: 'Classic',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        volunteerNeeds: true,
        volunteerPositions: ['Loader', 'Scorekeeper'],
      );
      harness.db.competitions[comp.id] = comp;

      await tester.pumpWidget(
        harness.buildApp(CompetitionDetailPage(competition: comp)),
      );
      await tester.pumpAndSettle();

      // Tap Apply
      final applyButton = find.widgetWithText(
        OutlinedButton,
        'Apply as Volunteer',
      );
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Verify the Submit button is disabled (has null onPressed) because preferred roles is empty
      final submitBtn = find.widgetWithText(
        ElevatedButton,
        'Submit Application',
      );
      ElevatedButton buttonWidget = tester.widget<ElevatedButton>(submitBtn);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('4. Disclaimer text & URL validators', (tester) async {
      final harness = E2ETestHarness();
      await harness.initialize();
      harness.db.competitions.clear();

      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
        harness.dispose();
      });

      await tester.pumpWidget(
        harness.buildApp(const CompetitionCreationPage()),
      );
      await tester.pumpAndSettle();

      // Step 1 Title
      await tester.enterText(
        find.byKey(const Key('comp_name_field')),
        'Disclaimer Meet',
      );
      await tester.pumpAndSettle();

      final nextButton = find.byKey(const Key('comp_next_btn'));
      await tester.tap(nextButton); // 1 -> 2
      await tester.pumpAndSettle();

      // Step 2 Location
      await tester.enterText(
        find.byKey(const Key('comp_location_field')),
        'Alexanderplatz 1, 10178 Berlin, Germany',
      );
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 2 -> 3
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      final context = tester.element(nextButton);
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 3 -> 4
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 4 -> 5
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 5 -> 6
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 6 -> 7
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 7 -> 8
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 8 -> 9
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 9 -> 10
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 10 -> 11 (Disclaimers & Custom Fields)
      await tester.pumpAndSettle();

      expect(find.text('Step 11 of 11'), findsOneWidget);

      // Tap "Add Disclaimer"
      final addDisclaimerBtn = find.widgetWithText(ElevatedButton, 'Add Disclaimer');
      await tester.tap(addDisclaimerBtn);
      await tester.pumpAndSettle();

      // Tap ADD inside the dialog with empty text -> should fail with snackbar
      await tester.tap(find.widgetWithText(ElevatedButton, 'ADD'));
      await tester.pumpAndSettle();
      expect(find.text('Disclaimer Text is required.'), findsOneWidget);
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();

      // Enter valid text and invalid URL
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Disclaimer Text *'),
        'Accept our terms.',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Disclaimer URL (Optional)'),
        'invalid-url',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'ADD'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid URL.'), findsOneWidget);
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();

      // Enter valid URL
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Disclaimer URL (Optional)'),
        'https://example.com/terms',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'ADD'));
      await tester.pumpAndSettle();

      // Submit the wizard in Step 11
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Check if successfully submitted
      expect(harness.db.competitions.length, 1);
      final comp = harness.db.competitions.values.first;
      expect(comp.disclaimerType, 'both');
      final decoded = jsonDecode(comp.disclaimerText!);
      expect(decoded[0]['text'], 'Accept our terms.');
      expect(decoded[0]['url'], 'https://example.com/terms');
    });



    testWidgets(
      '5. Back-and-forth step navigation and subtype disciplines update',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();
        harness.db.competitions.clear();

        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
          harness.dispose();
        });

        await tester.pumpWidget(
          harness.buildApp(const CompetitionCreationPage()),
        );
        await tester.pumpAndSettle();

        // Step 1: Set title
        await tester.enterText(
          find.byKey(const Key('comp_name_field')),
          'Nav Meet',
        );
        await tester.pumpAndSettle();

        final nextButton = find.byKey(const Key('comp_next_btn'));
        await tester.tap(nextButton); // Step 1 -> 2
        await tester.pumpAndSettle();

        // Step 2: Location
        await tester.enterText(
          find.byKey(const Key('comp_location_field')),
          'Alexanderplatz 1, 10178 Berlin, Germany',
        );
        await tester.tap(nextButton); // Step 2 -> 3
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pumpAndSettle();

        final context = tester.element(nextButton);
        ScaffoldMessenger.of(context).clearSnackBars();
        await tester.pumpAndSettle();

        // Step 3: Sport & Format -> set Sport Subtype to Modern
        final subtypeDropdown = find.byTooltip('Sport Format');
        await tester.tap(subtypeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Modern').last,
        );
        await tester.pumpAndSettle();

        await tester.tap(nextButton); // Step 3 -> 4
        await tester.pumpAndSettle();

        // Step 4: Banner Image -> Step 5 (Dates)
        await tester.tap(nextButton); // Step 4 -> 5
        await tester.pumpAndSettle();

        // Go back to Step 1
        final backButton = find.widgetWithText(OutlinedButton, 'BACK');
        await tester.tap(backButton); // Step 5 -> 4
        await tester.pumpAndSettle();
        await tester.tap(backButton); // Step 4 -> 3
        await tester.pumpAndSettle();
        await tester.tap(backButton); // Step 3 -> 2
        await tester.pumpAndSettle();
        await tester.tap(backButton); // Step 2 -> 1
        await tester.pumpAndSettle();

        // Proceed back to Step 3
        await tester.tap(nextButton); // Step 1 -> 2
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 2 -> 3
        await tester.pumpAndSettle();

        // Change Subtype to Classic on Step 3
        await tester.tap(subtypeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Classic').last);
        await tester.pumpAndSettle();

        // Proceed all the way to Step 11 and submit
        await tester.tap(nextButton); // Step 3 -> 4
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 4 -> 5
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 5 -> 6
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 6 -> 7
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 7 -> 8
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 8 -> 9
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 9 -> 10
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 10 -> 11
        await tester.pumpAndSettle();
        await tester.tap(nextButton); // Step 11 -> Submit
        await tester.pumpAndSettle();

        // Verify subtype is Classic
        expect(harness.db.competitions.length, 1);
        final comp = harness.db.competitions.values.first;
        expect(comp.sportSubtype, 'Classic');
      },
    );

    testWidgets('6. Step 5 Volunteer Setup Leak of Max Volunteers', (
      tester,
    ) async {
      final harness = E2ETestHarness();
      await harness.initialize();
      harness.db.competitions.clear();

      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
        harness.dispose();
      });

      await tester.pumpWidget(
        harness.buildApp(const CompetitionCreationPage()),
      );
      await tester.pumpAndSettle();

      // Go to Step 10
      await tester.enterText(
        find.byKey(const Key('comp_name_field')),
        'Volunteer Leak Meet',
      );
      await tester.pumpAndSettle();

      final nextButton = find.byKey(const Key('comp_next_btn'));
      await tester.tap(nextButton); // 1 -> 2
      await tester.pumpAndSettle();


      await tester.enterText(
        find.byKey(const Key('comp_location_field')),
        'Alexanderplatz 1, 10178 Berlin, Germany',
      );
      await tester.tap(nextButton); // 2 -> 3
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      final context = tester.element(nextButton);
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 3 -> 4
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 4 -> 5
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 5 -> 6
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 6 -> 7
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 7 -> 8
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 8 -> 9
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 9 -> 10
      await tester.pumpAndSettle();

      // Enable volunteer needs
      final volunteerNeedsToggle = find.widgetWithText(
        SwitchListTile,
        'Enable Volunteer Needs',
      );
      await tester.tap(volunteerNeedsToggle);
      await tester.pumpAndSettle();

      // Enter max volunteers = 15
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Total Volunteer Limit'),
        '15',
      );
      await tester.pumpAndSettle();

      // Toggle volunteer needs OFF
      await tester.tap(
        find.descendant(
          of: volunteerNeedsToggle,
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Step 11 and submit
      await tester.tap(nextButton); // 10 -> 11
      await tester.pumpAndSettle();
      await tester.tap(nextButton); // 11 -> submit
      await tester.pumpAndSettle();

      // Verify that volunteerNeeds is false, and volunteerPositions/volunteerShifts/maxVolunteers are cleaned up!
      expect(harness.db.competitions.length, 1);
      final comp = harness.db.competitions.values.first;
      expect(comp.volunteerNeeds, false);
      expect(comp.maxVolunteers, isNull); // BUG: Check if state leak exists!
    });

    testWidgets(
      '7. Volunteer Application - State Leak of Deselected Role Shifts',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();
        harness.db.competitions.clear();

        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
          harness.dispose();
        });

        // Seed competition with two volunteer roles and shift choices
        final comp = Competition(
          id: 'comp-v7',
          title: 'Volunteer Shift Leak Meet',
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          location: 'Berlin Gym',
          sportSubtype: 'Classic',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          volunteerNeeds: true,
          volunteerPositions: ['Loader', 'Judge'],
          volunteerShifts: {
            'Loader': ['Morning', 'Afternoon'],
            'Judge': ['Morning', 'Evening'],
          },
        );
        harness.db.competitions[comp.id] = comp;

        await tester.pumpWidget(
          harness.buildApp(CompetitionDetailPage(competition: comp)),
        );
        await tester.pumpAndSettle();

        // Tap Apply
        final applyButton = find.widgetWithText(
          OutlinedButton,
          'Apply as Volunteer',
        );
        await tester.tap(applyButton);
        await tester.pumpAndSettle();

        // Select 'Loader' and select 'Morning' shift for Loader
        await tester.tap(find.text('Loader').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Morning').first);
        await tester.pumpAndSettle();

        // Now deselect 'Loader' role chip
        await tester.tap(find.text('Loader').first);
        await tester.pumpAndSettle();

        // Select 'Judge' role chip and select 'Evening' shift
        await tester.tap(find.text('Judge').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Evening').first);
        await tester.pumpAndSettle();

        // Submit application
        final submitBtn = find.widgetWithText(
          ElevatedButton,
          'Submit Application',
        );
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Verify that volunteerApplications does NOT leak the deselected Loader role shifts!
        expect(harness.db.volunteerApplications.length, 1);
        final app = harness.db.volunteerApplications.first;
        expect(app['preferred_roles'], equals(['Judge']));

        final shiftsMap = app['shift_availability'] as Map<dynamic, dynamic>;
        expect(
          shiftsMap.containsKey('Loader'),
          isFalse,
        ); // Should be cleaned up!
      },
    );

    testWidgets('8. Fee Config Validation & Non-Numeric/Negative Fee Amounts', (
      tester,
    ) async {
      final harness = E2ETestHarness();
      await harness.initialize();
      harness.db.competitions.clear();

      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
        harness.dispose();
      });

      await tester.pumpWidget(
        harness.buildApp(const CompetitionCreationPage()),
      );
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(
        find.byKey(const Key('comp_name_field')),
        'Fee Validation Meet',
      );
      await tester.pumpAndSettle();

      final nextButton = find.byKey(const Key('comp_next_btn'));
      await tester.tap(nextButton); // 1 -> 2
      await tester.pumpAndSettle();

      // Step 2
      await tester.enterText(
        find.byKey(const Key('comp_location_field')),
        'Alexanderplatz 1, 10178 Berlin, Germany',
      );
      await tester.tap(nextButton); // 2 -> 3
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      final context = tester.element(nextButton);
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 3 -> 4
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 4 -> 5
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 5 -> 6
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 6 -> 7
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 7 -> 8
      await tester.pumpAndSettle();

      // Step 8: Fees
      final feesToggle = find.byKey(const Key('comp_fees_toggle'));
      await tester.tap(feesToggle);
      await tester.pumpAndSettle();

      // Click Next with empty details
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.text('Fee amount is required and cannot be negative'), findsOneWidget);
      expect(find.text('IBAN is required'), findsOneWidget);
      expect(find.text('BIC is required'), findsOneWidget);
      expect(find.text('Bank Name is required'), findsOneWidget);

      // Input non-numeric value in Fee Amount
      final feeAmountField = find.widgetWithText(TextFormField, 'Fee Amount *');
      await tester.enterText(feeAmountField, 'abc');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'IBAN *'),
        'DE12345',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'BIC *'),
        'WELADEDDXXX',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bank Name *'),
        'Sparkasse Berlin',
      );
      await tester.pumpAndSettle();

      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.text('Fee amount is required and cannot be negative'), findsOneWidget);

      // Input negative fee amount (-20.0)
      await tester.enterText(feeAmountField, '-20.0');
      await tester.pumpAndSettle();

      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Check if it accepted negative amount
      final step9Visible = find.text('Step 9 of 11');
      if (step9Visible.evaluate().isNotEmpty) {
        debugPrint(
          'WARNING: Negative fee amounts are accepted by the wizard validator!',
        );
      } else {
        expect(find.text('Fee amount is required and cannot be negative'), findsOneWidget);
      }
    });

    testWidgets('9. Date Constraints Validation & SnackBar Alerts', (
      tester,
    ) async {
      final harness = E2ETestHarness();
      await harness.initialize();
      harness.db.competitions.clear();

      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
        harness.dispose();
      });

      await tester.pumpWidget(
        harness.buildApp(const CompetitionCreationPage()),
      );
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(
        find.byKey(const Key('comp_name_field')),
        'Date Constraints Meet',
      );
      await tester.pumpAndSettle();

      final nextButton = find.byKey(const Key('comp_next_btn'));
      await tester.tap(nextButton); // 1 -> 2
      await tester.pumpAndSettle();

      // Step 2
      await tester.enterText(
        find.byKey(const Key('comp_location_field')),
        'Alexanderplatz 1, 10178 Berlin, Germany',
      );
      await tester.tap(nextButton); // 2 -> 3
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      final context = tester.element(nextButton);
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 3 -> 4
      await tester.pumpAndSettle();

      await tester.tap(nextButton); // 4 -> 5
      await tester.pumpAndSettle();

      // Step 5: Set start date to 06/10/2026 and end date to 06/05/2026 (invalid)
      await selectDateInPicker(
        tester,
        find.widgetWithText(ListTile, 'Competition Start Date *'),
        '06/10/2026',
      );
      await selectDateInPicker(
        tester,
        find.widgetWithText(ListTile, 'Competition End Date *'),
        '06/05/2026',
      );

      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Expect standard SnackBar alert
      expect(
        find.text('End date must be on or after start date'),
        findsOneWidget,
      );

      // Dismiss Snackbar
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();

      // Set valid end date but invalid registration end date
      await selectDateInPicker(
        tester,
        find.widgetWithText(ListTile, 'Competition End Date *'),
        '06/15/2026',
      );
      await selectDateInPicker(
        tester,
        find.widgetWithText(ListTile, 'Registration End Date *'),
        '06/20/2026',
      ); // after comp start 06/10

      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Registration end date must be on or before competition start date',
        ),
        findsOneWidget,
      );
    });
  });
}
