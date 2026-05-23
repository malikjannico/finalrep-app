# Implementation Instructions: System Notifications (N1) - Iteration 2

Your task is to fix specific findings and challenges identified during verification of Iteration 1.

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Requirements

### 1. Fix payment details notification user ID (`lib/providers/competition_provider.dart`)
- In `createCompetition(Competition competition)`:
  - The payment setup notification target user ID is currently set to the association ID (`created.associationId`). This makes the notification orphaned as it cannot be loaded by the creator.
  - Modify the notification creation logic so that the `userId` is set to the logged-in creator's profile ID:
    ```dart
    final creatorUserId = _repository.client.auth.currentUser?.id ?? created.associationId ?? '';
    ```
    Pass this `creatorUserId` as the `userId` in the `SystemNotification` constructor.

### 2. Implement volunteer application notification trigger (`lib/providers/competition_provider.dart`)
- In `submitVolunteerApplication(...)`:
  - After successfully inserting the payload into the `volunteer_applications` table, retrieve the competition details by ID:
    ```dart
    final competition = await _repository.getCompetitionById(competitionId);
    ```
  - If the competition exists, trigger a volunteer confirmation notification:
    - ID: `notif-vol-${DateTime.now().millisecondsSinceEpoch}`
    - User ID: `userId`
    - Title: `"Volunteer Application Submitted"`
    - Message: `"Your application to volunteer for the meet \"${competition.title}\" has been submitted."`
    - Category: `"registration"`
    - Created at: `DateTime.now()`
  - Create and save this notification using `await _notificationRepository.createNotification(notif)`.

### 3. Disable switches for unauthenticated users (`lib/views/notifications_page.dart`)
- In `ExpansionTile` for alert settings:
  - If the user is unauthenticated (meaning `authProvider.currentUserProfile == null`), disable all switch toggles.
  - Specifically, set the `onChanged` parameter of the `SwitchListTile` to `null` if `authProvider.currentUserProfile == null`:
    ```dart
    onChanged: authProvider.currentUserProfile == null
        ? null
        : (val) {
            authProvider.updateNotificationPreference(category, val);
          },
    ```

### 4. Ensure widget test robustness
- Ensure any widget/stress tests (specifically `test/notification_stress_test.dart` and `test/notification_system_test.dart`) use `tester.pumpAndSettle()` where appropriate to wait for asynchronous notification insertions and fallback caches.

### 5. Verification
- Run the full test suite using `flutter test`. Ensure all tests compile and pass cleanly.
- Verify specifically that the new tests for volunteer application triggers pass.
