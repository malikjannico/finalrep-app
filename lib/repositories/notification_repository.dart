import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_notification.dart';

class NotificationRepository {
  final SupabaseClient? _client;

  // Static mock cache to persist state across operations as fallback
  static final List<SystemNotification> _mockNotifications = [];

  NotificationRepository(this._client);

  SupabaseClient? get client => _client;

  void _logError(String op, Object e, String table) {
    if (e is PostgrestException && e.code == 'PGRST205') {
      debugPrint('[Info] Supabase table "$table" not found. Using local mock fallback for "$op".');
    } else {
      debugPrint('Error $op (using mock fallback): $e');
    }
  }

  Future<List<SystemNotification>> getNotifications(String userId) async {
    try {
      if (_client == null) throw Exception('No client');
      final response = await _client!
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((data) => SystemNotification.fromJson(data as Map<String, dynamic>))
          .toList();
      
      // Sync mock list
      _mockNotifications.removeWhere((n) => n.userId == userId);
      _mockNotifications.addAll(list);
      return list;
    } catch (e) {
      _logError('fetching notifications', e, 'notifications');
      return _mockNotifications.where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Future<SystemNotification?> createNotification(SystemNotification notification) async {
    try {
      if (_client == null) throw Exception('No client');
      final response = await _client!
          .from('notifications')
          .insert(notification.toJson())
          .select()
          .single();
      final created = SystemNotification.fromJson(response);
      _syncToMock(created);
      return created;
    } catch (e) {
      _logError('creating notification', e, 'notifications');
      _syncToMock(notification);
      return notification;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      if (_client == null) throw Exception('No client');
      await _client!
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
          
      // Sync mock list
      final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _mockNotifications[idx] = _mockNotifications[idx].copyWith(isRead: true);
      }
    } catch (e) {
      _logError('marking notification as read', e, 'notifications');
      final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _mockNotifications[idx] = _mockNotifications[idx].copyWith(isRead: true);
      }
    }
  }

  void _syncToMock(SystemNotification notification) {
    final idx = _mockNotifications.indexWhere((n) => n.id == notification.id);
    if (idx != -1) {
      _mockNotifications[idx] = notification;
    } else {
      _mockNotifications.add(notification);
    }
  }
}
