import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/system_notification.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';

void main() {
  group('System Notification Model Tests', () {
    test('SystemNotification.fromJson parses fields correctly', () {
      final json = {
        'id': 'notif-123',
        'user_id': 'user-abc',
        'title': 'Test Title',
        'message': 'Test Message',
        'category': 'registration',
        'is_read': true,
        'created_at': '2026-05-23T12:00:00.000Z',
      };

      final notif = SystemNotification.fromJson(json);

      expect(notif.id, 'notif-123');
      expect(notif.userId, 'user-abc');
      expect(notif.title, 'Test Title');
      expect(notif.message, 'Test Message');
      expect(notif.category, 'registration');
      expect(notif.isRead, true);
      expect(notif.createdAt, isNotNull);
    });

    test('SystemNotification.toJson encodes properly', () {
      final notif = SystemNotification(
        id: 'notif-456',
        userId: 'user-xyz',
        title: 'Title 2',
        message: 'Message 2',
        category: 'payments',
        isRead: false,
        createdAt: DateTime.utc(2026, 5, 23, 14, 0, 0),
      );

      final json = notif.toJson();

      expect(json['id'], 'notif-456');
      expect(json['user_id'], 'user-xyz');
      expect(json['title'], 'Title 2');
      expect(json['message'], 'Message 2');
      expect(json['category'], 'payments');
      expect(json['is_read'], false);
      expect(json['created_at'], '2026-05-23T14:00:00.000Z');
    });

    test('SystemNotification copyWith updates fields', () {
      final notif = SystemNotification(
        id: 'notif-abc',
        userId: 'user-xyz',
        title: 'Original Title',
        message: 'Original Message',
        category: 'schedule',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final updated = notif.copyWith(isRead: true, title: 'New Title');

      expect(updated.id, 'notif-abc');
      expect(updated.title, 'New Title');
      expect(updated.isRead, true);
    });
  });

  group('NotificationRepository Fallback Tests', () {
    test(
      'NotificationRepository works as an in-memory database fallback when client is null',
      () async {
        // Create repository with null client
        final repo = NotificationRepository(null);
        final userId = 'fallback-user-123';

        // 1. Initial notifications list should be empty
        final initialList = await repo.getNotifications(userId);
        expect(initialList, isEmpty);

        // 2. Create notification
        final notif = SystemNotification(
          id: 'notif-fallback-1',
          userId: userId,
          title: 'Local Alert',
          message: 'This is a mock notification.',
          category: 'permissions',
          isRead: false,
          createdAt: DateTime.now(),
        );

        final created = await repo.createNotification(notif);
        expect(created, isNotNull);
        expect(created!.id, 'notif-fallback-1');

        // 3. Retrieve notifications list
        final fetchedList = await repo.getNotifications(userId);
        expect(fetchedList.length, 1);
        expect(fetchedList.first.id, 'notif-fallback-1');
        expect(fetchedList.first.isRead, false);

        // 4. Mark notification as read
        await repo.markAsRead('notif-fallback-1');

        // 5. Verify status was updated in cache
        final updatedList = await repo.getNotifications(userId);
        expect(updatedList.length, 1);
        expect(updatedList.first.isRead, true);
      },
    );
  });
}
