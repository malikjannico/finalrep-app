import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;
import '../mocks/supabase_dummies.dart';
import 'package:file_picker/file_picker.dart';

import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/repositories/admin_repository.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';
import 'package:finalrep_app/utils/api_client.dart';
import 'package:finalrep_app/utils/mock_safety.dart';
import 'package:finalrep_app/views/competition_judging_page.dart';
import 'package:finalrep_app/views/rankings_page.dart';
import 'package:finalrep_app/views/notifications_page.dart';
import 'package:finalrep_app/views/competition_creation_page.dart';
import 'mock_views.dart'
    hide CompetitionJudgingPage, RankingsPage, NotificationsPage;

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
  final List<Map<String, dynamic>> athleteGroups = [];
  final List<Map<String, dynamic>> athleteRegistrations = [];
  final List<Map<String, dynamic>> competitionGroups = [];
  final List<Map<String, dynamic>> notifications = [];
  final List<Map<String, dynamic>> associationMembers = [];
  final Map<String, Uint8List> storage = {}; // bucket/path -> data

  void reset() {
    profiles.clear();
    competitions.clear();
    associations.clear();
    applications.clear();
    attempts.clear();
    volunteerApplications.clear();
    athleteGroups.clear();
    athleteRegistrations.clear();
    competitionGroups.clear();
    notifications.clear();
    associationMembers.clear();
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
      sex: 'male',
      country: 'Germany',
      description: 'System admin bio.',
      colorMode: 'dark',
    );

    profiles['user-1'] = Profile(
      id: 'user-1',
      username: 'johndoe',
      fullName: 'John Doe',
      email: 'john@example.com',
      sex: 'male',
      country: 'Germany',
      description: 'Lifting is life.',
      colorMode: 'dark',
    );

    profiles['user-2'] = Profile(
      id: 'user-2',
      username: 'mariesmith',
      fullName: 'Marie Smith',
      email: 'marie@example.com',
      sex: 'Female',
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
    if (table == 'athlete_groups') return athleteGroups;
    if (table == 'athlete_registrations') return athleteRegistrations;
    if (table == 'competition_groups') return competitionGroups;
    if (table == 'notifications') return notifications;
    if (table == 'association_members') return associationMembers;
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

  MockSupabaseClient({
    required this.auth,
    required this.storage,
    required this.db,
  });

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
  MockFirebaseAuth? firebaseAuth;

  MockGoTrueClient(this._authStateController, this.db);

  @override
  User? get currentUser => _currentUser;
  @override
  Session? get currentSession => _currentSession;

  void triggerAuthStateChange(AuthChangeEvent event, Session? session) {
    debugPrint(
      'DEBUG: triggerAuthStateChange event=$event user=${session?.user.id}',
    );
    _currentSession = session;
    _currentUser = session?.user;
    _authStateController.add(AuthState(event, session));
    if (session != null) {
      firebaseAuth?.setCurrentUser(MockUser(uid: session.user.id, email: session.user.email));
    } else {
      firebaseAuth?.setCurrentUser(null);
    }
  }

  @override
  Stream<AuthState> get onAuthStateChange {
    final controller = StreamController<AuthState>.broadcast(sync: true);
    StreamSubscription? sub;
    controller.onListen = () {
      debugPrint(
        'DEBUG: onAuthStateChange onListen, currentSession=${_currentSession?.user.id}',
      );
      controller.add(
        AuthState(AuthChangeEvent.initialSession, _currentSession),
      );
      sub = _authStateController.stream.listen(
        (data) {
          debugPrint(
            'DEBUG: onAuthStateChange forward data event=${data.event} user=${data.session?.user.id}',
          );
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
        sex: data?['sex'] as String?,
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
      return MockPostgrestFilterBuilder<List<Map<String, dynamic>>>(
        tableName,
        db,
        'select',
      );
    }
    if (name == #update) {
      final values = invocation.positionalArguments[0] as Map;
      return MockPostgrestFilterBuilder<List<Map<String, dynamic>>>(
        tableName,
        db,
        'update',
        payload: values,
      );
    }
    if (name == #insert) {
      final values = invocation.positionalArguments[0];
      return MockPostgrestFilterBuilder<List<Map<String, dynamic>>>(
        tableName,
        db,
        'insert',
        payload: values,
      );
    }
    return super.noSuchMethod(invocation);
  }
}

// ignore: must_be_immutable
class MockPostgrestFilterBuilder<T>
    implements
        PostgrestFilterBuilder<T>,
        PostgrestTransformBuilder<T>,
        Future<T> {
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
    debugPrint(
      'DEBUG: _getResultFuture table=$tableName op=$op eqFilters=$eqFilters isSingle=$isSingle allowNull=$allowNull',
    );
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
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return _getResultFuture().then(
      (val) => onValue(val as T),
      onError: onError,
    );
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return _getResultFuture()
        .then((val) => val as T)
        .catchError(onError, test: test);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return _getResultFuture()
        .then((val) => val as T)
        .timeout(
          timeLimit,
          onTimeout: onTimeout != null ? () async => (await onTimeout()) : null,
        );
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

class E2EHttpClient extends http.BaseClient {
  final InMemoryDatabase db;
  E2EHttpClient(this.db);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method;
    final path = request.url.path;
    final query = request.url.queryParameters;

    String bodyString = '';
    if (request is http.Request) {
      bodyString = request.body;
    }

    dynamic responseJson;
    int statusCode = 200;

    try {
      if (path.startsWith('/profiles/')) {
        final id = path.substring('/profiles/'.length);
        if (method == 'GET') {
          final profile = db.profiles[id];
          if (profile != null) {
            responseJson = profile.toJson();
          } else {
            statusCode = 404;
          }
        }
      } else if (path == '/profiles') {
        if (method == 'GET') {
          if (query.containsKey('username')) {
            final u = query['username']!.toLowerCase();
            try {
              final p = db.profiles.values.firstWhere(
                (x) => x.username.toLowerCase() == u,
              );
              responseJson = p.toJson();
            } catch (_) {
              statusCode = 404;
            }
          } else if (query.containsKey('email')) {
            final e = query['email']!.toLowerCase();
            try {
              final p = db.profiles.values.firstWhere(
                (x) => x.email.toLowerCase() == e,
              );
              responseJson = p.toJson();
            } catch (_) {
              statusCode = 404;
            }
          } else if (query.containsKey('search')) {
            final q = query['search']!.toLowerCase();
            final matches = db.profiles.values.where(
              (x) => x.username.toLowerCase().contains(q) || x.fullName.toLowerCase().contains(q),
            ).map((x) => x.toJson()).toList();
            responseJson = matches;
          } else if (query.containsKey('userId')) {
            final userId = query['userId']!;
            final type = query['type'];
            if (type == 'upcoming') {
              final list = db.competitions.values.where(
                (c) => c.startDate.isAfter(DateTime.now()),
              ).map((c) => c.toJson()).toList();
              responseJson = list;
            } else if (type == 'completed') {
              final list = db.competitions.values.where(
                (c) => c.startDate.isBefore(DateTime.now()),
              ).map((c) => c.toJson()).toList();
              responseJson = list;
            } else if (type == 'rankings') {
              if (userId == 'user-1') {
                responseJson = [
                  {
                    'profile_id': 'user-1',
                    'discipline': 'Overall Modern (-80kg)',
                    'rank': '2nd Place',
                    'competition': 'Hamburg Streetlifting Meet',
                  },
                  {
                    'profile_id': 'user-1',
                    'discipline': 'Overall Modern (-80kg)',
                    'rank': '1st Place',
                    'competition': 'Classic Pull & Dip Cup',
                  },
                ];
              } else {
                responseJson = [];
              }
            } else if (type == 'records') {
              responseJson = [];
            }
          }
        } else if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          final profile = Profile.fromJson(data);
          db.profiles[profile.id] = profile;
          responseJson = profile.toJson();
        }
      } else if (path.startsWith('/competitions/')) {
        final remaining = path.substring('/competitions/'.length);
        if (!remaining.contains('/')) {
          final id = remaining;
          if (method == 'GET') {
            final comp = db.competitions[id];
            if (comp != null) {
              responseJson = comp.toJson();
            } else {
              statusCode = 404;
            }
          } else if (method == 'PUT') {
            final data = jsonDecode(bodyString) as Map<String, dynamic>;
            final comp = Competition.fromJson(data);
            db.competitions[comp.id] = comp;
            responseJson = comp.toJson();
          }
        } else {
          final parts = remaining.split('/');
          final id = parts[0];
          final subpath = parts[1];
          if (subpath == 'athletes') {
            final userIds = db.athleteRegistrations
                .where((r) => r['competition_id'] == id)
                .map((r) => r['user_id'] as String)
                .toSet();
            final list = db.profiles.values
                .where((p) => userIds.contains(p.id))
                .map((p) => p.toJson())
                .toList();
            responseJson = list;
          } else if (subpath == 'athlete-ids' || subpath == 'registrations') {
            final userIds = db.athleteRegistrations
                .where((r) => r['competition_id'] == id)
                .map((r) => r['user_id'] as String)
                .toList();
            responseJson = userIds;
          } else if (subpath == 'volunteers') {
            final count = db.volunteerApplications
                .where((v) => v['competition_id'] == id)
                .length;
            responseJson = {'count': count};
          } else if (subpath == 'register') {
            if (method == 'POST') {
              final data = jsonDecode(bodyString) as Map<String, dynamic>;
              db.athleteRegistrations.add({
                'competition_id': id,
                'user_id': data['userId'],
                'status': data['status'] ?? 'registered',
              });
              responseJson = {'success': true};
            }
          } else if (subpath == 'draw') {
            if (method == 'POST') {
              final comp = db.competitions[id];
              if (comp != null) {
                final groupLimits = comp.maxAthletesPerGroup;
                final enableWaitlist = comp.enableWaitlist;
                final limit = comp.maxAthletes;
                final compRegs = db.athleteRegistrations.where((r) => r['competition_id'] == id).toList();

                if (groupLimits != null && groupLimits.isNotEmpty) {
                  final assignedStatus = <Map<String, dynamic>, String>{};
                  for (final group in groupLimits) {
                    final groupGender = (group['gender'] as String? ?? 'open').toLowerCase();
                    final groupLimit = group['limit'] as int?;

                    final candidates = compRegs.where((reg) {
                      if (assignedStatus[reg] == 'registered') return false;
                      final userId = reg['user_id'] as String;
                      final userProfile = db.profiles[userId];
                      final userSex = (userProfile?.sex ?? '').toLowerCase();

                      if (groupGender == 'open' || groupGender == 'mixed') return true;
                      if ((groupGender == 'men' || groupGender == 'male') && (userSex == 'male' || userSex == 'other')) return true;
                      if ((groupGender == 'women' || groupGender == 'female' || groupGender == 'woman') && (userSex == 'female' || userSex == 'other')) return true;
                      return false;
                    }).toList();

                    candidates.shuffle();

                    if (groupLimit != null) {
                      final actualLimit = groupLimit < candidates.length ? groupLimit : candidates.length;
                      for (int i = 0; i < actualLimit; i++) {
                        assignedStatus[candidates[i]] = 'registered';
                      }
                      for (int i = actualLimit; i < candidates.length; i++) {
                        if (assignedStatus[candidates[i]] != 'registered') {
                          assignedStatus[candidates[i]] = enableWaitlist ? 'waitlisted' : 'pending';
                        }
                      }
                    } else {
                      for (final cand in candidates) {
                        assignedStatus[cand] = 'registered';
                      }
                    }
                  }

                  for (final reg in compRegs) {
                    reg['status'] = assignedStatus[reg] ?? (enableWaitlist ? 'waitlisted' : 'pending');
                  }
                } else {
                  compRegs.shuffle();
                  if (limit != null) {
                    final actualLimit = limit < compRegs.length ? limit : compRegs.length;
                    for (int i = 0; i < actualLimit; i++) {
                      compRegs[i]['status'] = 'registered';
                    }
                    for (int i = actualLimit; i < compRegs.length; i++) {
                      compRegs[i]['status'] = enableWaitlist ? 'waitlisted' : 'pending';
                    }
                  } else {
                    for (final reg in compRegs) {
                      reg['status'] = 'registered';
                    }
                  }
                }
                responseJson = {'success': true};
              } else {
                statusCode = 404;
              }
            }
          }
        }
      } else if (path == '/competitions') {
        if (method == 'GET') {
          responseJson = db.competitions.values.map((c) => c.toJson()).toList();
        } else if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          final comp = Competition.fromJson(data);
          db.competitions[comp.id] = comp;
          responseJson = comp.toJson();
        }
      } else if (path == '/competitions/register') {
        if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          db.athleteRegistrations.add({
            'competition_id': data['competitionId'],
            'user_id': data['userId'],
            'status': data['status'] ?? 'registered',
          });
          responseJson = {'success': true};
        }
      } else if (path == '/competitions/volunteers' || path == '/volunteer-applications') {
        if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          db.volunteerApplications.add(data);
          responseJson = true;
        }
      } else if (path == '/competitions/schedule') {
        if (method == 'POST') {
          responseJson = true;
        }
      } else if (path == '/competitions/results') {
        if (method == 'GET') {
          responseJson = <Map<String, dynamic>>[];
        }
      } else if (path == '/athlete-groups') {
        if (method == 'GET') {
          final assocId = query['associationId'];
          responseJson = db.athleteGroups.where((g) => g['association_id'] == assocId).toList();
        } else if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          db.athleteGroups.add(data);
          responseJson = data;
        } else if (method == 'PUT') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          final idx = db.athleteGroups.indexWhere((g) => g['id'] == data['id']);
          if (idx != -1) {
            db.athleteGroups[idx] = data;
          } else {
            db.athleteGroups.add(data);
          }
          responseJson = data;
        }
      } else if (path.startsWith('/athlete-groups/')) {
        final id = path.substring('/athlete-groups/'.length);
        if (method == 'DELETE') {
          db.athleteGroups.removeWhere((g) => g['id'] == id);
          responseJson = true;
        }
      } else if (path == '/competition-groups') {
        if (method == 'GET') {
          final assocId = query['associationId'];
          responseJson = db.competitionGroups.where((g) => g['association_id'] == assocId).toList();
        } else if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          db.competitionGroups.add(data);
          responseJson = data;
        } else if (method == 'PUT') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          final idx = db.competitionGroups.indexWhere((g) => g['id'] == data['id']);
          if (idx != -1) {
            db.competitionGroups[idx] = data;
          } else {
            db.competitionGroups.add(data);
          }
          responseJson = data;
        }
      } else if (path.startsWith('/competition-groups/')) {
        final id = path.substring('/competition-groups/'.length);
        if (method == 'DELETE') {
          db.competitionGroups.removeWhere((g) => g['id'] == id);
          responseJson = true;
        }
      } else if (path == '/associations') {
        if (method == 'GET') {
          responseJson = db.associations;
        } else if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          final idx = db.associations.indexWhere((a) => a['id'] == data['id']);
          if (idx != -1) {
            db.associations[idx] = data;
          } else {
            db.associations.add(data);
          }
          responseJson = data;
        }
      } else if (path.startsWith('/associations/')) {
        final remaining = path.substring('/associations/'.length);
        if (!remaining.contains('/')) {
          final id = remaining;
          if (method == 'GET') {
            try {
              final assoc = db.associations.firstWhere((a) => a['id'] == id);
              responseJson = assoc;
            } catch (_) {
              statusCode = 404;
            }
          } else if (method == 'DELETE') {
            db.associations.removeWhere((a) => a['id'] == id);
            responseJson = true;
          }
        } else {
          final parts = remaining.split('/');
          final id = parts[0];
          final subpath = parts[1];
          if (subpath == 'members') {
            if (method == 'GET') {
              final list = db.associationMembers
                  .where((m) => m['association_id'] == id)
                  .toList();
              responseJson = list;
            } else if (method == 'POST') {
              final data = jsonDecode(bodyString) as Map<String, dynamic>;
              db.associationMembers.add(data);
              responseJson = data;
            }
          } else if (subpath == 'owner') {
            if (method == 'POST') {
              final data = jsonDecode(bodyString) as Map<String, dynamic>;
              try {
                final assoc = db.associations.firstWhere((a) => a['id'] == id);
                assoc['owner_id'] = data['newOwnerId'];
                responseJson = assoc;
              } catch (_) {
                statusCode = 404;
              }
            }
          } else if (subpath == 'competition-groups') {
            final list = db.competitionGroups.where((g) => g['association_id'] == id).toList();
            responseJson = list;
          } else if (subpath == 'athlete-groups') {
            final list = db.athleteGroups.where((g) => g['association_id'] == id).toList();
            responseJson = list;
          }
        }
      } else if (path == '/admin/permission-applications') {
        if (method == 'GET') {
          responseJson = db.applications;
        } else if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          db.applications.add(data);
          responseJson = data;
        }
      } else if (path.startsWith('/admin/permission-applications/')) {
        final remaining = path.substring('/admin/permission-applications/'.length);
        final parts = remaining.split('/');
        final id = parts[0];
        final action = parts[1];
        try {
          final app = db.applications.firstWhere((a) => a['id'] == id);
          if (action == 'approve') {
            app['status'] = 'approved';
            responseJson = app;
          } else if (action == 'reject') {
            app['status'] = 'rejected';
            responseJson = app;
          }
        } catch (_) {
          statusCode = 404;
        }
      } else if (path == '/admin/sport-config') {
        if (method == 'GET') {
          responseJson = {
            'sports': [
              {'name': 'Streetlifting', 'description': 'Streetlifting sport'}
            ],
            'formats': [
              {'sport_name': 'Streetlifting', 'name': 'Modern', 'description': 'Modern format'},
              {'sport_name': 'Streetlifting', 'name': 'Classic', 'description': 'Classic format'}
            ],
            'disciplines': [
              {'name': 'Pull Up', 'description': 'Weighted Pull Up'},
              {'name': 'Dip', 'description': 'Weighted Dip'},
              {'name': 'Squat', 'description': 'Weighted Squat'},
              {'name': 'Muscle Up', 'description': 'Weighted Muscle Up'}
            ],
            'links': [
              {'sport_name': 'Streetlifting', 'format_name': 'Modern', 'discipline_name': 'Pull Up'},
              {'sport_name': 'Streetlifting', 'format_name': 'Modern', 'discipline_name': 'Dip'},
              {'sport_name': 'Streetlifting', 'format_name': 'Modern', 'discipline_name': 'Squat'},
              {'sport_name': 'Streetlifting', 'format_name': 'Modern', 'discipline_name': 'Muscle Up'},
              {'sport_name': 'Streetlifting', 'format_name': 'Classic', 'discipline_name': 'Pull Up'},
              {'sport_name': 'Streetlifting', 'format_name': 'Classic', 'discipline_name': 'Dip'}
            ]
          };
        } else if (method == 'POST') {
          responseJson = true;
        }
      } else if (path == '/notifications') {
        if (method == 'GET') {
          final userId = query['userId'];
          final list = db.notifications.where((n) => n['user_id'] == userId).toList();
          responseJson = list;
        } else if (method == 'POST') {
          final data = jsonDecode(bodyString) as Map<String, dynamic>;
          db.notifications.add(data);
          responseJson = data;
        }
      } else if (path.startsWith('/notifications/')) {
        final remaining = path.substring('/notifications/'.length);
        final parts = remaining.split('/');
        final id = parts[0];
        final sub = parts[1];
        if (sub == 'read') {
          try {
            final notif = db.notifications.firstWhere((n) => n['id'] == id);
            notif['is_read'] = true;
            responseJson = notif;
          } catch (_) {
            statusCode = 404;
          }
        }
      } else if (path == '/upload') {
        if (method == 'POST') {
          String filename = 'avatar_123.png';
          if (request is http.MultipartRequest && request.files.isNotEmpty) {
            filename = request.files.first.filename ?? 'avatar_123.png';
          }
          responseJson = {'url': 'https://supabase.mock.storage/uploads/$filename'};
        } else if (method == 'DELETE') {
          responseJson = true;
        }
      }
    } catch (e) {
      statusCode = 500;
    }

    if (responseJson == null && statusCode == 200) {
      statusCode = 404;
    }

    final responseBody = responseJson != null ? jsonEncode(responseJson) : '';
    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

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
    MockSafety.setMockAllowedForTesting(false);
    db.reset();

    final authController = StreamController<AuthState>.broadcast(sync: true);
    mockAuth = MockGoTrueClient(authController, db);
    mockStorage = MockSupabaseStorageClient(db);
    mockClient = MockSupabaseClient(
      auth: mockAuth,
      storage: mockStorage,
      db: db,
    );

    final fbAuthController = StreamController<fb.User?>.broadcast(sync: true);
    final mockFirebaseAuth = MockFirebaseAuth(fbAuthController, db, yieldImmediately: true);
    mockAuth.firebaseAuth = mockFirebaseAuth;

    final e2eClient = E2EHttpClient(db);
    final e2eApi = ApiClient(client: e2eClient);

    profileRepository = ProfileRepository(api: e2eApi);
    competitionRepository = CompetitionRepository(api: e2eApi);

    final associationRepository = AssociationRepository(api: e2eApi);
    final adminRepository = AdminRepository(api: e2eApi);
    final notificationRepository = NotificationRepository(api: e2eApi);

    authProvider = AuthProvider(
      profileRepository,
      firebaseAuth: mockFirebaseAuth,
      adminRepository: adminRepository,
      notificationRepository: notificationRepository,
    );
    competitionProvider = CompetitionProvider(
      competitionRepository,
      profileRepository,
      firebaseAuth: mockFirebaseAuth,
      associationRepository: associationRepository,
      notificationRepository: notificationRepository,
      adminRepository: adminRepository,
    );

    // Seed repositories with db data for mock fallback mode
    for (final profile in db.profiles.values) {
      await profileRepository.updateProfile(profile);
    }
    for (final comp in db.competitions.values) {
      await competitionRepository.createCompetition(comp);
    }

    mockFilePicker = MockFilePicker();
    FilePicker.platform = mockFilePicker;
  }

  void dispose() {
    MockSafety.setMockAllowedForTesting(null);
    authProvider.dispose();
    competitionProvider.dispose();
  }

  Widget buildApp(Widget homeWidget) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CompetitionProvider>.value(
          value: competitionProvider,
        ),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == '/admin') {
            return MaterialPageRoute(
              builder: (_) => const AdminDashboardPage(),
            );
          }
          if (settings.name == '/association/create') {
            return MaterialPageRoute(
              builder: (_) => const CreateAssociationPage(),
            );
          }
          if (settings.name == '/competition/create') {
            return MaterialPageRoute(
              builder: (_) => const CompetitionCreationPage(),
            );
          }
          if (settings.name == '/competition/handling') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) =>
                  CompetitionJudgingPage(competitionId: args['id']),
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
    debugPrint(
      'DEBUG: waitForAuthSettle starting. status=${authProvider.status}, error=${authProvider.errorMessage}',
    );
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (authProvider.status == AuthStatus.authenticated ||
          (authProvider.status == AuthStatus.unauthenticated &&
              authProvider.errorMessage != null)) {
        debugPrint(
          'DEBUG: waitForAuthSettle loop breaking condition met at i=$i. status=${authProvider.status}, error=${authProvider.errorMessage}',
        );
        break;
      }
    }
    // Instead of pumpAndSettle which hangs on blinking cursor/animations, pump a few times
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

class MockUser implements fb.User {
  @override
  final String uid;
  @override
  final String? email;

  MockUser({required this.uid, this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAuth implements fb.FirebaseAuth {
  final StreamController<fb.User?> _authStateController;
  final InMemoryDatabase db;
  MockUser? _currentUser;
  final bool yieldImmediately;

  MockFirebaseAuth(this._authStateController, this.db, {MockUser? currentUser, this.yieldImmediately = false})
      : _currentUser = currentUser;

  @override
  MockUser? get currentUser => _currentUser;

  void setCurrentUser(MockUser? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  @override
  Stream<fb.User?> authStateChanges() async* {
    if (yieldImmediately) {
      yield _currentUser;
    }
    yield* _authStateController.stream;
  }

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = MockUser(uid: 'user-created', email: email);
    setCurrentUser(user);
    return MockUserCredential(user);
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final clean = email.trim().toLowerCase();
    String uid = 'user-signedin';
    try {
      final p = db.profiles.values.firstWhere((x) => x.email.toLowerCase() == clean);
      uid = p.id;
    } catch (_) {}
    final user = MockUser(uid: uid, email: email);
    setCurrentUser(user);
    return MockUserCredential(user);
  }

  @override
  Future<void> signOut() async {
    setCurrentUser(null);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    fb.ActionCodeSettings? actionCodeSettings,
  }) async {
    // Mock implementation
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserCredential implements fb.UserCredential {
  @override
  final fb.User? user;
  MockUserCredential(this.user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
