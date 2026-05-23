## Current Status
Last visited: 2026-05-23T16:23:00Z

- [x] Decompose milestone & create SCOPE.md
- [x] Run iteration loop for System Notifications (N1) (Iteration 2)
- [x] Verify using unit and integration/widget tests

## Iteration Status
Current iteration: 2 / 32

## Retrospective Notes
### What Worked
1. **Option A (Filtering on Display)**: Implementing settings filtering on display rather than database persistence filtering preserved the notification feed's integrity and simplified querying.
2. **Nullable Constructor Injection**: Injecting an optional `NotificationRepository` in `AuthProvider` and `CompetitionProvider` allowed us to mock notification database interactions seamlessly while keeping 100% of existing tests compiling and passing without modification.
3. **Mock Properties and Helpers**: Adding production getters (`.client`, `.currentUser`) to `MockCompetitionRepository` and `MockGoTrueClient` resolved the widget test runner crashes and allowed mock environments to execute the exact same trigger logic as the real environment.

### What Didn't / Challenges Identified
1. **Volunteer Application Database Exception Handling**: A try-catch block wrapping database inserts in `submitVolunteerApplication` logs the error but still returns `true` and fires the volunteer confirmation notification. In production, a failing database insert should return `false` or rethrow the exception, as triggering a success notification for a failed registration is a false positive.
2. **Notification ID Generation**: Relying on `DateTime.now().millisecondsSinceEpoch` for notification IDs could result in primary key collisions if multiple notifications are generated within the same millisecond. Using a UUID or adding a random suffix is recommended for high-volume transactions.
3. **Loop-based Concurrent Requests**: Triggering notifications in a loop for schedule publishing or flight balancing will result in concurrent database calls, which could hit rate limits or exhaust sockets at scale. A batch insertion endpoint in `NotificationRepository` is a cleaner solution for production.

### Lessons Learned
- Ensure mocks accurately replicate properties and getters accessed by the main classes to avoid compilation/runtime crashes in test environments.
- Always check that user contexts (profiles) are authenticated before modifying state or executing database writes in settings interfaces.
