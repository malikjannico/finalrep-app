import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final list = await DbHelper.getAssociationMembers(id);
      return Response.json(body: list);
    case HttpMethod.post:
      final body = await context.request.json() as Map<String, dynamic>;
      final result = await DbHelper.addAssociationMember(body);
      return Response.json(statusCode: 201, body: result);
    case HttpMethod.delete:
      final userId = context.request.uri.queryParameters['userId'];
      if (userId == null) {
        return Response(statusCode: 400, body: 'Missing userId parameter');
      }
      final success = await DbHelper.removeAssociationMember(id, userId);
      return Response.json(body: {'success': success});
    default:
      return Response(statusCode: 405);
  }
}
