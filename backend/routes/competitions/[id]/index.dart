import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.get) {
    final comp = await DbHelper.getCompetitionById(id);
    if (comp == null) {
      return Response(statusCode: 404, body: 'Competition not found');
    }
    return Response.json(body: comp);
  }
  return Response(statusCode: 405);
}
