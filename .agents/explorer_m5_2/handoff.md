# Handoff Report — explorer_m5_2

## 1. Observation
We explored the FinalRep Flutter application code structure and observed the following:

- **Notification Model and Categories**:
  - In `lib/models/system_notification.dart`, line 6 defines standard categories:
    ```dart
    final String category; // registration, permissions, payments, schedule, flights
    ```

- **Notification Repository**:
  - In `lib/repositories/notification_repository.dart`, line 17 defines how notifications are inserted:
    ```dart
    final response = await _client.from('notifications').insert(notification.toJson()).select().single();
    ```

- **Transient Notification Settings**:
  - In `lib/views/notifications_page.dart` (lines 20-30), the settings switches are stored as transient local state:
    ```dart
    final Map<String, bool> _enabledAlerts = {
      'registration': true,
      'permissions': true,
      'payments': true,
      'schedule': true,
      'flights': true,
    };
    ```
  - When a user changes a switch, it only updates `setState` and is lost when the page is closed.

- **Trigger Points in Providers**:
  - **Permission approvals/rejections**:
    - In `lib/providers/auth_provider.dart` line 380:
      ```dart
      Future<PermissionApplication?> approvePermissionApplication(String applicationId) async {
      ```
    - In `lib/providers/auth_provider.dart` line 411:
      ```dart
      Future<PermissionApplication?> rejectPermissionApplication(String applicationId) async {
      ```
  - **Schedule releases**:
    - In `lib/providers/competition_provider.dart` line 982:
      ```dart
      Future<void> publishSchedule(String competitionId, {bool isPublic = true}) async {
      ```
  - **Flight listings**:
    - In `lib/providers/competition_provider.dart` line 947:
      ```dart
      Future<void> balanceFlights(String competitionId) async {
      ```

- **Athlete registration status**:
  - Athlete registration is stubs-only in `lib/views/competition_detail_page.dart` (lines 298-305) and has no backend implementation in the provider classes.

---

## 2. Logic Chain
- **Persistence Strategy**:
  - Because `_enabledAlerts` is locally managed inside `_NotificationsPageState` in `notifications_page.dart`, settings do not persist across app restarts or user sessions.
  - To make them persistent, we must store them in the database.
  - Extending the `Profile` model with a `Map<String, bool> notificationSettings` serialized to/from a `JSONB` column on the `profiles` table allows settings to be fetched automatically during user login/profile retrieval in `AuthProvider`.
  - When switches are toggled in `NotificationsPage`, they should invoke a method in `AuthProvider` that updates the settings on the user profile in Supabase.

- **Trigger Injection**:
  - Currently, providers (`AuthProvider`, `CompetitionProvider`) do not hold a reference to `NotificationRepository`.
  - By adding `NotificationRepository` as a constructor parameter to these providers and registering the dependency in `main.dart`, the provider classes can execute `createNotification` directly inside their respective workflow methods.
  - To handle athlete registration and payments deadlines, a new method `registerAthlete` should be added in `CompetitionProvider`. It will insert the record in the `meet_registrations` table, and write both a `registration` category notification and a `payments` deadline reminder notification to the database for the registered athlete.

---

## 3. Caveats
- **Local Fallbacks**:
  - Since `shared_preferences` is not included in `pubspec.yaml`, if Supabase database updates fail or the user runs in an offline environment, settings persistence must fall back to in-memory state inside `AuthProvider`.
- **Database RLS Policies**:
  - Because notifications are written client-side by admins (for permissions) or competition creators (for flights and schedules) to target other users' feeds, the `notifications` table RLS configuration must permit authenticated users to insert notification records for other profile IDs.

---

## 4. Conclusion
We have formulated a detailed integration plan to support persistent notification settings and automated system notification triggers. The plan involves:
1. Creating a DB migration to add the `notification_settings` column to the `profiles` table.
2. Modifying `Profile` model serializations to parse this new field.
3. Injecting `NotificationRepository` into `AuthProvider` and `CompetitionProvider` constructors.
4. Implementing trigger logics within the target provider actions.
5. Binding UI controls on the notifications screen to persistent profile state.

All technical specifications and code templates are written to `analysis.md`.

---

## 5. Verification Method
1. **Static Analysis**: Run `flutter analyze` to ensure there are no compilation errors or type warnings.
2. **Settings Persistence**: Log in to the application, navigate to the notifications settings page, toggle the switches, close the page, and navigate back. Ensure that settings selections are retained.
3. **Trigger Validation**: Run the database queries or check the network requests to verify that calling the provider functions (`approvePermissionApplication`, `publishSchedule`, `balanceFlights`, `registerAthlete`) inserts corresponding rows in the `notifications` table.
