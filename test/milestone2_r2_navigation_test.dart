import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/association_member.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/views/home_navigation_shell.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/association_library_page.dart';
import 'package:finalrep_app/views/competition_management_page.dart';
import 'package:finalrep_app/views/rankings_page.dart';
import 'package:finalrep_app/views/profile_page.dart';
import 'package:finalrep_app/views/login_page.dart';

import 'mocks/shared_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://placeholder-navigation.supabase.co',
        anonKey: 'placeholder-key',
      );
    } catch (_) {}
  });

  group('Milestone 2 - R2 Navigation & Layout Tests', () {
    late MockCompetitionRepository compRepo;
    late MockAssociationRepository assocRepo;
    late CompetitionProvider compProvider;
    late MockAuthProvider authProvider;

    setUp(() {
      compRepo = MockCompetitionRepository([
        Competition(
          id: 'comp-1',
          title: 'Hamburg Meet',
          location: 'Hamburg, Germany',
          sportSubtype: 'Modern',
          compGroupName: 'Hamburg Meet',
          area: 'Europe',
          country: 'Germany',
          city: 'Hamburg',
          startDate: DateTime(2026, 6, 15),
          endDate: DateTime(2026, 6, 15),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'upcoming',
          associationId: 'assoc-1',
        ),
      ]);
      assocRepo = MockAssociationRepository();
      compProvider = CompetitionProvider(
        compRepo,
        MockProfileRepository(),
        associationRepository: assocRepo,
      );
      authProvider = MockAuthProvider();
    });

    Widget buildTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CompetitionProvider>.value(
            value: compProvider,
          ),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          home: HomeNavigationShell(onToggleTheme: () {}, isDarkMode: false),
        ),
      );
    }

    testWidgets(
      'Verify 3 tabs in guest mode vs 4 tabs in auth mode on Desktop',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        authProvider.setAuthenticated(false);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Desktop sub-navbar buttons
        expect(find.text('Competitions'), findsOneWidget);
        expect(find.text('Associations'), findsOneWidget);
        expect(find.text('Rankings'), findsOneWidget);
        expect(find.text('My Profile'), findsNothing);

        // Authenticate
        authProvider.setAuthenticated(
          true,
          profile: Profile(
            id: 'user-1',
            username: 'johndoe',
            fullName: 'John Doe',
            email: 'john@example.com',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('My Profile'), findsOneWidget);
      },
    );

    testWidgets(
      'Verify bottom navigation structure in guest vs auth mode on Mobile',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        authProvider.setAuthenticated(false);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Mobile BottomNavigationBar items
        expect(find.byIcon(Icons.explore), findsOneWidget);
        expect(find.byIcon(Icons.business), findsOneWidget);
        expect(find.byIcon(Icons.emoji_events), findsOneWidget);
        expect(find.byIcon(Icons.person), findsNothing);

        // Authenticate
        authProvider.setAuthenticated(
          true,
          profile: Profile(
            id: 'user-1',
            username: 'johndoe',
            fullName: 'John Doe',
            email: 'john@example.com',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.person), findsOneWidget);
      },
    );

    testWidgets(
      'Verify view mode dropdown is only shown on Tab 0 (Competitions)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        authProvider.setAuthenticated(
          true,
          profile: Profile(
            id: 'user-1',
            username: 'johndoe',
            fullName: 'John Doe',
            email: 'john@example.com',
            isAssociationCreator: true,
          ),
        );

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tab 0 is Competitions - dropdown should be visible
        expect(find.byTooltip('Select layout'), findsOneWidget);

        // Click on Associations (Tab 1)
        await tester.tap(find.text('Associations'));
        await tester.pumpAndSettle();

        // Under 'All' view mode, tab 1 renders AssociationLibraryPage which has a layout selector tooltip
        expect(find.byType(AssociationLibraryPage), findsOneWidget);
        expect(find.byTooltip('Select layout '), findsOneWidget);

        // Switch to 'Management' view mode
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Management').last);
        await tester.pumpAndSettle();

        // Resets index to 0, which displays CompetitionManagementPage
        expect(find.byType(CompetitionManagementPage), findsOneWidget);
        expect(find.byTooltip('Select layout'), findsNothing);
        expect(find.byTooltip('Select layout '), findsNothing);

        // Click on My Associations (Tab 1) while in 'Management' mode
        await tester.tap(find.text('My Associations'));
        await tester.pumpAndSettle();

        expect(find.byType(AssociationManagementPage), findsOneWidget);
        expect(find.byTooltip('Select layout'), findsOneWidget);
        expect(find.byTooltip('Select layout '), findsNothing);

        // Switch back to 'All' view mode
        await tester.tap(find.text('Management'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('All').last);
        await tester.pumpAndSettle();

        // Click on Rankings (Tab 2)
        await tester.tap(find.text('Rankings'));
        await tester.pumpAndSettle();

        expect(find.byType(RankingsPage), findsOneWidget);
        expect(find.byTooltip('Select layout'), findsNothing);
        expect(find.byTooltip('Select layout '), findsOneWidget);
      },
    );

    testWidgets(
      'Verify filter controls are only shown/enabled on Tab 0 (Competitions)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // On Tab 0, the desktop left sidebar/filter panel with Date Range should be visible
        expect(find.text('DATE RANGE'), findsOneWidget);

        // Click on Associations (Tab 1)
        await tester.tap(find.text('Associations'));
        await tester.pumpAndSettle();

        // DATE RANGE filter should not be visible anymore
        expect(find.text('DATE RANGE'), findsNothing);
      },
    );
  });
}
