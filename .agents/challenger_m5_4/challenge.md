# Adversarial Review & Challenge Report — System Notifications (N1)

## Challenge Summary

**Overall risk assessment**: **LOW**

The implementation is highly resilient. It handles edge cases like database connection issues, partial profile JSON values, and unauthenticated users gracefully. I have designed and run a dedicated adversarial integration test suite (`test/notification_adversarial_test.dart`) to stress-test the trigger flow, settings/category filtering, unauthenticated switch states, and database sync fallbacks. All tests have passed successfully.

---

## Challenges

### [Low] Challenge 1: Database Error during Volunteer Application Submission
- **Assumption challenged**: A database constraint or query failure during volunteer application submission will crash the registration flow or prevent the notification from being generated.
- **Attack scenario**: The Supabase client throws an exception while inserting into the `volunteer_applications` table.
- **Blast radius**: The application registration flow is halted, throwing a runtime error to the volunteer user.
- **Mitigation**: The code in `submitVolunteerApplication` wraps the database insert in a separate nested `try-catch` block. Even if the DB write fails, it continues to construct and record the local notification.
- **Verification**: Verified using `notification_adversarial_test.dart`. The test simulates a failing database client, and the provider successfully catches the error, generates the volunteer notification, and returns true.

### [Low] Challenge 2: Missing or Incomplete Profile Notification Preferences
- **Assumption challenged**: The client profile in the database will always return a complete and valid map of preferences, matching the 5 expected categories (`registration`, `permissions`, `payments`, `schedule`, `flights`).
- **Attack scenario**: A user has an old schema in the DB, is missing the `notification_preferences` field completely, or has only a subset of category settings defined in their JSON payload.
- **Blast radius**: `NullThrownError` or missing key exceptions when rendering switch toggles or filtering notifications.
- **Mitigation**: The `Profile.fromJson` constructor merges parsed JSON fields into a default mapping template containing all 5 categories defaulted to `true`.
- **Verification**: Verified via test suite. Partial JSON parsing merges default fields correctly, and missing settings default all categories to `true`.

### [Low] Challenge 3: Unauthenticated Settings Interaction
- **Assumption challenged**: Guest users who visit the notification view can modify notification preference switches.
- **Attack scenario**: An unauthenticated user expands the Alert Settings accordion and taps switch toggles, causing updating attempts on a null user profile.
- **Blast radius**: App throws an exception attempting to call update methods on a null profile in the DB.
- **Mitigation**: Switch tiles in `NotificationsPage` are disabled (`onChanged: null`) when `authProvider.currentUserProfile == null`.
- **Verification**: Verified via widget test that unauthenticated users have disabled switch toggles (i.e. `onChanged == null`) and are displayed seed/fallback notifications.

---

## Stress Test Results

- **Permission Triggers (Approve & Reject)** → Creates permission category notification with correct description. → **PASS**
- **Payment Formulation (Comp Creation)** → Creates payments category notification. → **PASS**
- **Payment Requirement (Registration)** → Creates registration + payment category notifications. → **PASS**
- **Volunteer Application Trigger** → Creates volunteer submission notification. → **PASS**
- **Flight Assignment Trigger** → Creates flight assignment notification for each athlete. → **PASS**
- **Schedule Publication Trigger** → Creates schedule notification for all registered athletes. → **PASS**
- **Settings Toggle Filter** → Disabling a category switch filters matching notifications from display. → **PASS**
- **Category Chips Filter** → Tapping a category chip restricts visible notifications to just that category. → **PASS**
- **Unauthenticated Safety** → Unauthenticated users see fallback notifications and switches are disabled. → **PASS**
- **Database Connection Failure** → Fallback to local static mock cache works without crashes. → **PASS**

---

## Unchallenged Areas

- **Push Notification Subsystem** — Out of scope. The N1 requirement explicitly covers system (in-app) notifications.
