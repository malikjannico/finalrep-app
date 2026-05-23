import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/views/competition_handling_page.dart';
import 'package:finalrep_app/views/rankings_page.dart';
import 'package:finalrep_app/views/notifications_page.dart';
import 'package:finalrep_app/views/competition_creation_wizard.dart';
import 'mock_views.dart' hide CompetitionHandlingPage, RankingsPage, NotificationsPage;

// ==========================================
// 1. InMemoryDatabase (Fake DB)
// ==========================================

class InMemoryDatabase {
  final Map<String, Profile> profiles = {};
  final Map<String, Competition> competitions = {};
  final List<Map<String, dynamic>> associations = [];
  final List<Map<String, dynamic>> applications = [];
  final List<Map<String, dynamic>> attempts = [];
  final List<Map<String, dynamic>> volunteerApplications = [];
  final Map<String, Uint8List> storage = {}; // bucket/path -> data

  void reset() {
    profiles.clear();
    competitions.clear();
    associations.clear();
    applications.clear();
    attempts.clear();
    volunteerApplications.clear();
    storage.clear();
    seedDefaultData();
  }

  void seedDefaultData() {
    // Seed default profiles
    profiles['admin-123'] = Profile(
      id: 'admin-123',
      username: 'system_admin',
      fullName: 'System Administrator',
      email: 'admin@finalrep.com',
      gender: 'Male',
      country: 'Germany',
      description: 'System admin bio.',
      colorMode: 'dark',
    );

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

    // Seed default competitions
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

  List<Map<String, dynamic>> getTable(String table) {
    if (table == 'associations') return associations;
    if (table == 'applications') return applications;
    if (table == 'volunteer_applications') return volunteerApplications;
    return attempts;
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
  final InMemoryDatabase db;

  MockSupabaseClient({required this.auth, required this.storage, required this.db});

  @override
  SupabaseQueryBuilder from(String table) {
    return MockSupabaseQueryBuilder(table, db);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserResponse implements UserResponse {
  @override
  final User? user;
  MockUserResponse(this.user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoTrueClient implements GoTrueClient {
  final StreamController<AuthState> _authStateController;
  final InMemoryDatabase db;
  
  User? _currentUser;
  Session? _currentSession;

  MockGoTrueClient(this._authStateController, this.db);

  @override
  User? get currentUser => _currentUser;
  @override
  Session? get currentSession => _currentSession;

  void triggerAuthStateChange(AuthChangeEvent event, Session? session) {
    debugPrint('DEBUG: triggerAuthStateChange event=$event user=${session?.user.id}');
    _currentSession = session;
    _currentUser = session?.user;
    _authStateController.add(AuthState(event, session));
  }

  @override
  Stream<AuthState> get onAuthStateChange {
    final controller = StreamController<AuthState>.broadcast(sync: true);
    StreamSubscription? sub;
    controller.onListen = () {
      debugPrint('DEBUG: onAuthStateChange onListen, currentSession=${_currentSession?.user.id}');
      controller.add(AuthState(AuthChangeEvent.initialSession, _currentSession));
      sub = _authStateController.stream.listen(
        (data) {
          debugPrint('DEBUG: onAuthStateChange forward data event=${data.event} user=${data.session?.user.id}');
          if (!controller.isClosed) {
            controller.add(data);
          }
        },
        onError: (err) {
          if (!controller.isClosed) {
            controller.addError(err);
          }
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );
    };
    controller.onCancel = () {
      sub?.cancel();
    };
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #signUp) {
      final email = invocation.namedArguments[#email] as String;
      final data = invocation.namedArguments[#data] as Map<String, dynamic>?;

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

      final username = data?['username'] as String? ?? 'user_$uid';
      final fullName = data?['full_name'] as String? ?? 'User $uid';
      db.profiles[uid] = Profile(
        id: uid,
        username: username.toLowerCase(),
        fullName: fullName,
        email: email,
        gender: data?['gender'] as String?,
        country: data?['country'] as String?,
        profilePictureUrl: data?['profile_picture_url'] as String?,
      );

      triggerAuthStateChange(AuthChangeEvent.signedIn, session);
      return Future.value(AuthResponse(session: session, user: user));
    }
    if (name == #signInWithPassword) {
      final email = invocation.namedArguments[#email] as String?;
      final username = invocation.namedArguments[#username] as String?;
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
      return Future.value(AuthResponse(session: session, user: user));
    }
    if (name == #signOut) {
      triggerAuthStateChange(AuthChangeEvent.signedOut, null);
      return Future.value(null);
    }
    if (name == #updateUser) {
      if (_currentUser == null) throw Exception('No session active.');
      final attributes = invocation.positionalArguments[0] as UserAttributes;
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
      return Future.value(MockUserResponse(updatedUser));
    }
    if (name == #resetPasswordForEmail) {
      final email = invocation.positionalArguments[0] as String;
      final profile = db.profiles.values.firstWhere(
        (p) => p.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('Email not registered.'),
      );
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
      return Future.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

class MockSupabaseStorageClient implements SupabaseStorageClient {
  final InMemoryDatabase db;
  MockSupabaseStorageClient(this.db);

  @override
  StorageFileApi from(String id) {
    return MockStorageFileApi(id, db);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStorageFileApi implements StorageFileApi {
  @override
  final String bucketId;
  final InMemoryDatabase db;
  MockStorageFileApi(this.bucketId, this.db);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #uploadBinary) {
      final path = invocation.positionalArguments[0] as String;
      final data = invocation.positionalArguments[1] as Uint8List;
      db.storage['$bucketId/$path'] = data;
      return Future.value('$bucketId/$path');
    }
    if (name == #getPublicUrl) {
      final path = invocation.positionalArguments[0] as String;
      return 'https://supabase.mock.storage/$bucketId/$path';
    }
    return super.noSuchMethod(invocation);
  }
}

// ==========================================
// 3. Mock Postgrest Builder
// ==========================================

class MockSupabaseQueryBuilder implements SupabaseQueryBuilder {
  final String tableName;
  final InMemoryDatabase db;

  MockSupabaseQueryBuilder(this.tableName, this.db);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #select) {
      return MockPostgrestFilterBuilder<List<Map<String, dynamic>>>(tableName, db, 'select');
    }
    if (name == #update) {
      final values = invocation.positionalArguments[0] as Map;
      return MockPostgrestFilterBuilder<List<Map<String, dynamic>>>(tableName, db, 'update', payload: values);
    }
    if (name == #insert) {
      final values = invocation.positionalArguments[0];
      return MockPostgrestFilterBuilder<List<Map<String, dynamic>>>(tableName, db, 'insert', payload: values);
    }
    return super.noSuchMethod(invocation);
  }
}

// ignore: must_be_immutable
class MockPostgrestFilterBuilder<T> implements PostgrestFilterBuilder<T>, PostgrestTransformBuilder<T>, Future<T> {
  final String tableName;
  final InMemoryDatabase db;
  final String op;
  final dynamic payload;

  final Map<String, dynamic> eqFilters;
  final List<String> nullFilters;
  String? orFilterString;
  String? orderColumn;
  bool ascendingOrder;
  int? limitCount;
  bool isSingle;
  bool allowNull;

  MockPostgrestFilterBuilder(
    this.tableName,
    this.db,
    this.op, {
    this.payload,
    Map<String, dynamic>? eqFilters,
    List<String>? nullFilters,
    this.orFilterString,
    this.orderColumn,
    this.ascendingOrder = true,
    this.limitCount,
    this.isSingle = false,
    this.allowNull = false,
  }) : eqFilters = eqFilters ?? {},
       nullFilters = nullFilters ?? [];

  MockPostgrestFilterBuilder<R> _cloneWith<R>({
    bool? isSingle,
    bool? allowNull,
  }) {
    return MockPostgrestFilterBuilder<R>(
      tableName,
      db,
      op,
      payload: payload,
      eqFilters: eqFilters,
      nullFilters: nullFilters,
      orFilterString: orFilterString,
      orderColumn: orderColumn,
      ascendingOrder: ascendingOrder,
      limitCount: limitCount,
      isSingle: isSingle ?? this.isSingle,
      allowNull: allowNull ?? this.allowNull,
    );
  }

  List<Map<String, dynamic>> _executeFilter() {
    List<Map<String, dynamic>> source;
    if (tableName == 'profiles') {
      source = db.profiles.values.map((p) => p.toJson()).toList();
    } else if (tableName == 'competitions') {
      source = db.competitions.values.map((c) => c.toJson()).toList();
    } else {
      source = List<Map<String, dynamic>>.from(db.getTable(tableName));
    }

    var filtered = List<Map<String, dynamic>>.from(source);
    eqFilters.forEach((col, val) {
      filtered = filtered.where((item) => item[col] == val).toList();
    });

    for (final col in nullFilters) {
      filtered = filtered.where((item) => item[col] == null).toList();
    }

    if (orFilterString != null) {
      final parts = orFilterString!.split(',');
      filtered = filtered.where((item) {
        for (final part in parts) {
          final subparts = part.split('.');
          if (subparts.length == 3) {
            final col = subparts[0].trim();
            final operation = subparts[1].trim();
            final val = subparts[2].trim();
            if (operation == 'ilike') {
              final cleanVal = val.replaceAll('%', '').toLowerCase();
              final itemVal = (item[col] as String?)?.toLowerCase() ?? '';
              if (itemVal.contains(cleanVal)) {
                return true;
              }
            } else if (operation == 'eq') {
              if (item[col]?.toString() == val) {
                return true;
              }
            }
          }
        }
        return false;
      }).toList();
    }

    if (orderColumn != null) {
      filtered.sort((a, b) {
        final valA = a[orderColumn!];
        final valB = b[orderColumn!];
        if (valA == null || valB == null) return 0;
        if (valA is Comparable && valB is Comparable) {
          return ascendingOrder ? valA.compareTo(valB) : valB.compareTo(valA);
        }
        return 0;
      });
    }

    if (limitCount != null && filtered.length > limitCount!) {
      filtered = filtered.sublist(0, limitCount);
    }

    return filtered;
  }

  Future<dynamic> _getResultFuture() async {
    debugPrint('DEBUG: _getResultFuture table=$tableName op=$op eqFilters=$eqFilters isSingle=$isSingle allowNull=$allowNull');
    final results = _executeFilter();
    debugPrint('DEBUG: _executeFilter results=$results');
    if (op == 'insert') {
      List<Map<String, dynamic>> inserted = [];
      if (payload is List) {
        for (final item in payload) {
          final map = Map<String, dynamic>.from(item);
          if (tableName == 'profiles') {
            db.profiles[map['id']] = Profile.fromJson(map);
          } else if (tableName == 'competitions') {
            db.competitions[map['id']] = Competition.fromJson(map);
          } else {
            db.getTable(tableName).add(map);
          }
          inserted.add(map);
        }
      } else {
        final map = Map<String, dynamic>.from(payload);
        if (tableName == 'profiles') {
          db.profiles[map['id']] = Profile.fromJson(map);
        } else if (tableName == 'competitions') {
          db.competitions[map['id']] = Competition.fromJson(map);
        } else {
          db.getTable(tableName).add(map);
        }
        inserted.add(map);
      }
      if (isSingle) {
        return inserted.first;
      }
      return inserted;
    }

    if (op == 'update') {
      final matches = _executeFilter();
      for (final match in matches) {
        payload.forEach((k, v) {
          match[k] = v;
        });
        if (tableName == 'profiles') {
          db.profiles[match['id']] = Profile.fromJson(match);
        } else if (tableName == 'competitions') {
          db.competitions[match['id']] = Competition.fromJson(match);
        }
      }
      if (isSingle) {
        if (matches.isEmpty) {
          if (allowNull) return null;
          throw Exception('No records updated.');
        }
        return matches.first;
      }
      return matches;
    }

    // op == 'select'
    if (isSingle) {
      if (results.isEmpty) {
        if (allowNull) return null;
        throw Exception('No records found.');
      }
      return results.first;
    }
    return results;
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return _getResultFuture().then((val) => onValue(val as T), onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return _getResultFuture().then((val) => val as T).catchError(onError, test: test);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return _getResultFuture().then((val) => val as T).timeout(timeLimit, onTimeout: onTimeout != null ? () async => (await onTimeout()) : null);
  }

  @override
  Stream<T> asStream() {
    return _getResultFuture().then((val) => val as T).asStream();
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return _getResultFuture().then((val) => val as T).whenComplete(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #eq) {
      final column = invocation.positionalArguments[0] as String;
      final value = invocation.positionalArguments[1];
      eqFilters[column] = value;
      return this;
    }
    if (name == #or) {
      orFilterString = invocation.positionalArguments[0] as String;
      return this;
    }
    if (name == #isFilter) {
      final column = invocation.positionalArguments[0] as String;
      final value = invocation.positionalArguments[1];
      if (value == null) {
        nullFilters.add(column);
      } else {
        eqFilters[column] = value;
      }
      return this;
    }
    if (name == #order) {
      orderColumn = invocation.positionalArguments[0] as String;
      ascendingOrder = invocation.namedArguments[#ascending] as bool? ?? true;
      return this;
    }
    if (name == #limit) {
      limitCount = invocation.positionalArguments[0] as int;
      return this;
    }
    if (name == #single) {
      return _cloneWith<Map<String, dynamic>>(isSingle: true, allowNull: false);
    }
    if (name == #maybeSingle) {
      return _cloneWith<Map<String, dynamic>?>(isSingle: true, allowNull: true);
    }
    if (name == #select) {
      return _cloneWith<List<Map<String, dynamic>>>();
    }
    return super.noSuchMethod(invocation);
  }
}

// ==========================================
// 4. File Picker Mock
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
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    if (mockFile == null) return null;
    return FilePickerResult([mockFile!]);
  }
}

// ==========================================
// 5. Test Environment Initializer
// ==========================================

class E2ETestHarness {
  final InMemoryDatabase db = InMemoryDatabase();
  late MockGoTrueClient mockAuth;
  late MockSupabaseStorageClient mockStorage;
  late MockSupabaseClient mockClient;

  late ProfileRepository profileRepository;
  late CompetitionRepository competitionRepository;

  late AuthProvider authProvider;
  late CompetitionProvider competitionProvider;
  late MockFilePicker mockFilePicker;

  Future<void> initialize() async {
    db.reset();

    final authController = StreamController<AuthState>.broadcast(sync: true);
    mockAuth = MockGoTrueClient(authController, db);
    mockStorage = MockSupabaseStorageClient(db);
    mockClient = MockSupabaseClient(auth: mockAuth, storage: mockStorage, db: db);

    profileRepository = ProfileRepository(mockClient);
    competitionRepository = CompetitionRepository(mockClient);

    authProvider = AuthProvider(mockClient, profileRepository);
    competitionProvider = CompetitionProvider(competitionRepository, profileRepository);
    
    mockFilePicker = MockFilePicker();
    FilePicker.platform = mockFilePicker;

  }

  void dispose() {
    authProvider.dispose();
    competitionProvider.dispose();
  }

  Widget buildApp(Widget homeWidget) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CompetitionProvider>.value(value: competitionProvider),
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
            return MaterialPageRoute(builder: (_) => const CreateCompetitionWizard());
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
          if (settings.name == '/notifications') {
            return MaterialPageRoute(builder: (_) => const NotificationsPage());
          }
          return null;
        },
        home: homeWidget,
      ),
    );
  }

  Future<void> waitForAuthSettle(WidgetTester tester) async {
    debugPrint('DEBUG: waitForAuthSettle starting. status=${authProvider.status}, error=${authProvider.errorMessage}');
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (authProvider.status == AuthStatus.authenticated || 
          (authProvider.status == AuthStatus.unauthenticated && authProvider.errorMessage != null)) {
        debugPrint('DEBUG: waitForAuthSettle loop breaking condition met at i=$i. status=${authProvider.status}, error=${authProvider.errorMessage}');
        break;
      }
    }
    // Instead of pumpAndSettle which hangs on blinking cursor/animations, pump a few times
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}
