import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final config = await DbHelper.loadSportsConfig();
      if (config == null) {
        return Response(statusCode: 404, body: 'Sport config not found');
      }
      return Response.json(body: config['config']);
    case HttpMethod.post:
      final body = await context.request.json() as Map<String, dynamic>;
      final success = await DbHelper.saveSportsConfig(body);
      return Response.json(body: {'success': success});
    default:
      return Response(statusCode: 405);
  }
}
