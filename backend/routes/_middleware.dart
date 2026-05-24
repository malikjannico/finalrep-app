import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/db_connection.dart';

Handler middleware(Handler handler) {
  return (context) async {
    try {
      final conn = await DbConnection.connection;
      final response = await handler(
        context.provide<Connection>(() => conn),
      );
      return response;
    } catch (e) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'Database connection failed: $e'},
      );
    }
  };
}
