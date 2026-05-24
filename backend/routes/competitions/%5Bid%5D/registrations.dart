import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.get) {
    final list = await DbHelper.getRegisteredAthleteIds(id);
    return Response.json(body: list);
  }
  return Response(statusCode: 405);
}
