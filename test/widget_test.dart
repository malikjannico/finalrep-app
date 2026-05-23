import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/permission_application.dart';
import 'package:finalrep_app/models/admin_config.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/admin_repository.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/views/search_feed_page.dart';
import 'package:finalrep_app/views/competition_detail_page.dart';
import 'package:finalrep_app/widgets/competition_card.dart';
import 'package:finalrep_app/widgets/competition_compact_row.dart';
import 'package:finalrep_app/views/world_map_view.dart';
import 'package:finalrep_app/views/login_page.dart';
import 'package:finalrep_app/views/register_page.dart';
import 'package:finalrep_app/views/profile_page.dart';
import 'package:finalrep_app/views/settings_page.dart';
import 'package:finalrep_app/views/appearance_settings_page.dart';
import 'package:finalrep_app/views/change_password_page.dart';

class MockProfileRepository implements ProfileRepository {
  final List<Profile> profilesToReturn;

  MockProfileRepository({this.profilesToReturn = const []});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Profile>> searchProfiles(String query) async {
    return profilesToReturn;
  }

  @override
  Future<Profile> getProfile(String id) async {
    return profilesToReturn.firstWhere((p) => p.id == id, orElse: () => throw Exception('Profile not found'));
  }

  @override
  Future<Profile> getProfileByUsername(String username) async {
    return profilesToReturn.firstWhere((p) => p.username.toLowerCase() == username.toLowerCase(), orElse: () => throw Exception('Profile not found'));
  }

  @override
  Future<List<Competition>> getUserUpcomingMeets(String userId) async {
    return [];
  }

  @override
  Future<List<Competition>> getUserCompletedMeets(String userId) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getUserHighestRankings(String userId) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getUserPersonalRecords(String userId) async {
    return [];
  }
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final bool _isAuthenticated;
  final Profile? _currentUserProfile;
  final AuthStatus _status;
  final ProfileRepository? _profileRepository;
  final bool Function(String)? onIsUsernameTaken;
  final bool Function(String)? onIsEmailTaken;

  MockAuthProvider({
    bool isAuthenticated = false,
    Profile? currentUserProfile,
    AuthStatus status = AuthStatus.unauthenticated,
    ProfileRepository? profileRepository,
    this.onIsUsernameTaken,
    this.onIsEmailTaken,
  })  : _isAuthenticated = isAuthenticated,
        _currentUserProfile = currentUserProfile,
        _status = status,
        _profileRepository = profileRepository;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  AuthStatus get status => _status;
  @override
  Profile? get currentUserProfile => _currentUserProfile;
  @override
  ProfileRepository get profileRepository => _profileRepository ?? MockProfileRepository();
  @override
  bool get isAuthenticated => _isAuthenticated;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;

  @override
  bool get isPasswordRecoveryActive => false;

  @override
  void clearPasswordRecovery() {}

  @override
  Future<bool> isUsernameTaken(String username) async {
    return onIsUsernameTaken?.call(username) ?? false;
  }

  @override
  Future<bool> isEmailTaken(String email) async {
    return onIsEmailTaken?.call(email) ?? false;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> loginWithEmailAndPassword({required String email, required String password}) async {}

  @override
  Future<void> changePassword(String newPassword) async {}

  @override
  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? gender,
    String? country,
    String? description,
    required String colorMode,
    String? profilePictureUrl,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  bool get isAdmin => _currentUserProfile?.isAdmin ?? false;

  @override
  bool get isCompetitionCreator => _currentUserProfile?.isCompetitionCreator ?? false;

  @override
  bool get isAssociationCreator => _currentUserProfile?.isAssociationCreator ?? false;

  @override
  AdminRepository get adminRepository => AdminRepository(null);

  @override
  Future<PermissionApplication?> applyForPermissions(String type, String reason) async {
    return null;
  }

  @override
  Future<List<PermissionApplication>> getPermissionApplications() async {
    return [];
  }

  @override
  Future<PermissionApplication?> approvePermissionApplication(String applicationId) async {
    return null;
  }

  @override
  Future<PermissionApplication?> rejectPermissionApplication(String applicationId) async {
    return null;
  }

  @override
  Future<Profile?> promoteToAdmin(String userId) async {
    return null;
  }

  @override
  Future<SportConfig> loadSportsConfig() async {
    return SportConfig(sports: [], formats: [], disciplines: [], links: []);
  }

  @override
  Future<bool> saveSportsConfig(SportConfig config) async {
    return true;
  }

  @override
  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    required String fullName,
    String? gender,
    String? country,
    String? profilePictureUrl,
    Uint8List? customAvatarBytes,
    String? customAvatarExtension,
  }) async {}

  @override
  void clearError() {}

  @override
  Future<void> loginWithUsernameAndPassword({required String username, required String password}) async {}

  @override
  Future<String> resolveEmailFromUsername(String username) async => '';

  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  Session? get session => null;

  @override
  bool get hasListeners => false;
}

class MockFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult([
      PlatformFile(
        name: 'test_avatar.png',
        size: 100,
        bytes: base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
      ),
    ]);
  }
}

// Mock repository for UI testing
class FakeCompetitionRepository implements CompetitionRepository {
  final List<Competition> _fakeCompetitions = [
    Competition(
      id: '1',
      title: 'Hamburg Streetlifting Meet',
      location: 'Hamburg, Germany',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      startDate: DateTime.now().add(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '2',
      title: 'Classic Pull & Dip Cup',
      location: 'Berlin, Germany',
      sportSubtype: 'Classic',
      compGroupName: null,
      startDate: DateTime.now().add(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
  }) async {
    return _fakeCompetitions.where((comp) {
      if (query != null && query.isNotEmpty) {
        if (!comp.title.toLowerCase().contains(query.toLowerCase()))
          return false;
      }
      if (sportSubtype != null &&
          sportSubtype != 'All' &&
          comp.sportSubtype != sportSubtype) {
        return false;
      }
      if (compGroupName != null && compGroupName != 'All') {
        if (compGroupName == 'Individual') {
          if (comp.compGroupName != null) return false;
        } else if (comp.compGroupName != compGroupName) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

void main() {
  testWidgets('SearchFeedPage Renders and Filters Competitions', (
    WidgetTester tester,
  ) async {
    // Set screen size to desktop width so sidebar filters are visible
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeCompetitionRepository();
    final provider = CompetitionProvider(repo, MockProfileRepository());
    final authProvider = MockAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          home: SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
        ),
      ),
    );

    // Initial load frame
    await tester.pump();
    await tester.pump(Duration.zero); // Wait for provider fetch complete

    // Verify title and header logo elements exist
    expect(find.textContaining('Competitions'), findsAtLeast(1));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Search competitions',
      ),
      findsOneWidget,
    );

    // Verify both mock competitions exist on feed
    expect(find.text('Hamburg Streetlifting Meet'), findsOneWidget);
    expect(find.text('Classic Pull & Dip Cup'), findsOneWidget);

    // Verify modern/classic badge details
    expect(find.text('MODERN'), findsOneWidget);
    expect(find.text('CLASSIC'), findsOneWidget);

    // Expand the Format section
    final formatHeader = find.text('FORMAT');
    expect(formatHeader, findsOneWidget);
    await tester.tap(formatHeader);
    await tester.pumpAndSettle();

    // Filter by Modern subtype
    // Tap on the 'Modern' checkbox filter in the sidebar
    final modernFilter = find.text('Modern');
    expect(modernFilter, findsOneWidget);
    await tester.tap(modernFilter);
    await tester.pumpAndSettle();

    // Verify Classic competition is now filtered out
    expect(find.text('Hamburg Streetlifting Meet'), findsOneWidget);
    expect(find.text('Classic Pull & Dip Cup'), findsNothing);
  });

  testWidgets('CompetitionDetailPage renders details and action buttons', (
    WidgetTester tester,
  ) async {
    final comp = Competition(
      id: '123',
      title: 'Test Championship',
      location: 'New York, USA',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(home: CompetitionDetailPage(competition: comp)),
    );

    // Verify Title and Location are rendered
    expect(find.text('Test Championship'), findsOneWidget);
    expect(find.text('New York, USA'), findsOneWidget);

    // Verify Volunteer button exists
    expect(find.text('Apply as Volunteer'), findsOneWidget);

    // Verify Share button exists in the SliverAppBar actions
    expect(find.byIcon(Icons.share), findsOneWidget);
  });

  testWidgets('Navigation Drawer displays Color Mode', (
    WidgetTester tester,
  ) async {
    // Set screen size to mobile width so drawer is accessible
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeCompetitionRepository();
    final provider = CompetitionProvider(repo, MockProfileRepository());
    final authProvider = MockAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          home: SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(Duration.zero);

    // Open the navigation drawer by tapping the menu icon
    final menuIcon = find.byIcon(Icons.menu);
    expect(menuIcon, findsOneWidget);
    await tester.tap(menuIcon);
    await tester.pumpAndSettle();

    // Verify 'Color Mode' text is present
    expect(find.text('Color Mode'), findsOneWidget);
    expect(find.text('Theme Mode'), findsNothing);
  });

  testWidgets(
    'Verify layout options, search feed navigation, and filter chips location',
    (WidgetTester tester) async {
      // Desktop layout test
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeCompetitionRepository();
      final provider = CompetitionProvider(repo, MockProfileRepository());
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);

      // Verify sub-navigation bar has only "Competitions" and NOT "World Map"
      expect(find.text('Competitions'), findsAtLeast(1));
      expect(find.text('World Map'), findsNothing);

      // Verify layout selector dropdown exists
      expect(find.byTooltip('Select layout'), findsOneWidget);

      // Verify default layout is Grid (shows grid elements like CompetitionCard, list layout has CompetitionCompactRow)
      expect(find.byType(CompetitionCard), findsNWidgets(2));
      expect(find.byType(CompetitionCompactRow), findsNothing);

      // Toggle to Compact/List Layout via dropdown
      await tester.tap(find.byTooltip('Select layout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compact Layout'));
      await tester.pumpAndSettle();
      expect(provider.layout, CompetitionsLayout.list);
      expect(find.byType(CompetitionCompactRow), findsNWidgets(2));
      expect(find.byType(CompetitionCard), findsNothing);

      // Toggle to Map Layout via dropdown
      await tester.tap(find.byTooltip('Select layout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Map Layout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(provider.layout, CompetitionsLayout.map);
      expect(find.byType(WorldMapView), findsOneWidget);

      // In Map Layout, sort options should be hidden
      expect(find.byTooltip('Sort options'), findsNothing);

      // Toggle back to Grid via dropdown
      await tester.tap(find.byTooltip('Select layout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Grid Layout'));
      await tester.pumpAndSettle();
      expect(provider.layout, CompetitionsLayout.grid);
      expect(find.byTooltip('Sort options'), findsOneWidget);

      // Verify active filter chips are rendered in the Left Sidebar on desktop
      // We expand FORMAT and filter by Modern
      final formatHeader = find.text('FORMAT');
      await tester.tap(formatHeader);
      await tester.pumpAndSettle();

      final modernFilter = find.text('Modern');
      await tester.tap(modernFilter);
      await tester.pumpAndSettle();

      // Verify the active chip "Format: Modern" is shown.
      expect(find.text('Format: Modern'), findsOneWidget);
    },
  );

  testWidgets(
    'Verify mobile layout has bottom navigation bar, and filter chips are in the drawer',
    (WidgetTester tester) async {
      // Mobile layout
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeCompetitionRepository();
      final provider = CompetitionProvider(repo, MockProfileRepository());
      final authProvider = MockAuthProvider(isAuthenticated: true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);

      // Verify BottomNavigationBar is found
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Open the navigation drawer and verify no "World Map" list tile exists
      final menuIcon = find.byIcon(Icons.menu);
      await tester.tap(menuIcon);
      await tester.pumpAndSettle();

      expect(find.text('Competitions'), findsAtLeast(1));
      expect(find.text('World Map'), findsNothing);

      // Close the navigation drawer by popping it
      Navigator.of(tester.element(find.text('Competitions').first)).pop();
      await tester.pumpAndSettle();

      // Filter by modern using the mobile search page or filter drawer
      // In mobile, we tap the filter icon in the results header to open the filter drawer
      final filterButton = find.byTooltip('Filters');
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      // Expand FORMAT section in the drawer
      final formatHeader = find.descendant(
        of: find.byType(Drawer),
        matching: find.text('FORMAT'),
      );
      await tester.tap(formatHeader);
      await tester.pumpAndSettle();

      // Tap Modern checkbox
      final modernFilter = find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Modern'),
      );
      await tester.tap(modernFilter);
      await tester.pumpAndSettle();

      // Verify chip "Format: Modern" is shown inside the drawer
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Format: Modern'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Desktop Header displays separate Sign In and Register buttons for guest',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeCompetitionRepository();
      final provider = CompetitionProvider(repo, MockProfileRepository());
      final authProvider = MockAuthProvider(isAuthenticated: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);

      // Verify separate Sign In and Register buttons exist in desktop view
      expect(find.byKey(const Key('desktop_signin_button')), findsOneWidget);
      expect(find.byKey(const Key('desktop_register_button')), findsOneWidget);

      // Tap Sign In and verify LoginPage is pushed
      await tester.tap(find.byKey(const Key('desktop_signin_button')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  testWidgets(
    'RegisterPage has a multi-step registration flow with step validation',
    (WidgetTester tester) async {
      // Set physical size to avoid overflow warnings/tap offscreen errors
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final originalProvider = debugNetworkImageHttpClientProvider;
      debugNetworkImageHttpClientProvider = () => MockHttpClient();
      try {
        final authProvider = MockAuthProvider(isAuthenticated: false);

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: authProvider,
            child: const MaterialApp(
              home: RegisterPage(),
            ),
          ),
        );

        // Verify we start at Step 1: Account
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);
        expect(find.byKey(const Key('register_username_field')), findsOneWidget);
        expect(find.byKey(const Key('register_email_field')), findsOneWidget);
        expect(find.byKey(const Key('register_password_field')), findsOneWidget);

        // Verify password safety rules are displayed
        expect(find.text('Minimum 8 characters'), findsOneWidget);
        expect(find.text('At least one uppercase letter (A-Z)'), findsOneWidget);
        expect(find.text('At least one lowercase letter (a-z)'), findsOneWidget);
        expect(find.text('At least one numeric digit (0-9)'), findsOneWidget);
        expect(find.text('At least one special character (!@#\$%^&*)'), findsOneWidget);

        // Tap NEXT to advance - validation should trigger and keep us on Step 1
        // (NEXT is disabled since password is empty)
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        
        // Fields are still present, indicating we did not advance
        expect(find.byKey(const Key('register_username_field')), findsOneWidget);

        // Fill out Step 1 with a weak password (fails rules)
        await tester.enterText(find.byKey(const Key('register_username_field')), 'testuser');
        await tester.enterText(find.byKey(const Key('register_email_field')), 'test@email.com');
        await tester.enterText(find.byKey(const Key('register_password_field')), 'password123');
        await tester.pumpAndSettle();

        // NEXT should still be disabled because password rules are not met
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('register_username_field')), findsOneWidget);

        // Fill out Step 1 with a strong/valid password (satisfies all 5 rules)
        await tester.enterText(find.byKey(const Key('register_password_field')), 'Password123!');
        await tester.pumpAndSettle();

        // Tap NEXT to advance to Step 2
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();

        // Verify we are now on Step 2: Details
        expect(find.byKey(const Key('register_fullname_field')), findsOneWidget);
        expect(find.text('Gender'), findsOneWidget);
        expect(find.text('Country'), findsOneWidget);

        // Tap NEXT to validate Step 2 (Full Name is empty)
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('register_fullname_field')), findsOneWidget); // still on step 2

        // Fill out Step 2
        await tester.enterText(find.byKey(const Key('register_fullname_field')), 'Test User');
        await tester.pumpAndSettle();

        // Tap NEXT to advance to Step 3
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();

        // Verify we are on Step 3: Avatar / Profile Picture
        expect(find.text('Profile Picture'), findsOneWidget);
        expect(find.text('UPLOAD CUSTOM PHOTO'), findsOneWidget);

        // Setup custom FilePicker mock
        FilePicker? originalPlatform;
        try {
          originalPlatform = FilePicker.platform;
        } catch (_) {}
        FilePicker.platform = MockFilePicker();

        // Tap UPLOAD CUSTOM PHOTO
        await tester.tap(find.text('UPLOAD CUSTOM PHOTO'));
        await tester.pumpAndSettle();

        // Verify custom photo is previewed
        expect(find.text('test_avatar.png'), findsOneWidget);

        // Verify there is a delete/remove option and press it
        final deleteIcon = find.byIcon(Icons.delete_outline);
        expect(deleteIcon, findsOneWidget);
        await tester.tap(deleteIcon);
        await tester.pumpAndSettle();

        // Custom photo name should be gone, and UPLOAD CUSTOM PHOTO button visible again
        expect(find.text('test_avatar.png'), findsNothing);
        expect(find.text('UPLOAD CUSTOM PHOTO'), findsOneWidget);

        // Upload custom photo again for final registration submission test
        await tester.tap(find.text('UPLOAD CUSTOM PHOTO'));
        await tester.pumpAndSettle();
        expect(find.text('test_avatar.png'), findsOneWidget);

        // Tap CREATE ACCOUNT
        expect(find.text('CREATE ACCOUNT'), findsOneWidget);
        await tester.tap(find.text('CREATE ACCOUNT'));
        await tester.pump(); // Start request

        // Restore default FilePicker platform
        if (originalPlatform != null) {
          FilePicker.platform = originalPlatform;
        }

        // Tap BACK to return to Step 2 (if we were to click BACK)
        // Since we are mocking register, the tester is in step 3
      } finally {
        debugNetworkImageHttpClientProvider = originalProvider;
      }
    },
  );

  testWidgets(
    'Mobile drawer displays separate Sign In and Register buttons side-by-side',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeCompetitionRepository();
      final provider = CompetitionProvider(repo, MockProfileRepository());
      final authProvider = MockAuthProvider(isAuthenticated: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);

      // Open the navigation drawer by tapping the menu icon
      final menuIcon = find.byIcon(Icons.menu);
      expect(menuIcon, findsOneWidget);
      await tester.tap(menuIcon);
      await tester.pumpAndSettle();

      // Verify separate buttons exist in drawer
      expect(find.byKey(const Key('drawer_signin_button')), findsOneWidget);
      expect(find.byKey(const Key('drawer_register_button')), findsOneWidget);
    },
  );

  testWidgets(
    'ProfilePage refactoring renders settings icon, compact description, and edit button below description',
    (WidgetTester tester) async {
      final profile = Profile(
        id: 'user-123',
        username: 'johndoe',
        fullName: 'John Doe',
        email: 'john@example.com',
        description: 'Passionate lifter description.',
        colorMode: 'dark',
      );
      final authProvider = MockAuthProvider(
        isAuthenticated: true,
        currentUserProfile: profile,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: ProfilePage(),
          ),
        ),
      );

      await tester.pump();

      // Verify that settings icon next to the username exists
      expect(find.byIcon(Icons.settings), findsOneWidget);

      // Verify "About Me" title does NOT exist
      expect(find.text('About Me'), findsNothing);

      // Verify compact description exists
      expect(find.text('Passionate lifter description.'), findsOneWidget);

      // Verify "EDIT PROFILE" button exists below description
      expect(find.text('EDIT PROFILE'), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsPage renders details, subpages navigation, and logout',
    (WidgetTester tester) async {
      final profile = Profile(
        id: 'user-123',
        username: 'johndoe',
        fullName: 'John Doe',
        email: 'john@example.com',
        description: 'Passionate lifter description.',
        colorMode: 'dark',
      );
      final authProvider = MockAuthProvider(
        isAuthenticated: true,
        currentUserProfile: profile,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      await tester.pump();

      // Verify settings title
      expect(find.text('Settings'), findsOneWidget);

      // Verify profile details rendered directly on background
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('@johndoe'), findsOneWidget);

      // Verify subpage tiles exist
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);

      // Verify logout button
      expect(find.text('Log Out'), findsOneWidget);
    },
  );

  testWidgets(
    'AppearanceSettingsPage renders Default Color Mode preference',
    (WidgetTester tester) async {
      final profile = Profile(
        id: 'user-123',
        username: 'johndoe',
        fullName: 'John Doe',
        email: 'john@example.com',
        description: 'Passionate lifter description.',
        colorMode: 'dark',
      );
      final authProvider = MockAuthProvider(
        isAuthenticated: true,
        currentUserProfile: profile,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: AppearanceSettingsPage(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme Settings'), findsOneWidget);
      expect(find.text('Default Color Mode'), findsOneWidget);
    },
  );

  testWidgets(
    'ChangePasswordPage renders password rules, strength bar, and forms',
    (WidgetTester tester) async {
      final profile = Profile(
        id: 'user-123',
        username: 'johndoe',
        fullName: 'John Doe',
        email: 'john@example.com',
        description: 'Passionate lifter description.',
        colorMode: 'dark',
      );
      final authProvider = MockAuthProvider(
        isAuthenticated: true,
        currentUserProfile: profile,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: ChangePasswordPage(),
          ),
        ),
      );

      await tester.pump();

      // Verify Change Password page components
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Update Security Credentials'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);

      // Verify checklist
      expect(find.text('Security Requirements:'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('At least 1 uppercase letter (A-Z)'), findsOneWidget);
      expect(find.text('At least 1 lowercase letter (a-z)'), findsOneWidget);
      expect(find.text('At least 1 number (0-9)'), findsOneWidget);
      expect(find.text('At least 1 special character (e.g. !@#\$%^&*)'), findsOneWidget);

      // Verify "Forgot Password?" link on Change Password page
      expect(find.text('Forgot Password?'), findsOneWidget);
    },
  );

  testWidgets(
    'RegisterPage username and email availability checks block transition and display snackbar',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final originalProvider = debugNetworkImageHttpClientProvider;
      debugNetworkImageHttpClientProvider = () => MockHttpClient();
      try {
        // Case A: Username taken
        final authProviderUsernameTaken = MockAuthProvider(
          isAuthenticated: false,
          onIsUsernameTaken: (username) => true,
          onIsEmailTaken: (email) => false,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: authProviderUsernameTaken,
            child: const MaterialApp(
              home: RegisterPage(),
            ),
          ),
        );

        // Fill in Step 1
        await tester.enterText(find.byKey(const Key('register_username_field')), 'takenuser');
        await tester.enterText(find.byKey(const Key('register_email_field')), 'test@email.com');
        await tester.enterText(find.byKey(const Key('register_password_field')), 'Password123!');
        await tester.pumpAndSettle();

        // Click NEXT
        await tester.tap(find.text('NEXT'));
        await tester.pump(); // Start async check
        await tester.pump(const Duration(milliseconds: 100)); // allow async to resolve
        await tester.pumpAndSettle();

        // Should show Snackbar and remain on Step 1
        expect(find.text('Username is already taken'), findsOneWidget);
        expect(find.byKey(const Key('register_username_field')), findsOneWidget);

        // Case B: Email taken
        final authProviderEmailTaken = MockAuthProvider(
          isAuthenticated: false,
          onIsUsernameTaken: (username) => false,
          onIsEmailTaken: (email) => true,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: authProviderEmailTaken,
            child: const MaterialApp(
              home: RegisterPage(),
            ),
          ),
        );

        // Fill in Step 1
        await tester.enterText(find.byKey(const Key('register_username_field')), 'freeuser');
        await tester.enterText(find.byKey(const Key('register_email_field')), 'taken@email.com');
        await tester.enterText(find.byKey(const Key('register_password_field')), 'Password123!');
        await tester.pumpAndSettle();

        // Click NEXT
        await tester.tap(find.text('NEXT'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Should show Snackbar and remain on Step 1
        expect(find.text('Email is already taken'), findsOneWidget);
        expect(find.byKey(const Key('register_username_field')), findsOneWidget);
      } finally {
        debugNetworkImageHttpClientProvider = originalProvider;
      }
    },
  );

  testWidgets(
    'LoginPage forgot password dialog opens, inputs email, and cancels',
    (WidgetTester tester) async {
      final authProvider = MockAuthProvider(isAuthenticated: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Forgot Password? button is present
      final forgotPasswordButton = find.text('Forgot Password?');
      expect(forgotPasswordButton, findsOneWidget);

      // Tap Forgot Password?
      await tester.tap(forgotPasswordButton);
      await tester.pumpAndSettle();

      // Dialog should be open
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.byKey(const Key('forgot_password_email_field')), findsOneWidget);

      // Enter email
      await tester.enterText(find.byKey(const Key('forgot_password_email_field')), 'reset@example.com');
      await tester.pumpAndSettle();

      // Tap CANCEL
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Reset Password'), findsNothing);
    },
  );

  testWidgets(
    'ProfilePage renders social links and athlete dashboard components',
    (WidgetTester tester) async {
      final profile = Profile(
        id: 'user-123',
        username: 'johndoe',
        fullName: 'John Doe',
        email: 'john@example.com',
        description: 'Bio description.',
        colorMode: 'dark',
        gender: 'Male',
        country: 'Germany',
        socialLinks: {
          'instagram': 'https://instagram.com/johndoe',
          'youtube': 'https://youtube.com/johndoe',
        },
      );
      final authProvider = MockAuthProvider(
        isAuthenticated: true,
        currentUserProfile: profile,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: ProfilePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Verify gender and country badges
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Germany'), findsOneWidget);

      // Verify social links chips are rendered
      expect(find.textContaining('instagram'), findsOneWidget);
      expect(find.textContaining('youtube'), findsOneWidget);

      // Verify Athlete Dashboard sections are rendered
      expect(find.text('Athlete Dashboard'), findsOneWidget);
      expect(find.textContaining('Upcoming Meets'), findsOneWidget);
      expect(find.textContaining('Completed Meets'), findsOneWidget);
      expect(find.textContaining('Personal Records'), findsOneWidget);
      expect(find.textContaining('Highest Rankings'), findsOneWidget);
    },
  );

  testWidgets(
    'SearchFeedPage connects taps on ProfileCard and UserCompactRow to set selected profile state in desktop view',
    (WidgetTester tester) async {
      // Desktop view
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeCompetitionRepository();
      
      final searchedProfiles = [
        Profile(
          id: 'athlete-1',
          username: 'janedoe',
          fullName: 'Jane Doe',
          email: 'jane@example.com',
          colorMode: 'light',
          description: 'A dedicated lifter.',
          country: 'Germany',
        ),
      ];

      final mockProfileRepo = MockProfileRepository(profilesToReturn: searchedProfiles);
      final provider = CompetitionProvider(repo, mockProfileRepo);
      final authProvider = MockAuthProvider(isAuthenticated: true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: SearchFeedPage(onToggleTheme: () {}, isDarkMode: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);

      provider.setSearchScopeAndQuery(SearchScope.users, '');
      await tester.pumpAndSettle();

      // Verify ProfileCard is displayed
      expect(find.text('Jane Doe'), findsOneWidget);

      // Tap on the profile card (Jane Doe)
      await tester.tap(find.text('Jane Doe'));
      await tester.pumpAndSettle();

      // Verify that ProfilePage is shown inline and the back button is visible
      expect(find.text('Back to search feed'), findsOneWidget);
      expect(find.text('A dedicated lifter.'), findsOneWidget);

      // Tap back button
      await tester.tap(find.text('Back to search feed'));
      await tester.pumpAndSettle();

      // Back button is gone, we are back on the search feed
      expect(find.text('Back to search feed'), findsNothing);
    },
  );
}

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl) {
      return Future.value(MockHttpClientRequest());
    }
    if (invocation.memberName == #autoUncompress) {
      return true;
    }
    return null;
  }
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #close) {
      return Future.value(MockHttpClientResponse());
    }
    if (invocation.memberName == #headers) {
      return MockHttpHeaders();
    }
    return null;
  }
}

class MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class MockHttpClientResponse implements HttpClientResponse {
  static final List<int> kTransparentImage = [
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #listen) {
      final Stream<List<int>> stream = Stream.value(kTransparentImage);
      return stream.listen(
        invocation.positionalArguments[0] as void Function(List<int>),
        onError: invocation.namedArguments[#onError] as Function?,
        onDone: invocation.namedArguments[#onDone] as void Function()?,
        cancelOnError: invocation.namedArguments[#cancelOnError] as bool?,
      );
    }
    if (invocation.memberName == #statusCode) {
      return HttpStatus.ok;
    }
    if (invocation.memberName == #contentLength) {
      return kTransparentImage.length;
    }
    if (invocation.memberName == #compressionState) {
      return HttpClientResponseCompressionState.notCompressed;
    }
    return null;
  }
}
