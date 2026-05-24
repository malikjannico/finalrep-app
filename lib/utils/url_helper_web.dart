import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../providers/competition_provider.dart';

void updateWebUrl(String path, [Map<String, String>? queryParams]) {
  final uri = Uri(
    path: path,
    queryParameters: (queryParams != null && queryParams.isNotEmpty)
        ? queryParams
        : null,
  );
  // Use HTML5 history API replaceState to update the URL cleanly and prevent duplicate history stacks
  html.window.history.replaceState(null, '', uri.toString());
}

class WebUrlObserver extends NavigatorObserver {
  final CompetitionProvider provider;
  bool _isInitial = true;

  WebUrlObserver(this.provider);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_isInitial) {
      _isInitial = false;
      return;
    }
    _updateUrl(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateUrl(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateUrl(newRoute);
    }
  }

  void _updateUrl(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null) {
      if (name == '/') {
        final Map<String, String> params = {};
        if (provider.query.isNotEmpty) {
          params['q'] = provider.query;
        }
        params['scope'] = provider.searchScope.name;
        updateWebUrl('/', params);
      } else {
        updateWebUrl(name);
      }
    } else {
      final Map<String, String> params = {};
      if (provider.query.isNotEmpty) {
        params['q'] = provider.query;
      }
      params['scope'] = provider.searchScope.name;
      updateWebUrl('/', params);
    }
  }
}

class UrlHelper {
  static Uri? _initialUri;

  static void initialize() {
    _initialUri ??= Uri.base;
  }

  static Uri get initialUri => _initialUri ?? Uri.parse('/');
}
