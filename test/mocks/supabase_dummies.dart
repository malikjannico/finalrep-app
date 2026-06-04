import 'dart:async';

enum AuthChangeEvent {
  initialSession,
  signedIn,
  signedOut,
  userUpdated,
  passwordRecovery,
  tokenRefreshed,
  mfaChallengeVerified
}

class User {
  final String id;
  final Map<String, dynamic> appMetadata;
  final Map<String, dynamic> userMetadata;
  final String aud;
  final String createdAt;
  final String? email;

  User({
    required this.id,
    required this.appMetadata,
    required this.userMetadata,
    required this.aud,
    required this.createdAt,
    this.email,
  });
}

class Session {
  final String accessToken;
  final String tokenType;
  final User user;

  Session({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });
}

class AuthState {
  final AuthChangeEvent event;
  final Session? session;

  AuthState(this.event, this.session);
}

class UserAttributes {
  final String? email;
  UserAttributes({this.email});
}

class UserResponse {
  final User? user;
  UserResponse({this.user});
}

class AuthResponse {
  final Session? session;
  final User? user;
  AuthResponse({this.session, this.user});
}

class Supabase {
  static final Supabase instance = Supabase._();
  Supabase._();

  late SupabaseClient client;

  static Future<Supabase> initialize({
    required String url,
    required String anonKey,
    String? authFlowType,
    bool? debug,
  }) async {
    return instance;
  }
}

abstract class SupabaseClient {
  GoTrueClient get auth;
  SupabaseStorageClient get storage;
  SupabaseQueryBuilder from(String table);
}

abstract class GoTrueClient {
  User? get currentUser;
  Session? get currentSession;
  Stream<AuthState> get onAuthStateChange;
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  });
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? username,
    required String password,
  });
  Future<void> signOut();
  Future<UserResponse> updateUser(UserAttributes attributes);
  Future<void> resetPasswordForEmail(String email, {String? redirectTo});
}

abstract class SupabaseStorageClient {
  StorageFileApi from(String id);
}

abstract class StorageFileApi {
  String get bucketId;
}

abstract class SupabaseQueryBuilder {
  dynamic select([String columns = '*']);
  dynamic insert(dynamic values);
  dynamic update(Map<String, dynamic> values);
}

abstract class PostgrestFilterBuilder<T> {}
abstract class PostgrestTransformBuilder<T> {}

class MockSupabaseClient implements SupabaseClient {
  @override
  final MockGoTrueClient auth;
  MockSupabaseClient({required this.auth});
  
  @override
  SupabaseStorageClient get storage => throw UnimplementedError();

  @override
  SupabaseQueryBuilder from(String table) => throw UnimplementedError();
}

class MockGoTrueClient implements GoTrueClient {
  final StreamController<AuthState> _authStateController;
  MockGoTrueClient(this._authStateController);

  @override
  User? get currentUser => null;
  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  void triggerAuthStateChange(AuthChangeEvent event, Session? session) {
    _authStateController.add(AuthState(event, session));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
