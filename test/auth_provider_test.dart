import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/utils/uuid_helper.dart';

// --- Mocks ---

class MockUser implements fb.User {
  @override
  final String uid;
  @override
  final String? email;

  MockUser({required this.uid, this.email});

  final List<String> updateEmailCalls = [];
  final List<String> updatePasswordCalls = [];

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail, [fb.ActionCodeSettings? actionCodeSettings]) async {
    updateEmailCalls.add(newEmail);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatePasswordCalls.add(newPassword);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserCredential implements fb.UserCredential {
  @override
  final fb.User? user;

  MockUserCredential({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAuth implements fb.FirebaseAuth {
  final StreamController<fb.User?> _authStateController;
  MockUser? _currentUser;

  MockFirebaseAuth(this._authStateController, {MockUser? currentUser})
      : _currentUser = currentUser;

  final List<Map<String, dynamic>> signUpCalls = [];
  final List<Map<String, dynamic>> signInCalls = [];
  final List<String> sendResetPasswordCalls = [];
  int signOutCallCount = 0;

  fb.UserCredential? signUpResult;
  fb.UserCredential? signInResult;
  Object? signUpError;
  Object? signInError;

  @override
  MockUser? get currentUser => _currentUser;

  void setCurrentUser(MockUser? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  @override
  Stream<fb.User?> authStateChanges() => _authStateController.stream;

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signUpCalls.add({'email': email, 'password': password});
    if (signUpError != null) throw signUpError!;
    final user = MockUser(uid: 'user-created', email: email);
    setCurrentUser(user);
    return signUpResult ?? MockUserCredential(user: user);
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls.add({'email': email, 'password': password});
    if (signInError != null) throw signInError!;
    final user = MockUser(uid: 'user-signedin', email: email);
    setCurrentUser(user);
    return signInResult ?? MockUserCredential(user: user);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    setCurrentUser(null);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    fb.ActionCodeSettings? actionCodeSettings,
  }) async {
    sendResetPasswordCalls.add(email);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

void main() {
  group('AuthProvider Tests', () {
    late StreamController<fb.User?> authStateController;
    late MockFirebaseAuth mockAuth;
    late MockProfileRepository mockProfileRepository;
    late AuthProvider authProvider;

    setUp(() {
      authStateController = StreamController<fb.User?>.broadcast();
      mockAuth = MockFirebaseAuth(authStateController);
      mockProfileRepository = MockProfileRepository();
      authProvider = AuthProvider(mockProfileRepository, firebaseAuth: mockAuth);
    });

    tearDown(() {
      authProvider.dispose();
      authStateController.close();
    });

    test('Initial state is unauthenticated', () {
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.currentUserProfile, isNull);
      expect(authProvider.isLoading, false);
    });

    test('Auth state change to authenticated loads profile', () async {
      final user = MockUser(uid: 'user-1', email: 'user1@example.com');
      final profile = Profile(
        id: 'user-1',
        username: 'user1',
        fullName: 'User One',
        email: 'user1@example.com',
      );
      
      final mappedUuid = UuidHelper.getDeterministicUuid('user-1');
      mockProfileRepository.profiles[mappedUuid] = profile;

      // Trigger auth change
      mockAuth.setCurrentUser(user);

      // Wait for auth provider to process
      await Future.delayed(const Duration(milliseconds: 100));

      expect(authProvider.isLoading, false);
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.currentUserProfile, profile);
      expect(authProvider.errorMessage, isNull);
    });

    test(
      'Auth state change fails if profile details cannot be loaded',
      () async {
        final user = MockUser(uid: 'user-1', email: 'user1@example.com');

        // Trigger auth change (no profile in repository)
        mockAuth.setCurrentUser(user);

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
      mockAuth.setCurrentUser(null);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(authProvider.isLoading, false);
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.currentUserProfile, isNull);
    });

    test('registerWithEmailAndPassword checks username and signs up', () async {
      await authProvider.registerWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
        username: 'testuser',
        fullName: 'Test User',
        sex: 'male',
        country: 'USA',
        profilePictureUrl: 'https://example.com/pic.png',
      );

      expect(mockAuth.signUpCalls.length, 1);
      final call = mockAuth.signUpCalls.first;
      expect(call['email'], 'test@example.com');
      expect(call['password'], 'password123');
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

        final mappedUuid = UuidHelper.getDeterministicUuid('user-4');
        mockProfileRepository.profiles[mappedUuid] = initialProfile;

        final user = MockUser(uid: 'user-4', email: 'user4@example.com');
        mockAuth._currentUser = user;
        
        mockAuth.setCurrentUser(user);
        await Future.delayed(const Duration(milliseconds: 100));

        // Trigger update with new email and name
        await authProvider.updateProfile(
          fullName: 'Updated User Four',
          email: 'newemail@example.com',
          sex: 'Female',
          country: 'Canada',
          description: 'New Description',
          colorMode: 'dark',
        );

        // Email update triggered
        expect(user.updateEmailCalls.length, 1);
        expect(user.updateEmailCalls.first, 'newemail@example.com');

        // Profile repository update triggered
        expect(mockProfileRepository.updateCalls.length, 1);
        final updatedProfile = mockProfileRepository.updateCalls.first;
        expect(updatedProfile.fullName, 'Updated User Four');
        expect(updatedProfile.email, 'newemail@example.com');
        expect(updatedProfile.sex, 'Female');
        expect(updatedProfile.country, 'Canada');
        expect(updatedProfile.description, 'New Description');
        expect(updatedProfile.colorMode, 'dark');
      },
    );

    test('changePassword updates password attribute', () async {
      final user = MockUser(uid: 'user-5', email: 'user5@example.com');
      mockAuth._currentUser = user;

      await authProvider.changePassword('new-secure-password');

      expect(user.updatePasswordCalls.length, 1);
      expect(user.updatePasswordCalls.first, 'new-secure-password');
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
