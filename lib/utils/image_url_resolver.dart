import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/competition_provider.dart';

class ImageUrlResolver {
  /// Resolves a relative or absolute image path to a fully qualified URL.
  /// If [path] is relative (starts with `/`), it prepends the backend's baseUrl.
  /// Safely falls back to a default localhost URL in widget test environments.
  static String resolve(BuildContext context, String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) {
      String baseUrl = 'http://localhost:8080';
      try {
        baseUrl = Provider.of<CompetitionProvider>(context, listen: false)
            .competitionRepository
            .baseUrl;
      } catch (_) {}
      return '$baseUrl$path';
    }
    return path;
  }
}
