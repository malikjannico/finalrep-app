import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/views/competition_detail_page.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('Competition Random Registration Mode Tests', () {
    testWidgets(
      'Athletes registered under random mode are pending, and runRandomDraw shuffles and assigns spots according to limits and waitlist settings',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();
        addTearDown(harness.dispose);

        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
        });

        // 1. Authenticate as organizer
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

        // 2. Seed a competition with athlete groups in random mode
        final comp = Competition(
          id: 'comp-random-test',
          title: 'Random Lottery Meet',
          location: 'Hamburg Gym',
          sportSubtype: 'Classic',
          associationId: 'assoc-1',
          registrationMode: 'random',
          enableWaitlist: true,
          // Registration period has ended so draw can be run
          registrationStart: DateTime.now().subtract(const Duration(days: 2)),
          registrationEnd: DateTime.now().subtract(const Duration(hours: 1)),
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          maxAthletesPerGroup: [
            {'name': 'Men Group', 'gender': 'men', 'limit': 1},
            {'name': 'Women Group', 'gender': 'women', 'limit': 1},
          ],
        );
        harness.db.competitions[comp.id] = comp;

        // Seed parent association and make user-1 the owner so they can manage it
        final assoc = Association(
          id: 'assoc-1',
          name: 'Olympic Association',
          description: 'Parent assoc',
          scope: 'national',
          ownerId: 'user-1',
          rulebooks: {},
          socialChannels: {},
        );
        await harness.competitionProvider.createAssociation(assoc);

        // Seed candidate profiles in mock database
        harness.db.profiles['athlete-m1'] = Profile(
          id: 'athlete-m1',
          username: 'athletem1',
          fullName: 'Male Athlete One',
          email: 'm1@example.com',
          sex: 'male',
        );
        harness.db.profiles['athlete-m2'] = Profile(
          id: 'athlete-m2',
          username: 'athletem2',
          fullName: 'Male Athlete Two',
          email: 'm2@example.com',
          sex: 'male',
        );
        harness.db.profiles['athlete-f1'] = Profile(
          id: 'athlete-f1',
          username: 'athletef1',
          fullName: 'Female Athlete One',
          email: 'f1@example.com',
          sex: 'female',
        );

        // 3. Register athletes -> status should be 'pending' initially
        final reg1 = await harness.competitionProvider.registerAthlete(
          competitionId: comp.id,
          userId: 'athlete-m1',
        );
        expect(reg1, isTrue);

        final reg2 = await harness.competitionProvider.registerAthlete(
          competitionId: comp.id,
          userId: 'athlete-m2',
        );
        expect(reg2, isTrue);

        final reg3 = await harness.competitionProvider.registerAthlete(
          competitionId: comp.id,
          userId: 'athlete-f1',
        );
        expect(reg3, isTrue);

        // Check registrations in DB are all pending
        final regs = harness.db.athleteRegistrations;
        expect(regs.length, 3);
        for (final r in regs) {
          expect(r['status'], 'pending');
        }

        // 4. Build detail page widget
        final currentUser = harness.authProvider.currentUserProfile;
        final authStatus = harness.authProvider.status;
        final authError = harness.authProvider.errorMessage;
        debugPrint('TEST DEBUG: currentUser=${currentUser?.id} status=$authStatus error=$authError comp.associationId=${comp.associationId}');
        await tester.pumpWidget(
          harness.buildApp(CompetitionDetailPage(competition: comp)),
        );
        await tester.pumpAndSettle();

        // 5. Verify "Run Random Draw" button is visible and active
        final drawBtnFinder = find.byKey(const Key('run_random_draw_btn'));
        expect(drawBtnFinder, findsOneWidget);

        // 6. Tap "Run Random Draw"
        await tester.tap(drawBtnFinder);
        await tester.pumpAndSettle();

        // Verify draw successfully processed the statuses
        // For Men Group (limit: 1, 2 candidates: m1 & m2):
        // One must be 'registered', the other 'waitlisted' (since enableWaitlist is true)
        final statusM1 = regs.firstWhere((r) => r['profile_id'] == 'athlete-m1')['status'];
        final statusM2 = regs.firstWhere((r) => r['profile_id'] == 'athlete-m2')['status'];
        final statusF1 = regs.firstWhere((r) => r['profile_id'] == 'athlete-f1')['status'];

        expect([statusM1, statusM2], contains('registered'));
        expect([statusM1, statusM2], contains('waitlisted'));

        // For Women Group (limit: 1, 1 candidate: f1):
        // f1 must be 'registered'
        expect(statusF1, 'registered');
      },
    );

    testWidgets(
      'Run Random Draw button is disabled if registration period has not ended yet',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();
        addTearDown(harness.dispose);

        // Seed a competition where registrationEnd is in the future
        final comp = Competition(
          id: 'comp-future-end',
          title: 'Future Draw Meet',
          location: 'Hamburg Gym',
          sportSubtype: 'Classic',
          associationId: 'assoc-1',
          registrationMode: 'random',
          enableWaitlist: true,
          registrationStart: DateTime.now().subtract(const Duration(days: 1)),
          registrationEnd: DateTime.now().add(const Duration(hours: 2)), // Future
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        harness.db.competitions[comp.id] = comp;

        // Seed parent association and make user-1 the owner so they can manage it
        final assoc = Association(
          id: 'assoc-1',
          name: 'Olympic Association',
          description: 'Parent assoc',
          scope: 'national',
          ownerId: 'user-1',
          rulebooks: {},
          socialChannels: {},
        );
        await harness.competitionProvider.createAssociation(assoc);

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

        // Build widget
        await tester.pumpWidget(
          harness.buildApp(CompetitionDetailPage(competition: comp)),
        );
        await tester.pumpAndSettle();

        // Button should be visible but disabled (onPressed is null)
        final drawBtnFinder = find.byKey(const Key('run_random_draw_btn'));
        expect(drawBtnFinder, findsOneWidget);
        final ElevatedButton drawBtn = tester.widget<ElevatedButton>(drawBtnFinder);
        expect(drawBtn.onPressed, isNull);

        // Warning message should be shown
        expect(find.text('Draw can only be run after registration ends.'), findsOneWidget);
      },
    );
  });
}
