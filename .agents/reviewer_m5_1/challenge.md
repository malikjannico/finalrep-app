# Adversarial Review Report

## Challenge Summary

**Overall risk assessment**: MEDIUM

While the notification preferences state serialization is well-designed and covers typical model parsing edge cases (e.g., partial or non-map payloads), there are critical assumptions regarding authentication states, missing user IDs during async notifications dispatch, and static state caching that could lead to subtle failures.

---

## Challenges

### [Medium] Challenge 1: Empty Association IDs in Competition Creation Trigger

- **Assumption challenged**: Every competition has a valid association ID to which a notification can be delivered upon creation.
- **Attack scenario**: Creating a competition with a null `associationId` (such as individual meets where `associationId` is omitted).
- **Blast radius**: Inside `CompetitionProvider.createCompetition`:
  ```dart
  final assocNotification = SystemNotification(
    id: 'notif-assoc-${DateTime.now().millisecondsSinceEpoch}',
    userId: created.associationId ?? '',
    ...
  );
  ```
  If `associationId` is null, the notification is saved with an empty string `userId: ''`. The notification is successfully created, but it becomes "orphan" data in the database since no registered user has an empty ID, leading to dead database records.
- **Mitigation**: Only trigger association/creator notifications when `created.associationId` is non-null and not empty, or check if the creator profile ID is available.

### [Medium] Challenge 2: Null Auth Session During Notifications Loading

- **Assumption challenged**: `NotificationsPage` assumes a user is always logged in when reading the notification page.
- **Attack scenario**: If a user logs out, or if the authentication session expires while the user is still on the `NotificationsPage`, the page calls `_loadNotifications()`:
  ```dart
  final userId = authProvider.currentUserProfile?.id;
  if (userId != null) {
    ...
  }
  ```
  If `userId` becomes null, the loading function silently skips fetching but does not clear `_notifications`, leaving stale notifications from the previous user visible on screen.
- **Mitigation**: Clear the notifications list if `userId` becomes null, or automatically pop/redirect the page if the user state shifts to unauthenticated.

### [Low] Challenge 3: In-Memory Static List Pollution

- **Assumption challenged**: The in-memory fallback static list `_mockNotifications` acts as a clean mock database for testing.
- **Attack scenario**: Multiple concurrent tests insert notifications into the static list. Because Dart test runs do not isolate statics between tests within the same file (unless cleared explicitly in `setUp`), tests run in sequence might see polluted state from previous tests.
- **Blast radius**: Potentially flaky tests when tests are run out of order or if the list size is asserted globally.
- **Mitigation**: Provide a clean-up method (e.g. `clearCache()`) in `NotificationRepository` and call it in `setUp`/`tearDown` in tests.

---

## Stress Test Results

- **JSON Deserialization with Invalid Types**: Parsing `notification_preferences: "invalid-type"` -> Profile model gracefully falls back to default map with all 5 categories set to true -> PASS
- **Filtering when preferences are partially populated**: Disabling `payments` via switch -> Verify payments notifications vanish while registration remains -> PASS
- **Flight balancing trigger with large athlete set**: Splitting 15 athletes into flights A and B -> Notifications generated for all of them containing their respective flight assignments -> PASS

---

## Unchallenged Areas

- **PostgreSQL / Supabase Row-Level Security (RLS)**: Real database-level security policies (e.g., users should only be able to view notifications where `user_id = auth.uid()`) could not be stress-tested in local mock mode.
