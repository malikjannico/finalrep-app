import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final associationId = context.request.uri.queryParameters['associationId'];
      if (associationId == null) {
        return Response(statusCode: 400, body: 'Missing associationId parameter');
      }
      final list = await DbHelper.getAthleteGroups(associationId);
      return Response.json(body: list);
    case HttpMethod.post:
      final body = await context.request.json() as Map<String, dynamic>;
      final result = await DbHelper.createAthleteGroup(body);
      return Response.json(statusCode: 201, body: result);
    case HttpMethod.put:
      final body = await context.request.json() as Map<String, dynamic>;
      final result = await DbHelper.updateAthleteGroup(body);
      return Response.json(body: result);
    default:
      return Response(statusCode: 405);
  }
}
