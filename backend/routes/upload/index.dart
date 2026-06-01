import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    try {
      final formData = await context.request.formData();
      final file = formData.files['file'];
      if (file == null) {
        return Response(statusCode: 400, body: 'No file uploaded');
      }

      final bytes = await file.readAsBytes();
      final name = file.name;
      final bucket = Platform.environment['STORAGE_BUCKET_NAME'] ?? 'finalrep-app-media-dev';

      // Check if running on GCP Cloud Run
      final isGcp = Platform.environment['K_SERVICE'] != null;

      if (isGcp) {
        try {
          final uri = Uri.parse(
            'https://storage.googleapis.com/upload/storage/v1/b/$bucket/o?uploadType=media&name=avatars/$name',
          );
          
          // Fetch service account token from metadata server
          String? token;
          try {
            final tokenRes = await http.get(
              Uri.parse(
                'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token',
              ),
              headers: {'Metadata-Flavor': 'Google'},
            ).timeout(const Duration(seconds: 2));
            
            if (tokenRes.statusCode == 200) {
              final json = jsonDecode(tokenRes.body) as Map<String, dynamic>;
              token = json['access_token'] as String?;
            }
          } catch (_) {}

          final headers = <String, String>{
            'Content-Type': file.contentType.mimeType,
          };
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }
          
          final uploadRes = await http.post(uri, headers: headers, body: bytes);
          if (uploadRes.statusCode == 200) {
            return Response.json(
              body: {'url': 'https://storage.googleapis.com/$bucket/avatars/$name'},
            );
          }
        } catch (_) {}
      }

      // Local Fallback
      final dir = Directory('uploads');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      
      final savedFile = File('uploads/$name');
      await savedFile.writeAsBytes(bytes);
      return Response.json(body: {'url': '/uploads/$name'});
    } catch (e) {
      return Response(statusCode: 500, body: 'Upload failed: $e');
    }
  } else if (context.request.method == HttpMethod.delete) {
    try {
      final url = context.request.uri.queryParameters['url'];
      if (url == null || url.isEmpty) {
        return Response(statusCode: 400, body: 'No url specified');
      }

      final bucket = Platform.environment['STORAGE_BUCKET_NAME'] ?? 'finalrep-app-media-dev';
      final isGcp = Platform.environment['K_SERVICE'] != null;

      if (isGcp) {
        String objectName = '';
        if (url.contains('storage.googleapis.com/$bucket/')) {
          objectName = url.split('storage.googleapis.com/$bucket/')[1];
        } else if (url.contains('/o/')) {
          final uri = Uri.parse(url);
          objectName = uri.pathSegments.last;
        }

        if (objectName.isNotEmpty) {
          final encodedObject = Uri.encodeComponent(objectName);
          final deleteUri = Uri.parse(
            'https://storage.googleapis.com/storage/v1/b/$bucket/o/$encodedObject',
          );

          String? token;
          try {
            final tokenRes = await http.get(
              Uri.parse(
                'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token',
              ),
              headers: {'Metadata-Flavor': 'Google'},
            ).timeout(const Duration(seconds: 2));
            
            if (tokenRes.statusCode == 200) {
              final json = jsonDecode(tokenRes.body) as Map<String, dynamic>;
              token = json['access_token'] as String?;
            }
          } catch (_) {}

          final headers = <String, String>{};
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }

          final deleteRes = await http.delete(deleteUri, headers: headers);
          if (deleteRes.statusCode == 204 || deleteRes.statusCode == 200) {
            return Response(statusCode: 200, body: 'File deleted successfully');
          }
          return Response(statusCode: deleteRes.statusCode, body: 'Failed to delete from GCS: ${deleteRes.body}');
        }
      }

      // Local Fallback deletion
      String fileName = '';
      if (url.startsWith('/uploads/')) {
        fileName = url.substring('/uploads/'.length);
      } else {
        final uri = Uri.parse(url);
        fileName = uri.pathSegments.last;
      }

      if (fileName.isNotEmpty) {
        final file = File('uploads/$fileName');
        if (file.existsSync()) {
          file.deleteSync();
          return Response(statusCode: 200, body: 'File deleted successfully');
        }
      }
      return Response(statusCode: 404, body: 'File not found');
    } catch (e) {
      return Response(statusCode: 500, body: 'Delete failed: $e');
    }
  } else {
    return Response(statusCode: 405);
  }
}
