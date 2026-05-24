import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class ThrowingMockSupabaseClient implements SupabaseClient {
  @override
  SupabaseQueryBuilder from(String table) {
    throw PostgrestException(message: 'Database query failed for testing', code: '500');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EmptyMockSupabaseClient implements SupabaseClient {
  @override
  SupabaseQueryBuilder from(String table) {
    return EmptyMockQueryBuilder(table);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EmptyMockQueryBuilder implements SupabaseQueryBuilder {
  final String table;
  EmptyMockQueryBuilder(this.table);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #select || name == #insert || name == #update || name == #delete || name == #upsert) {
      return EmptyMockFilterBuilder<List<Map<String, dynamic>>>(table);
    }
    return EmptyMockFilterBuilder<dynamic>(table);
  }
}

class EmptyMockFilterBuilder<T> implements PostgrestFilterBuilder<T>, Future<T> {
  final String table;
  EmptyMockFilterBuilder(this.table);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #maybeSingle) {
      return EmptyMockFilterBuilder<Map<String, dynamic>?>(table);
    }
    if (name == #single) {
      return EmptyMockFilterBuilder<Map<String, dynamic>>(table);
    }
    return this;
  }

  Future<T> _toFuture() {
    T value;
    try {
      value = null as T;
    } catch (_) {
      try {
        dynamic result = <Map<String, dynamic>>[];
        value = result as T;
      } catch (_) {
        try {
          dynamic result = <String, dynamic>{};
          value = result as T;
        } catch (_) {
          value = null as T;
        }
      }
    }
    return Future<T>.value(value);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return _toFuture().then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return _toFuture().catchError(onError, test: test);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return _toFuture().timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Stream<T> asStream() {
    return _toFuture().asStream();
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return _toFuture().whenComplete(action);
  }
}

void main() {
  group('R6 Environment Configuration & Mock Safety Tests', () {
    late ThrowingMockSupabaseClient throwingClient;
    late EmptyMockSupabaseClient emptyClient;
    late ApiClient throwingApi;
    late ApiClient emptyApi;

    setUp(() {
      throwingClient = ThrowingMockSupabaseClient();
      emptyClient = EmptyMockSupabaseClient();

      final throwingHttpClient = MockHttpClient((request) async {
        throw PostgrestException(message: 'Database query failed for testing', code: '500');
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
      final profileRepo = ProfileRepository(throwingClient, api: throwingApi);

      final results = await profileRepo.getUserHighestRankings('test-user');
      expect(results, isNotEmpty); // Returns mock rankings successfully
    });

    test('Staging/Production (Mock disallowed): ProfileRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final profileRepo = ProfileRepository(throwingClient, api: throwingApi);

      expect(() => profileRepo.getUserHighestRankings('test-user'), throwsA(isA<PostgrestException>()));
    });

    test('Staging/Production (Mock disallowed): ProfileRepository returns actual empty lists instead of mocks', () async {
      MockSafety.setMockAllowedForTesting(false);
      final profileRepo = ProfileRepository(emptyClient, api: emptyApi);

      final results = await profileRepo.getUserHighestRankings('test-user');
      expect(results, isEmpty); // Returns actual empty list instead of mocks
    });

    test('Staging/Production (Mock disallowed): NotificationRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final notificationRepo = NotificationRepository(throwingClient, api: throwingApi);

      expect(() => notificationRepo.getNotifications('test-user'), throwsA(isA<PostgrestException>()));
    });

    test('Staging/Production (Mock disallowed): CompetitionRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final competitionRepo = CompetitionRepository(throwingClient, api: throwingApi);

      expect(() => competitionRepo.getUpcomingCompetitions(), throwsA(isA<PostgrestException>()));
    });

    test('Staging/Production (Mock disallowed): AdminRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final adminRepo = AdminRepository(throwingClient, api: throwingApi);

      expect(() => adminRepo.getPermissionApplications(), throwsA(isA<PostgrestException>()));
    });

    test('Staging/Production (Mock disallowed): AdminRepository.loadSportsConfig throws StateError on empty configuration', () async {
      MockSafety.setMockAllowedForTesting(false);
      final adminRepo = AdminRepository(emptyClient, api: emptyApi);

      try {
        await adminRepo.loadSportsConfig();
        fail('Expected StateError to be thrown');
      } catch (e) {
        expect(e, isA<StateError>());
      }
    });

    test('Staging/Production (Mock disallowed): AssociationRepository rethrows exceptions', () async {
      MockSafety.setMockAllowedForTesting(false);
      final associationRepo = AssociationRepository(throwingClient, api: throwingApi);

      expect(() => associationRepo.getAssociations(), throwsA(isA<PostgrestException>()));
    });
  });
}
