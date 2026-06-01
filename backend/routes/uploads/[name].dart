import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context, String name) async {
  if (context.request.method == HttpMethod.get) {
    // Sanitize the file name to prevent directory traversal
    final sanitizedName = name.replaceAll(RegExp(r'\.\./'), '');
    final file = File('uploads/$sanitizedName');
    if (!file.existsSync()) {
      return Response(statusCode: 404, body: 'File not found');
    }

    final bytes = await file.readAsBytes();
    String contentType = 'application/octet-stream';
    final lowerName = sanitizedName.toLowerCase();
    if (lowerName.endsWith('.png')) {
      contentType = 'image/png';
    } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    } else if (lowerName.endsWith('.svg')) {
      contentType = 'image/svg+xml';
    } else if (lowerName.endsWith('.gif')) {
      contentType = 'image/gif';
    } else if (lowerName.endsWith('.webp')) {
      contentType = 'image/webp';
    }

    return Response.bytes(
      body: bytes,
      headers: {
        'Content-Type': contentType,
      },
    );
  }
  return Response(statusCode: 405);
}
