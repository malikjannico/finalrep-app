import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permission_application.dart';
import '../models/admin_config.dart';

class AdminRepository {
  final SupabaseClient? _client;

  // Static mock cache to persist state across operations as fallback
  static final List<PermissionApplication> _mockApplications = [];
  static SportConfig _mockSportConfig = SportConfig(
    sports: [
      SportDefinition(name: 'Streetlifting', description: 'Standard bodyweight with added load'),
    ],
    formats: [
      FormatDefinition(sportName: 'Streetlifting', name: 'Modern', description: '4 exercises: Muscle Up, Pull Up, Dip, Squat'),
      FormatDefinition(sportName: 'Streetlifting', name: 'Classic', description: '2 exercises: Pull Up, Dip'),
    ],
    disciplines: [
      DisciplineDefinition(name: 'Muscle Up', description: 'Standard muscle up'),
      DisciplineDefinition(name: 'Pull Up', description: 'Weighted pull up'),
      DisciplineDefinition(name: 'Dip', description: 'Weighted dip'),
      DisciplineDefinition(name: 'Squat', description: 'Weighted back squat'),
    ],
    links: [
      FormatDisciplineLink(sportName: 'Streetlifting', formatName: 'Modern', disciplineName: 'Muscle Up'),
      FormatDisciplineLink(sportName: 'Streetlifting', formatName: 'Modern', disciplineName: 'Pull Up'),
      FormatDisciplineLink(sportName: 'Streetlifting', formatName: 'Modern', disciplineName: 'Dip'),
      FormatDisciplineLink(sportName: 'Streetlifting', formatName: 'Modern', disciplineName: 'Squat'),
      FormatDisciplineLink(sportName: 'Streetlifting', formatName: 'Classic', disciplineName: 'Pull Up'),
      FormatDisciplineLink(sportName: 'Streetlifting', formatName: 'Classic', disciplineName: 'Dip'),
    ],
  );

  AdminRepository(this._client);

  SupabaseClient? get client => _client;

  void _logError(String op, Object e, String table) {
    if (e is PostgrestException && e.code == 'PGRST205') {
      debugPrint('[Info] Supabase table "$table" not found. Using local mock fallback for "$op".');
    } else {
      debugPrint('Supabase $op error (using mock fallback): $e');
    }
  }

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

    try {
      final response = await _client!.from('permission_applications').insert(newApp.toJson()).select().single();
      final app = PermissionApplication.fromJson(response);
      _syncApplicationToMock(app);
      return app;
    } catch (e) {
      _logError('applyForPermissions', e, 'permission_applications');
      _mockApplications.add(newApp);
      return newApp;
    }
  }

  /// Get list of all permission applications.
  Future<List<PermissionApplication>> getPermissionApplications() async {
    try {
      final response = await _client!.from('permission_applications').select().order('created_at', ascending: false);
      final list = (response as List).map((e) => PermissionApplication.fromJson(e as Map<String, dynamic>)).toList();
      _mockApplications.clear();
      _mockApplications.addAll(list);
      return list;
    } catch (e) {
      _logError('getPermissionApplications', e, 'permission_applications');
      return List.from(_mockApplications);
    }
  }

  /// Approve permission application.
  Future<PermissionApplication?> approvePermissionApplication(String applicationId) async {
    try {
      final response = await _client!
          .from('permission_applications')
          .update({'status': 'approved'})
          .eq('id', applicationId)
          .select()
          .single();
      final app = PermissionApplication.fromJson(response);
      _syncApplicationToMock(app);
      return app;
    } catch (e) {
      _logError('approvePermissionApplication', e, 'permission_applications');
      final idx = _mockApplications.indexWhere((element) => element.id == applicationId);
      if (idx != -1) {
        final updated = _mockApplications[idx].copyWith(status: 'approved');
        _mockApplications[idx] = updated;
        return updated;
      }
      return null;
    }
  }

  /// Reject permission application.
  Future<PermissionApplication?> rejectPermissionApplication(String applicationId) async {
    try {
      final response = await _client!
          .from('permission_applications')
          .update({'status': 'rejected'})
          .eq('id', applicationId)
          .select()
          .single();
      final app = PermissionApplication.fromJson(response);
      _syncApplicationToMock(app);
      return app;
    } catch (e) {
      _logError('rejectPermissionApplication', e, 'permission_applications');
      final idx = _mockApplications.indexWhere((element) => element.id == applicationId);
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
    try {
      final response = await _client!.from('sport_configs').select().maybeSingle();
      if (response != null) {
        final config = SportConfig.fromJson(response['config'] as Map<String, dynamic>);
        _mockSportConfig = config;
        return config;
      }
      return _mockSportConfig;
    } catch (e) {
      _logError('loadSportsConfig', e, 'sport_configs');
      return _mockSportConfig;
    }
  }

  /// Save sport config.
  Future<bool> saveSportsConfig(SportConfig config) async {
    try {
      // Upsert to sport_configs table
      await _client!.from('sport_configs').upsert({
        'id': 'global_config',
        'config': config.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _mockSportConfig = config;
      return true;
    } catch (e) {
      _logError('saveSportsConfig', e, 'sport_configs');
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
