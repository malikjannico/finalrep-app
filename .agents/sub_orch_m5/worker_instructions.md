# Implementation Instructions: System Notifications (N1)

Your task is to implement and verify all requirements under N1 (System Notifications) in the FinalRep Streetlifting application.

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Requirements

### 1. Model Updates (`lib/models/profile.dart`)
- Add a new field: `final Map<String, bool> notificationPreferences`.
- Default value in constructor:
  ```dart
  this.notificationPreferences = const {
    'registration': true,
    'permissions': true,
    'payments': true,
    'schedule': true,
    'flights': true,
  }
  ```
- Update `fromJson`:
  Deserialize `notification_preferences` safely from JSON. Check if it's a Map, map its keys to String and values to bool. Fall back to the default map if null or not a Map.
- Update `toJson`:
  Add `'notification_preferences': notificationPreferences` to the returned map.
- Update `copyWith`:
  Include `notificationPreferences` in `copyWith`.

### 2. Dependency Injection / Constructor Initialization
- Add `NotificationRepository` as an optional parameter to both `AuthProvider` and `CompetitionProvider` constructors:
  - In `lib/providers/auth_provider.dart`:
    ```dart
    final NotificationRepository _notificationRepository;
    ```
    Initialize it using `notificationRepository ?? NotificationRepository(_client)`.
  - In `lib/providers/competition_provider.dart`:
    ```dart
    final NotificationRepository _notificationRepository;
    ```
    Initialize it using `notificationRepository ?? NotificationRepository(_repository.client)`.
- Instantiation in `lib/main.dart`:
  Instantiate `NotificationRepository(supabase)` and pass it into both `AuthProvider` and `CompetitionProvider` constructors.

### 3. Provider Notifications Triggers & Logic
- **`lib/providers/auth_provider.dart`**:
  - Add the persistence method:
    ```dart
    Future<void> updateNotificationPreference(String category, bool enabled) async {
      if (_currentUserProfile == null) return;
      final updatedPrefs = Map<String, bool>.from(_currentUserProfile!.notificationPreferences);
      updatedPrefs[category] = enabled;
      final updatedProfile = _currentUserProfile!.copyWith(notificationPreferences: updatedPrefs);
      try {
        final result = await _profileRepository.updateProfile(updatedProfile);
        if (result != null) {
          _currentUserProfile = result;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Failed to save notification preferences: $e');
        // Fallback: update local profile in-memory to keep UI responsive
        _currentUserProfile = updatedProfile;
        notifyListeners();
      }
    }
    ```
  - In `approvePermissionApplication(String applicationId)`:
    If application is approved, trigger a notification:
    - ID: `notif-perm-${DateTime.now().millisecondsSinceEpoch}`
    - User ID: `app.userId`
    - Title: `"Permissions Approved"`
    - Message: `"Your application to become a ${app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator'} has been approved."`
    - Category: `"permissions"`
    - Created at: `DateTime.now()`
  - In `rejectPermissionApplication(String applicationId)`:
    If application is rejected, trigger a notification:
    - ID: `notif-perm-${DateTime.now().millisecondsSinceEpoch}`
    - User ID: `app.userId`
    - Title: `"Permissions Application Update"`
    - Message: `"Your application to become a ${app.type == 'create_competition' ? 'Competition Creator' : 'Association Creator'} was rejected."`
    - Category: `"permissions"`
    - Created at: `DateTime.now()`

- **`lib/providers/competition_provider.dart`**:
  - Implement `registerAthlete({required String competitionId, required String userId})`:
    - Insert registration record into `meet_registrations` table in Supabase.
      Fields: `id`, `competition_id`, `profile_id`, `status` ('registered'), `created_at` (now as ISO string).
    - Trigger a registration notification (category: `'registration'`, title: `"Registration Confirmed"`, message: `"You have successfully registered for the meet ${competition.title}."`).
    - If `competition.requiresFees` is true, trigger a payment deadline notification (category: `'payments'`, title: `"Payment Action Required"`, message: `"A registration fee of ${feeAmount} ${feeCurrency} is due for ${competition.title}. Deadline: ${deadline}."` where deadline is `paymentEnd ?? registrationEnd`).
  - In `createCompetition(Competition competition)`:
    - After creation, if `created.requiresFees` is true, trigger a notification for the association/creator (category: `'payments'`, title: `"Payment Details Formulated"`, message: `"Competition ${created.title} created with fee... Deadline: ..."`).
  - In `publishSchedule(String competitionId, {bool isPublic = true})`:
    - Update `schedule_published` to `isPublic` in the database.
    - Query registered athlete profile IDs for this competition from `meet_registrations`.
    - Loop over them and create a notification for each athlete (category: `'schedule'`, title: `"Meet Schedule Published"`, message: `"The official schedule for ${comp.title} has been published. Check the agenda now!"`).
  - In `balanceFlights(String competitionId)`:
    - After generating and saving flights in the database, loop over all athlete IDs assigned to the generated flights and create a notification for each (category: `'flights'`, title: `"Flight Assignment Updated"`, message: `"You have been assigned to ${flight.name} for the meet ${comp.title}."`).

### 4. UI Settings Persistence & Display Filtering
- **`lib/views/notifications_page.dart`** and **`test/e2e/mock_views.dart`**:
  - Retrieve current user's preferences from `AuthProvider`. Use default if null or unauthenticated.
  - Bind switch tiles to these preferences.
  - Update switch tile `onChanged` to call `authProvider.updateNotificationPreference(category, val)`.
  - Filter notifications displayed in the list by verifying that `enabledAlerts[n.category]` is not false.

### 5. Tests
- Update `test/profile_model_test.dart` to verify `notification_preferences` in `Profile.fromJson`, `Profile.toJson`, and `copyWith`.
- Ensure all tests build and pass successfully.

Please perform these changes, verify that the application compiles, and run tests.
Write a report describing the files modified and test results.
