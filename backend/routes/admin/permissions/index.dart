import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final list = await DbHelper.getPermissionApplications();
      return Response.json(body: list);
    case HttpMethod.post:
      final body = await context.request.json() as Map<String, dynamic>;
      final result = await DbHelper.applyForPermissions(body);
      return Response.json(statusCode: 201, body: result);
    default:
      return Response(statusCode: 405);
  }
}
