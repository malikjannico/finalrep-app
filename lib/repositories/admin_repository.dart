import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permission_application.dart';
import '../models/admin_config.dart';
import '../utils/mock_safety.dart';
import '../utils/api_client.dart';

class AdminRepository {
  final dynamic _client;
  final ApiClient _api;

  // Static mock cache to persist state across operations as fallback
  static final List<PermissionApplication> _mockApplications = [];
  static SportConfig _mockSportConfig = SportConfig(
    sports: [
      SportDefinition(
        name: 'Streetlifting',
        description: 'Standard bodyweight with added load',
      ),
    ],
    formats: [
      FormatDefinition(
        sportName: 'Streetlifting',
        name: 'Modern',
        description: '4 exercises: Muscle Up, Pull Up, Dip, Squat',
      ),
      FormatDefinition(
        sportName: 'Streetlifting',
        name: 'Classic',
        description: '2 exercises: Pull Up, Dip',
      ),
    ],
    disciplines: [
      DisciplineDefinition(
        name: 'Muscle Up',
        description: 'Standard muscle up',
      ),
      DisciplineDefinition(name: 'Pull Up', description: 'Weighted pull up'),
      DisciplineDefinition(name: 'Dip', description: 'Weighted dip'),
      DisciplineDefinition(name: 'Squat', description: 'Weighted back squat'),
    ],
    links: [
      FormatDisciplineLink(
        sportName: 'Streetlifting',
        formatName: 'Modern',
        disciplineName: 'Muscle Up',
      ),
      FormatDisciplineLink(
        sportName: 'Streetlifting',
        formatName: 'Modern',
        disciplineName: 'Pull Up',
      ),
      FormatDisciplineLink(
        sportName: 'Streetlifting',
        formatName: 'Modern',
        disciplineName: 'Dip',
      ),
      FormatDisciplineLink(
        sportName: 'Streetlifting',
        formatName: 'Modern',
        disciplineName: 'Squat',
      ),
      FormatDisciplineLink(
        sportName: 'Streetlifting',
        formatName: 'Classic',
        disciplineName: 'Pull Up',
      ),
      FormatDisciplineLink(
        sportName: 'Streetlifting',
        formatName: 'Classic',
        disciplineName: 'Dip',
      ),
    ],
  );

  AdminRepository(dynamic client, {ApiClient? api})
      : _client = client,
        _api = api ?? ApiClient();

  dynamic get client => _client;

  bool get _useMockFallback => MockSafety.isMockAllowed;

  /// Apply for creation permissions.
  Future<PermissionApplication?> applyForPermissions(
    String userId,
    String type,
    String reason,
  ) async {
    final newApp = PermissionApplication(
      id: 'app-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: type,
      reason: reason,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('permission_applications').insert(newApp.toJson()).select().single();
        final app = PermissionApplication.fromJson(response as Map<String, dynamic>);
        _syncApplicationToMock(app);
        return app;
      } catch (_) {
        _mockApplications.add(newApp);
        return newApp;
      }
    }
    try {
      final response = await _api.post('/admin/permissions', body: newApp.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final app = PermissionApplication.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncApplicationToMock(app);
        return app;
      }
      throw Exception('Failed to apply for permissions: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockApplications.add(newApp);
      return newApp;
    }
  }

  /// Get list of all permission applications.
  Future<List<PermissionApplication>> getPermissionApplications() async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('permission_applications').select();
        final list = (response as List).map((e) => PermissionApplication.fromJson(e as Map<String, dynamic>)).toList();
        _mockApplications.clear();
        _mockApplications.addAll(list);
        return list;
      } catch (_) {
        return List.from(_mockApplications);
      }
    }
    try {
      final response = await _api.get('/admin/permissions');
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List)
            .map((e) => PermissionApplication.fromJson(e as Map<String, dynamic>))
            .toList();
        _mockApplications.clear();
        _mockApplications.addAll(list);
        return list;
      }
      throw Exception('Failed to get permission applications: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      return List.from(_mockApplications);
    }
  }

  /// Approve permission application.
  Future<PermissionApplication?> approvePermissionApplication(
    String applicationId,
  ) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('permission_applications').update({'status': 'approved'}).eq('id', applicationId).select().single();
        final app = PermissionApplication.fromJson(response as Map<String, dynamic>);
        _syncApplicationToMock(app);
        return app;
      } catch (_) {
        final idx = _mockApplications.indexWhere((element) => element.id == applicationId);
        if (idx != -1) {
          final updated = _mockApplications[idx].copyWith(status: 'approved');
          _mockApplications[idx] = updated;
          return updated;
        }
        return null;
      }
    }
    try {
      final response = await _api.put('/admin/permissions/$applicationId/approve');
      if (response.statusCode == 200) {
        final app = PermissionApplication.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncApplicationToMock(app);
        return app;
      }
      throw Exception('Failed to approve application: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      final idx = _mockApplications.indexWhere(
        (element) => element.id == applicationId,
      );
      if (idx != -1) {
        final updated = _mockApplications[idx].copyWith(status: 'approved');
        _mockApplications[idx] = updated;
        return updated;
      }
      return null;
    }
  }

  /// Reject permission application.
  Future<PermissionApplication?> rejectPermissionApplication(
    String applicationId,
  ) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('permission_applications').update({'status': 'rejected'}).eq('id', applicationId).select().single();
        final app = PermissionApplication.fromJson(response as Map<String, dynamic>);
        _syncApplicationToMock(app);
        return app;
      } catch (_) {
        final idx = _mockApplications.indexWhere((element) => element.id == applicationId);
        if (idx != -1) {
          final updated = _mockApplications[idx].copyWith(status: 'rejected');
          _mockApplications[idx] = updated;
          return updated;
        }
        return null;
      }
    }
    try {
      final response = await _api.put('/admin/permissions/$applicationId/reject');
      if (response.statusCode == 200) {
        final app = PermissionApplication.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncApplicationToMock(app);
        return app;
      }
      throw Exception('Failed to reject application: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      final idx = _mockApplications.indexWhere(
        (element) => element.id == applicationId,
      );
      if (idx != -1) {
        final updated = _mockApplications[idx].copyWith(status: 'rejected');
        _mockApplications[idx] = updated;
        return updated;
      }
      return null;
    }
  }

  /// Load sport config.
  Future<SportConfig> loadSportsConfig() async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('sports_config').select().maybeSingle();
        if (response == null) {
          if (!_useMockFallback) {
            throw StateError('Sport configuration not found in database.');
          }
          return _mockSportConfig;
        }
        return SportConfig.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return _mockSportConfig;
      }
    }
    try {
      final response = await _api.get('/admin/sport-config');
      if (response.statusCode == 200) {
        final config = SportConfig.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _mockSportConfig = config;
        return config;
      }
      if (!_useMockFallback) {
        throw StateError('Sport configuration not found in database.');
      }
      return _mockSportConfig;
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      return _mockSportConfig;
    }
  }

  /// Save sport config.
  Future<bool> saveSportsConfig(SportConfig config) async {
    if (_useMockFallback && _client != null) {
      try {
        await _client.from('sports_config').upsert(config.toJson());
        _mockSportConfig = config;
        return true;
      } catch (_) {
        _mockSportConfig = config;
        return true;
      }
    }
    try {
      final response = await _api.post('/admin/sport-config', body: config.toJson());
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        _mockSportConfig = config;
        return body['success'] == true;
      }
      throw Exception('Failed to save sports config: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockSportConfig = config;
      return true;
    }
  }

  void _syncApplicationToMock(PermissionApplication app) {
    final idx = _mockApplications.indexWhere((element) => element.id == app.id);
    if (idx != -1) {
      _mockApplications[idx] = app;
    } else {
      _mockApplications.add(app);
    }
  }
}
