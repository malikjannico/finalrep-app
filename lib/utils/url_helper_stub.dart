import 'package:flutter/material.dart';
import '../providers/competition_provider.dart';

void updateWebUrl(String path, [Map<String, String>? queryParams]) {
  // No-op on non-web platforms
}

class WebUrlObserver extends NavigatorObserver {
  final CompetitionProvider provider;
  WebUrlObserver(this.provider);
}

class UrlHelper {
  static void initialize() {
    // No-op on non-web platforms
  }

  static Uri get initialUri => Uri.parse('/');
}
