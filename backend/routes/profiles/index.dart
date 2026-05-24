import 'package:dart_frog/dart_frog.dart';
import 'package:backend/db_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final params = context.request.uri.queryParameters;
      
      // 1. Get by username
      if (params.containsKey('username')) {
        final profile = await DbHelper.getProfileByUsername(params['username']!);
        if (profile == null) return Response(statusCode: 404, body: 'Profile not found');
        return Response.json(body: profile);
      }

      // 2. Get by email
      if (params.containsKey('email')) {
        final profile = await DbHelper.getProfileByEmail(params['email']!);
        if (profile == null) return Response(statusCode: 404, body: 'Profile not found');
        return Response.json(body: profile);
      }

      // 3. Search profiles
      if (params.containsKey('search')) {
        final list = await DbHelper.searchProfiles(params['search']!);
        return Response.json(body: list);
      }

      // 4. User sub-collections (meets, records, rankings)
      if (params.containsKey('userId') && params.containsKey('type')) {
        final userId = params['userId']!;
        final type = params['type']!;
        
        switch (type) {
          case 'upcoming':
            final list = await DbHelper.getUserUpcomingMeets(userId);
            return Response.json(body: list);
          case 'completed':
            final list = await DbHelper.getUserCompletedMeets(userId);
            return Response.json(body: list);
          case 'rankings':
            final list = await DbHelper.getUserHighestRankings(userId);
            return Response.json(body: list);
          case 'records':
            final list = await DbHelper.getUserPersonalRecords(userId);
            return Response.json(body: list);
          default:
            return Response(statusCode: 400, body: 'Invalid type parameter');
        }
      }

      return Response(statusCode: 400, body: 'Missing query parameters');

    case HttpMethod.post:
      final body = await context.request.json() as Map<String, dynamic>;
      final result = await DbHelper.createOrUpdateProfile(body);
      return Response.json(body: result);

    default:
      return Response(statusCode: 405);
  }
}
