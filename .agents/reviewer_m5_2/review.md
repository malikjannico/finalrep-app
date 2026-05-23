# Review and Challenge Report — 2026-05-23T16:15:00+02:00

## Review Summary

**Verdict**: REQUEST_CHANGES

The core features for N1 (System Notifications) have been implemented, including the user settings switches for notification preferences, in-memory state fallbacks, deserialization merging with defaults, and notification triggers for athlete registrations, flight assignments, permission decisions, and schedule publishing. All 107 unit and widget tests in the repository pass. 

However, two major findings/gaps must be corrected before approval.

---

## Findings

### [Major] Finding 1: Orphaned Payment Setup Notification

- **What**: The notification triggered after creating a fee-requiring competition has its target user ID set to the association ID instead of a user profile ID.
- **Where**: `lib/providers/competition_provider.dart` (Line 781)
- **Why**: `created.associationId` represents the UUID of the association, not a user profile ID. Since notifications on the page are retrieved by the current user's profile ID (`getNotifications(userId)`), this notification is orphaned and will never be displayed to any user.
- **Suggestion**: Use the logged-in creator's/organizer's user profile ID as the `userId` for this notification.

### [Major] Finding 2: Missing Volunteer Application Notification Trigger

- **What**: Submitting a volunteer application does not trigger any notification.
- **Where**: `lib/providers/competition_provider.dart` (Lines 861–891) in `submitVolunteerApplication`
- **Why**: The worker instructions and system scope require triggers for volunteer applications. While registrations and permission events create confirmations, submitting a volunteer application does not generate any `SystemNotification` (under either `registration` or `permissions`).
- **Suggestion**: Trigger a confirmation notification to the applicant when `submitVolunteerApplication` succeeds.

---

## Verified Claims

- **All tests pass** → Verified via running `flutter test` → **PASS** (107/107 tests completed successfully).
- **Default profile preferences deserialization merging** → Verified via inspecting `lib/models/profile.dart` and verifying `test/profile_model_test.dart` passes → **PASS** (partial preferences are merged with defaults).
- **Display filtering by switches & chips** → Verified via inspecting `lib/views/notifications_page.dart` and `test/e2e/mock_views.dart` → **PASS** (filtering behaves correctly under both user settings and filter chips).

---

## Coverage Gaps

- **Waitlist notification updates** — risk level: low — recommendation: accept risk (no waitlist progression or assignment logic exists yet in the application code, so notifications cannot be triggered).

---

## Unverified Items

- No unverified items.

---
---

## Challenge Summary

**Overall risk assessment**: MEDIUM

---

## Challenges

### [High] Challenge 1: Flight assignment notifications generate O(N) database operations

- **Assumption challenged**: Flight assignment notification scales linearly without performance overhead.
- **Attack scenario**: When `balanceFlights` is executed for a competition with 100+ athletes, it loops through each athlete and awaits `_notificationRepository.createNotification(notif)` sequentially. This triggers a separate Supabase insert query for every athlete, risking connection exhaustion, rate limits, or page timeouts.
- **Blast radius**: Performance degradation and potential partial assignment notification failures.
- **Mitigation**: Implement a batch/bulk insert method in `NotificationRepository` and trigger a single insert query for all flight assignment notifications.

### [Medium] Challenge 2: Inconsistent settings switch state on unauthenticated profiles

- **Assumption challenged**: User preferences are always saved under a valid profile.
- **Attack scenario**: If `updateNotificationPreference` is called when `_currentUserProfile` is null, it returns early. However, `notifications_page.dart` does not check for null values when initializing SwitchListTile bindings (falling back to a static default map). If the guest tries to interact with switch toggles, the UI switches but the settings are neither persisted nor linked to any account.
- **Blast radius**: Confusing UI behavior for guest/anonymous users.
- **Mitigation**: Disable settings toggle switches on `notifications_page.dart` if the user is not authenticated.

---

## Stress Test Results

- **Run bulk flight assignments** → Loop calls to `createNotification` sequentially → Expected: all notifications created; Actual: succeeded in mockup but represents a scalability bottleneck → **FAIL** (on performance/scalability standards).

---

## Unchallenged Areas

- No unchallenged areas.
