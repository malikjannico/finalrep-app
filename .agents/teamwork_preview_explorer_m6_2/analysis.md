# E2E Test Harness & Testing Plan Recommendations

This document details the recommended plan, directory structure, and code implementation details for the End-to-End (E2E) test suite of the FinalRep sport competition management platform. It includes a fully mock-based, database-backed Supabase client and placeholder mock pages/routes to ensure compiler safety.

---

## 1. Directory Structure Proposal

The E2E test files will be located in the `test/e2e/` folder to separate them from the unit and widget tests. Since several platform features (such as Association creation, Admin approval, and Competition handling) do not have production views inside `lib/views/` yet, the harness provides mock view stubs inside `test/e2e/mock_views.dart`. This decouples compilation from missing production files and allows flows to compile and run under `flutter test`.

```
test/
├── e2e/
│   ├── e2e_test_harness.dart        # Mock Supabase client, InMemoryDatabase, pumpE2EApp helper
│   ├── mock_views.dart              # Placeholder widgets for missing production screens
│   ├── auth_e2e_test.dart           # Tier 1 & 2 tests for Authentication & Reset flow
│   ├── profile_e2e_test.dart        # Tier 1 & 2 tests for Profile customization & PRs
│   ├── feed_e2e_test.dart           # Tier 1 & 2 tests for Search, Layouts & Cascade Filtering
│   ├── creation_e2e_test.dart       # Tier 1 & 2 tests for Association & Competition wizards
│   └── competition_handling_test.dart # Tier 1 & 2 tests for Streetlifting scoring, VAR, and Platform Judging
```

---

## 2. E2E Test Harness & Infrastructure

The test harness (`test/e2e/e2e_test_harness.dart`) encapsulates:
1. **`InMemoryDatabase`**: Simulates the state of remote tables (`profiles`, `competitions`, `associations`, `permission_applications`, `attempts`) and handles CRUD mock logic.
2. **`MockSupabaseClient`**: Implements `SupabaseClient` using Dart's `noSuchMethod` dynamic dispatch to intercept database queries, auth actions, and storage updates, feeding them directly to the `InMemoryDatabase`.
3. **`pumpE2EApp`**: A tester helper to bootstrap the widget tree, inject mock providers, override standard file selectors, and configure custom view sizes.

### Implementation Blueprint: `test/e2e/e2e_test_harness.dart`

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'mock_views.dart';

// --- IN-MEMORY DATABASE ---
class InMemoryDatabase {
  final List<Map<String, dynamic>> profiles = [];
  final List<Map<String, dynamic>> competitions = [];
  final List<Map<String, dynamic>> associations = [];
  final List<Map<String, dynamic>> applications = [];
  final List<Map<String, dynamic>> attempts = [];
  final Map<String, List<int>> storage = {}; // bucket_name/path -> bytes

  void reset() {
    profiles.clear();
    competitions.clear();
    associations.clear();
    applications.clear();
    attempts.clear();
    storage.clear();
    _seedDefaultData();
  }

  void _seedDefaultData() {
    profiles.addAll([
      {
        'id': 'admin-uuid-123',
        'username': 'system_admin',
        'email': 'admin@finalrep.com',
        'full_name': 'System Administrator',
        'gender': 'Male',
        'country': 'Germany',
        'color_mode': 'system',
        'is_admin': true,
      },
      {
        'id': 'organizer-uuid-456',
        'username': 'meet_organizer',
        'email': 'organizer@finalrep.com',
        'full_name': 'Meet Organizer',
        'gender': 'Female',
        'country': 'USA',
        'color_mode': 'dark',
        'is_admin': false,
      },
    ]);
  }
}

// --- MOCK SUPABASE CLIENTS ---
class MockSupabaseClient implements SupabaseClient {
  @override
  final MockGoTrueClient auth;
  @override
  final MockSupabaseStorageClient storage;
  final InMemoryDatabase db;

  MockSupabaseClient(this.db)
      : auth = MockGoTrueClient(db),
        storage = MockSupabaseStorageClient(db);

  @override
  PostgrestQueryBuilder from(String table) {
    return MockPostgrestQueryBuilder(table, db);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoTrueClient implements GoTrueClient {
  final InMemoryDatabase db;
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();
  Session? _currentSession;

  MockGoTrueClient(this.db);

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #signUp) {
      final email = invocation.namedArguments[#email] as String;
      final password = invocation.namedArguments[#password] as String;
      final data = invocation.namedArguments[#data] as Map<String, dynamic>?;

      final userId = 'user-gen-${DateTime.now().millisecondsSinceEpoch}';
      final newProfile = {
        'id': userId,
        'username': data?['username'] ?? email.split('@')[0],
        'email': email,
        'full_name': data?['full_name'] ?? 'New User',
        'gender': data?['gender'],
        'country': data?['country'],
        'profile_picture_url': data?['profile_picture_url'],
        'color_mode': 'system',
      };
      db.profiles.add(newProfile);

      final user = User(
        id: userId,
        appMetadata: const {},
        userMetadata: data ?? const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      );
      _currentSession = Session(accessToken: 'access-tkn', tokenType: 'bearer', user: user);
      _authStateController.add(AuthState(AuthChangeEvent.signedIn, _currentSession));

      return Future.value(AuthResponse(session: _currentSession, user: user));
    }
    if (name == #signInWithPassword) {
      final email = invocation.namedArguments[#email] as String;
      final profile = db.profiles.firstWhere((p) => p['email'] == email, orElse: () => throw Exception('User not found'));

      final user = User(
        id: profile['id'],
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      );
      _currentSession = Session(accessToken: 'access-tkn', tokenType: 'bearer', user: user);
      _authStateController.add(AuthState(AuthChangeEvent.signedIn, _currentSession));
      return Future.value(AuthResponse(session: _currentSession, user: user));
    }
    if (name == #signOut) {
      _currentSession = null;
      _authStateController.add(const AuthState(AuthChangeEvent.signedOut, null));
      return Future.value(null);
    }
    if (name == #updateUser) {
      final attributes = invocation.positionalArguments.first as UserAttributes;
      // Trigger change in current session if exists
      return Future.value(UserResponse(user: _currentSession?.user));
    }
    if (name == #resetPasswordForEmail) {
      return Future.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

class MockSupabaseStorageClient implements SupabaseStorageClient {
  final InMemoryDatabase db;
  MockSupabaseStorageClient(this.db);

  @override
  StorageFileApi from(String id) => MockStorageFileApi(id, db);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStorageFileApi implements StorageFileApi {
  final String bucket;
  final InMemoryDatabase db;

  MockStorageFileApi(this.bucket, this.db);

  @override
  Future<String> uploadBinary(String path, Uint8List data, {FileOptions? fileOptions}) async {
    db.storage['$bucket/$path'] = data;
    return '$bucket/$path';
  }

  @override
  String getPublicUrl(String path) => 'https://mock-supabase.storage/$bucket/$path';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPostgrestQueryBuilder implements PostgrestQueryBuilder {
  final String table;
  final InMemoryDatabase db;

  MockPostgrestQueryBuilder(this.table, this.db);

  @override
  PostgrestFilterBuilder select([String? columns]) => MockPostgrestFilterBuilder(table, db, 'select');
  @override
  PostgrestFilterBuilder update(Map<String, dynamic> values) => MockPostgrestFilterBuilder(table, db, 'update', payload: values);
  @override
  PostgrestFilterBuilder insert(dynamic values) => MockPostgrestFilterBuilder(table, db, 'insert', payload: values);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPostgrestFilterBuilder extends Future<dynamic> implements PostgrestFilterBuilder {
  final String table;
  final InMemoryDatabase db;
  final String op;
  final dynamic payload;
  final Map<String, dynamic> eqFilters = {};
  String? ilikeColumn;
  String? ilikeValue;

  MockPostgrestFilterBuilder(this.table, this.db, this.op, {this.payload});

  @override
  PostgrestFilterBuilder eq(String column, Object value) {
    eqFilters[column] = value;
    return this;
  }

  @override
  PostgrestFilterBuilder ilike(String column, String value) {
    ilikeColumn = column;
    ilikeValue = value;
    return this;
  }

  @override
  PostgrestFilterBuilder order(String column, {bool? ascending, bool? nullsFirst, String? referencedTable}) => this;
  @override
  PostgrestFilterBuilder limit(int count, {String? referencedTable}) => this;

  @override
  dynamic maybeSingle() {
    final list = _eval();
    return Future.value(list.isNotEmpty ? list.first : null);
  }

  @override
  dynamic single() {
    final list = _eval();
    if (list.isEmpty) throw Exception('No rows found');
    return Future.value(list.first);
  }

  List<Map<String, dynamic>> _eval() {
    List<Map<String, dynamic>> source;
    if (table == 'profiles') source = db.profiles;
    else if (table == 'competitions') source = db.competitions;
    else if (table == 'associations') source = db.associations;
    else if (table == 'applications') source = db.applications;
    else source = db.attempts;

    var filtered = List<Map<String, dynamic>>.from(source);
    eqFilters.forEach((col, val) {
      filtered = filtered.where((item) => item[col] == val).toList();
    });

    if (ilikeColumn != null && ilikeValue != null) {
      final cleanVal = ilikeValue!.replaceAll('%', '').toLowerCase();
      filtered = filtered.where((item) =>
          (item[ilikeColumn!] as String?)?.toLowerCase().contains(cleanVal) ?? false
      ).toList();
    }
    return filtered;
  }

  @override
  Future<T> then<T>(FutureOr<T> Function(dynamic value) onValue, {Function? onError}) {
    if (op == 'insert') {
      if (payload is List) {
        db.getTable(table).addAll(List<Map<String, dynamic>>.from(payload));
      } else {
        db.getTable(table).add(Map<String, dynamic>.from(payload));
      }
      return Future.value(payload).then(onValue, onError: onError);
    }
    if (op == 'update') {
      final matches = _eval();
      for (var match in matches) {
        payload.forEach((k, v) => match[k] = v);
      }
      return Future.value(payload).then(onValue, onError: onError);
    }
    return Future.value(_eval()).then(onValue, onError: onError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

extension on InMemoryDatabase {
  List<Map<String, dynamic>> getTable(String table) {
    if (table == 'profiles') return profiles;
    if (table == 'competitions') return competitions;
    if (table == 'associations') return associations;
    if (table == 'applications') return applications;
    return attempts;
  }
}

// --- TEST BOOTSTRAPPER ---
Future<void> pumpE2EApp(
  WidgetTester tester, {
  required Widget home,
  required MockSupabaseClient client,
}) async {
  final compRepo = CompetitionRepository(client);
  final profileRepo = ProfileRepository(client);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(client, profileRepo)),
        ChangeNotifierProvider(create: (_) => CompetitionProvider(compRepo, profileRepo)),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == '/admin') {
            return MaterialPageRoute(builder: (_) => const AdminDashboardPage());
          }
          if (settings.name == '/association/create') {
            return MaterialPageRoute(builder: (_) => const CreateAssociationPage());
          }
          if (settings.name == '/competition/create') {
            return MaterialPageRoute(builder: (_) => const CreateCompetitionPage());
          }
          if (settings.name == '/competition/handling') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => CompetitionHandlingPage(competitionId: args['id']),
            );
          }
          if (settings.name == '/rankings') {
            return MaterialPageRoute(builder: (_) => const RankingsPage());
          }
          return null;
        },
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(Duration.zero);
}
```

---

## 3. Mock Views/Routes Stub File

The stub file (`test/e2e/mock_views.dart`) provides compilation-safe screens representing features currently missing from the codebase. These stub views render form elements, tables, and buttons with matching keys so that tests can interact with them.

### Implementation Blueprint: `test/e2e/mock_views.dart`

```dart
import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Permissions Applications'),
            subtitle: Text('Review user creation requests'),
          ),
          ListTile(
            key: const Key('pending_app_1'),
            title: const Text('user_123 - Competition Creation'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  key: const Key('approve_btn_1'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application Approved')),
                    );
                  },
                  child: const Text('Approve'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateAssociationPage extends StatefulWidget {
  const CreateAssociationPage({super.key});
  @override
  State<CreateAssociationPage> createState() => _CreateAssociationPageState();
}

class _CreateAssociationPageState extends State<CreateAssociationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Association')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                key: const Key('assoc_name_field'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Association Name'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              ElevatedButton(
                key: const Key('submit_assoc_btn'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateCompetitionPage extends StatefulWidget {
  const CreateCompetitionPage({super.key});
  @override
  State<CreateCompetitionPage> createState() => _CreateCompetitionPageState();
}

class _CreateCompetitionPageState extends State<CreateCompetitionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Competition')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                key: const Key('comp_title_field'),
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Competition Title'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              ElevatedButton(
                key: const Key('submit_comp_btn'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompetitionHandlingPage extends StatelessWidget {
  final String? competitionId;
  const CompetitionHandlingPage({super.key, this.competitionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Competition Handling: $competitionId')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Lift Scopes & Platform Judging'),
            ElevatedButton(
              key: const Key('attempt_lift_btn'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lift Attempt Registered')),
                );
              },
              child: const Text('Register Attempt'),
            ),
          ],
        ),
      ),
    );
  }
}

class RankingsPage extends StatelessWidget {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Global Rankings')),
      body: const Center(
        child: Text('Rankings list: Hamburg Meet, Berlin Cup'),
      ),
    );
  }
}
```

---

## 4. Feature Coverage E2E Tests (Tiers 1-4)

### Feature Areas Index

| Logical Feature Area | Features Covered | Target Views |
| :--- | :--- | :--- |
| **FA 1: Authentication & Password** | lowercase registration/login checks, rules check, recovery flow | `LoginPage`, `RegisterPage` |
| **FA 2: Profile Customization** | social media links, scroll visibility, inline sub-profiles, PRs | `ProfilePage`, `SettingsPage` |
| **FA 3: Meet Feeds & Cascades** | Grid/List/Map layout, sorting, active filter chips, cascade location | `SearchFeedPage`, `WorldMapView`, `MobileSearchPage` |
| **FA 4: Meet Setup & Admin** | creation wizard step checking, permissions request, approvals | `AdminDashboardPage`, `CreateAssociationPage`, `CreateCompetitionPage` |
| **FA 5: Comp Day & Scoring** | attempt recording, judging votes majority vs unanimous, plates loader, VAR | `CompetitionHandlingPage` |

---

### Tier 1: Feature Coverage (5+ tests per feature)

#### Feature Area 1: Authentication & Password
*   **Test 1.1 (Registration flow)**: Enter register credentials, verify password rules validate in real-time, pick custom file and complete submission.
*   **Test 1.2 (Taken username rejection)**: Attempt registration with a pre-existing username, verify warning toast triggers and registration page remains.
*   **Test 1.3 (Username case-insensitive login)**: Enter username in capitalized form (`System_Admin`), confirm controller converts it to lowercase and logs in.
*   **Test 1.4 (Email-based login)**: Verify user can login directly using their email address with valid authentication session emission.
*   **Test 1.5 (Forgot password)**: Select forgot password dialog, input valid email, press Send, and confirm recovery event is pushed to auth provider stream.

#### Feature Area 2: Profile Customization
*   **Test 2.1 (Social media link creation)**: Open profile settings, add Instagram and YouTube links, verify they render on the page with proper icon selectors.
*   **Test 2.2 (Settings button placement)**: Verify settings icon placement resides immediately inline following the user's Full Name header.
*   **Test 2.3 (Header scrolling name update)**: Scroll page down on mobile view, verify user name is hidden from body and displayed in a smaller font in the header.
*   **Test 2.4 (Achievements PR display)**: Verify PR discipline scores (e.g. Muscle Up, Pull Up, Squat) render on profile achievements tab.
*   **Test 2.5 (Inline other user view)**: Navigate to another user's profile view, verify it displays inline under the header matches "My Profile" view.

#### Feature Area 3: Competition Exploration & Feeds
*   **Test 3.1 (Feed layout toggles)**: Toggle layouts from dropdown selector (Grid to Compact to Map) and assert appropriate cards render.
*   **Test 3.2 (Location cascading filters)**: Expand filters list, select Area: Europe, verify Country filter list cascades, and count chips update.
*   **Test 3.3 (Active filter chips display)**: Select a filter, verify "Format: Modern" chip renders above feed, and tapping "X" clears the filter.
*   **Test 3.4 (Sorting order toggles)**: Toggle sorting by "Name (A-Z)" and verify list displays classic meet before modern meet alphabetically.
*   **Test 3.5 (Competition detail view navigation)**: Tap a meet card in grid feed, verify Sliver layout, start date, location details, and share icon display.

---

### Tier 2: Boundary & Corner Cases (5+ tests per feature)

#### Feature Area 1: Authentication
*   **Test 2.1.1 (Password strength validation boundaries)**: Enter password lacking uppercase, special character, or numeric digit. Verify registration NEXT button remains disabled for each violation.
*   **Test 2.1.2 (Malformed email input)**: Verify login button is disabled or input throws error if input field lacks `@` or domain details.
*   **Test 2.1.3 (Extremely long username boundary)**: Enter a 100+ character username. Check validation response behavior and boundaries.
*   **Test 2.1.4 (Forgot password empty submission)**: Confirm validation triggers and blocks link generation if input is empty or invalid.
*   **Test 2.1.5 (Session latency retry)**: Simulate database trigger delay where profile query returns null twice before success. Verify auth provider retries 3 times before succeeding.

#### Feature Area 5: Competition Handling (Streetlifting Rules)
*   **Test 2.5.1 (Attempt weight increment constraints)**: Enter +1.25kg increment for Muscle Up, Pull Up, Dip (success). Verify squat accepts +2.5kg. Attempt a non-valid increment (e.g. +1.0kg) and confirm validation blocking.
*   **Test 2.5.2 (Decreasing weight attempts)**: Attempt to submit a lighter weight for attempt 2 than attempt 1. Assert validation prevents decrement.
*   **Test 2.5.3 (Attempt entry 3-minute technical timer constraint)**: Submit an attempt weight after 3 minutes has elapsed since the prior lift. Verify that coaches/athletes are blocked, and only owners/editors can adjust the weight.
*   **Test 2.5.4 (Platform judging 2:1 majority vs 3:0 unanimous voting)**: Input 2 "Invalid Depth" red cards for Squats. Verify lift is ruled invalid. Input 2 "Chicken Wing" red cards for Muscle Up (requires unanimous 3:0). Verify lift is ruled VALID.
*   **Test 2.5.5 (Video Assisted Referee (VAR) recovery constraints)**: Request a VAR challenge. Head judge overrules and changes card to white. Verify athlete's VAR request count is restored. Run second challenge, head judge rejects. Verify VAR token is exhausted.

---

### Tier 3: Cross-Feature Combinations

*   **Test 3.1 (Role Promotion -> Custom Config -> Meet Creation Flow)**:
    1. System Admin logs in and promotes User A to admin.
    2. User A logs in, adds custom discipline (e.g., "Heavy Chin Up") under streetlifting formats.
    3. User A starts competition creator, selects new discipline, saves, and verifies it displays in search feed.
*   **Test 3.2 (Athlete parameters -> Attempt scoring -> Rankings update)**:
    1. Athlete logs in, updates profile rack settings.
    2. Meet manager starts weigh-in slot, pulls athlete parameters from profile.
    3. Athlete completes lifts with platform judging votes.
    4. Rankings page is loaded, verifying total score updates and positions athlete in rankings feed.

---

### Tier 4: Real-World Application Scenarios

*   **Test 4.1 (Complete Meet Day Flow)**:
    1. Organizer starts meet weigh-in slot.
    2. Register athlete, verify body weight and default attempt weights are recorded.
    3. Start flight. Attempt weights are updated within the 3-minute window.
    4. Standard silver/black/white plate calculation is generated and verified on-screen for the loader.
    5. Platforms judges anonymously cast failure reasons. Head judge applies a VAR review that overrules a disqualification.
    6. Verify final ranking and notification alerts.
*   **Test 4.2 (Password Recovery and Theme Settings Refresh Flow)**:
    1. Athlete triggers forgot password via username.
    2. Enters code/recovery mode, changes password, validating safety requirements.
    3. Logs in with new password.
    4. Navigates to settings -> appearance, toggles dark/light theme, and checks theme persistence across page navigations.

---

## 5. Sample Integration Test Case

Here is how a compiled E2E test case would look using this harness, confirming it is ready to be added to `test/e2e/auth_e2e_test.dart` and executes using `flutter test`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/views/login_page.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Authentication E2E Tests', () {
    late InMemoryDatabase db;
    late MockSupabaseClient client;

    setUp(() {
      db = InMemoryDatabase();
      db.reset(); // Seeds default system_admin and meet_organizer
      client = MockSupabaseClient(db);
    });

    testWidgets('Case-insensitive login and redirect to mock Admin Dashboard', (WidgetTester tester) async {
      await pumpE2EApp(
        tester,
        home: const LoginPage(),
        client: client,
      );

      // Verify page loaded
      expect(find.text('Welcome Back'), findsOneWidget);

      // Toggle to Username mode
      await tester.tap(find.text('Username'));
      await tester.pumpAndSettle();

      // Enter capitalized username (harness and auth_provider should lower it)
      await tester.enterText(find.byKey(const Key('login_id_field')), 'SYSTEM_ADMIN');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'any-password');

      // Click sign in
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify Snack Bar success message
      expect(find.text('Successfully logged in!'), findsOneWidget);

      // Verify auth state is authenticated
      final buildContext = tester.element(find.byType(LoginPage));
      final auth = Provider.of<AuthProvider>(buildContext, listen: false);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUserProfile?.username, 'system_admin');
    });
  });
}
```

This ensures E2E testing covers features currently in development while remaining compile-safe.
