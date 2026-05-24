import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.put) {
    return Response(statusCode: 405);
  }
  final newOwnerId = context.request.uri.queryParameters['newOwnerId'];
  if (newOwnerId == null) {
    return Response(statusCode: 400, body: 'Missing newOwnerId parameter');
  }
  final result = await DbHelper.transferAssociationOwnership(id, newOwnerId);
  if (result == null) {
    return Response(statusCode: 404, body: 'Association not found');
  }
  return Response.json(body: result);
}
