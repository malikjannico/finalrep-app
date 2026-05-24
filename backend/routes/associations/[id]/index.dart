import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final assoc = await DbHelper.getAssociationById(id);
      if (assoc == null) {
        return Response(statusCode: 404, body: 'Association not found');
      }
      return Response.json(body: assoc);
    case HttpMethod.put:
      final body = await context.request.json() as Map<String, dynamic>;
      body['id'] = id;
      final result = await DbHelper.updateAssociation(body);
      return Response.json(body: result);
    default:
      return Response(statusCode: 405);
  }
}
