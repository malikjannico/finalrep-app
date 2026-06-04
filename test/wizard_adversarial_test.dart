import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/views/competition_creation_page.dart';
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

    testWidgets(
      'Adversarial Test 3: Capacity limits ignored during athlete registration',
      (tester) async {
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
        
        // Seed user profiles in mock database
        harness.db.profiles['athlete-1'] = Profile(
          id: 'athlete-1',
          username: 'athlete1',
          fullName: 'Athlete One',
          email: 'athlete1@example.com',
          sex: 'male',
        );
        harness.db.profiles['athlete-2'] = Profile(
          id: 'athlete-2',
          username: 'athlete2',
          fullName: 'Athlete Two',
          email: 'athlete2@example.com',
          sex: 'male',
        );
        harness.db.profiles['athlete-3'] = Profile(
          id: 'athlete-3',
          username: 'athlete3',
          fullName: 'Athlete Three',
          email: 'athlete3@example.com',
          sex: 'male',
        );

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
        expect(
          reg3,
          isFalse,
          reason: 'Registration must fail when capacity limit is exceeded',
        );
      },
    );

    testWidgets(
      'Adversarial Test 3b: Athlete sex eligibility validation during registration',
      (tester) async {
        // Seed association
        final assoc = Association(
          id: 'assoc-1',
          name: 'Men Association',
          description: 'Restricted to Men',
          scope: 'local',
          ownerId: 'user-1',
          rulebooks: {},
          socialChannels: {},
        );
        harness.db.associations.add(assoc.toJson());

        // Seed a Men-only athlete group
        final group = AthleteGroup(
          id: 'group-men-1',
          associationId: 'assoc-1',
          name: 'Men Group',
          sport: 'Streetlifting',
          format: 'Modern',
          gender: 'men',
          isActive: true,
        );
        harness.db.athleteGroups.add(group.toJson());

        // Seed a competition belonging to assoc-1, which has Men-only athlete groups seeded
        final comp = Competition(
          id: 'comp-sex-test',
          title: 'Sex Restricted Meet',
          location: 'Berlin Gym',
          sportType: 'Streetlifting',
          sportSubtype: 'Modern',
          associationId: 'assoc-1',
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        harness.db.competitions[comp.id] = comp;

        // 1. Register user with Male sex -> Should succeed
        harness.db.profiles['user-male'] = Profile(
          id: 'user-male',
          username: 'maleuser',
          fullName: 'Male User',
          email: 'male@example.com',
          sex: 'male',
        );
        bool regMale = await harness.competitionProvider.registerAthlete(
          competitionId: comp.id,
          userId: 'user-male',
        );
        expect(regMale, isTrue);

        // 2. Register user with Female sex -> Should fail (only Men groups exist)
        harness.db.profiles['user-female'] = Profile(
          id: 'user-female',
          username: 'femaleuser',
          fullName: 'Female User',
          email: 'female@example.com',
          sex: 'female',
        );
        bool regFemale = await harness.competitionProvider.registerAthlete(
          competitionId: comp.id,
          userId: 'user-female',
        );
        expect(regFemale, isFalse);
        expect(
          harness.competitionProvider.errorMessage,
          'You are not eligible to register for this competition based on your sex',
        );

        // 3. Register user with "Prefer not to say" -> Should fail with "Sex must be set..."
        harness.db.profiles['user-prefer-not'] = Profile(
          id: 'user-prefer-not',
          username: 'prefernotuser',
          fullName: 'Prefer Not User',
          email: 'prefernot@example.com',
          sex: 'prefer not to say',
        );
        bool regPreferNot = await harness.competitionProvider.registerAthlete(
          competitionId: comp.id,
          userId: 'user-prefer-not',
        );
        expect(regPreferNot, isFalse);
        expect(
          harness.competitionProvider.errorMessage,
          'Sex must be set in order to register as an athlete',
        );

        // 4. Register user with null/unset sex -> Should fail with "Sex must be set..."
        harness.db.profiles['user-unset'] = Profile(
          id: 'user-unset',
          username: 'unsetuser',
          fullName: 'Unset User',
          email: 'unset@example.com',
          sex: null,
        );
        bool regUnset = await harness.competitionProvider.registerAthlete(
          competitionId: comp.id,
          userId: 'user-unset',
        );
        expect(regUnset, isFalse);
        expect(
          harness.competitionProvider.errorMessage,
          'Sex must be set in order to register as an athlete',
        );
      },
    );

    testWidgets('Adversarial Test 4: Wizard permits negative entry fee amounts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        harness.buildApp(const CompetitionCreationPage()),
      );
      await tester.pumpAndSettle();

      // Step 1: Title
      await tester.enterText(
        find.byKey(const Key('comp_name_field')),
        'Negative Fee Meet',
      );
      await tester.pumpAndSettle();

      final nextButton = find.byKey(const Key('comp_next_btn'));
      await tester.tap(nextButton); // 1 -> 2
      await tester.pumpAndSettle();

      // Step 2: Location
      await tester.enterText(
        find.byKey(const Key('comp_location_field')),
        'Alexanderplatz 1, 10178 Berlin, Germany',
      );
      await tester.tap(nextButton); // 2 -> 3 (triggers verification automatically)
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      final context = tester.element(nextButton);
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();

      // Step 3: Sport & Format
      await tester.tap(nextButton); // 3 -> 4
      await tester.pumpAndSettle();

      // Step 4: Banner Image
      await tester.tap(nextButton); // 4 -> 5
      await tester.pumpAndSettle();

      // Step 5: Dates
      await tester.tap(nextButton); // 5 -> 6
      await tester.pumpAndSettle();

      // Step 6: Registration Settings
      await tester.tap(nextButton); // 6 -> 7 (Athlete Groups)
      await tester.pumpAndSettle();

      // Step 7: Athlete Groups
      await tester.tap(nextButton); // 7 -> 8 (Fees)
      await tester.pumpAndSettle();

      // Step 8: Fees
      // Toggle fees ON
      final feesToggle = find.byKey(const Key('comp_fees_toggle'));
      await tester.tap(feesToggle);
      await tester.pumpAndSettle();

      // Input negative fee amount
      final feeAmountField = find.widgetWithText(TextFormField, 'Fee Amount *');
      await tester.enterText(feeAmountField, '-50.0');
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

      // Tap Next to see if negative fee is validated/blocked
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // If the wizard allows moving to Step 9, it means negative fee was accepted!
      final step9Visible = find.text('Step 9 of 11');
      expect(
        step9Visible,
        findsNothing,
        reason: 'Negative fee amount must be blocked by validation',
      );
    });

    testWidgets(
      'Adversarial Test 5: Wizard permits waitlist enabled without capacity limit',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
        });

        await tester.pumpWidget(
          harness.buildApp(const CompetitionCreationPage()),
        );
        await tester.pumpAndSettle();

        // Step 1: Set title
        await tester.enterText(
          find.byKey(const Key('comp_name_field')),
          'Waitlist Test Meet',
        );
        await tester.pumpAndSettle();

        final nextButton = find.byKey(const Key('comp_next_btn'));
        await tester.tap(nextButton); // 1 -> 2
        await tester.pumpAndSettle();

        // Step 2: Location
        await tester.enterText(
          find.byKey(const Key('comp_location_field')),
          'Alexanderplatz 1, 10178 Berlin, Germany',
        );
        await tester.tap(nextButton); // 2 -> 3 (triggers verification automatically)
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pumpAndSettle();

        final context = tester.element(nextButton);
        ScaffoldMessenger.of(context).clearSnackBars();
        await tester.pumpAndSettle();

        // Step 3: Sport & Format
        await tester.tap(nextButton); // 3 -> 4
        await tester.pumpAndSettle();

        // Step 4: Banner Image
        await tester.tap(nextButton); // 4 -> 5
        await tester.pumpAndSettle();

        // Step 5: Dates
        await tester.tap(nextButton); // 5 -> 6
        await tester.pumpAndSettle();

        // Step 6: Registration Settings
        // Enable waitlist but leave capacity limit empty (unlimited)
        final waitlistToggle = find.byKey(const Key('comp_waitlist_toggle'));
        await tester.tap(
          find.descendant(of: waitlistToggle, matching: find.byType(Switch)),
        );
        await tester.pumpAndSettle();

        // Proceed to Step 7
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // A waitlist makes no sense without a capacity limit! Validation should block this.
        final step7Visible = find.text('Step 7 of 11');
        expect(
          step7Visible,
          findsNothing,
          reason: 'Waitlist should not be enabled without a capacity limit',
        );
      },
    );

    group('Additional Validation & Capacity Bound Checks', () {
      testWidgets(
        'Adversarial Test 6: Wizard permits negative capacity limits',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1200);
          tester.view.devicePixelRatio = 1.0;
          await tester.binding.setSurfaceSize(const Size(1200, 1200));
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.binding.setSurfaceSize(null);
          });

          await tester.pumpWidget(
            harness.buildApp(const CompetitionCreationPage()),
          );
          await tester.pumpAndSettle();

          // Step 1: Set title
          await tester.enterText(
            find.byKey(const Key('comp_name_field')),
            'Negative Capacity Meet',
          );
          await tester.pumpAndSettle();

          final nextButton = find.byKey(const Key('comp_next_btn'));
          await tester.tap(nextButton); // 1 -> 2
          await tester.pumpAndSettle();

          // Step 2: Location
          await tester.enterText(
            find.byKey(const Key('comp_location_field')),
            'Alexanderplatz 1, 10178 Berlin, Germany',
          );
          await tester.tap(nextButton); // 2 -> 3 (triggers verification automatically)
          await tester.pump(const Duration(milliseconds: 550));
          await tester.pumpAndSettle();

          final context = tester.element(nextButton);
          ScaffoldMessenger.of(context).clearSnackBars();
          await tester.pumpAndSettle();

          // Step 3: Sport & Format
          await tester.tap(nextButton); // 3 -> 4
          await tester.pumpAndSettle();

          // Step 4: Banner Image
          await tester.tap(nextButton); // 4 -> 5
          await tester.pumpAndSettle();

          // Step 5: Dates
          await tester.tap(nextButton); // 5 -> 6
          await tester.pumpAndSettle();

          // Step 6: Registration Settings
          // Set negative capacity
          final maxAthletesField = find.widgetWithText(
            TextFormField,
            'Total Athlete Capacity Limit',
          );
          await tester.enterText(maxAthletesField, '-5');
          await tester.pumpAndSettle();

          // Proceed to Step 7
          await tester.tap(nextButton);
          await tester.pumpAndSettle();

          // Negative capacity must be blocked by validation
          final step7Visible = find.text('Step 7 of 11');
          expect(
            step7Visible,
            findsNothing,
            reason: 'Negative capacity limit must be blocked by validation',
          );
        },
      );
    });
  });
}
