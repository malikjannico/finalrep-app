import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../repositories/profile_repository.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated }

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _client;
  final ProfileRepository _profileRepository;
  
  AuthStatus _status = AuthStatus.unauthenticated;
  Profile? _currentUserProfile;
  Session? _session;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isPasswordRecoveryActive = false;

  AuthProvider(this._client, this._profileRepository) {
    _init();
  }

  // Getters
  AuthStatus get status => _status;
  Profile? get currentUserProfile => _currentUserProfile;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Session? get session => _session;
  bool get isPasswordRecoveryActive => _isPasswordRecoveryActive;

  void clearPasswordRecovery() {
    _isPasswordRecoveryActive = false;
    notifyListeners();
  }

  Future<bool> isUsernameTaken(String username) async {
    final profile = await _profileRepository.getProfileByUsername(username);
    return profile != null;
  }

  Future<bool> isEmailTaken(String email) async {
    final profile = await _profileRepository.getProfileByEmail(email);
    return profile != null;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _init() {
    _isLoading = true;
    _authSubscription = _client.auth.onAuthStateChange.listen((data) async {
      _session = data.session;
      final user = data.session?.user;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecoveryActive = true;
      }

      if (user != null) {
        _status = AuthStatus.authenticating;
        // Fetch profile with retry logic in case of DB trigger latency
        final profile = await _fetchProfileWithRetry(user.id);
        if (profile != null) {
          _currentUserProfile = profile;
          _status = AuthStatus.authenticated;
        } else {
          _currentUserProfile = null;
          _status = AuthStatus.unauthenticated;
          _errorMessage = "Profile details could not be loaded.";
        }
      } else {
        _currentUserProfile = null;
        _status = AuthStatus.unauthenticated;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<Profile?> _fetchProfileWithRetry(String id) async {
    for (int i = 0; i < 3; i++) {
      final profile = await _profileRepository.getProfile(id);
      if (profile != null) return profile;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  /// Reset error messages.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Register a new user with Email + Password.
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
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First, check if username is already taken to give a clean error
      final existing = await _profileRepository.getProfileByUsername(username);
      if (existing != null) {
        throw Exception("Username '$username' is already taken.");
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'full_name': fullName,
          'gender':? gender,
          'country':? country,
          'profile_picture_url':? profilePictureUrl,
        },
      );

      final user = response.user;
      if (user != null && customAvatarBytes != null) {
        final ext = customAvatarExtension ?? 'jpg';
        final filePath = 'profiles/${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await _client.storage.from('avatars').uploadBinary(
          filePath,
          customAvatarBytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            cacheControl: '3600',
            upsert: true,
          ),
        );

        final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);

        // Fetch user profile with retry since trigger is async
        final profile = await _fetchProfileWithRetry(user.id);
        if (profile != null) {
          final updated = profile.copyWith(profilePictureUrl: publicUrl);
          await _profileRepository.updateProfile(updated);
          _currentUserProfile = updated;
          notifyListeners();
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Login with Email + Password.
  Future<void> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Login with Username + Password.
  Future<void> loginWithUsernameAndPassword({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _profileRepository.getProfileByUsername(username);
      if (profile == null) {
        throw Exception("Username '$username' not found.");
      }

      await _client.auth.signInWithPassword(
        email: profile.email,
        password: password,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Logout current session.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _client.auth.signOut();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update current user profile.
  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? gender,
    String? country,
    String? description,
    required String colorMode,
  }) async {
    if (_currentUserProfile == null) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // If email has changed, update in auth.users first
      if (email != _currentUserProfile!.email) {
        await _client.auth.updateUser(UserAttributes(email: email));
      }

      final updatedProfile = _currentUserProfile!.copyWith(
        fullName: fullName,
        email: email,
        gender: gender,
        country: country,
        description: description,
        colorMode: colorMode,
      );

      final result = await _profileRepository.updateProfile(updatedProfile);
      if (result != null) {
        _currentUserProfile = result;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change/update current user password (update credentials login method).
  Future<void> changePassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
