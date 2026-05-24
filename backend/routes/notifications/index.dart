import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final userId = context.request.uri.queryParameters['userId'];
      if (userId == null) {
        return Response(statusCode: 400, body: 'Missing userId parameter');
      }
      final list = await DbHelper.getNotifications(userId);
      return Response.json(body: list);
    case HttpMethod.post:
      final body = await context.request.json() as Map<String, dynamic>;
      final result = await DbHelper.createNotification(body);
      return Response.json(statusCode: 201, body: result);
    default:
      return Response(statusCode: 405);
  }
}
