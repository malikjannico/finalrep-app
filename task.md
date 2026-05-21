# Implementation Tasks - User Authentication & Profiles

- [x] Deploy database migrations (create `profiles` table, handle_new_user trigger, RLS policies, mock data)
- [x] Create Profile model (`lib/models/profile.dart`)
- [x] Create Profile repository (`lib/repositories/profile_repository.dart`)
- [x] Implement Auth Provider (`lib/providers/auth_provider.dart`) for authentication state management
- [x] Update `lib/main.dart` (Provider registration, dynamic themeMode listening)
- [x] Create Authentication Page (`lib/views/auth_page.dart`) with register/login methods (email + password and username + password)
- [x] Create Profile Page (`lib/views/profile_page.dart`) supporting bio edits, settings, color preference overrides, and logging out
- [x] Create Profile Card Widget (`lib/widgets/profile_card.dart`) for search listings
- [x] Modify `lib/views/search_feed_page.dart`:
  - [x] Add scope selection (Competitions vs. Users) to search bar
  - [x] Integrate user list rendering when "Users" scope is active
  - [x] Add Profile shortcut to Desktop header and Mobile drawer
  - [x] Implement Persistent Mobile Bottom Navigation Bar (Competitions and Profile)
  - [x] Support deep linking and profile URL sharing (`/users/{username}`)
  - [x] Enhance hash fragment parsing to extract parameters on non-root startup routes
  - [x] Clean up obsolete helper methods `_getInitialRoutePath` and `_getInitialQueryParams`
- [x] Update `lib/providers/competition_provider.dart` to support user search scope and queries
- [x] Write unit tests for:
  - [x] Profile model parsing (`test/profile_model_test.dart`)
  - [x] Authentication and profile updates state changes (`test/auth_provider_test.dart`)
- [x] Verify functionality (manual tests for registration, password-based logins, profile updates, theme application, user searching, sharing, and deep links)


