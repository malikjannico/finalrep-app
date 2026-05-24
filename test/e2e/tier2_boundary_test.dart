import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'e2e_test_harness.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/views/login_page.dart';
import 'package:finalrep_app/views/register_page.dart';
import 'package:finalrep_app/views/competition_handling_page.dart';

void main() {
  group('E2E Tier 2: Boundary & Corner Cases', () {
    late E2ETestHarness harness;

    setUp(() {
      harness = E2ETestHarness();
    });

    tearDown(() {
      harness.dispose();
    });

    group('Feature Area 1: Authentication Boundaries', () {
      testWidgets(
        'Test 2.1.1: Trim leading and trailing whitespace from login fields',
        (WidgetTester tester) async {
          await harness.initialize();
          await tester.pumpWidget(
            harness.buildApp(const LoginPage(isInline: true)),
          );
          await tester.pumpAndSettle();

          // Switch to Username login
          await tester.tap(find.text('Username'));
          await tester.pumpAndSettle();

          // Enter correct username with leading/trailing spaces
          await tester.enterText(
            find.byKey(const Key('login_id_field')),
            '   mariesmith   ',
          );
          await tester.enterText(
            find.byKey(const Key('login_password_field')),
            'password123',
          );
          await tester.pumpAndSettle();

          // Click SIGN IN
          await tester.tap(find.text('SIGN IN'));
          await harness.waitForAuthSettle(tester);

          // Verify authenticated successfully (meaning username was trimmed and lowercased)
          expect(harness.authProvider.isAuthenticated, true);
          expect(
            harness.authProvider.currentUserProfile?.username,
            'mariesmith',
          );
        },
      );

      testWidgets(
        'Test 2.1.2: Password strength validator constraints on Registration',
        (WidgetTester tester) async {
          await harness.initialize();
          tester.view.physicalSize = const Size(800, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            harness.buildApp(const RegisterPage(isInline: true)),
          );
          await tester.pumpAndSettle();

          // Enter valid user/email but weak password (no uppercase, no special char)
          await tester.enterText(
            find.byKey(const Key('register_username_field')),
            'newathlete',
          );
          await tester.enterText(
            find.byKey(const Key('register_email_field')),
            'new@example.com',
          );
          await tester.enterText(
            find.byKey(const Key('register_password_field')),
            'weakpw123',
          );
          await tester.pumpAndSettle();

          // Tap NEXT. Password requirements are not met, so validation fails and we remain on step 1.
          await tester.tap(find.text('NEXT'));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('register_username_field')),
            findsOneWidget,
          ); // still on step 1
        },
      );

      testWidgets('Test 2.1.3: Forgot password invalid/empty email feedback', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        await tester.pumpWidget(
          harness.buildApp(const LoginPage(isInline: true)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();

        // Enter invalid email format
        await tester.enterText(
          find.byKey(const Key('forgot_password_email_field')),
          'notanemail',
        );
        await tester.pumpAndSettle();

        // Tap SEND RESET LINK - dialog/validation should reject
        await tester.tap(find.text('SEND RESET LINK'));
        await tester.pumpAndSettle();

        expect(harness.authProvider.isPasswordRecoveryActive, isFalse);
      });

      testWidgets('Test 2.1.4: Database profile fetch retry logic on latency', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        // We will simulate a user signing up, but their profile row in database takes time to be inserted
        // through the Postgres trigger. So the first two profile fetches will return null, and the third will succeed.
        final mockProfile = Profile(
          id: 'delayed-user',
          username: 'delayeduser',
          fullName: 'Delayed User',
          email: 'delayed@example.com',
          colorMode: 'dark',
        );

        // We can hook a query interceptor or let InMemoryDatabase handle delayed availability
        // Let's remove 'delayed-user' profile from DB initially, and seed it only after 2 calls.
        harness.db.profiles.remove('delayed-user');

        final session = Session(
          accessToken: 'delayed-token',
          tokenType: 'bearer',
          user: User(
            id: 'delayed-user',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: '',
            email: 'delayed@example.com',
          ),
        );

        // Periodically inject the profile into the database to mimic DB latency
        Future.delayed(const Duration(milliseconds: 600), () {
          harness.db.profiles['delayed-user'] = mockProfile;
        });

        // Trigger sign in
        harness.mockAuth.triggerAuthStateChange(
          AuthChangeEvent.signedIn,
          session,
        );

        // Wait for the AuthProvider init flow (which does retries with 500ms delays)
        // 1st fetch (0ms) -> fails.
        // 2nd fetch (500ms) -> fails.
        // 3rd fetch (1000ms) -> succeeds (as we added the profile at 600ms).
        await harness.waitForAuthSettle(tester);

        expect(harness.authProvider.isAuthenticated, isTrue);
        expect(harness.authProvider.currentUserProfile?.id, 'delayed-user');
      });
    });

    group('Feature Area 5: Competition Handling (Streetlifting Rules)', () {
      testWidgets('Test 2.5.1: Attempt weight increments and validations', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        final comp = Competition(
          id: 'test-rules-comp',
          title: 'Test Rules Competition',
          location: 'Berlin, Germany',
          sportSubtype: 'Modern',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          harness.buildApp(CompetitionHandlingPage(competitionId: comp.id)),
        );
        await tester.pumpAndSettle();

        // 1. Enter +1.0kg invalid weight (modern disciplines like Muscle Up require multiple of 1.25kg)
        final weightInput = find.byKey(const Key('attempt_weight_input'));
        expect(weightInput, findsOneWidget);

        await tester.enterText(weightInput, '1.0');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Verify error SnackBar
        expect(find.text('Weight must be multiple of 1.25kg!'), findsOneWidget);

        // 2. Enter valid +1.25kg increment
        await tester.enterText(weightInput, '1.25');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Standard plates calculations: 1.25kg -> 0x25, 0x20
        expect(find.text('Standard Plates: 0x25kg, 0x20kg'), findsOneWidget);
      });

      testWidgets('Test 2.5.2: Decreasing weight attempts are blocked', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        final comp = Competition(
          id: 'test-rules-comp',
          title: 'Test Rules Competition',
          location: 'Berlin, Germany',
          sportSubtype: 'Modern',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          harness.buildApp(CompetitionHandlingPage(competitionId: comp.id)),
        );
        await tester.pumpAndSettle();

        final weightInput = find.byKey(const Key('attempt_weight_input'));

        // Submit first attempt with 10kg
        await tester.enterText(weightInput, '10.0');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Submit judging votes (3 white cards = Good Lift)
        await tester.tap(find.byKey(const Key('judge_submit')));
        await tester.pumpAndSettle();

        expect(find.text('LIFT PASSED'), findsOneWidget);

        // Now attempt 2 weight = 8.75kg (lighter than first attempt of 10.0kg)
        await tester.enterText(weightInput, '8.75');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Verify error snackbar blocks it
        expect(find.text('Attempt weight must be ascending!'), findsOneWidget);
      });

      testWidgets('Test 2.5.3: Platform Judging majority vs unanimous voting', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        final comp = Competition(
          id: 'test-rules-comp',
          title: 'Test Rules Competition',
          location: 'Berlin, Germany',
          sportSubtype: 'Modern',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          harness.buildApp(CompetitionHandlingPage(competitionId: comp.id)),
        );
        await tester.pumpAndSettle();

        // Active discipline is Muscle Up. Requires UNANIMOUS 3:0 for some failure reasons.
        final weightInput = find.byKey(const Key('attempt_weight_input'));
        await tester.enterText(weightInput, '5.0');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Set J1 and J2 to Good, J3 to No Lift (2 Good, 1 Bad)
        await tester.tap(
          find.byKey(const Key('judge_3_toggle')),
        ); // Toggle J3 from Good to No
        await tester.pumpAndSettle();

        // Select failure reason "Chicken Wing" (which triggers Unanimous check)
        await tester.tap(find.byKey(const Key('failure_reason_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chicken Wing').last);
        await tester.pumpAndSettle();

        // Submit judging
        await tester.tap(find.byKey(const Key('judge_submit')));
        await tester.pumpAndSettle();

        // Since it's Muscle Up + Chicken Wing, 2:1 is NOT enough. Needs unanimous. Lift fails.
        expect(find.text('LIFT FAILED'), findsOneWidget);
      });

      testWidgets(
        'Test 2.5.4: Video Assisted Referee (VAR) overrules and credit restore',
        (WidgetTester tester) async {
          await harness.initialize();
          final comp = Competition(
            id: 'test-rules-comp',
            title: 'Test Rules Competition',
            location: 'Berlin, Germany',
            sportSubtype: 'Modern',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await tester.pumpWidget(
            harness.buildApp(CompetitionHandlingPage(competitionId: comp.id)),
          );
          await tester.pumpAndSettle();

          // Submit a lift attempt
          final weightInput = find.byKey(const Key('attempt_weight_input'));
          await tester.enterText(weightInput, '5.0');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          // Set J1, J2, J3 to No Lift
          await tester.tap(find.byKey(const Key('judge_1_toggle')));
          await tester.tap(find.byKey(const Key('judge_2_toggle')));
          await tester.tap(find.byKey(const Key('judge_3_toggle')));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('judge_submit')));
          await tester.pumpAndSettle();

          expect(find.text('LIFT FAILED'), findsOneWidget);

          // Tap Request VAR
          final varBtn = find.byKey(const Key('var_request_btn'));
          expect(varBtn, findsOneWidget);
          await tester.tap(varBtn);
          await tester.pumpAndSettle();

          // Overrule to Good Lift
          final overruleBtn = find.byKey(const Key('var_overrule_pass'));
          expect(overruleBtn, findsOneWidget);
          await tester.tap(overruleBtn);
          await tester.pumpAndSettle();

          // Verify lift is now PASSED
          expect(find.text('LIFT PASSED'), findsOneWidget);
        },
      );

      testWidgets('Test 2.5.5: Athlete disqualified on three failed attempts', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        final comp = Competition(
          id: 'test-rules-comp',
          title: 'Test Rules Competition',
          location: 'Berlin, Germany',
          sportSubtype: 'Modern',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          harness.buildApp(CompetitionHandlingPage(competitionId: comp.id)),
        );
        await tester.pumpAndSettle();

        final weightInput = find.byKey(const Key('attempt_weight_input'));

        // We need to submit 3 failed attempts in a row for Muscle Up
        for (int i = 0; i < 3; i++) {
          await tester.enterText(weightInput, '10.0');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          // Set all judges to No Lift if they aren't already
          // Toggle judge_1_toggle, judge_2_toggle, judge_3_toggle on first iteration
          if (i == 0) {
            await tester.tap(find.byKey(const Key('judge_1_toggle')));
            await tester.tap(find.byKey(const Key('judge_2_toggle')));
            await tester.tap(find.byKey(const Key('judge_3_toggle')));
            await tester.pumpAndSettle();
          }

          await tester.tap(find.byKey(const Key('judge_submit')));
          await tester.pumpAndSettle();
        }

        // Verify athlete is disqualified (0/3 lifts valid)
        expect(find.byKey(const Key('dq_status')), findsOneWidget);
      });
    });
  });
}
