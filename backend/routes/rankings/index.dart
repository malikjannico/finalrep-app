import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      try {
        final list = await DbHelper.getMeetResults();
        return Response.json(body: list);
      } catch (e) {
        return Response.json(
          statusCode: 500,
          body: {'error': e.toString()},
        );
      }
    default:
      return Response(statusCode: 405);
  }
}
