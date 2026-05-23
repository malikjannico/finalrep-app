# Codebase Exploration and Architecture Analysis Report

This report outlines the codebase structure of the FinalRep Streetlifting application, analyzes the current implementation of authentication, profiles, and competitions, and provides detailed recommendations for implementing the requested requirements (R1-R5, H1, N1) along with an overview of the testing utilities.

---

## 1. Codebase Structure

The application is structured as a standard Flutter project using **Provider** for state management and **Supabase** as the backend database, storage, and authentication provider.

### File and Folder Layout
- **`lib/`**: Contains the source code of the application.
  - **`models/`**: Defines the data models.
    - `profile.dart`: Model for user profiles (username, name, email, country, gender, etc.).
    - `competition.dart`: Model for competition data (disciplines, dates, location, status, groups, etc.).
  - **`providers/`**: Application state management classes extending `ChangeNotifier`.
    - `auth_provider.dart`: Manages current user session, sign up, login, profile updates, and password changes.
    - `competition_provider.dart`: Manages retrieval, filtering, layout options, and state of competitions.
  - **`repositories/`**: Interactivity layer with Supabase database.
    - `profile_repository.dart`: Select/update queries for the `profiles` table.
    - `competition_repository.dart`: Select/insert queries for the `competitions` table.
  - **`views/`**: Pages/routes of the application.
    - `login_page.dart`: Sign in page (email vs username toggle) and password reset dialog.
    - `register_page.dart`: Stepper wizard for registering accounts with email/password.
    - `profile_page.dart`: User profiles (banner upload, editing details).
    - `search_feed_page.dart`: Main dashboard view showing competition search filters, map views, and drawers.
    - `settings_page.dart`, `appearance_settings_page.dart`, `change_password_page.dart`: User configuration forms.
    - `world_map_view.dart`: Renders competitions on a map using `flutter_map`.
  - **`widgets/`**: Reusable custom components.
    - `profile_card.dart` and `user_compact_row.dart`: Visual displays of user profile items.
    - `competition_card.dart` and `competition_compact_row.dart`: Visual displays of competition items.
  - **`utils/`**: Helper methods, stubs, and platform checks.
    - `url_helper.dart`, `url_helper_web.dart`, `url_helper_stub.dart`: Helpers for handling origin URLs.
- **`test/`**: Unit, widget, and database testing suites.
  - `auth_provider_test.dart`: Mocks authentication and profile repository to verify AuthProvider behaviors.
  - `profile_model_test.dart` and `competition_model_test.dart`: Serialization/deserialization verification.
  - `competition_provider_test.dart`: Provider logic testing.
  - `widget_test.dart`: Extensive widget tests for forms, steps, filtering, layout toggling, and drawers.
  - `test_db.dart` and `db_inspect_test.dart`: Database configuration schema check.

### Key Dependencies
- `supabase_flutter: ^2.8.0` (Client authentication, database operations, realtime, and storage).
- `provider: ^6.1.2` (State management).
- `flutter_map: ^8.3.0` & `latlong2: ^0.9.1` (Interactive map layouts).
- `file_picker: ^8.1.3` (Profile banner/avatar image picking).
- `intl: ^0.19.0` (Datetime parsing and formatting).

---

## 2. Current Implementations

### Authentication & Password Resets
- Managed in `AuthProvider` using `SupabaseClient.auth`.
- Supports email/password registration (`signUp` in `auth.users` and profile details synchronization) and sign-in.
- Supports login using both **Email** and **Username**:
  - Email sign-in calls `signInWithPassword(email: email, password: password)`.
  - Username sign-in resolves username to email using `ProfileRepository.getProfileByUsername` first, and then calls `signInWithPassword` using the resolved email.
- Password Reset: The forgot password dialog calls `AuthProvider.sendPasswordResetEmail`, which directly passes the input string to `_client.auth.resetPasswordForEmail`. It currently does not resolve usernames to emails.

### User Profiles
- Defined in `Profile` model and `ProfileRepository` matching the `profiles` table in Supabase.
- A profile details page is shown in `ProfilePage`. It fetches profile information, supports details updates (`updateProfile`), and allows users to upload JPEG banners using `FilePicker` which are stored in the Supabase Storage bucket `avatars` under `profiles/<id>/banner.jpg`.
- Mobile rendering displays `ProfilePage` as an inline tab (selected via `BottomNavigationBar`). On desktop, it is rendered either inline or via navigation depending on the route.

### Competitions
- Defined in `Competition` model.
- Supports basic location information, dates, status (`upcoming`, `ongoing`, `completed`), and sport categorization (`Classic` or `Modern`).
- Displayed on the `SearchFeedPage` with different layouts (Grid, Compact Row, and Map View) and filter sections (Sport, Format, Group, and Location).

---

## 3. Implementation Recommendations for Requirements

### R1. Login & Forgot Password
1. **Dynamic Lowercase Username Input**:
   - In `lib/views/login_page.dart`, attach a custom `TextInputFormatter` to the `TextFormField` of the username field.
     ```dart
     class LowerCaseTextFormatter extends TextInputFormatter {
       @override
       TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
         return newValue.copyWith(text: newValue.text.toLowerCase());
       }
     }
     ```
   - In `_handleLogin()`, ensure that `final id = _loginIdController.text.trim().toLowerCase();` is used before authenticating.
2. **Username or Email on Password Reset**:
   - In `lib/views/login_page.dart` `_showForgotPasswordDialog` validator, remove the strict email pattern requirement (`value.contains('@')`). Accept any non-empty input.
   - In `AuthProvider.sendPasswordResetEmail`, check if the identifier contains `@`. If it does, proceed with the email reset. If it does not, first retrieve the profile using `_profileRepository.getProfileByUsername(identifier)`. If found, trigger the email reset for `profile.email`. If not found, throw an `Exception("Username not found.")`.

### R2. User Profiles Customization
1. **Social Media Links**:
   - **Database**: Add columns `website_url`, `instagram_handle`, `youtube_handle`, `tiktok_handle`, `twitter_handle` to `profiles` table in Supabase.
   - **Model**: Add fields to `Profile` class, update `fromJson`/`toJson` and `copyWith`.
   - **Form**: In `profile_page.dart` `_buildEditForm`, add text input fields for these URLs.
   - **View**: In `profile_page.dart`, display social links under description as clickable icons (with respective names) utilizing the `url_launcher` package.
2. **Settings Gear Icon Position**:
   - In `profile_page.dart` `_buildProfileHeader`, change the row holding the full name and settings icon. Replace `Expanded(child: Text(_profile!.fullName))` with a nested `Row` containing `Flexible(child: Text(_profile!.fullName, overflow: TextOverflow.ellipsis))` followed directly by the settings `GestureDetector` icon.
3. **Inline Other Profiles (Desktop)**:
   - In `SearchFeedPage`, declare `String? _desktopSelectedUserId` and `String? _desktopSelectedUsername`.
   - When a profile card or row is clicked on desktop, set these variables and toggle `_desktopProfileActive = true` (or custom flag). Render `ProfilePage(userId: _desktopSelectedUserId, username: _desktopSelectedUsername, isInline: true)` inline.
   - In `ProfilePage`, hide the `AppBar` entirely if `widget.isInline && isDesktop` is true to remove the gap between subheader and banner.
4. **Shifted Profile Picture & Left Alignment**:
   - In `profile_page.dart`, modify `_buildBanner` to wrap the banner in a `Stack(clipBehavior: Clip.none)` and position `CircleAvatar` at `bottom: -50` and `left: 24`.
   - In the body column below the banner, add a `SizedBox(height: 50)` padding to allow space for the shifted avatar.
   - In `_buildProfileHeader`, remove the `CircleAvatar` and render a `Column` containing the row-wrapped Name/Settings, Username, Gender, and Country, aligned with `CrossAxisAlignment.start`.
5. **Mobile Navigation Drawer items**:
   - In `search_feed_page.dart` `_buildNavigationDrawer`, for the profile tap items, check if `!isDesktop`. If so, update state `_currentMobileTabIndex = 1` and close the drawer instead of pushing a new route.
6. **Users Page Top Header touching viewport (Mobile)**:
   - In `search_feed_page.dart` `SafeArea`, set `top: !(!isDesktop && provider.searchScope == SearchScope.users)`.
   - In `_buildTopHeader`, if this mobile users-view condition is met, add the status bar height (`MediaQuery.of(context).padding.top`) to the container's top padding.
7. **Username Scroll Behavior in Header**:
   - In `profile_page.dart`, add a `ScrollController` to the `SingleChildScrollView`. Listen to changes and update `_showUsernameInHeader` to true if `offset > 200` (threshold where the inline username scrolls off screen). Conditionally show the username in `AppBar.title` based on this flag.
8. **Competitions, Rankings, and PR Sections**:
   - Create a tabbed interface or cards under the profile details card querying:
     - Upcoming/Completed Meets: Filter competitions by start/end dates and check participant lists.
     - Highest Rankings & Personal Records: Add lookup tables `rankings` and `personal_records` to fetch and render.

### R3. System Administration
1. **Admin Permissions Toggle & Applications**:
   - Create table `permission_applications` with columns `id`, `user_id`, `permission_type` (`competition_creation` | `association_creation`), `reason`, `status` (`pending` | `approved` | `rejected`), and timestamps.
   - Provide application forms in settings checking permission eligibility.
2. **Admin Panel**:
   - Create `lib/views/admin_panel_page.dart` showing tabs for "Users & Permissions" and "Permission Configurator".
   - Control application states using custom Supabase repository calls.

### R4. Associations & Management
1. **Association Wizard**:
   - Create `lib/views/association_create_wizard.dart` utilizing the Flutter `Stepper` widget to step through association metadata, scope selectors, parent associations, and media uploads.
2. **Details & Management pages**:
   - Create `association_detail_page.dart` and `association_manage_page.dart`. Add owner transfer features and role tables (`association_members` / `association_roles`).
   - Define groups inside association details (Competition Groups, Athlete Groups).

### R5. Competition Creation Wizard & Custom Fields
1. **Stepper Form**:
   - Create `lib/views/competition_create_wizard.dart` containing detailed forms for name/location, datetimes, payments configuration, limits, custom input fields, and disclaimer checkboxes.
2. **Volunteer Setup & Safe Zones**:
   - Include volunteer shifts options and overlay visual guides on the banner picker to show cropping boundaries for mobile vs desktop.

### H1. Streetlifting Rules & Judging Engine
1. **Modern Engine**:
   - Implement `lib/utils/streetlifting_rules_engine.dart` encapsulating calculation rules (3 attempts, ascending weights, default weights, plate configurations).
2. **Plate Calculator**:
   - Build a calculation utility resolving a target weight (e.g. 56.25kg) to individual plate selections (2x20kg, 2x5kg, 2x2.5kg, 2x0.625kg, plus collar weights).
3. **Judging Voting logic**:
   - Implement evaluation logic. Dips & Squats: majority 2:1 is valid. Other lifts: require unanimous 3:0.
   - Implement VAR confirmation toggles and execution timer controls.

### N1. System Notifications
1. **System Notifications**:
   - Create a `notifications` database table. Show a notification drawer inside the app header. Create notification category toggles inside user settings page.

---

## 4. Verification and Testing

### Testing Framework
- Standard `flutter_test` is used for all tests.
- UI tests are written as widget tests within `test/widget_test.dart` using mock classes (`MockAuthProvider`, `MockProfileRepository`, `FakeCompetitionRepository`, and `MockFilePicker`) to bypass database latency and test widgets in isolation.

### Running the Test Suite
Ensure that the Flutter environment is set up and execute:
```bash
flutter test
```
All existing tests are compiling and passing successfully.

### Testing Recommendations for New Requirements
1. **Username Lowercase**: Add widget test in `widget_test.dart` entering uppercase characters into the login username field and verifying that the value is dynamically lowercased, and login calls pass username in lowercase.
2. **Forgot Password Username Lookup**: Add mock repository test where username is input to forgot password dialog, and verify mock auth provider successfully maps it to email and sends reset email.
3. **Voting Rules Engine**: Add unit tests in `test/streetlifting_rules_engine_test.dart` with various judging inputs (e.g. `['Good Lift', 'Good Lift', 'No Lift']`) and verify it returns correct status depending on modern/classic and lift type.
4. **Permissions Checks**: Mock user profiles with different boolean flags (`isAdmin`, `canCreateCompetitions`) and verify restricted UI buttons (create competition) are disabled/hidden.
