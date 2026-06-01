import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.get) {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuidRegex.hasMatch(id)) {
      return Response(statusCode: 404, body: 'Profile not found');
    }
    final profile = await DbHelper.getProfileById(id);
    if (profile == null) {
      return Response(statusCode: 404, body: 'Profile not found');
    }
    return Response.json(body: profile);
  }
  return Response(statusCode: 405);
}

