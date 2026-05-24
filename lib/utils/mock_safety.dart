import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart' show WidgetsBinding;

class MockSafety {
  static bool? _isMockAllowedOverride;

  @visibleForTesting
  static void setMockAllowedForTesting(bool? value) {
    _isMockAllowedOverride = value;
  }

  static bool get isTesting {
    if (kIsWeb) {
      final binding = WidgetsBinding.instance;
      if (binding != null) {
        final name = binding.runtimeType.toString();
        return name.contains('Test') || name.contains('Mock');
      }
      return false;
    }
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    final binding = WidgetsBinding.instance;
    if (binding != null) {
      final name = binding.runtimeType.toString();
      return name.contains('Test') || name.contains('Mock');
    }
    return false;
  }

  static bool get isMockAllowed {
    if (_isMockAllowedOverride != null) {
      return _isMockAllowedOverride!;
    }
    return isTesting;
  }

  static String get env => const String.fromEnvironment('ENV', defaultValue: 'dev');
  static String get apiBaseUrl => const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');
  static String get firebaseApiKey => const String.fromEnvironment('FIREBASE_API_KEY');
  static String get firebaseAuthDomain => const String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static String get firebaseProjectId => const String.fromEnvironment('FIREBASE_PROJECT_ID');
  static String get firebaseStorageBucket => const String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static String get firebaseMessagingSenderId => const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseAppId => const String.fromEnvironment('FIREBASE_APP_ID');

  static bool get hasFirebaseKeys =>
      firebaseApiKey.isNotEmpty &&
      firebaseAuthDomain.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static void validateStartupConfiguration() {
    if (env != 'dev' && env != 'staging' && env != 'prod') {
      throw StateError('Invalid environment: "$env". Must be dev, staging, or prod.');
    }

    if (env == 'staging' || env == 'prod') {
      if (apiBaseUrl.isEmpty || !hasFirebaseKeys) {
        throw StateError('API_BASE_URL and Firebase configurations must be provided in "$env" environment.');
      }
      final uri = Uri.tryParse(apiBaseUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw StateError('Invalid API_BASE_URL: "$apiBaseUrl"');
      }
    }
  }
}
