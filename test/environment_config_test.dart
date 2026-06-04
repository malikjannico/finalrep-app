import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:finalrep_app/utils/mock_safety.dart';
import 'package:finalrep_app/utils/api_client.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/admin_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) sendHandler;

  MockHttpClient(this.sendHandler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => sendHandler(request);
}

void main() {
  group('R6 Environment Configuration & Mock Safety Tests', () {
    late ApiClient throwingApi;
    late ApiClient emptyApi;

    setUp(() {
      final throwingHttpClient = MockHttpClient((request) async {
        throw Exception('Database query failed for testing');
      });
      throwingApi = ApiClient(client: throwingHttpClient);

      final emptyHttpClient = MockHttpClient((request) async {
        if (request.url.path.endsWith('/admin/sport-config')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode('Not found')),
            404,
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode('[]')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      emptyApi = ApiClient(client: emptyHttpClient);
    });

    tearDown(() {
      MockSafety.setMockAllowedForTesting(null);
    });

    test('Dev with empty keys: mock database fallback is allowed', () async {
      MockSafety.setMockAllowedForTesting(true);
      final profileRepo = ProfileRepository(api: throwingApi);

      final results = await profileRepo.getUserHighestRankings('test-user');
      expect(results, isNotEmpty); // Returns mock rankings successfully
    });

    test('Staging/Production (Mock disallowed): ProfileRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final profileRepo = ProfileRepository(api: throwingApi);

      expect(() => profileRepo.getUserHighestRankings('test-user'), throwsA(isA<Exception>()));
    });

    test('Staging/Production (Mock disallowed): ProfileRepository returns actual empty lists instead of mocks', () async {
      MockSafety.setMockAllowedForTesting(false);
      final profileRepo = ProfileRepository(api: emptyApi);

      final results = await profileRepo.getUserHighestRankings('test-user');
      expect(results, isEmpty); // Returns actual empty list instead of mocks
    });

    test('Staging/Production (Mock disallowed): NotificationRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final notificationRepo = NotificationRepository(api: throwingApi);

      expect(() => notificationRepo.getNotifications('test-user'), throwsA(isA<Exception>()));
    });

    test('Staging/Production (Mock disallowed): CompetitionRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final competitionRepo = CompetitionRepository(api: throwingApi);

      expect(() => competitionRepo.getUpcomingCompetitions(), throwsA(isA<Exception>()));
    });

    test('Staging/Production (Mock disallowed): AdminRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final adminRepo = AdminRepository(api: throwingApi);

      expect(() => adminRepo.getPermissionApplications(), throwsA(isA<Exception>()));
    });

    test('Staging/Production (Mock disallowed): AdminRepository.loadSportsConfig throws StateError on empty configuration', () async {
      MockSafety.setMockAllowedForTesting(false);
      final adminRepo = AdminRepository(api: emptyApi);

      try {
        await adminRepo.loadSportsConfig();
        fail('Expected StateError to be thrown');
      } catch (e) {
        expect(e, isA<StateError>());
      }
    });

    test('Staging/Production (Mock disallowed): AssociationRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final associationRepo = AssociationRepository(api: throwingApi);

      expect(() => associationRepo.getAssociations(), throwsA(isA<Exception>()));
    });
  });
}
