import 'dart:collection';
import 'dart:io';
import 'package:backend/db_connection.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../../routes/competitions/index.dart' as route;

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
  group('competitions route', () {
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

    test('GET returns list of upcoming competitions', () async {
      when(() => request.method).thenReturn(HttpMethod.get);
      when(() => request.uri).thenReturn(Uri.parse('http://localhost/competitions'));

      final row = _MockResultRow();
      when(() => row.toColumnMap()).thenReturn({
        'id': 'comp-1',
        'title': 'Hamburg Qualifier',
        'location': 'Hamburg Gym',
        'sport_subtype': 'Modern',
        'status': 'upcoming',
        'start_date': DateTime(2026, 6, 15).toUtc().toIso8601String(),
      });
      final fakeResult = FakeResult([row]);

      when(() => connection.execute(any(), parameters: any(named: 'parameters')))
          .thenAnswer((_) async => fakeResult);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json() as List;
      expect(body.length, equals(1));
      expect(body[0]['title'], equals('Hamburg Qualifier'));
    });
  });
}
