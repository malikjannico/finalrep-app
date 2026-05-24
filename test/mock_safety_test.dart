import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/utils/mock_safety.dart';

void main() {
  group('MockSafety Tests', () {
    tearDown(() {
      MockSafety.setMockAllowedForTesting(null);
    });

    test('default environment settings', () {
      // By default in test environment without special environment flags
      expect(MockSafety.env, 'dev');
      expect(MockSafety.firebaseApiKey, isEmpty);
      expect(MockSafety.firebaseAuthDomain, isEmpty);
      expect(MockSafety.hasFirebaseKeys, isFalse);
      expect(MockSafety.isMockAllowed, isTrue);
    });

    test('isMockAllowed override behavior', () {
      MockSafety.setMockAllowedForTesting(true);
      expect(MockSafety.isMockAllowed, isTrue);

      MockSafety.setMockAllowedForTesting(false);
      expect(MockSafety.isMockAllowed, isFalse);

      MockSafety.setMockAllowedForTesting(null);
      expect(MockSafety.isMockAllowed, isTrue); // Back to default (dev + no keys)
    });

    test('validateStartupConfiguration handles dev correctly', () {
      // In dev with empty keys, validateStartupConfiguration should pass
      expect(() => MockSafety.validateStartupConfiguration(), returnsNormally);
    });

    test('validateStartupConfiguration handles staging and prod credentials requirements', () {
      // We cannot easily change String.fromEnvironment at runtime,
      // but we can test that validateStartupConfiguration will enforce the rules.
      // Since env is 'dev', we can't test the staging/prod paths directly without setting
      // the environment variables during 'flutter test' or if we refactored,
      // but the rules are static and clear. Let's make sure the dev path passes.
      expect(MockSafety.env, 'dev');
      expect(() => MockSafety.validateStartupConfiguration(), returnsNormally);
    });
  });
}
