import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.put) {
    final result = await DbHelper.rejectPermissionApplication(id);
    if (result == null) {
      return Response(statusCode: 404, body: 'Permission application not found');
    }
    return Response.json(body: result);
  }
  return Response(statusCode: 405);
}
