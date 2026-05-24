import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.post) {
    final body = await context.request.json() as Map<String, dynamic>;
    final userId = body['userId'] as String?;
    if (userId == null) {
      return Response(statusCode: 400, body: 'Missing userId in body');
    }
    final success = await DbHelper.registerAthlete(id, userId);
    return Response.json(body: {'success': success});
  }
  return Response(statusCode: 405);
}
