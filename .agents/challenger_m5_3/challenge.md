## Challenge Summary

**Overall risk assessment**: MEDIUM

## Challenges

### [High] Challenge 1: False Positive Volunteer Confirmation on Database Write Failures

- **Assumption challenged**: Assumes that if `submitVolunteerApplication` is called, the database write successfully records the application before triggering the volunteer application confirmation notification.
- **Attack scenario**: In `CompetitionProvider.submitVolunteerApplication` (lines 886-890), the insert database call to `volunteer_applications` is wrapped in a defensive try-catch block:
  ```dart
  try {
    await _repository.client.from('volunteer_applications').insert(payload);
  } catch (e) {
    debugPrint('Error inserting volunteer application: $e');
  }
  ```
  If the insert fails (due to database constraint violation, connection loss, or lack of write permissions), the error is caught and printed to console. The method then proceeds to retrieve the competition name, create and save the `SystemNotification` to the client cache/DB, and returns `true` (success). The user is shown a notification saying `"Your application to volunteer for the meet \"...\" has been submitted."`, even though their application was never saved in the database.
- **Blast radius**: High. Loss of volunteer data and false assurance to users.
- **Mitigation**: Rethrow the database error or return `false` if the DB insert fails. The confirmation notification should only be triggered if the database write succeeds.

### [High] Challenge 2: Network & Socket Exhaustion (Scale Flaws) on Bulk Notification Triggers

- **Assumption challenged**: Assumes that looping and firing individual client-side database insertions for each registered athlete is scalable for schedule releases and flight assignments.
- **Attack scenario**: When a schedule is published via `publishSchedule` or flights are balanced via `balanceFlights`, the provider loops over all registered athlete IDs and calls `_notificationRepository.createNotification(notif)` for each one. If a competition has hundreds of registered athletes, this triggers hundreds of concurrent/sequential HTTP requests to the Supabase database. This will hit Supabase rate limits (429), exhaust network sockets on mobile devices, or time out, resulting in incomplete notifications and potential UI/app freeze.
- **Blast radius**: High. Notification delivery failures and UI performance degradation for larger competitions.
- **Mitigation**: Implement a batch insert method (`createNotifications(List<SystemNotification> notifications)`) in `NotificationRepository` to perform a single batch write (e.g. `client.from('notifications').insert(list)`), or delegate notification generation to a Postgres trigger / Supabase Edge Function on the database side.

### [Medium] Challenge 3: Orphaned Notifications from Association ID Fallback

- **Assumption challenged**: Assumes that the `associationId` can be used as a fallback `userId` for payment notifications when creating a competition.
- **Attack scenario**: In `CompetitionProvider.createCompetition` (line 779), if the creator user cannot be determined from the auth state, the code falls back to `created.associationId`:
  ```dart
  final creatorUserId = _repository.client.auth.currentUser?.id ?? created.associationId ?? '';
  ```
  If this fallback is triggered, the notification is stored in the database with `user_id` set to the association ID. However, users fetch notifications using their auth user ID (`authProvider.currentUserProfile?.id`). Since association IDs are database keys for association entities, not auth user IDs, the notification is orphaned in the database and will never be seen by any user.
- **Blast radius**: Medium. Users miss payment details formulated notifications when auth context is lost or partially initialized.
- **Mitigation**: Resolve the user ID representing the association's owner or administrator instead of using the raw association ID.

## Stress Test Results

- **Registration triggers fire** → Trigger registration for athlete → Notification created under "registration" category with expected meet details → **PASS**
- **Volunteer application triggers fire** → Submit volunteer application → Notification created under "registration" category with expected volunteer details → **PASS**
- **Permission triggers fire** → Approve/reject permission application → Notification created under "permissions" category with approved/rejected details → **PASS**
- **Payment triggers fire** → Create fee-based competition & register athlete → Notifications created under "payments" category for formulation and action required → **PASS**
- **Schedule release triggers fire** → Publish schedule for competition → Notifications created under "schedule" category for all registered athletes → **PASS**
- **Flight assignment triggers fire** → Balance flights for competition → Notifications created under "flights" category for assigned athletes → **PASS**
- **Settings toggles respect filters** → Toggle "payments" category switch to false on NotificationsPage → Only "registration" category notification is shown; "payments" is filtered out → **PASS**
- **Unauthenticated settings switches disabled** → Renders NotificationsPage with null profile → Toggles are disabled (onChanged is null) and cannot be modified → **PASS**

## Unchallenged Areas

- **Real Database RLS Policies** — Not challenged as the local execution environment runs against mocked/fallback repositories where real Postgres security invokers and row-level policies cannot be evaluated.
