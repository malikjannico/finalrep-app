import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/notification_repository.dart';
import '../models/system_notification.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationRepository _repository;
  List<SystemNotification> _notifications = [];
  bool _isLoading = true;

  // Category filters toggles (what to show)
  final Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _repository = Provider.of<AuthProvider>(context, listen: false).notificationRepository;
    _loadNotifications();
  }


  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUserProfile?.id ?? '';

    List<SystemNotification> list = [];
    if (userId.isNotEmpty) {
      list = await _repository.getNotifications(userId);
    }

    if (list.isEmpty) {
      // Fallback notifications seeding
      list = [
        SystemNotification(
          id: 'fallback-1',
          userId: userId,
          title: 'Registration Approved',
          message: 'Your application to Hamburg Meet was accepted.',
          category: 'registration',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isRead: false,
        ),
        SystemNotification(
          id: 'fallback-2',
          userId: userId,
          title: 'Payment Reminder',
          message: 'Please pay the fee of 25.00 EUR by 2026-06-01.',
          category: 'payments',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ];
    }

    setState(() {
      _notifications = list;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(SystemNotification notification) async {
    if (notification.isRead) return;
    await _repository.markAsRead(notification.id);
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        _notifications[index] = notification.copyWith(isRead: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final enabledAlerts =
        authProvider.currentUserProfile?.notificationPreferences ??
        const {
          'registration': true,
          'permissions': true,
          'payments': true,
          'schedule': true,
          'flights': true,
        };

    // 1. Filter notifications based on alert settings (if alert is disabled, we do not show those notifications)
    final allowedNotifications = _notifications.where((n) {
      return enabledAlerts[n.category] ?? true;
    }).toList();

    // 2. Filter notifications based on selected category chips (if any are selected)
    final filteredNotifications = allowedNotifications.where((n) {
      if (_selectedCategories.isEmpty) return true;
      return _selectedCategories.contains(n.category);
    }).toList();

    final categories = [
      'registration',
      'permissions',
      'payments',
      'schedule',
      'flights',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Alert Settings Section (Collapsible)
                ExpansionTile(
                  key: const Key('alert_settings_tile'),
                  title: const Text('Alert Settings'),
                  leading: const Icon(Icons.settings),
                  children: categories.map((category) {
                    return SwitchListTile(
                      key: Key('switch_$category'),
                      title: Text(
                        category[0].toUpperCase() + category.substring(1),
                      ),
                      value: enabledAlerts[category] ?? true,
                      onChanged: authProvider.currentUserProfile == null
                          ? null
                          : (val) {
                              authProvider.updateNotificationPreference(
                                category,
                                val,
                              );
                            },
                    );
                  }).toList(),
                ),

                // Category Filter Chips Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) {
                        final isSelected = _selectedCategories.contains(
                          category,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            key: Key('chip_$category'),
                            label: Text(
                              category[0].toUpperCase() + category.substring(1),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const Divider(),

                // Notifications List Section
                Expanded(
                  child: filteredNotifications.isEmpty
                      ? ListView(
                          key: const Key('notifications_list'),
                          children: const [
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('No notifications found.'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          key: const Key('notifications_list'),
                          itemCount: filteredNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = filteredNotifications[index];
                            return ListTile(
                              key: Key('notification_item_${notification.id}'),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification.message),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Category: ${notification.category} • ${notification.createdAt.toString().split('.')[0]}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              leading: Icon(
                                notification.isRead
                                    ? Icons.mark_email_read
                                    : Icons.mark_email_unread,
                                color: notification.isRead
                                    ? Colors.grey
                                    : Colors.blue,
                              ),
                              onTap: () => _markAsRead(notification),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
