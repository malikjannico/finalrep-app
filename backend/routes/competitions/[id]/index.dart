import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.get) {
    final comp = await DbHelper.getCompetitionById(id);
    if (comp == null) {
      return Response(statusCode: 404, body: 'Competition not found');
    }
    return Response.json(body: comp);
  } else if (context.request.method == HttpMethod.put) {
    final payload = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    payload['id'] = id;
    try {
      final updated = await DbHelper.updateCompetition(payload);
      return Response.json(body: updated);
    } catch (e) {
      return Response(statusCode: 500, body: e.toString());
    }
  }
  return Response(statusCode: 405);
}
