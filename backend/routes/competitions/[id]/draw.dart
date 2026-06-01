import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.post) {
    final success = await DbHelper.runRandomDraw(id);
    return Response.json(body: {'success': success});
  }
  return Response(statusCode: 405);
}
