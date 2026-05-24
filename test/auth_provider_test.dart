import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';

// --- Mocks ---

class MockSupabaseClient implements SupabaseClient {
  @override
  final MockGoTrueClient auth;

  MockSupabaseClient({required this.auth});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserResponse implements UserResponse {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoTrueClient implements GoTrueClient {
  final StreamController<AuthState> _authStateController;

  MockGoTrueClient(this._authStateController);

  final List<Map<String, dynamic>> signUpCalls = [];
  final List<Map<String, dynamic>> signInCalls = [];
  final List<Map<String, dynamic>> updateUserCalls = [];
  int signOutCallCount = 0;

  AuthResponse? signUpResult;
  AuthResponse? signInResult;
  UserResponse? updateUserResult;
  Object? signUpError;
  Object? signInError;
  Object? updateUserError;

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #signUp) {
      final namedArgs = invocation.namedArguments;
      signUpCalls.add({
        'email': namedArgs[#email],
        'password': namedArgs[#password],
        'data': namedArgs[#data],
      });
      if (signUpError != null) throw signUpError!;
      return Future.value(
        signUpResult ?? AuthResponse(session: null, user: null),
      );
    }
    if (name == #signInWithPassword) {
      final namedArgs = invocation.namedArguments;
      signInCalls.add({
        'email': namedArgs[#email],
        'password': namedArgs[#password],
      });
      if (signInError != null) throw signInError!;
      return Future.value(
        signInResult ?? AuthResponse(session: null, user: null),
      );
    }
    if (name == #signOut) {
      signOutCallCount++;
      return Future.value(null);
    }
    if (name == #updateUser) {
      final positionalArgs = invocation.positionalArguments;
      final attributes = positionalArgs.isNotEmpty
          ? positionalArgs.first as UserAttributes
          : null;
      updateUserCalls.add({
        'email': attributes?.email,
        'password': attributes?.password,
      });
      if (updateUserError != null) throw updateUserError!;
      return Future.value(updateUserResult ?? MockUserResponse());
    }
    if (name == #resetPasswordForEmail) {
      return Future.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

class MockProfileRepository implements ProfileRepository {
  final Map<String, Profile> profiles = {};
  final List<Profile> searchResults = [];

  final List<Profile> updateCalls = [];
  Profile? updateResult;
  Object? updateError;

  int getProfileCallCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Profile?> getProfile(String id) async {
    getProfileCallCount++;
    return profiles[id];
  }

  @override
  Future<Profile?> getProfileByUsername(String username) async {
    for (final profile in profiles.values) {
      if (profile.username == username) {
        return profile;
      }
    }
    return null;
  }

  @override
  Future<Profile?> getProfileByEmail(String email) async {
    for (final profile in profiles.values) {
      if (profile.email == email) {
        return profile;
      }
    }
    return null;
  }

  @override
  Future<List<Profile>> searchProfiles(String query) async {
    return searchResults;
  }

  @override
  Future<Profile?> updateProfile(Profile profile) async {
    updateCalls.add(profile);
    if (updateError != null) throw updateError!;
    return updateResult ?? profile;
  }
}

// Helper to create a fake User & Session
User _createFakeUser(String id, String email) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: email,
  );
}

Session _createFakeSession(User user) {
  return Session(accessToken: 'token-abc', tokenType: 'bearer', user: user);
}

void main() {
  group('AuthProvider Tests', () {
    late StreamController<AuthState> authStateController;
    late MockGoTrueClient mockAuth;
    late MockSupabaseClient mockClient;
    late MockProfileRepository mockProfileRepository;
    late AuthProvider authProvider;

    setUp(() {
      authStateController = StreamController<AuthState>.broadcast();
      mockAuth = MockGoTrueClient(authStateController);
      mockClient = MockSupabaseClient(auth: mockAuth);
      mockProfileRepository = MockProfileRepository();
      authProvider = AuthProvider(mockClient, mockProfileRepository);
    });

    tearDown(() {
      authProvider.dispose();
      authStateController.close();
    });

    test('Initial state is unauthenticated and loading', () {
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.currentUserProfile, isNull);
      expect(authProvider.isLoading, true);
    });

    test('Auth state change to authenticated loads profile', () async {
      final user = _createFakeUser('user-1', 'user1@example.com');
      final session = _createFakeSession(user);

      final profile = Profile(
        id: 'user-1',
        username: 'user1',
        fullName: 'User One',
        email: 'user1@example.com',
      );
      mockProfileRepository.profiles['user-1'] = profile;

      // Trigger auth change
      authStateController.add(AuthState(AuthChangeEvent.signedIn, session));

      // Wait for auth provider to process
      await Future.delayed(const Duration(milliseconds: 100));

      expect(authProvider.isLoading, false);
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.currentUserProfile, profile);
      expect(authProvider.session, session);
      expect(authProvider.errorMessage, isNull);
    });

    test(
      'Auth state change fails if profile details cannot be loaded',
      () async {
        final user = _createFakeUser('user-1', 'user1@example.com');
        final session = _createFakeSession(user);

        // Trigger auth change (no profile in repository)
        authStateController.add(AuthState(AuthChangeEvent.signedIn, session));

        // Wait for 3 retries (500ms delay each) to complete
        await Future.delayed(const Duration(milliseconds: 1700));

        expect(authProvider.isLoading, false);
        expect(authProvider.status, AuthStatus.unauthenticated);
        expect(authProvider.currentUserProfile, isNull);
        expect(
          authProvider.errorMessage,
          'Profile details could not be loaded.',
        );
        expect(mockProfileRepository.getProfileCallCount, 3);
      },
    );

    test('Auth state change to unauthenticated resets profile', () async {
      // Trigger sign out event
      authStateController.add(const AuthState(AuthChangeEvent.signedOut, null));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(authProvider.isLoading, false);
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.currentUserProfile, isNull);
      expect(authProvider.session, isNull);
    });

    test('registerWithEmailAndPassword checks username and signs up', () async {
      // Should succeed when username is free
      await authProvider.registerWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
        username: 'testuser',
        fullName: 'Test User',
        gender: 'Male',
        country: 'USA',
        profilePictureUrl: 'https://example.com/pic.png',
      );

      expect(mockAuth.signUpCalls.length, 1);
      final call = mockAuth.signUpCalls.first;
      expect(call['email'], 'test@example.com');
      expect(call['password'], 'password123');
      expect(call['data'], {
        'username': 'testuser',
        'full_name': 'Test User',
        'gender': 'Male',
        'country': 'USA',
        'profile_picture_url': 'https://example.com/pic.png',
      });
    });

    test(
      'registerWithEmailAndPassword fails if username is already taken',
      () async {
        final existingProfile = Profile(
          id: 'user-2',
          username: 'takenuser',
          fullName: 'Taken User',
          email: 'taken@example.com',
        );
        mockProfileRepository.profiles['user-2'] = existingProfile;

        expect(
          () => authProvider.registerWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
            username: 'takenuser',
            fullName: 'Test User',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains("Username 'takenuser' is already taken."),
            ),
          ),
        );

        // Auth sign up should NOT have been called
        expect(mockAuth.signUpCalls, isEmpty);
      },
    );

    test('loginWithEmailAndPassword calls signInWithPassword', () async {
      await authProvider.loginWithEmailAndPassword(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(mockAuth.signInCalls.length, 1);
      final call = mockAuth.signInCalls.first;
      expect(call['email'], 'user@example.com');
      expect(call['password'], 'password123');
    });

    test(
      'loginWithUsernameAndPassword resolves email and calls signInWithPassword',
      () async {
        final profile = Profile(
          id: 'user-3',
          username: 'user3',
          fullName: 'User Three',
          email: 'user3@example.com',
        );
        mockProfileRepository.profiles['user-3'] = profile;

        await authProvider.loginWithUsernameAndPassword(
          username: 'user3',
          password: 'my-password',
        );

        expect(mockAuth.signInCalls.length, 1);
        final call = mockAuth.signInCalls.first;
        expect(call['email'], 'user3@example.com');
        expect(call['password'], 'my-password');
      },
    );

    test(
      'loginWithUsernameAndPassword fails if username is not found',
      () async {
        expect(
          () => authProvider.loginWithUsernameAndPassword(
            username: 'unknownuser',
            password: 'password123',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains("Username 'unknownuser' not found."),
            ),
          ),
        );

        expect(mockAuth.signInCalls, isEmpty);
      },
    );

    test('logout calls signOut', () async {
      await authProvider.logout();
      expect(mockAuth.signOutCallCount, 1);
    });

    test(
      'updateProfile updates user attributes and updates repository profile',
      () async {
        final initialProfile = Profile(
          id: 'user-4',
          username: 'user4',
          fullName: 'User Four',
          email: 'user4@example.com',
          colorMode: 'system',
        );

        // Simulate auth state as authenticated with user-4
        mockProfileRepository.profiles['user-4'] = initialProfile;
        final user = _createFakeUser('user-4', 'user4@example.com');
        final session = _createFakeSession(user);
        authStateController.add(AuthState(AuthChangeEvent.signedIn, session));
        await Future.delayed(const Duration(milliseconds: 100));

        // Trigger update with new email and name
        await authProvider.updateProfile(
          fullName: 'Updated User Four',
          email: 'newemail@example.com',
          gender: 'Female',
          country: 'Canada',
          description: 'New Description',
          colorMode: 'dark',
        );

        // Email update triggered
        expect(mockAuth.updateUserCalls.length, 1);
        expect(mockAuth.updateUserCalls.first['email'], 'newemail@example.com');

        // Profile repository update triggered
        expect(mockProfileRepository.updateCalls.length, 1);
        final updatedProfile = mockProfileRepository.updateCalls.first;
        expect(updatedProfile.fullName, 'Updated User Four');
        expect(updatedProfile.email, 'newemail@example.com');
        expect(updatedProfile.gender, 'Female');
        expect(updatedProfile.country, 'Canada');
        expect(updatedProfile.description, 'New Description');
        expect(updatedProfile.colorMode, 'dark');
      },
    );

    test('changePassword updates password attribute', () async {
      await authProvider.changePassword('new-secure-password');

      expect(mockAuth.updateUserCalls.length, 1);
      expect(mockAuth.updateUserCalls.first['password'], 'new-secure-password');
    });

    test('resolveEmailFromUsername trims and lowercases username', () async {
      final profile = Profile(
        id: 'user-resolution',
        username: 'resolveduser',
        fullName: 'Resolved User',
        email: 'resolved@example.com',
      );
      mockProfileRepository.profiles['user-resolution'] = profile;

      final email = await authProvider.resolveEmailFromUsername(
        '   ResolvedUser   ',
      );
      expect(email, 'resolved@example.com');
    });

    test(
      'loginWithUsernameAndPassword trims and lowercases username',
      () async {
        final profile = Profile(
          id: 'user-login-trim',
          username: 'logintrimuser',
          fullName: 'Login Trim User',
          email: 'logintrim@example.com',
        );
        mockProfileRepository.profiles['user-login-trim'] = profile;

        await authProvider.loginWithUsernameAndPassword(
          username: '  LoginTrimUser  ',
          password: 'password123',
        );

        expect(mockAuth.signInCalls.length, 1);
        expect(mockAuth.signInCalls.first['email'], 'logintrim@example.com');
      },
    );
  });
}
