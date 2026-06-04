import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:backend/db_connection.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../../routes/competitions/[id]/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockConnection extends Mock implements Connection {}
class _MockResultRow extends Mock implements ResultRow {}

class FakeResult extends ListBase<ResultRow> implements Result {
  final List<ResultRow> _rows;
  FakeResult(this._rows);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  int get affectedRows => _rows.length;

  @override
  int get length => _rows.length;

  @override
  set length(int newLength) => _rows.length = newLength;

  @override
  ResultRow operator [](int index) => _rows[index];

  @override
  void operator []=(int index, ResultRow value) => _rows[index] = value;
}

void main() {
  group('competitions/[id] route', () {
    late _MockRequestContext context;
    late _MockRequest request;
    late _MockConnection connection;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      connection = _MockConnection();

      when(() => context.request).thenReturn(request);
      DbConnection.connection = connection;
    });

    test('GET returns competition when found', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final row = _MockResultRow();
      when(() => row.toColumnMap()).thenReturn({
        'id': 'comp-1',
        'title': 'Hamburg Qualifier',
        'location': 'Hamburg Gym',
        'sport_subtype': 'Modern',
        'status': 'upcoming',
        'start_date': DateTime(2026, 6, 15).toUtc().toIso8601String(),
        'end_date': DateTime(2026, 6, 15).toUtc().toIso8601String(),
        'created_at': DateTime(2026, 6, 15).toUtc().toIso8601String(),
        'updated_at': DateTime(2026, 6, 15).toUtc().toIso8601String(),
      });
      final fakeResult = FakeResult([row]);

      when(() => connection.execute(any(), parameters: any(named: 'parameters')))
          .thenAnswer((_) async => fakeResult);

      final response = await route.onRequest(context, '00000000-0000-0000-0000-000000000001');

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json() as Map<String, dynamic>;
      expect(body['title'], equals('Hamburg Qualifier'));
    });

    test('GET returns 404 when not found', () async {
      when(() => request.method).thenReturn(HttpMethod.get);
      final fakeResult = FakeResult([]);

      when(() => connection.execute(any(), parameters: any(named: 'parameters')))
          .thenAnswer((_) async => fakeResult);

      final response = await route.onRequest(context, '00000000-0000-0000-0000-000000000002');

      expect(response.statusCode, equals(HttpStatus.notFound));
    });

    test('PUT updates and returns competition', () async {
      when(() => request.method).thenReturn(HttpMethod.put);
      when(() => request.body()).thenAnswer((_) async => jsonEncode({
        'title': 'Updated Hamburg Qualifier',
        'location': 'Updated Hamburg Gym',
      }));

      final row = _MockResultRow();
      when(() => row.toColumnMap()).thenReturn({
        'id': '00000000-0000-0000-0000-000000000001',
        'title': 'Updated Hamburg Qualifier',
        'location': 'Updated Hamburg Gym',
        'sport_subtype': 'Modern',
        'status': 'upcoming',
        'start_date': DateTime(2026, 6, 15).toUtc().toIso8601String(),
        'end_date': DateTime(2026, 6, 15).toUtc().toIso8601String(),
        'created_at': DateTime(2026, 6, 15).toUtc().toIso8601String(),
        'updated_at': DateTime(2026, 6, 15).toUtc().toIso8601String(),
      });
      final fakeResult = FakeResult([row]);

      when(() => connection.execute(any(), parameters: any(named: 'parameters')))
          .thenAnswer((_) async => fakeResult);

      final response = await route.onRequest(context, '00000000-0000-0000-0000-000000000001');

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json() as Map<String, dynamic>;
      expect(body['title'], equals('Updated Hamburg Qualifier'));
    });
  });
}
