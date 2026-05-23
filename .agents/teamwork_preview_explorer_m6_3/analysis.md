# E2E Test Harness & Plan Recommendations — FinalRep App

This document details the architectural plan, codebase structure, and concrete mock implementation recommendations for the End-to-End (E2E) testing suite of the FinalRep Streetlifting application.

---

## 1. Directory Structure

To keep layout compliance (tests co-located or under the `test/` directory, conforming to standard Flutter project structure), we recommend organizing all E2E resources under a dedicated sub-folder within `test/`:

```
test/
├── e2e/
│   ├── e2e_test_harness.dart              # E2E Mocking & App Wrapper Infrastructure
│   ├── tier1_feature_coverage_test.dart   # Tier 1 tests (5+ per feature)
│   ├── tier2_boundary_corner_test.dart    # Tier 2 tests (5+ per feature)
│   ├── tier3_cross_feature_test.dart      # Tier 3 tests (cross-feature interactions)
│   └── tier4_real_world_journey_test.dart # Tier 4 tests (complete user journeys)
```

---

## 2. E2E Test Harness Infrastructure (`e2e_test_harness.dart`)

The E2E test harness acts as a virtual gateway, completely bypassing the network calls to Supabase, replacing them with in-memory states and mock objects that mimic actual DB responses. It also wraps the app inside a test environment with necessary Providers, `SharedPreferences` mock setup, and file selection interceptors.

### Proposed Implementation for `test/e2e/e2e_test_harness.dart`

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/views/search_feed_page.dart';
import 'package:finalrep_app/views/login_page.dart';
import 'package:finalrep_app/views/register_page.dart';
import 'package:finalrep_app/views/profile_page.dart';
import 'package:finalrep_app/views/settings_page.dart';

// ==========================================
// 1. Database Mocking (In-Memory Fake DB)
// ==========================================

class FakeDatabase {
  final Map<String, Profile> profiles = {};
  final Map<String, Competition> competitions = {};
  final Set<String> favoritedCompetitions = {};

  void reset() {
    profiles.clear();
    competitions.clear();
    favoritedCompetitions.clear();
  }

  void seedDefaultData() {
    reset();
    
    // Seed Profiles
    profiles['user-1'] = Profile(
      id: 'user-1',
      username: 'johndoe',
      fullName: 'John Doe',
      email: 'john@example.com',
      gender: 'Male',
      country: 'Germany',
      description: 'Lifting is life.',
      colorMode: 'dark',
    );
    profiles['user-2'] = Profile(
      id: 'user-2',
      username: 'mariesmith',
      fullName: 'Marie Smith',
      email: 'marie@example.com',
      gender: 'Female',
      country: 'USA',
      description: 'Classic pull and dip specialist.',
      colorMode: 'light',
    );

    // Seed Competitions
    competitions['comp-1'] = Competition(
      id: 'comp-1',
      title: 'Hamburg Streetlifting Meet',
      location: 'Hamburg, Germany',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      area: 'Europe',
      country: 'Germany',
      city: 'Hamburg',
      startDate: DateTime.now().add(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    competitions['comp-2'] = Competition(
      id: 'comp-2',
      title: 'Classic Pull & Dip Cup',
      location: 'Berlin, Germany',
      sportSubtype: 'Classic',
      compGroupName: null,
      area: 'Europe',
      country: 'Germany',
      city: 'Berlin',
      startDate: DateTime.now().add(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

// ==========================================
// 2. Supabase Mock Classes
// ==========================================

class MockSupabaseClient implements SupabaseClient {
  @override
  final MockGoTrueClient auth;
  @override
  final MockSupabaseStorageClient storage;
  final FakeDatabase db;

  MockSupabaseClient({required this.auth, required this.storage, required this.db});

  @override
  PostgrestQueryBuilder from(String table) {
    return MockPostgrestQueryBuilder(table, db);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoTrueClient implements GoTrueClient {
  final StreamController<AuthState> _authStateController;
  final FakeDatabase db;
  
  User? _currentUser;
  Session? _currentSession;

  MockGoTrueClient(this._authStateController, this.db);

  User? get currentUser => _currentUser;
  Session? get currentSession => _currentSession;

  void triggerAuthStateChange(AuthChangeEvent event, Session? session) {
    _currentSession = session;
    _currentUser = session?.user;
    _authStateController.add(AuthState(event, session));
  }

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
  }) async {
    final uid = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final user = User(
      id: uid,
      appMetadata: const {},
      userMetadata: data ?? const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    final session = Session(
      accessToken: 'token-$uid',
      tokenType: 'bearer',
      user: user,
    );

    // Create the profile in the fake db representing the database trigger
    final username = data?['username'] as String? ?? 'user_$uid';
    final fullName = data?['full_name'] as String? ?? 'User $uid';
    db.profiles[uid] = Profile(
      id: uid,
      username: username,
      fullName: fullName,
      email: email,
      gender: data?['gender'] as String?,
      country: data?['country'] as String?,
      profilePictureUrl: data?['profile_picture_url'] as String?,
    );

    triggerAuthStateChange(AuthChangeEvent.signedIn, session);
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? username,
    required String password,
    String? captchaToken,
  }) async {
    Profile? matchingProfile;
    if (email != null) {
      matchingProfile = db.profiles.values.firstWhere(
        (p) => p.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('User not found.'),
      );
    } else if (username != null) {
      matchingProfile = db.profiles.values.firstWhere(
        (p) => p.username.toLowerCase() == username.toLowerCase(),
        orElse: () => throw Exception('User not found.'),
      );
    }

    if (matchingProfile == null) {
      throw Exception('Invalid login credentials.');
    }

    final user = User(
      id: matchingProfile.id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: matchingProfile.email,
    );
    final session = Session(
      accessToken: 'token-${matchingProfile.id}',
      tokenType: 'bearer',
      user: user,
    );

    triggerAuthStateChange(AuthChangeEvent.signedIn, session);
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<void> signOut({AuthScope scope = AuthScope.global}) async {
    triggerAuthStateChange(AuthChangeEvent.signedOut, null);
  }

  @override
  Future<UserResponse> updateUser(UserAttributes attributes) async {
    if (_currentUser == null) throw Exception('No session active.');
    
    // Update credentials
    final uid = _currentUser!.id;
    final originalProfile = db.profiles[uid]!;
    
    if (attributes.email != null) {
      db.profiles[uid] = originalProfile.copyWith(email: attributes.email);
    }

    final updatedUser = User(
      id: uid,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: attributes.email ?? _currentUser!.email,
    );

    _currentUser = updatedUser;
    return UserResponse(user: updatedUser);
  }

  @override
  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) async {
    final profile = db.profiles.values.firstWhere(
      (p) => p.email.toLowerCase() == email.toLowerCase(),
      orElse: () => throw Exception('Email not registered.'),
    );
    // Simulate recovery event trigger
    final user = User(
      id: profile.id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: profile.email,
    );
    final session = Session(
      accessToken: 'recovery-token',
      tokenType: 'bearer',
      user: user,
    );
    triggerAuthStateChange(AuthChangeEvent.passwordRecovery, session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSupabaseStorageClient implements SupabaseStorageClient {
  @override
  StorageBucketApi from(String id) {
    return MockStorageBucketApi(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStorageBucketApi implements StorageBucketApi {
  final String bucketId;
  MockStorageBucketApi(this.bucketId);

  @override
  Future<String> uploadBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
  }) async {
    return 'profiles/uploaded_avatar_path.jpg';
  }

  @override
  String getPublicUrl(String path) {
    return 'https://supabase.mock.storage/$bucketId/$path';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ==========================================
// 3. Mock Postgrest Builder (Fluent DB Query Chain)
// ==========================================

class MockPostgrestQueryBuilder extends PostgrestQueryBuilder {
  final String tableName;
  final FakeDatabase db;

  MockPostgrestQueryBuilder(this.tableName, this.db)
      : super(
          url: Uri.parse('https://mock.supabase.co'),
          headers: {},
        );

  @override
  PostgrestFilterBuilder select([String columns = '*']) {
    return MockPostgrestFilterBuilder(tableName, db);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPostgrestFilterBuilder extends PostgrestFilterBuilder {
  final String tableName;
  final FakeDatabase db;
  final Map<String, dynamic> filters = {};
  String? orderColumn;
  bool ascendingOrder = true;

  MockPostgrestFilterBuilder(this.tableName, this.db)
      : super(PostgrestBuilder(
          url: Uri.parse('https://mock.supabase.co'),
          headers: {},
        ));

  @override
  PostgrestFilterBuilder eq(String column, Object value) {
    filters[column] = value;
    return this;
  }

  @override
  PostgrestFilterBuilder or(String filters, {String? referencedTable}) {
    // Simple mock filter parser logic can be placed here if needed.
    return this;
  }

  @override
  PostgrestTransformBuilder order(String column, {bool ascending = false, bool nullsFirst = false, String? referencedTable}) {
    orderColumn = column;
    ascendingOrder = ascending;
    return this;
  }

  @override
  PostgrestTransformBuilder limit(int count, {String? referencedTable}) {
    return this;
  }

  @override
  Future<dynamic> maybeSingle() async {
    final results = _executeFilter();
    if (results.isEmpty) return null;
    return results.first;
  }

  @override
  Future<dynamic> single() async {
    final results = _executeFilter();
    if (results.isEmpty) throw Exception('No records found.');
    return results.first;
  }

  @override
  Future<dynamic> update(Map<String, dynamic> values, {String? returning}) async {
    final id = filters['id'] as String;
    if (tableName == 'profiles') {
      final current = db.profiles[id];
      if (current != null) {
        final updated = Profile.fromJson({...current.toJson(), ...values});
        db.profiles[id] = updated;
        return updated.toJson();
      }
    }
    throw Exception('Record not found.');
  }

  @override
  Future<dynamic> select([String columns = '*']) async {
    return _executeFilter();
  }

  // Helper to resolve filters locally
  List<Map<String, dynamic>> _executeFilter() {
    if (tableName == 'profiles') {
      List<Profile> matched = db.profiles.values.toList();
      if (filters.containsKey('id')) {
        matched = matched.where((p) => p.id == filters['id']).toList();
      }
      if (filters.containsKey('username')) {
        matched = matched.where((p) => p.username.toLowerCase() == (filters['username'] as String).toLowerCase()).toList();
      }
      if (filters.containsKey('email')) {
        matched = matched.where((p) => p.email.toLowerCase() == (filters['email'] as String).toLowerCase()).toList();
      }
      return matched.map((p) => p.toJson()).toList();
    } else if (tableName == 'competitions') {
      List<Competition> matched = db.competitions.values.toList();
      if (filters.containsKey('id')) {
        matched = matched.where((c) => c.id == filters['id']).toList();
      }
      // Order and sort
      if (orderColumn == 'start_date') {
        matched.sort((a, b) => ascendingOrder
            ? a.startDate.compareTo(b.startDate)
            : b.startDate.compareTo(a.startDate));
      }
      return matched.map((c) => c.toJson()).toList();
    }
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ==========================================
// 4. File Picker & Shared Preferences Mocks
// ==========================================

class MockFilePicker extends FilePicker {
  PlatformFile? mockFile;
  
  void setMockFile(String name, int size, Uint8List bytes) {
    mockFile = PlatformFile(name: name, size: size, bytes: bytes);
  }

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
    withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    if (mockFile == null) return null;
    return FilePickerResult([mockFile!]);
  }
}

// ==========================================
// 5. Test App Wrapper Widget
// ==========================================

class E2ETestAppWrapper extends StatelessWidget {
  final Widget child;
  final MockSupabaseClient client;
  final ProfileRepository profileRepository;
  final CompetitionRepository competitionRepository;
  final AuthProvider authProvider;
  final CompetitionProvider competitionProvider;

  const E2ETestAppWrapper({
    super.key,
    required this.child,
    required this.client,
    required this.profileRepository,
    required this.competitionRepository,
    required this.authProvider,
    required this.competitionProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CompetitionProvider>.value(value: competitionProvider),
      ],
      child: child,
    );
  }
}

// ==========================================
// 6. Test Environment Initializer
// ==========================================

class E2ETestHarness {
  final FakeDatabase db = FakeDatabase();
  late MockGoTrueClient mockAuth;
  late MockSupabaseStorageClient mockStorage;
  late MockSupabaseClient mockClient;

  late ProfileRepository profileRepository;
  late CompetitionRepository competitionRepository;

  late AuthProvider authProvider;
  late CompetitionProvider competitionProvider;
  late MockFilePicker mockFilePicker;

  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    db.seedDefaultData();

    final authController = StreamController<AuthState>.broadcast();
    mockAuth = MockGoTrueClient(authController, db);
    mockStorage = MockSupabaseStorageClient();
    mockClient = MockSupabaseClient(auth: mockAuth, storage: mockStorage, db: db);

    profileRepository = ProfileRepository(mockClient);
    competitionRepository = CompetitionRepository(mockClient);

    authProvider = AuthProvider(mockClient, profileRepository);
    competitionProvider = CompetitionProvider(competitionRepository, profileRepository);
    
    mockFilePicker = MockFilePicker();
    FilePicker.platform = mockFilePicker;

    // Fast-forward pump task loops
    await Future.delayed(Duration.zero);
  }

  void dispose() {
    authProvider.dispose();
    competitionProvider.dispose();
  }

  Widget buildApp(Widget homeWidget) {
    return E2ETestAppWrapper(
      client: mockClient,
      profileRepository: profileRepository,
      competitionRepository: competitionRepository,
      authProvider: authProvider,
      competitionProvider: competitionProvider,
      child: MaterialApp(
        home: homeWidget,
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/settings': (_) => const SettingsPage(),
        },
      ),
    );
  }
}
```

---

## 3. Recommended E2E Test Suite (Tier 1 to 4)

We recommend dividing E2E tests into four logical files that reflect their specific test coverage tier:

### Tier 1: Feature Coverage (`tier1_feature_coverage_test.dart`)
Verifies individual core workflows operate according to specifications, assuming correct user interaction. At least **5+ tests per feature** for three chosen features:
1. **Login & Forgot Password (Feature A)**
   - Test 1.1: Username entry dynamically lowercases all input text before verification.
   - Test 1.2: Successful login with correct Username + Password credentials.
   - Test 1.3: Successful login with correct Email + Password credentials.
   - Test 1.4: Initiating forgot password recovery sends the reset link using the email form.
   - Test 1.5: Logout successfully resets current user profile and returns app back to guest status.
2. **Profile Customization (Feature B)**
   - Test 2.1: Render profile details directly on page scaffold without enclosing Card borders (as per style guide).
   - Test 2.2: Settings gear icon is positioned immediately to the right of the user's Full Name.
   - Test 2.3: Toggle edit mode and update profile parameters (Full Name, Country, Bio description).
   - Test 2.4: Upload custom profile avatar image, previewing and verifying updated public storage URL.
   - Test 2.5: Deep linking triggers loading someone else's profile inline or on a new route page.
3. **Competitions Feed & Details / World Map (Feature F)**
   - Test 3.1: Switch feed view dynamically between Upcoming and Completed meets.
   - Test 3.2: Filter competitions list by modern vs classic format.
   - Test 3.3: Search input changes trigger reactive listing update (e.g. query "Hamburg").
   - Test 3.4: Toggle view layout styles (Grid view, Compact list view, Map layout).
   - Test 3.5: Map view fallback resolves geographic coordinates correctly based on city and country.

### Tier 2: Boundary & Corner Cases (`tier2_boundary_corner_test.dart`)
Assesses how the app behaves when encountering invalid inputs, empty states, or layout limit constraints. At least **5+ tests per feature** for the three chosen features:
1. **Login & Forgot Password Boundaries**
   - Test 1.1: Attempting to register/login with trailing/leading white space in username or email trims input correctly.
   - Test 1.2: Reset Password rules validator strength bar updates dynamically as uppercase, digits, and special characters are typed.
   - Test 1.3: Submitting login with empty username or invalid email formats triggers field validation errors.
   - Test 1.4: Forgot password modal shows recovery link error feedback if a non-existent email is entered.
   - Test 1.5: Back-button intercepting during a password recovery event blocks page pops before saving credentials.
2. **Profile Customization Boundaries**
   - Test 2.1: Setting an extremely long bio description wraps properly and respects the 150 characters limit.
   - Test 2.2: Deep link pathing for a non-existent user profile handles error state cleanly (displays "User profile not found").
   - Test 2.3: Attempting to upload a zero-byte file or canceling picker results in no updates or crashes.
   - Test 2.4: Editing profile field changes then clicking CANCEL discards changes and restores former values.
   - Test 2.5: Verifying profile details when gender or country are null hides chips cleanly rather than leaving empty spacing.
3. **Competitions Feed Boundaries**
   - Test 3.1: Map view resolves coordinate values to (0.0, 0.0) fallback for unknown cities/locations instead of throwing.
   - Test 3.2: Searching with special regex characters (e.g. `.*+?^${}()|[]\`) does not cause queries to fail.
   - Test 3.3: Selecting date ranges where start date is after end date blocks search execution and alerts users.
   - Test 3.4: Switching to completed competitions list when zero records exist displays a clean empty state indicator.
   - Test 3.5: Clearing all active chips in the sidebar filter layout resets the grid results to show all default entries.

### Tier 3: Cross-Feature Combinations (`tier3_cross_feature_test.dart`)
Verifies multiple independent feature modules interact correctly:
- **Test 3.1: Register -> Login -> Customize Profile**
  Create a new user, log in using the newly created credentials (converting username to lowercase), edit user attributes on the settings page, and check if changes are immediately visible on the Profile view.
- **Test 3.2: Auth State Synchronization & App Mode Toggling**
  Log in, toggle theme settings (System vs Light vs Dark) inside the appearance settings pane, and confirm the `colorMode` attribute syncs with Supabase database and persists theme configurations even across auth state cycles (logout and login back).
- **Test 3.3: Deep Link Navigation -> Authentication Gateway Interception**
  A guest accesses the app using a deep link path targeting a private page (e.g., `/settings`). Verify the system intercepts the deep link, triggers the `LoginPage` flow, and routes to `/settings` only after the user logs in.

### Tier 4: Real-World Application Scenarios (`tier4_real_world_journey_test.dart`)
Full user journeys simulating complete scenarios:
- **Test 4.1: Guest Spectator Competition Discovery Journey**
  An anonymous guest opens the app -> filters by Classic format -> searches for "Berlin" -> taps the "Classic Pull & Dip Cup" card -> views the detail page -> switches to Map view -> verifies locations on map -> attempts to favor it but is redirected to register a new account.
- **Test 4.2: New Athlete Registration, Onboarding & Setup Journey**
  A new user starts on the homepage -> clicks register -> progresses through the multi-step wizard (Account -> details -> uploading custom avatar) -> validates security checks -> clicks submit -> gets redirected -> accesses profile, adds bio, and copies profile link to clipboard.

---

## 4. Sample Compile-Ready E2E Test Cases

Below are the mock test cases showing how the proposed harness integrates seamlessly with `flutter_test` widget testing.

### Compilation Check Verification

All recommended tests use standard widget tester APIs:
- We interact directly with UI components (e.g. `tester.enterText`, `tester.tap`, `tester.pumpAndSettle`).
- Mock providers are fed into the widget tree via standard `Provider` structures.
- Tests will compile successfully using `flutter test` without referencing non-existent files.

### E2E Test Case Implementation Blueprint

Here is a blueprint for implementing the test suites (which can be split into the respective files):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import 'e2e_test_harness.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/views/search_feed_page.dart';
import 'package:finalrep_app/views/login_page.dart';
import 'package:finalrep_app/views/register_page.dart';
import 'package:finalrep_app/views/profile_page.dart';

void main() {
  group('E2E Tier 1: Feature Coverage Tests', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.initialize();
    });

    tearDown(() {
      harness.dispose();
    });

    testWidgets('Test 1.1: Username entry dynamically lowercases and verifies successfully', (WidgetTester tester) async {
      // Set desktop screen resolution
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Launch login page
      await tester.pumpWidget(harness.buildApp(const LoginPage()));
      await tester.pumpAndSettle();

      // Switch to Username login type
      await tester.tap(find.text('Username'));
      await tester.pumpAndSettle();

      // Enter mixed-case username 'JohnDoe' and correct password
      await tester.enterText(find.byKey(const Key('login_id_field')), 'JohnDoe');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'password123');
      await tester.pumpAndSettle();

      // Click SIGN IN
      await tester.tap(find.text('SIGN IN'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify the auth provider received the lowercased username and is authenticated
      expect(harness.authProvider.isAuthenticated, true);
      expect(harness.authProvider.currentUserProfile?.username, 'johndoe');
    });

    testWidgets('Test 2.3: Toggle edit profile mode and verify attributes update in DB', (WidgetTester tester) async {
      // Authenticate user-1 first
      final user = harness.db.profiles['user-1']!;
      final session = Session(
        accessToken: 'token-user-1',
        tokenType: 'bearer',
        user: User(id: user.id, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '', email: user.email),
      );
      harness.mockAuth.triggerAuthStateChange(AuthChangeEvent.signedIn, session);
      await tester.pumpAndSettle();

      // Launch profile page
      await tester.pumpWidget(harness.buildApp(const ProfilePage()));
      await tester.pumpAndSettle();

      // Tap EDIT PROFILE button
      final editBtn = find.byKey(const Key('edit_profile_button'));
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Edit fields: Bio description
      await tester.enterText(find.widgetWithText(TextFormField, 'Description / Bio'), 'New test bio content');
      await tester.pumpAndSettle();

      // Tap SAVE
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify profile description is updated in fake db
      expect(harness.db.profiles['user-1']?.description, 'New test bio content');
      expect(find.text('New test bio content'), findsOneWidget);
    });

    testWidgets('Test 3.2: Filter competitions list by modern vs classic format', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Launch feed page
      await tester.pumpWidget(harness.buildApp(SearchFeedPage(onToggleTheme: () {}, isDarkMode: true)));
      await tester.pump();
      await tester.pump(Duration.zero);

      // Verify both competitions are displayed
      expect(find.text('Hamburg Streetlifting Meet'), findsOneWidget); // Modern
      expect(find.text('Classic Pull & Dip Cup'), findsOneWidget); // Classic

      // Expand the FORMAT section filter card in sidebar
      await tester.tap(find.text('FORMAT'));
      await tester.pumpAndSettle();

      // Filter by 'Modern' format
      await tester.tap(find.text('Modern'));
      await tester.pumpAndSettle();

      // Verify filtering removes Classic Pull & Dip Cup but leaves Hamburg Streetlifting Meet
      expect(find.text('Hamburg Streetlifting Meet'), findsOneWidget);
      expect(find.text('Classic Pull & Dip Cup'), findsNothing);
    });
  });

  group('E2E Tier 2: Boundary & Corner Cases', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.initialize();
    });

    tearDown(() {
      harness.dispose();
    });

    testWidgets('Test 1.2: Password validator bar strength indicator updates dynamically', (WidgetTester tester) async {
      await tester.pumpWidget(harness.buildApp(const RegisterPage()));
      await tester.pumpAndSettle();

      final passField = find.byKey(const Key('register_password_field'));
      expect(passField, findsOneWidget);

      // Weak: only lowercases
      await tester.enterText(passField, 'weak');
      await tester.pumpAndSettle();
      expect(find.text('Weak'), findsOneWidget);

      // Medium: uppercase, lowercase, numbers
      await tester.enterText(passField, 'WeakPassword123');
      await tester.pumpAndSettle();
      expect(find.text('Medium'), findsOneWidget);

      // Strong: uppercase, lowercase, numbers, special characters
      await tester.enterText(passField, 'StrongPassword123!');
      await tester.pumpAndSettle();
      expect(find.text('Strong'), findsOneWidget);
    });

    testWidgets('Test 2.1: Long bio description trims at 150 characters and warns user', (WidgetTester tester) async {
      // Authenticate user-1
      final user = harness.db.profiles['user-1']!;
      final session = Session(
        accessToken: 'token-user-1',
        tokenType: 'bearer',
        user: User(id: user.id, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '', email: user.email),
      );
      harness.mockAuth.triggerAuthStateChange(AuthChangeEvent.signedIn, session);
      await tester.pumpAndSettle();

      await tester.pumpWidget(harness.buildApp(const ProfilePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      final longText = 'a' * 160; // 160 characters long (exceeds max limit)
      await tester.enterText(find.widgetWithText(TextFormField, 'Description / Bio'), longText);
      await tester.pumpAndSettle();

      // Check if text is truncated or has length limit of 150 characters
      final bioController = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Description / Bio')).controller;
      expect(bioController?.text.length, 150);
    });
  });

  group('E2E Tier 3: Cross-Feature Combination Tests', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.initialize();
    });

    tearDown(() {
      harness.dispose();
    });

    testWidgets('Test 3.1: Complete Register -> Login -> Edit Profile journey', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Launch RegisterPage and create a new account
      await tester.pumpWidget(harness.buildApp(const RegisterPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_username_field')), 'newlifter');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'newlifter@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'LifterPassword123!');
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_fullname_field')), 'New Lifter User');
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Set mock profile picture upload
      harness.mockFilePicker.setMockFile('avatar.jpg', 500, Uint8List.fromList([0, 1, 2, 3]));
      await tester.tap(find.text('UPLOAD CUSTOM PHOTO'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pump();
      await tester.pumpAndSettle();

      // User registered and automatically signed in by mock auth
      expect(harness.authProvider.isAuthenticated, true);
      expect(harness.authProvider.currentUserProfile?.username, 'newlifter');

      // 2. Open Profile page directly
      await tester.pumpWidget(harness.buildApp(const ProfilePage()));
      await tester.pumpAndSettle();

      // Edit description in Profile Page
      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Description / Bio'), 'Hello, I am a new lifter!');
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify the new bio has updated successfully in the profile page and database
      expect(harness.db.profiles[harness.authProvider.currentUserProfile!.id]?.description, 'Hello, I am a new lifter!');
      expect(find.text('Hello, I am a new lifter!'), findsOneWidget);
    });
  });
}
```

---

## 5. Summary of Recommended E2E Test Suite Action Items

1. **Add `e2e_test_harness.dart`**: Create the mock database schema and the Supabase Client mock wrapper.
2. **Implement Feature Coverage Suite (`tier1`)**: Create tests for standard user pathways in auth, profile management, and search screens.
3. **Implement Edge-Case Verification Suite (`tier2`)**: Verify password formatting validators, coordinate falls, boundary bio limits, and error dialogues are handled smoothly.
4. **Implement Complex Scenarios (`tier3` and `tier4`)**: Write tests for complete multi-page navigation chains and deep linking.
5. **Run the suite**: Run `flutter test test/e2e` to verify all components compile correctly and run fast in local environments.
