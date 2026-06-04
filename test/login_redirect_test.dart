import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finalrep_app/router.dart';
import 'package:finalrep_app/main.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/models/profile.dart';
import 'mocks/shared_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GoRouter Login Redirect Success Test', (WidgetTester tester) async {
    final authProvider = MockAuthProvider();
    final compProvider = CompetitionProvider(
      MockCompetitionRepository([]),
      MockProfileRepository(),
      associationRepository: MockAssociationRepository(),
    );
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: MaterialApp.router(
          routerConfig: goRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initially at home '/'
    expect(goRouter.state?.matchedLocation, '/');

    // Navigate to '/login'
    goRouter.go('/login');
    await tester.pumpAndSettle();
    expect(goRouter.state?.matchedLocation, '/login');

    // Fill in credentials
    await tester.enterText(
      find.byKey(const Key('login_id_field')),
      'john@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'password123',
    );
    await tester.pumpAndSettle();

    // Set mock successful authentication state when SIGN IN is tapped
    // We override login callback or set authenticated right after tapping SIGN IN
    // Let's tap SIGN IN and then immediately simulate the auth state update and notify GoRouter
    final signInBtn = find.text('SIGN IN');
    expect(signInBtn, findsOneWidget);
    await tester.tap(signInBtn);
    
    // Simulate successful login state update
    authProvider.setAuthenticated(
      true,
      profile: Profile(
        id: 'user-1',
        username: 'johndoe',
        fullName: 'John Doe',
        email: 'john@example.com',
      ),
    );
    authRedirectNotifier.refresh();

    // Let transition run
    await tester.pumpAndSettle();

    // Verify it redirected to '/'
    expect(goRouter.state?.matchedLocation, '/');
  });
}
