import 'dart:io';
import 'package:backend/db_connection.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../../routes/profiles/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockConnection extends Mock implements Connection {}
class _MockResult extends Mock implements Result {}
class _MockResultRow extends Mock implements ResultRow {}

void main() {
  group('profiles route', () {
    late _MockRequestContext context;
    late _MockRequest request;
    late _MockConnection connection;
    late _MockResult result;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      connection = _MockConnection();
      result = _MockResult();

      when(() => context.request).thenReturn(request);
      DbConnection.connection = connection;
    });

    test('GET by username returns 404 if profile not found', () async {
      when(() => request.method).thenReturn(HttpMethod.get);
      when(() => request.uri).thenReturn(Uri.parse('http://localhost/profiles?username=missing'));
      when(() => connection.execute(any(), parameters: any(named: 'parameters')))
          .thenAnswer((_) async => result);
      when(() => result.isEmpty).thenReturn(true);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.notFound));
      expect(await response.body(), equals('Profile not found'));
    });

    test('GET by username returns profile JSON if found', () async {
      when(() => request.method).thenReturn(HttpMethod.get);
      when(() => request.uri).thenReturn(Uri.parse('http://localhost/profiles?username=johndoe'));
      when(() => connection.execute(any(), parameters: any(named: 'parameters')))
          .thenAnswer((_) async => result);
      when(() => result.isEmpty).thenReturn(false);

      final row = _MockResultRow();
      when(() => row.toColumnMap()).thenReturn({
        'id': 'user-1',
        'username': 'johndoe',
        'full_name': 'John Doe',
        'email': 'john@example.com',
        'sex': 'male',
      });
      when(() => result.first).thenReturn(row);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['username'], equals('johndoe'));
      expect(body['id'], equals('user-1'));
    });
  });
}
