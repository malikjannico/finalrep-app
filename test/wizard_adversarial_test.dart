import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/views/competition_creation_wizard.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('Competition Creation & Registration Adversarial Tests', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.initialize();
    });

    tearDown(() {
      harness.dispose();
    });

    testWidgets('Adversarial Test 3: Capacity limits ignored during athlete registration', (tester) async {
      // Seed a competition with capacity limit of 2 athletes
      final comp = Competition(
        id: 'comp-capacity-test',
        title: 'Limited Capacity Meet',
        location: 'Berlin Gym',
        sportSubtype: 'Classic',
        maxAthletes: 2,
        startDate: DateTime.now().add(const Duration(days: 2)),
        endDate: DateTime.now().add(const Duration(days: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      harness.db.competitions[comp.id] = comp;

      // Register Athlete 1 -> Should succeed
      bool reg1 = await harness.competitionProvider.registerAthlete(
        competitionId: comp.id,
        userId: 'athlete-1',
      );
      expect(reg1, isTrue);

      // Register Athlete 2 -> Should succeed
      bool reg2 = await harness.competitionProvider.registerAthlete(
        competitionId: comp.id,
        userId: 'athlete-2',
      );
      expect(reg2, isTrue);

      // Register Athlete 3 -> Should fail because capacity is 2!
      bool reg3 = await harness.competitionProvider.registerAthlete(
        competitionId: comp.id,
        userId: 'athlete-3',
      );
      
      // If the bug exists, this will succeed and register a 3rd athlete!
      debugPrint('REGISTRATION 3 SUCCESS: $reg3');
      expect(reg3, isFalse, reason: 'Registration must fail when capacity limit is exceeded');
    });

    testWidgets('Adversarial Test 4: Wizard permits negative entry fee amounts', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(harness.buildApp(const CreateCompetitionWizard()));
      await tester.pumpAndSettle();

      // Step 1: Info
      await tester.enterText(find.byKey(const Key('comp_name_field')), 'Negative Fee Meet');
      await tester.enterText(find.byKey(const Key('comp_location_field')), 'Berlin Gym');
      final nextButton = find.byKey(const Key('comp_next_btn'));
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Step 2: Dates
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Step 3: Registration
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Step 4: Fees
      // Toggle fees ON
      final feesToggle = find.byKey(const Key('comp_fees_toggle'));
      await tester.tap(find.descendant(of: feesToggle, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      // Input negative fee amount
      final feeAmountField = find.widgetWithText(TextFormField, 'Fee Amount *');
      await tester.enterText(feeAmountField, '-50.0');
      await tester.enterText(find.widgetWithText(TextFormField, 'IBAN / Bank Details *'), 'DE9876543210');
      await tester.enterText(find.widgetWithText(TextFormField, 'Payment Reference / Description *'), 'Negative Fee Test');
      await tester.pumpAndSettle();

      // Tap Next to see if negative fee is validated/blocked
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // If the wizard allows moving to Step 5 (Volunteer Setup), it means negative fee was accepted!
      final step5Visible = find.text('Step 5: Volunteer Setup');
      expect(step5Visible, findsNothing, reason: 'Negative fee amount must be blocked by validation');
    });

    testWidgets('Adversarial Test 5: Wizard permits waitlist enabled without capacity limit', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(harness.buildApp(const CreateCompetitionWizard()));
      await tester.pumpAndSettle();

      // Step 1: Info
      await tester.enterText(find.byKey(const Key('comp_name_field')), 'Waitlist Test Meet');
      await tester.enterText(find.byKey(const Key('comp_location_field')), 'Berlin Gym');
      final nextButton = find.byKey(const Key('comp_next_btn'));
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Step 2: Dates
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Step 3: Registration
      // Enable waitlist but leave capacity limit empty (unlimited)
      final waitlistToggle = find.byKey(const Key('comp_waitlist_toggle'));
      await tester.tap(find.descendant(of: waitlistToggle, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      // Proceed to Step 4
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // A waitlist makes no sense without a capacity limit! Validation should block this.
      // If it moves to Step 4 (Fees & Payment Config), it's a validation gap.
      final step4Visible = find.text('Step 4: Fees & Payment Config');
      expect(step4Visible, findsNothing, reason: 'Waitlist should not be enabled without a capacity limit');
    });

    group('Additional Validation & Capacity Bound Checks', () {
      testWidgets('Adversarial Test 6: Wizard permits negative capacity limits', (tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
        });

        await tester.pumpWidget(harness.buildApp(const CreateCompetitionWizard()));
        await tester.pumpAndSettle();

        // Step 1: Info
        await tester.enterText(find.byKey(const Key('comp_name_field')), 'Negative Capacity Meet');
        await tester.enterText(find.byKey(const Key('comp_location_field')), 'Berlin Gym');
        final nextButton = find.byKey(const Key('comp_next_btn'));
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Step 2: Dates
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Step 3: Registration
        // Set negative capacity
        final maxAthletesField = find.widgetWithText(TextFormField, 'Total Athlete Capacity Limit');
        await tester.enterText(maxAthletesField, '-5');
        await tester.pumpAndSettle();

        // Proceed to Step 4
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Negative capacity must be blocked by validation
        final step4Visible = find.text('Step 4: Fees & Payment Config');
        expect(step4Visible, findsNothing, reason: 'Negative capacity limit must be blocked by validation');
      });
    });
  });
}
