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
import 'package:finalrep_app/views/search_feed_page.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/rankings_page.dart';
import 'package:finalrep_app/views/profile_page.dart';
import 'package:finalrep_app/views/login_page.dart';

class MockProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Profile>> searchProfiles(String query) async => [];

  @override
  Future<Profile> getProfile(String id) async {
    return Profile(
      id: id,
      username: 'testuser',
      fullName: 'Test User',
      email: 'test@example.com',
    );
  }

  @override
  Future<Profile> getProfileByUsername(String username) async {
    return Profile(
      id: 'user-1',
      username: username,
      fullName: 'Test User',
      email: 'test@example.com',
    );
  }

  @override
  Future<List<Competition>> getUserUpcomingMeets(String userId) async => [];

  @override
  Future<List<Competition>> getUserCompletedMeets(String userId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getUserHighestRankings(
    String userId,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> getUserPersonalRecords(
    String userId,
  ) async => [];
}

class MockCompetitionRepository implements CompetitionRepository {
  final List<Competition> _fakeCompetitions = [
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
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status,
  }) async {
    return _fakeCompetitions;
  }

  @override
  Future<List<Competition>> fetchCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status,
  }) async {
    return _fakeCompetitions;
  }
}

class MockAssociationRepository implements AssociationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Association>> getAssociations() async => [];

  @override
  Future<List<AssociationMember>> getAssociationMembers(
    String associationId,
  ) async => [];
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  bool _isAuthenticated;
  Profile? _currentUserProfile;

  MockAuthProvider({bool isAuthenticated = false, Profile? currentUserProfile})
    : _isAuthenticated = isAuthenticated,
      _currentUserProfile = currentUserProfile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Profile? get currentUserProfile => _currentUserProfile;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get isPasswordRecoveryActive => false;

  @override
  bool get isAdmin => _currentUserProfile?.isAdmin ?? false;

  @override
  bool get isAssociationCreator =>
      _currentUserProfile?.isAssociationCreator ?? false;

  @override
  bool get isCompetitionCreator =>
      _currentUserProfile?.isCompetitionCreator ?? false;

  @override
  ProfileRepository get profileRepository => MockProfileRepository();

  void setAuthenticated(bool val, {Profile? profile}) {
    _isAuthenticated = val;
    _currentUserProfile = profile;
    notifyListeners();
  }
}

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
      compRepo = MockCompetitionRepository();
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
          home: SearchFeedPage(onToggleTheme: () {}, isDarkMode: false),
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
          ),
        );

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tab 0 is Competitions - dropdown should be visible
        expect(find.byTooltip('Select layout'), findsOneWidget);

        // Click on Associations (Tab 1)
        await tester.tap(find.text('Associations'));
        await tester.pumpAndSettle();

        // View mode dropdown should be hidden on tab 1
        expect(find.byTooltip('Select layout'), findsNothing);
        expect(find.byType(AssociationManagementPage), findsOneWidget);

        // Click on Rankings (Tab 2)
        await tester.tap(find.text('Rankings'));
        await tester.pumpAndSettle();

        expect(find.byType(RankingsPage), findsOneWidget);
        expect(find.byTooltip('Select layout'), findsNothing);
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

        // On Tab 0, the desktop left sidebar/filter panel should be visible
        expect(find.text('Filters'), findsOneWidget);

        // Click on Associations (Tab 1)
        await tester.tap(find.text('Associations'));
        await tester.pumpAndSettle();

        // Filters should not be visible anymore
        expect(find.text('Filters'), findsNothing);
      },
    );
  });
}
