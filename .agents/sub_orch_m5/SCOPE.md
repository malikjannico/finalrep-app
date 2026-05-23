# Scope: Milestone 5 - System Notifications

## Architecture
- **SystemNotification Model**: Refers to `lib/models/system_notification.dart`. Defines fields like `id`, `profileId`, `category`, `title`, `message`, `isRead`, `createdAt`.
- **NotificationRepository**: Refers to `lib/repositories/notification_repository.dart`. Responsible for CRUD database actions on notifications.
- **AuthProvider**: Refers to `lib/providers/auth_provider.dart`. Needs to manage notification category preferences for the logged-in user (fetching preferences, toggling categories, storing preferences).
- **CompetitionProvider**: Refers to `lib/providers/competition_provider.dart`. Handles events like schedule publishing, flight balancing, registrations.
- **AdminRepository / AuthProvider**: Handles permission approvals/rejections.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration | Identify exact code paths for triggers, preferences schema/storage, and integration points. | None | DONE |
| 2 | Implementation | Implement triggers in providers/repositories, integrate category toggles in settings/auth provider, connect with Supabase. | M1 | DONE |
| 3 | Verification | Write widget and unit tests to verify notifications are triggered and categories can be enabled/disabled. | M2 | DONE |

## Interface Contracts
### Notification Triggering
- Triggers must check user notification preferences (e.g., in `AuthProvider` or via database query) before or during notifications retrieval, or simply store all notifications and filter them on display according to settings.
- Standard notification categories: `registration`, `permissions`, `payments`, `schedule`, `flights`.

## Code Layout
- `lib/models/system_notification.dart` - Notification data model
- `lib/repositories/notification_repository.dart` - Database fetch / save
- `lib/providers/auth_provider.dart` - Preferences state
- `lib/providers/competition_provider.dart` - Competition events triggering notifications
- `lib/views/notifications_page.dart` - Notification display & settings toggles
