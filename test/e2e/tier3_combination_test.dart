import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'e2e_test_harness.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/views/login_page.dart';
import 'package:finalrep_app/views/register_page.dart';
import 'package:finalrep_app/views/profile_page.dart';
import 'package:finalrep_app/views/settings_page.dart';
import 'package:finalrep_app/views/appearance_settings_page.dart';

void main() {
  group('E2E Tier 3: Cross-Feature Combination Tests', () {
    late E2ETestHarness harness;

    setUp(() {
      harness = E2ETestHarness();
    });

    tearDown(() {
      harness.dispose();
    });

    testWidgets('Test 3.1: Register -> Login -> Customize Profile Flow', (
      WidgetTester tester,
    ) async {
      await harness.initialize();
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. REGISTER NEW USER (with mixed case username)
      await tester.pumpWidget(
        harness.buildApp(const RegisterPage(isInline: true)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_username_field')),
        'NewAthlete',
      );
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'newathlete@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'StrongPw123!',
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_fullname_field')),
        'New Athlete',
      );
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Click CREATE ACCOUNT
      await tester.tap(find.text('CREATE ACCOUNT'));
      await harness.waitForAuthSettle(tester);

      // Log out first (to return to guest status, since registration auto-logged in)
      await harness.authProvider.logout();
      await tester.pumpAndSettle();

      // 2. LOGIN WITH REGISTERED CREDENTIALS (lowercase check)
      await tester.pumpWidget(
        harness.buildApp(const LoginPage(isInline: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Username'));
      await tester.pumpAndSettle();

      // Input mixed case 'newathlete' -> should lower case
      await tester.enterText(
        find.byKey(const Key('login_id_field')),
        'NEWATHLETE',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'StrongPw123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIGN IN'));
      await harness.waitForAuthSettle(tester);

      expect(harness.authProvider.isAuthenticated, isTrue);
      expect(harness.authProvider.currentUserProfile?.username, 'newathlete');

      // 3. CUSTOMIZE PROFILE
      await tester.pumpWidget(harness.buildApp(const ProfilePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EDIT PROFILE'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description / Bio'),
        'Lifting all day.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify updated profile
      expect(
        harness
            .db
            .profiles[harness.authProvider.currentUserProfile!.id]
            ?.description,
        'Lifting all day.',
      );
      expect(find.text('Lifting all day.'), findsOneWidget);
    });

    testWidgets('Test 3.2: Auth State Synchronization & Theme Persistence', (
      WidgetTester tester,
    ) async {
      await harness.initialize();
      // Authenticate user-1
      final user = harness.db.profiles['user-1']!;
      final session = Session(
        accessToken: 'token-user-1',
        tokenType: 'bearer',
        user: User(
          id: user.id,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '',
          email: user.email,
        ),
      );
      harness.mockAuth.triggerAuthStateChange(
        AuthChangeEvent.signedIn,
        session,
      );
      await tester.pumpAndSettle();

      // Launch appearance settings
      await tester.pumpWidget(harness.buildApp(const AppearanceSettingsPage()));
      await tester.pumpAndSettle();

      // Select 'light' mode
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();

      // Verify DB synced with 'light'
      expect(harness.db.profiles['user-1']?.colorMode, 'light');

      // Log out
      await harness.authProvider.logout();
      await tester.pumpAndSettle();

      // Log back in
      harness.mockAuth.triggerAuthStateChange(
        AuthChangeEvent.signedIn,
        session,
      );
      await tester.pumpAndSettle();

      // Verify colorMode remains 'light' (persistent theme state)
      expect(harness.authProvider.currentUserProfile?.colorMode, 'light');
    });

    testWidgets(
      'Test 3.3: Deep Link Navigation -> Authentication Gateway Interception',
      (WidgetTester tester) async {
        await harness.initialize();
        // We simulate navigating to a private page (/settings) directly as a guest
        // We expect the Gateway (MaterialsApp settings in our buildApp or our custom route protection) to redirect us.
        // Let's implement route redirection inside the harness or a wrapper to simulate deep link interception:
        final privateWidget = Builder(
          builder: (context) {
            final auth = Provider.of<AuthProvider>(context);
            if (!auth.isAuthenticated) {
              return const LoginPage(isInline: true);
            }
            return const SettingsPage();
          },
        );

        await tester.pumpWidget(harness.buildApp(privateWidget));
        await tester.pumpAndSettle();

        // Verify that we are intercepted and showing the login screen instead of Settings
        expect(find.text('Welcome Back'), findsOneWidget);
        expect(find.text('Settings'), findsNothing);

        // Perform a successful login
        await tester.enterText(
          find.byKey(const Key('login_id_field')),
          'john@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'password123',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('SIGN IN'));
        await harness.waitForAuthSettle(tester);

        // Verify we are now forwarded to Settings page
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Welcome Back'), findsNothing);
      },
    );
  });
}
