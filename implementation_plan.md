# Implementation Plan - User Authentication and Profile System

This plan details the design and implementation steps for introducing user authentication, profiles, basic login methods (email/username + password), default color modes, profile searching, and deep linking.

## User Review Required

> [!IMPORTANT]
> **Database Migrations:**
> We will create a `public.profiles` table in Supabase. To automate profile creation for email registrations, we will add a PostgreSQL function `public.handle_new_user()` and a database trigger `on_auth_user_created` on the `auth.users` table.

## Open Questions

> [!NOTE]
> No critical open questions remain. We will proceed with establishing the database schemas and the Flutter views using the specifications below.

---

## Proposed Changes

### Database & Models

---

#### [NEW] Supabase Database Migration
We will run a SQL script via the Supabase MCP tool (`execute_sql`) to:
1. Create the `public.profiles` table linked to `auth.users(id)` containing `username`, `full_name`, `email`, `gender`, `country`, `profile_picture_url`, `description`, and `color_mode`.
2. Define a database trigger on `auth.users` to automatically create a profile record upon user sign-up.
3. Enable Row Level Security (RLS) on `public.profiles` (public select, owner-restricted update).
4. Insert mock profiles to allow immediate profile searching.

#### [NEW] [profile.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/models/profile.dart)
- Model representing user profiles, including constructor, `fromJson`, and `toJson` methods.
- Includes properties for: `id`, `username`, `fullName`, `email`, `gender`, `country`, `profilePictureUrl`, `description`, and `colorMode`.

---

### Repositories & State Management

---

#### [NEW] [profile_repository.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/repositories/profile_repository.dart)
- Create a repository class interacting with the Supabase client to fetch, update, and search profiles.
- Methods:
  - `getProfile(String id)`: Fetches a single profile by user ID.
  - `getProfileByUsername(String username)`: Fetches a profile by username (for deep links).
  - `updateProfile(Profile profile)`: Updates profile details.
  - `searchProfiles(String query)`: Searches profiles by username or full name.

#### [NEW] [auth_provider.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/providers/auth_provider.dart)
- Create a state notifier that listens to Supabase auth state changes (`onAuthStateChange`).
- Holds current user details (`Profile? _currentProfile`) and authentication status.
- Implements:
  - `register(username, fullName, email, password, gender, country, profilePicture)`
  - `loginWithPassword(emailOrUsername, password)`
  - `logout()`
  - `updateProfileDetails(fullName, email, gender, country, description)`
  - `updateColorMode(colorMode)`

#### [MODIFY] [competition_provider.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/providers/competition_provider.dart)
- Add user search state:
  - `String _searchScope = 'competitions'` ('competitions' or 'users')
  - `List<Profile> _searchedUsers = []`
  - Getters/setters for `searchScope` and `searchedUsers`.
- Update `setQuery` and `clearFilters` to handle profile querying when `searchScope == 'users'`.

---

### UI Components & Navigation

---

#### [MODIFY] [main.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/main.dart)
- Register `AuthProvider` alongside `CompetitionProvider` in the `MultiProvider` block.
- Read `AuthProvider.currentProfile.colorMode` to set the theme mode of the application dynamically (System, Light, or Dark) when the user is logged in.

#### [NEW] [auth_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/views/auth_page.dart)
- Add a beautiful authentication view:
  - Smooth toggling between **Login** and **Register** panels.
  - Form support for Login methods: Email + Password and Username + Password.
  - Register fields: Username, Full Name, Email, Gender (dropdown), Country (dropdown), Profile Picture (mock uploader with option to pick pre-designed avatars).

#### [NEW] [profile_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/views/profile_page.dart)
- Add a premium user profile view:
  - Renders user avatar, full name, username, bio, and country flag.
  - Edit Profile modal: edit full name, email, gender, country, and bio description.
  - Preferences: define default Color Mode (System, Light, Dark).
  - Manage Login Methods: links to manage/add alternative password login methods.
  - Share Profile button: copies profile URL to clipboard and triggers a toast notification.
  - Logout action.

#### [MODIFY] [search_feed_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/views/search_feed_page.dart)
- **Search Bar Updates**:
  - Add a dropdown toggle inside the search input to select between "Competitions" and "Users".
  - If "Users" is active, render user cards instead of competition cards, and call the user search API.
- **Header Updates (Desktop)**:
  - Add a circular profile avatar shortcut on the right side of the header. If guest, displays "Login / Register".
- **Drawer Updates (Mobile)**:
  - Include a user header inside the navigation drawer linking to "Profile" if authenticated, or a "Sign In" CTA.
- **Bottom Navigation (Mobile)**:
  - Add a persistent bottom navigation bar on mobile scaffolds with items: "Competitions" and "Profile".
- **Deep Linking for Profiles**:
  - Add logic in `_checkSharedLink` to detect profile URL sharing (`/users/{username}` or `/profiles/{username}`) and route users directly to the Profile Page of the searched user.

#### [NEW] [profile_card.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/implement-user-authentication-system/lib/widgets/profile_card.dart)
- A modern card displaying other users' avatars, username, full name, country, and bio details in the search list when search scope is set to "Users".

---

### Verification Plan

### Automated Tests
- Create unit tests for parsing profiles in `profile_model_test.dart`.
- Create unit tests for state updates (register, login, theme mode setting) in `auth_provider_test.dart`.
- Run `flutter test` to ensure all tests pass.

### Manual Verification
- Deploy schema changes to Supabase database.
- Launch the application locally and perform:
  - User registration with optional profile picture, using email or username password login options.
  - Verify theme change overrides when logged-in users modify their default color mode preference.
  - Verify mobile view: check bottom navigation, left drawer link, and bottom nav item.
  - Search for users via search bar toggles.
  - Copy and verify the shared profile URLs route directly on reload.

---

## Implementation Status
- **Supabase Database Migration**: [x] Completed and deployed.
- **Profile Model**: [x] Completed (`lib/models/profile.dart`).
- **Profile Repository**: [x] Completed (`lib/repositories/profile_repository.dart`).
- **Auth Provider**: [x] Completed (`lib/providers/auth_provider.dart`).
- **Competition Provider**: [x] Completed search scope modifications.
- **UI Components**:
  - [x] Provider registration & themeMode in `lib/main.dart`.
  - [x] Authentication Page (`lib/views/auth_page.dart`).
  - [x] Profile Page (`lib/views/profile_page.dart`).
  - [x] Profile Card widget (`lib/widgets/profile_card.dart`).
  - [x] Search feed page scope toggle, user search layout, bottom navigation, and profile drawer shortcut.
- **URL Syncing & Deep Links**:
  - [x] Added `WebUrlObserver` and configured `initialRoute: '/'`.
  - [x] Implemented route checking and hash extraction on startup in `search_feed_page.dart`.

