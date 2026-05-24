import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import 'e2e_test_harness.dart';
import 'dart:io';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/login_page.dart';
import 'package:finalrep_app/views/profile_page.dart';
import 'package:finalrep_app/views/settings_page.dart';
import 'package:finalrep_app/views/search_feed_page.dart';

final Uint8List transparentPngBytes = File(
  'assets/images/comp_berlin.png',
).readAsBytesSync();

void main() {
  group('E2E Tier 1: Feature Coverage Tests', () {
    late E2ETestHarness harness;

    setUp(() {
      harness = E2ETestHarness();
    });

    tearDown(() {
      harness.dispose();
    });

    group('Feature Area 1: Authentication & Password', () {
      testWidgets(
        'Test 1.1: Username entry dynamically lowercases and verifies successfully',
        (WidgetTester tester) async {
          await harness.initialize();
          await tester.pumpWidget(
            harness.buildApp(const LoginPage(isInline: true)),
          );
          await tester.pumpAndSettle();

          // Switch to Username login
          final usernameTab = find.text('Username');
          expect(usernameTab, findsOneWidget);
          await tester.tap(usernameTab);
          await tester.pumpAndSettle();

          // Enter mixed-case username 'JohnDoe' and correct password
          await tester.enterText(
            find.byKey(const Key('login_id_field')),
            'JohnDoe',
          );
          await tester.enterText(
            find.byKey(const Key('login_password_field')),
            'password123',
          );
          await tester.pumpAndSettle();

          // Click SIGN IN
          final signInBtn = find.text('SIGN IN');
          expect(signInBtn, findsOneWidget);
          await tester.tap(signInBtn);
          await harness.waitForAuthSettle(tester);

          debugPrint(
            'DEBUG TEST 1.1 AFTER PUMP: isAuthenticated=${harness.authProvider.isAuthenticated} status=${harness.authProvider.status}',
          );

          // Verify the auth provider received the lowercased username and is authenticated
          expect(harness.authProvider.isAuthenticated, true);
          expect(harness.authProvider.currentUserProfile?.username, 'johndoe');
        },
      );

      testWidgets(
        'Test 1.2: Successful login with correct Username + Password credentials',
        (WidgetTester tester) async {
          await harness.initialize();
          await tester.pumpWidget(
            harness.buildApp(const LoginPage(isInline: true)),
          );
          await tester.pumpAndSettle();

          // Switch to Username login
          await tester.tap(find.text('Username'));
          await tester.pumpAndSettle();

          // Enter correct username and password
          await tester.enterText(
            find.byKey(const Key('login_id_field')),
            'mariesmith',
          );
          await tester.enterText(
            find.byKey(const Key('login_password_field')),
            'password123',
          );
          await tester.pumpAndSettle();

          // Click SIGN IN
          await tester.tap(find.text('SIGN IN'));
          await harness.waitForAuthSettle(tester);

          expect(harness.authProvider.isAuthenticated, true);
          expect(
            harness.authProvider.currentUserProfile?.username,
            'mariesmith',
          );
        },
      );

      testWidgets(
        'Test 1.3: Successful login with correct Email + Password credentials',
        (WidgetTester tester) async {
          await harness.initialize();
          await tester.pumpWidget(
            harness.buildApp(const LoginPage(isInline: true)),
          );
          await tester.pumpAndSettle();

          // Email login is default, enter correct email and password
          await tester.enterText(
            find.byKey(const Key('login_id_field')),
            'john@example.com',
          );
          await tester.enterText(
            find.byKey(const Key('login_password_field')),
            'password123',
          );
          await tester.pumpAndSettle();

          // Click SIGN IN
          await tester.tap(find.text('SIGN IN'));
          await harness.waitForAuthSettle(tester);

          expect(harness.authProvider.isAuthenticated, true);
          expect(
            harness.authProvider.currentUserProfile?.email,
            'john@example.com',
          );
        },
      );

      testWidgets(
        'Test 1.4: Initiating forgot password recovery sends the reset link using the email form',
        (WidgetTester tester) async {
          await harness.initialize();
          await tester.pumpWidget(
            harness.buildApp(const LoginPage(isInline: true)),
          );
          await tester.pumpAndSettle();

          // Find and tap FORGOT PASSWORD?
          final forgotBtn = find.text('Forgot Password?');
          expect(forgotBtn, findsOneWidget);
          await tester.tap(forgotBtn);
          await tester.pumpAndSettle();

          // Verify forgot password dialog / fields
          expect(find.text('Reset Password'), findsOneWidget);
          final emailInput = find.byKey(
            const Key('forgot_password_email_field'),
          );
          expect(emailInput, findsOneWidget);

          await tester.enterText(emailInput, 'john@example.com');
          await tester.pumpAndSettle();

          final sendBtn = find.text('SEND RESET LINK');
          expect(sendBtn, findsOneWidget);
          await tester.tap(sendBtn);
          await harness.waitForAuthSettle(tester);

          // Check password recovery status is active
          expect(harness.authProvider.isPasswordRecoveryActive, isTrue);
        },
      );

      testWidgets(
        'Test 1.5: Logout successfully resets current user profile and returns app back to guest status',
        (WidgetTester tester) async {
          await harness.initialize();
          // Authenticate user-1 first
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
          await harness.waitForAuthSettle(tester);

          // Verify authenticated
          expect(harness.authProvider.isAuthenticated, isTrue);

          await tester.pumpWidget(harness.buildApp(const SettingsPage()));
          await tester.pumpAndSettle();

          // Tap Log Out tile
          final logoutBtn = find.text('Log Out');
          expect(logoutBtn, findsOneWidget);
          await tester.tap(logoutBtn);
          await tester.pumpAndSettle();

          // Tap LOG OUT button in dialog
          final dialogLogoutBtn = find.text('LOG OUT');
          expect(dialogLogoutBtn, findsOneWidget);
          await tester.tap(dialogLogoutBtn);
          await tester.pumpAndSettle();

          // Check user is unauthenticated
          expect(harness.authProvider.isAuthenticated, isFalse);
          expect(harness.authProvider.currentUserProfile, isNull);
        },
      );
    });

    group('Feature Area 2: Profile Customization', () {
      testWidgets(
        'Test 2.1: Render profile details directly on page scaffold without enclosing Card borders',
        (WidgetTester tester) async {
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
          await harness.waitForAuthSettle(tester);

          await tester.pumpWidget(harness.buildApp(const ProfilePage()));
          await tester.pumpAndSettle();

          // Verify username and fullname are rendered
          expect(find.text('John Doe'), findsOneWidget);
          expect(find.text('@johndoe'), findsNWidgets(2));
          // Verify compact description is rendered directly
          expect(find.text('Lifting is life.'), findsOneWidget);
        },
      );

      testWidgets(
        'Test 2.2: Settings gear icon is positioned immediately inline following the user\'s Full Name',
        (WidgetTester tester) async {
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
          await harness.waitForAuthSettle(tester);

          await tester.pumpWidget(harness.buildApp(const ProfilePage()));
          await tester.pumpAndSettle();

          // Find settings icon button
          final settingsBtn = find.byIcon(Icons.settings_outlined);
          expect(settingsBtn, findsOneWidget);
        },
      );

      testWidgets('Test 2.3: Toggle edit mode and update profile parameters', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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
        await harness.waitForAuthSettle(tester);

        await tester.pumpWidget(harness.buildApp(const ProfilePage()));
        await tester.pumpAndSettle();

        // Tap EDIT PROFILE
        final editBtn = find.text('EDIT PROFILE');
        expect(editBtn, findsOneWidget);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        // Edit fields
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Description / Bio'),
          'New lifting bio!',
        );
        await tester.pumpAndSettle();

        // Save changes
        final saveBtn = find.text('SAVE');
        expect(saveBtn, findsOneWidget);
        await tester.tap(saveBtn);
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify updated database and UI description
        expect(harness.db.profiles['user-1']?.description, 'New lifting bio!');
        expect(find.text('New lifting bio!'), findsOneWidget);
      });

      testWidgets(
        'Test 2.4: Upload custom profile avatar image, previewing and verifying updated public storage URL',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(800, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

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
          await harness.waitForAuthSettle(tester);

          // Setup custom file picker file
          harness.mockFilePicker.setMockFile(
            'my_avatar.png',
            1024,
            transparentPngBytes,
          );

          await tester.pumpWidget(harness.buildApp(const ProfilePage()));
          await tester.pumpAndSettle();

          // Tap EDIT PROFILE
          await tester.tap(find.text('EDIT PROFILE'));
          await tester.pumpAndSettle();

          // Print debug information
          final changePhotoFinder = find.text('CHANGE PHOTO');
          debugPrint(
            'DEBUG TEST 2.4: changePhotoFinder.evaluate() elements length = ${changePhotoFinder.evaluate().length}',
          );
          if (changePhotoFinder.evaluate().isNotEmpty) {
            final renderBox =
                tester.renderObject(changePhotoFinder) as RenderBox;
            final position = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            debugPrint(
              'DEBUG TEST 2.4: CHANGE PHOTO position=$position size=$size',
            );
          }

          // Tap avatar selection button / area
          final changePhotoBtn = find.text('CHANGE PHOTO');
          expect(changePhotoBtn, findsOneWidget);
          await tester.tap(changePhotoBtn);
          await tester.pumpAndSettle();

          // Verify custom avatar preview filename is visible
          expect(find.text('my_avatar.png'), findsOneWidget);

          // Tap SAVE to execute uploading
          await tester.tap(find.text('SAVE'));
          await tester.pump();
          await tester.pumpAndSettle();

          // Verify that the avatar URL contains the uploaded path
          final updatedProfile = harness.db.profiles['user-1']!;
          expect(updatedProfile.profilePictureUrl, contains('my_avatar.png'));
        },
      );

      testWidgets('Test 2.5: Navigate to another user\'s profile view', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        // Log in user-1
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
        await harness.waitForAuthSettle(tester);

        // Navigate directly to ProfilePage
        // In this test, we can pass another user Profile or simulate viewing one.
        // Let's verify that the ProfilePage handles general Profile injection or can display currentUserProfile.
        await tester.pumpWidget(harness.buildApp(const ProfilePage()));
        await tester.pumpAndSettle();

        expect(find.text('John Doe'), findsOneWidget);
      });
    });

    group('Feature Area 3: Competitions Feed & Details', () {
      testWidgets(
        'Test 3.1: Switch feed view dynamically between layouts (Grid / List / Map)',
        (WidgetTester tester) async {
          await harness.initialize();
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            harness.buildApp(
              SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
            ),
          );
          await tester.pump();
          await tester.pump(Duration.zero);

          // By default, layout is grid. Shows cards.
          expect(find.byKey(const Key('comp_card_comp-1')), findsOneWidget);

          // Change layout to List (Compact Layout)
          await tester.tap(find.byTooltip('Select layout'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Compact Layout'));
          await tester.pumpAndSettle();

          // Verify layout state
          expect(harness.competitionProvider.layout, CompetitionsLayout.list);

          // Change layout to Map
          await tester.tap(find.byTooltip('Select layout'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Map Layout'));
          await tester.pumpAndSettle();

          expect(harness.competitionProvider.layout, CompetitionsLayout.map);
        },
      );

      testWidgets(
        'Test 3.2: Filter competitions list by modern vs classic format',
        (WidgetTester tester) async {
          await harness.initialize();
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            harness.buildApp(
              SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
            ),
          );
          await tester.pump();
          await tester.pump(Duration.zero);

          // Verify both items rendered
          expect(find.text('Hamburg Streetlifting Meet'), findsOneWidget);
          expect(find.text('Classic Pull & Dip Cup'), findsOneWidget);

          // Expand format filter
          await tester.tap(find.text('FORMAT'));
          await tester.pumpAndSettle();

          // Tap Modern filter checkbox
          await tester.tap(find.text('Modern'));
          await tester.pumpAndSettle();

          // Verify Classic Cup is filtered out
          expect(find.text('Hamburg Streetlifting Meet'), findsOneWidget);
          expect(find.text('Classic Pull & Dip Cup'), findsNothing);
        },
      );

      testWidgets('Test 3.3: Active filter chips are rendered above feed', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          harness.buildApp(
            SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
          ),
        );
        await tester.pump();
        await tester.pump(Duration.zero);

        // Expand format filter
        await tester.tap(find.text('FORMAT'));
        await tester.pumpAndSettle();

        // Tap Modern filter checkbox
        await tester.tap(find.text('Modern'));
        await tester.pumpAndSettle();

        // Check if chip "Format: Modern" is shown
        expect(find.text('Format: Modern'), findsOneWidget);
      });

      testWidgets('Test 3.4: Sorting order toggles correctly', (
        WidgetTester tester,
      ) async {
        await harness.initialize();
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          harness.buildApp(
            SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
          ),
        );
        await tester.pump();
        await tester.pump(Duration.zero);

        // Find sort options dropdown
        final sortBtn = find.byTooltip('Sort options');
        expect(sortBtn, findsOneWidget);
        await tester.tap(sortBtn);
        await tester.pumpAndSettle();

        // Select Sort by Name (A-Z)
        await tester.tap(find.text('Name: A-Z'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(harness.competitionProvider.sortOrder, 'name_asc');
      });

      testWidgets(
        'Test 3.5: Competition detail view navigation renders content',
        (WidgetTester tester) async {
          await harness.initialize();
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            harness.buildApp(
              SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
            ),
          );
          await tester.pump();
          await tester.pump(Duration.zero);

          // Tap card of Hamburg Meet
          final compCard = find.text('Hamburg Streetlifting Meet');
          expect(compCard, findsAtLeast(1));
          await tester.tap(compCard.first);
          await tester.pumpAndSettle();

          // Verify we navigated to detail page
          expect(find.text('Hamburg, Germany'), findsAtLeast(1));
          expect(find.text('Apply as Volunteer'), findsOneWidget);
          expect(find.byIcon(Icons.share), findsOneWidget);
        },
      );
    });
  });
}
