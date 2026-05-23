# Adversarial Review Challenge Report — Notification System

## Challenge Summary

**Overall risk assessment**: MEDIUM

While the notification system is functionally correct, passes all automated unit/widget/integration tests, and includes a robust in-memory mock fallback mode when database clients are unavailable, we have identified key architectural assumptions that introduce potential risks.

---

## Challenges

### [Medium] Challenge 1: Static Fallback State Leak Across User Sessions

- **Assumption challenged**: The in-memory fallback cache `_mockNotifications` in `NotificationRepository` is stateless and safe for testing.
- **Attack scenario**: The list is declared as `static final List<SystemNotification> _mockNotifications = [];`. If multiple users log in and out on the same client device session (e.g., during guest testing, local manual QA, or kiosk usage) when the backend is offline, notifications for User A will persist in the static cache. If User B subsequently uses the device, or if a guest user with an empty/null ID is active, they can retrieve cached notifications belonging to other profiles.
- **Blast radius**: Low-Medium (isolated to environments where the Supabase backend query fails and falls back to mock caching, but can leak private athlete information locally).
- **Mitigation**: Introduce a public `clearCache()` method in `NotificationRepository` and invoke it from `AuthProvider.logout()`.

### [Low] Challenge 2: Client-side UI Filtering and Memory Load Overhead

- **Assumption challenged**: Fetching all notifications at once and filtering them in the Flutter UI thread `build()` method scales efficiently.
- **Attack scenario**: The repository queries the `notifications` table without limit or pagination. For power-users/athletes who participate in dozens of competitions and accumulate thousands of notifications, loading all rows from the database causes high memory consumption. When they open the `NotificationsPage`, Flutter performs client-side `where` filtering on every toggle switch and chip interaction inside the build loop, leading to frames dropping and UI stutter.
- **Blast radius**: Medium (UI responsiveness degrades over time as the database grows).
- **Mitigation**: Implement server-side pagination (e.g., `.limit(20)`) and offload category filtering directly to Postgres queries rather than performing it client-side.

### [Medium] Challenge 3: Mismatched/Unvalidated Category String Schema

- **Assumption challenged**: Mappings between backend notification triggers, database schema strings, and the hardcoded categories in the UI are permanently synchronized.
- **Attack scenario**: In `NotificationsPage`, the fallback for unrecognized categories defaults to `true`:
  ```dart
  return enabledAlerts[n.category] ?? true;
  ```
  If a developer or database migration changes/extends notification categories (e.g. using `'flight'` instead of `'flights'`, or introducing a new `'volunteer'` category) without immediately updating the UI settings panel, the settings toggles will fail to mute these alerts. The athlete will receive unwanted notifications because the UI doesn't know to map them to an existing switch control.
- **Blast radius**: Medium (loss of control over user alert preferences for unmapped categories).
- **Mitigation**: Enforce a strict enum or constrained string type (e.g., `NotificationCategory`) throughout the codebase instead of raw `String` values.

---

## Stress Test Results

- **Scenario 1: Fallback CRUD** → Verify repository CRUD functionality using null-client mock fallback. → All notifications created, fetched, and marked read correctly. → **PASS**
- **Scenario 2: Permissions Trigger** → Verify `AuthProvider` triggers permissions notifications on application approvals and rejections. → Correct notifications with `permissions` category generated. → **PASS**
- **Scenario 3: Registration and Payments Triggers** → Verify `CompetitionProvider.registerAthlete` triggers registrations notifications, and adds payments notifications if fees are required. → Correct notifications generated with `registration` and `payments` categories. → **PASS**
- **Scenario 4: Flight Assignment Trigger** → Verify `CompetitionProvider.balanceFlights` triggers flights notifications for all registered/assigned athletes. → Correct flight notifications generated. → **PASS**
- **Scenario 5: Schedule Release Trigger** → Verify `CompetitionProvider.publishSchedule` triggers schedule release notifications. → Correct schedule notifications generated. → **PASS**
- **Scenario 6: Settings & Chips Filtering** → Verify `NotificationsPage` UI filters out notifications when categories are disabled or when category chips are selected. → UI rendered and updated to display only the selected categories. → **PASS**

---

## Unchallenged Areas

- **Supabase Realtime Subscriptions** — Due to the network-restricted `CODE_ONLY` test environment, we did not verify live realtime notifications via Postgres replication triggers, but focused on the repository/provider triggers and mock-mode integration.
