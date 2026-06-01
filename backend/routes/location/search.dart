import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final q = context.request.uri.queryParameters['q'];
  if (q == null || q.trim().isEmpty) {
    return Response(statusCode: 400, body: 'Missing query parameter "q"');
  }

  final limit = context.request.uri.queryParameters['limit'] ?? '1';
  final addressdetails = context.request.uri.queryParameters['addressdetails'] ?? '0';

  try {
    List<dynamic> results = await _geocodeQuery(q, limit, addressdetails);
    
    // If no results and query contains commas, try stripping the first segment (which could be a custom gym/venue name)
    var currentQuery = q;
    while (results.isEmpty && currentQuery.contains(',')) {
      final parts = currentQuery.split(',');
      if (parts.length <= 1) break;
      
      // Remove first part and join remainder
      currentQuery = parts.skip(1).join(',').trim();
      if (currentQuery.isEmpty) break;
      
      results = await _geocodeQuery(currentQuery, limit, addressdetails);
    }

    return Response.json(body: results);
  } catch (e) {
    return Response(
      statusCode: 500,
      body: 'Location search failed: $e',
    );
  }
}

Future<List<dynamic>> _geocodeQuery(String query, String limit, String addressdetails) async {
  final encoded = Uri.encodeComponent(query);
  final url = Uri.parse(
    'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=$limit&addressdetails=$addressdetails',
  );

  final response = await http.get(
    url,
    headers: {
      'User-Agent': 'FinalRepApp/1.0 (contact: info@finalrep.com)',
      'Accept': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded;
    }
  }
  return [];
}
