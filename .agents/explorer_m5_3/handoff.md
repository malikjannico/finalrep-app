# Handoff Report: System Notifications Exploration

This report outlines the proposed strategy for integrating system notifications and persisting category settings in the FinalRep application.

## 1. Observation

During our codebase exploration, we made the following direct observations:

* **SystemNotification Model**: In `lib/models/system_notification.dart`, the fields are:
  ```dart
  class SystemNotification {
    final String id;
    final String userId;
    final String title;
    final String message;
    final String category; // registration, permissions, payments, schedule, flights
    final bool isRead;
    final DateTime createdAt;
  ```
* **NotificationRepository**: In `lib/repositories/notification_repository.dart`, the CRUD actions are:
  ```dart
  Future<List<SystemNotification>> getNotifications(String userId) async { ... }
  Future<SystemNotification?> createNotification(SystemNotification notification) async { ... }
  Future<void> markAsRead(String notificationId) async { ... }
  ```
* **Preferences local-only state**: In `lib/views/notifications_page.dart` (lines 24-30), switches are managed locally in state without persistence:
  ```dart
  final Map<String, bool> _enabledAlerts = {
    'registration': true,
    'permissions': true,
    'payments': true,
    'schedule': true,
    'flights': true,
  };
  ```
* **Admin permissions workflow**: In `lib/providers/auth_provider.dart` (lines 380-424), approvals/rejections promote permissions locally and call the DB repository but do not create notification items:
  ```dart
  Future<PermissionApplication?> approvePermissionApplication(String applicationId) async { ... }
  Future<PermissionApplication?> rejectPermissionApplication(String applicationId) async { ... }
  ```
* **Competition event stubs**:
  * Flight balancing occurs in `CompetitionProvider.balanceFlights` (lines 947-970) using:
    ```dart
    await _repository.createFlight(flight);
    ```
    without notifying assigned athletes.
  * Schedule publishing is a dummy stub in `CompetitionProvider.publishSchedule` (lines 982-984):
    ```dart
    Future<void> publishSchedule(String competitionId, {bool isPublic = true}) async {
      notifyListeners();
    }
    ```
  * Athlete registration is currently non-operational (represented by a dummy SnackBar in `CompetitionDetailPage` line 278).

---

## 2. Logic Chain

1. Since `Profiles` are stored in the database and retrieved via `ProfileRepository.getProfile`/`updateProfile` (using `lib/models/profile.dart`), introducing a new field `notificationPreferences` (`Map<String, bool>`) to the `Profile` model and adding a corresponding `notification_preferences` column (`jsonb` in postgres) will allow settings to be persisted seamlessly whenever a profile updates.
2. In `lib/views/notifications_page.dart`, binding the `SwitchListTile` components to `AuthProvider` instead of the local state allows the user to mutate database-persisted preferences.
3. System notifications should be saved to the database regardless of the user's current settings so that notification history is preserved; settings can then filter notifications during retrieval/display in `NotificationsPage` using:
   `_notifications.where((n) => enabledAlerts[n.category] ?? true).toList()`.
4. Triggering notifications requires injecting `NotificationRepository` into `AuthProvider` and `CompetitionProvider`.
5. For permission updates: injecting a trigger inside the resolve application methods in `AuthProvider` guarantees that users are immediately notified when an admin approves or rejects their role requests.
6. For flight listings: inside `CompetitionProvider.balanceFlights`, looping over the assigned athlete IDs within each balanced flight allows sending a notification with category `'flights'` to every athlete.
7. For schedule releases: implementing a database/provider publish method in `CompetitionProvider.publishSchedule` that fetches registered athlete IDs for the meet and sends them schedule release notifications guarantees they are alerted.
8. For registration/payments: introducing a concrete `registerAthlete` method in `CompetitionProvider` allows triggering a `'registration'` notification, plus a `'payments'` notification if the competition details show `requiresFees == true`.

---

## 3. Caveats

* **Assumptions**: We assume the existence of `meet_registrations` table in Postgres based on references in `ProfileRepository` (line 145), and that it stores athlete registrations. If this table schema changes, the exact insert arguments in `CompetitionRepository.registerAthlete` will need adjustment.
* **Database Migration**: A SQL migration script (shown in `analysis.md`) needs to be executed on Supabase to add the `notification_preferences` column to the `profiles` table.

---

## 4. Conclusion

A comprehensive and non-breaking strategy has been successfully formulated. By:
1. Extending the `Profile` model and Supabase table with a `notification_preferences` field.
2. Refactoring `NotificationsPage` settings to bind to `AuthProvider.updateNotificationPreference`.
3. Injecting `NotificationRepository` and trigger logic into `AuthProvider` and `CompetitionProvider` methods.

We can enable persistent preferences and fully automated notification triggering across all five business categories.

---

## 5. Verification Method

To independently verify this strategy:
1. Inspect the detailed proposals, schemas, and code signatures inside the technical report at:
   `/.agents/explorer_m5_3/analysis.md`
2. Run the existing test suite:
   ```bash
   flutter test
   ```
   (Verify that all tests pass, validating that no existing models or provider APIs are broken).
