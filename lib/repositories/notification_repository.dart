import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_notification.dart';
import '../utils/mock_safety.dart';
import '../utils/api_client.dart';

class NotificationRepository {
  final dynamic _client;
  final ApiClient _api;

  // Static mock cache to persist state across operations as fallback
  static final List<SystemNotification> _mockNotifications = [];

  NotificationRepository(dynamic client, {ApiClient? api})
      : _client = client,
        _api = api ?? ApiClient();

  dynamic get client => _client;

  bool get _useMockFallback => MockSafety.isMockAllowed;

  Future<List<SystemNotification>> getNotifications(String userId) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('notifications').select().eq('user_id', userId).order('created_at', ascending: false);
        final list = (response as List).map((data) => SystemNotification.fromJson(data as Map<String, dynamic>)).toList();
        _mockNotifications.removeWhere((n) => n.userId == userId);
        _mockNotifications.addAll(list);
        return list;
      } catch (_) {
        return _mockNotifications.where((n) => n.userId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    }
    try {
      final response = await _api.get('/notifications', queryParameters: {'userId': userId});
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List)
            .map(
              (data) => SystemNotification.fromJson(data as Map<String, dynamic>),
            )
            .toList();

        _mockNotifications.removeWhere((n) => n.userId == userId);
        _mockNotifications.addAll(list);
        return list;
      }
      throw Exception('Failed to fetch notifications: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      return _mockNotifications.where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Future<SystemNotification?> createNotification(
    SystemNotification notification,
  ) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('notifications').insert(notification.toJson()).select().single();
        final created = SystemNotification.fromJson(response as Map<String, dynamic>);
        _syncToMock(created);
        return created;
      } catch (_) {
        _syncToMock(notification);
        return notification;
      }
    }
    try {
      final response = await _api.post('/notifications', body: notification.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = SystemNotification.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncToMock(created);
        return created;
      }
      throw Exception('Failed to create notification: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _syncToMock(notification);
      return notification;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_useMockFallback && _client != null) {
      try {
        await _client.from('notifications').update({'is_read': true}).eq('id', notificationId);
        final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
        if (idx != -1) {
          _mockNotifications[idx] = _mockNotifications[idx].copyWith(isRead: true);
        }
        return;
      } catch (_) {
        final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
        if (idx != -1) {
          _mockNotifications[idx] = _mockNotifications[idx].copyWith(isRead: true);
        }
        return;
      }
    }
    try {
      final response = await _api.put('/notifications/$notificationId/read');
      if (response.statusCode == 200) {
        final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
        if (idx != -1) {
          _mockNotifications[idx] = _mockNotifications[idx].copyWith(
            isRead: true,
          );
        }
        return;
      }
      throw Exception('Failed to mark notification as read: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _mockNotifications[idx] = _mockNotifications[idx].copyWith(
          isRead: true,
        );
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
