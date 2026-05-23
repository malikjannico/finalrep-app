# Handoff Report: Explorer Milestone 5 - System Notifications

This handoff report outlines the key findings and the strategy proposed for implementing the notification features defined in Milestone 5.

## 1. Observation

- **Profile model** (`lib/models/profile.dart`): Does not currently contain fields to represent user-specific preferences for notifications.
- **Notifications page** (`lib/views/notifications_page.dart`): Employs a local, non-persistent map `_enabledAlerts` to toggle notification categories, showing a lack of integration with databases or `AuthProvider`.
- **Permission approvals/rejections** (`lib/providers/auth_provider.dart`): Methods `approvePermissionApplication` (line 380) and `rejectPermissionApplication` (line 411) process applications and modify profiles but do not write notifications.
- **Meet registration** (`lib/views/competition_detail_page.dart`): The "Register as Athlete" button (line 299) displays a placeholder snackbar saying registration is not active; there is no registration method in `CompetitionProvider` or repository.
- **Volunteer application** (`lib/providers/competition_provider.dart`): Method `submitVolunteerApplication` (line 775) inserts application payloads into the `volunteer_applications` table but does not trigger system notifications.
- **Flight balancing** (`lib/providers/competition_provider.dart`): Method `balanceFlights` (line 947) performs flight assignment calculations and creates flights in the database, but does not notify the affected users.
- **Schedule publishing** (`lib/providers/competition_provider.dart`): Method `publishSchedule` (line 982) is a shell method containing only `notifyListeners()`.
- **SystemNotification Model** (`lib/models/system_notification.dart`): Defines categories as `'registration', 'permissions', 'payments', 'schedule', 'flights'`.
- **Test execution**: Run `flutter test` completes successfully with `All tests passed!`.

## 2. Logic Chain

1. **Persistence of Settings**: Since preferences need to be persistent, storing them in Supabase is necessary.
   - Adding a JSONB field `notification_preferences` in the `profiles` database table is the most extensible method.
   - Mapping this to a `Map<String, bool> notificationPreferences` field in the `Profile` model ensures state providers can read preferences directly from the current user session profile.
   - Managing settings via `AuthProvider` methods ensures settings are persisted to Supabase and propagate state updates across all views.
2. **Category Toggling in UI**: In `NotificationsPage`, binding switch components to `authProvider.toggleNotificationCategory(...)` guarantees updates persist when the user toggles any switch.
3. **Injecting Triggers**: Triggers should fire immediately after the corresponding data state changes successfully:
   - *Registration Updates*: When volunteer applications are stored or when meet registration completes.
   - *Permission Updates*: When administrators approve or reject role applications.
   - *Payment Deadlines*: At creation time for fee-requiring meets, and upon successful athlete registration to notify them of fee amounts and deadlines.
   - *Schedule Releases*: When publishers mark the schedule as active/public.
   - *Flight Listings*: When athletes are assigned to balanced flights.
4. **Linking Settings to Triggers**: Filtering notifications on the client side at query/display time (Option A) is the most flexible approach. It allows notifications to remain in the database so that toggling a category back "on" makes old notifications visible again.

## 3. Caveats

- **Mock database behavior during tests**: Unit tests use in-memory database mocks. The new JSONB preference fields should handle fallback default settings when mock profiles do not populate this field.
- **Multiple recipients**: For notifications targeting multiple recipients (e.g. Schedule publishing, where all registered athletes must be notified), a loop is required in the provider. Performance scales with the number of registered users. For large-scale datasets, a database function or trigger could replace client-side iteration.

## 4. Conclusion

The strategy outlines the integration points and changes required in the model, provider, repository, and view layers to implement Milestone 5.
- The `Profile` model and `profiles` database table should be extended to hold JSONB notification preferences.
- Triggers must be injected directly within `CompetitionProvider` and `AuthProvider` methods after successful database operations.
- Triggers should store notifications using the standard schema in the `notifications` table.
- Display logic in `NotificationsPage` will filter notifications based on the persisted preferences mapped inside `Profile`.

## 5. Verification Method

To verify the implementation once complete:
1. Run `flutter test` to ensure no regressions are introduced.
2. Write unit tests inside `test/notifications_test.dart` to verify:
   - Settings changes are correctly saved to the repository and database.
   - A mock trigger (e.g. approving a permission application) successfully inserts a new notification of category `permissions` into the mock database.
   - UI tests in `NotificationsPage` confirm toggling a category switch hides/shows notifications of that category.
