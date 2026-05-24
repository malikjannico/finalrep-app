import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/db_connection.dart';

Handler middleware(Handler handler) {
  return (context) async {
    // 1. Handle CORS Preflight OPTIONS requests
    if (context.request.method == HttpMethod.options) {
      return Response(
        statusCode: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
        },
      );
    }

    try {
      final conn = await DbConnection.connection;
      final response = await handler(
        context.provide<Connection>(() => conn),
      );

      // 2. Attach CORS headers to successful responses
      return response.copyWith(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
        },
      );
    } catch (e) {
      return Response.json(
        statusCode: 500,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
        },
        body: {'error': 'Database connection failed: $e'},
      );
    }
  };
}
