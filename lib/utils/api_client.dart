import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'mock_safety.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  String get baseUrl {
    final url = MockSafety.apiBaseUrl;
    // Strip trailing slash if any
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<Map<String, String>> get _headers async {
    final headers = {'Content-Type': 'application/json'};
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (_) {}
    return headers;
  }

  Future<http.Response> get(String path, {Map<String, String>? queryParameters}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
    return _client.get(uri, headers: await _headers);
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    return _client.post(uri, headers: await _headers, body: body != null ? json.encode(body) : null);
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    return _client.put(uri, headers: await _headers, body: body != null ? json.encode(body) : null);
  }

  Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return _client.delete(uri, headers: await _headers);
  }

  Future<http.StreamedResponse> uploadMultipart(String path, List<int> bytes, String fileName) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    
    // Attach auth header
    final authHeaders = await _headers;
    request.headers.addAll(authHeaders);
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );
    
    return _client.send(request);
  }
}
