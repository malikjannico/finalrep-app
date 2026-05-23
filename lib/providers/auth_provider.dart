import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../repositories/profile_repository.dart';

import '../repositories/admin_repository.dart';
import '../models/permission_application.dart';
import '../models/admin_config.dart';
import '../repositories/notification_repository.dart';
import '../models/system_notification.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated }

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _client;
  final ProfileRepository _profileRepository;
  final AdminRepository _adminRepository;
  final NotificationRepository _notificationRepository;
  
  AuthStatus _status = AuthStatus.unauthenticated;
  Profile? _currentUserProfile;
  Session? _session;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isPasswordRecoveryActive = false;
  bool _isDisposed = false;

  AuthProvider(
    this._client,
    this._profileRepository, {
    AdminRepository? adminRepository,
    NotificationRepository? notificationRepository,
  }) : _adminRepository = adminRepository ?? AdminRepository(_client),
       _notificationRepository = notificationRepository ?? NotificationRepository(_client) {
    _init();
  }

  // Getters
  ProfileRepository get profileRepository => _profileRepository;
  AdminRepository get adminRepository => _adminRepository;
  AuthStatus get status => _status;
  Profile? get currentUserProfile => _currentUserProfile;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Session? get session => _session;
  bool get isPasswordRecoveryActive => _isPasswordRecoveryActive;

  bool get isAdmin => _currentUserProfile?.isAdmin ?? false;
  bool get isCompetitionCreator => _currentUserProfile?.isCompetitionCreator ?? false;
  bool get isAssociationCreator => _currentUserProfile?.isAssociationCreator ?? false;

  void clearPasswordRecovery() {
    _isPasswordRecoveryActive = false;
    notifyListeners();
  }

  Future<bool> isUsernameTaken(String username) async {
    final profile = await _profileRepository.getProfileByUsername(username.trim().toLowerCase());
    return profile != null;
  }

  Future<bool> isEmailTaken(String email) async {
    final profile = await _profileRepository.getProfileByEmail(email.trim().toLowerCase());
    return profile != null;
  }

  Future<String> resolveEmailFromUsername(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    final profile = await _profileRepository.getProfileByUsername(cleanUsername);
    if (profile == null) {
      throw Exception("Username '$username' not found.");
    }
    return profile.email;
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
      print('DEBUG: AuthProvider received event=${data.event} user=${data.session?.user.id}');
      _session = data.session;
      final user = data.session?.user;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecoveryActive = true;
      }

      if (user != null) {
        _status = AuthStatus.authenticating;
        // Fetch profile with retry logic in case of DB trigger latency
        print('DEBUG: AuthProvider starts fetching profile for user=${user.id}');
        final profile = await _fetchProfileWithRetry(user.id);
        print('DEBUG: AuthProvider finished fetching profile for user=${user.id}, profile=$profile');
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
      print('DEBUG: _fetchProfileWithRetry attempt=$i for id=$id');
      final profile = await _profileRepository.getProfile(id);
      if (profile != null) {
        print('DEBUG: _fetchProfileWithRetry success on attempt=$i for id=$id');
        return profile;
      }
      print('DEBUG: _fetchProfileWithRetry failed on attempt=$i, delaying...');
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
      final cleanUsername = username.trim().toLowerCase();
      final existing = await _profileRepository.getProfileByUsername(cleanUsername);
      if (existing != null) {
        throw Exception("Username '$username' is already taken.");
      }

      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'username': cleanUsername,
          'full_name': fullName,
          'gender': gender,
          'country': country,
          'profile_picture_url': profilePictureUrl,
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
      final cleanUsername = username.trim().toLowerCase();
      final profile = await _profileRepository.getProfileByUsername(cleanUsername);
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

  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? gender,
    String? country,
    String? description,
    required String colorMode,
    String? profilePictureUrl,
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
        profilePictureUrl: profilePictureUrl ?? _currentUserProfile!.profilePictureUrl,
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

  /// Apply for permissions (create_competition or create_association)
  Future<PermissionApplication?> applyForPermissions(String type, String reason) async {
    if (_currentUserProfile == null) return null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final app = await _adminRepository.applyForPermissions(_currentUserProfile!.id, type, reason);
      return app;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get list of permission applications
  Future<List<PermissionApplication>> getPermissionApplications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _adminRepository.getPermissionApplications();
    } catch (e) {
      _errorMessage = e.toString();
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approve permission application
  Future<PermissionApplication?> approvePermissionApplication(String applicationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final app = await _adminRepository.approvePermissionApplication(applicationId);
      if (app != null && app.status == 'approved') {
        // Automatically promote the user's permissions in the profile database
        final isCompCreator = app.type == 'create_competition' ? true : null;
        final isAssocCreator = app.type == 'create_association' ? true : null;
        final updatedProfile = await _profileRepository.updatePermissions(
          app.userId,
          isCompetitionCreator: isCompCreator,
          isAssociationCreator: isAssocCreator,
        );
        // If the updated user is the current logged-in user, refresh our local profile state
        if (updatedProfile != null && _currentUserProfile != null && updatedProfile.id == _currentUserProfile!.id) {
          _currentUserProfile = updatedProfile;
        }

        // Trigger Permission Notification
        final notif = SystemNotification(
          id: 'notif-perm-${DateTime.now().millisecondsSinceEpoch}',
          userId: app.userId,
          title: 'Permissions Approved',
          message: 'Your application to become a ${app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator'} has been approved.',
          category: 'permissions',
          createdAt: DateTime.now(),
        );
        await _notificationRepository.createNotification(notif);
      }
      return app;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reject permission application
  Future<PermissionApplication?> rejectPermissionApplication(String applicationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final app = await _adminRepository.rejectPermissionApplication(applicationId);
      if (app != null && app.status == 'rejected') {
        // Trigger Permission Notification
        final notif = SystemNotification(
          id: 'notif-perm-${DateTime.now().millisecondsSinceEpoch}',
          userId: app.userId,
          title: 'Permissions Application Update',
          message: 'Your application to become a ${app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator'} was rejected.',
          category: 'permissions',
          createdAt: DateTime.now(),
        );
        await _notificationRepository.createNotification(notif);
      }
      return app;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user notification settings
  Future<void> updateNotificationPreference(String category, bool enabled) async {
    if (_currentUserProfile == null) return;

    final updatedPrefs = Map<String, bool>.from(_currentUserProfile!.notificationPreferences);
    updatedPrefs[category] = enabled;

    final updatedProfile = _currentUserProfile!.copyWith(
      notificationPreferences: updatedPrefs,
    );

    try {
      final result = await _profileRepository.updateProfile(updatedProfile);
      if (result != null) {
        _currentUserProfile = result;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to save notification preferences: $e');
      // Local fallback: update local model state even if DB update fails to keep UI responsive
      _currentUserProfile = updatedProfile;
      notifyListeners();
    }
  }

  /// Promote a user to Admin
  Future<Profile?> promoteToAdmin(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updatedProfile = await _profileRepository.updatePermissions(userId, isAdmin: true);
      if (updatedProfile != null && _currentUserProfile != null && updatedProfile.id == _currentUserProfile!.id) {
        _currentUserProfile = updatedProfile;
      }
      return updatedProfile;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load global sports config
  Future<SportConfig> loadSportsConfig() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _adminRepository.loadSportsConfig();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save global sports config
  Future<bool> saveSportsConfig(SportConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _adminRepository.saveSportsConfig(config);
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
