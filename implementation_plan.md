# Implementation Plan - Profile Refactoring & Settings Enhancements

**Status:** Approved & Executed ✅

This plan details the design and implementation steps for fulfilling the additional user requirements:
1. Forgot Password capabilities at login and settings/security pages.
2. Username & email availability checks at registration step 1.
3. Registration username lowercase enforcement, character limits, and counters.
4. Profile Page design details: background rendering (no card wrappers), settings icon next to full name, banner image with flat color fallback, uppercase premium buttons for edit and share profile, description character limits.
5. Desktop inline profile page displaying under header and subheader when "My Profile" is selected.
6. Navigation mobile drawer logout button placed at the bottom.
7. Settings Page subpages for Appearance and Change Password, and subtitle removal from Logout button.
8. Mobile search layout additions and UX updates (User search compact stacked, User search grid banner display & chevron removal, Competition search results indicator and compact/grid popup menu).

---

## Proposed Changes

### Database & Repository Layer

#### [MODIFY] [profile_repository.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/repositories/profile_repository.dart)
- Add `getProfileByEmail(String email)` to check email existence in the database.

---

### Provider Layer

#### [MODIFY] [auth_provider.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/providers/auth_provider.dart)
- Add `isUsernameTaken(String username)` and `isEmailTaken(String email)` methods.
- Add `sendPasswordResetEmail(String email)` calling `_client.auth.resetPasswordForEmail`.
- Expose `bool get isPasswordRecoveryActive` and `void clearPasswordRecovery()`.
- In `_init()`, listen to `AuthState` changes. If `data.event == AuthChangeEvent.passwordRecovery`, set `isPasswordRecoveryActive = true` and notify listeners.

---

### View & Widget Layer

#### [MODIFY] [login_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/views/login_page.dart)
- Add a "Forgot Password?" text button near the password input field.
- Displays a dialog requesting their email (pre-filled with the email field value if present).
- Calls `authProvider.sendPasswordResetEmail(email)` and displays success/error feedback.

#### [MODIFY] [register_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/views/register_page.dart)
- On the Username field, add `inputFormatters` with `LowerCaseTextFormatter` to display and save only lowercase characters. Set `maxLength: 15` to show the character counter.
- On the Full Name field, set `maxLength: 30` to show the character counter.
- In `_nextStep()`, before moving from Step 1 to Step 2, run asynchronous database checks calling `authProvider.isUsernameTaken` and `authProvider.isEmailTaken`. Show an error and block the transition if either is already taken.

#### [MODIFY] [profile_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/views/profile_page.dart)
- Remove `Card` widgets wrapping the profile details, rendering all elements directly on the app background.
- Hide `AppBar` if `widget.isInline == true` (inline desktop view).
- Remove `My Profile` title if viewing the current user's profile.
- Remove share button from the `AppBar` actions for the current user's profile.
- Add a Profile Banner image slot at the top (height ~150px) using the public storage URL `profiles/{userId}/banner.jpg` (with fallback to a nice flat color if not found or on load error).
- In edit profile mode, display a banner upload trigger to pick/upload banner bytes using `file_picker`.
- Move the settings icon to be next to the user's Full Name instead of username.
- Render adjacent "EDIT PROFILE" and "SHARE PROFILE" buttons under the bio. Apply the premium update password design: primary colored, vertical padding 16, border radius 12, bold uppercase.
- On description `TextFormField`, set `maxLength: 150` to display the character counter.

#### [MODIFY] [search_feed_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/views/search_feed_page.dart)
- Add a state variable `_desktopProfileActive = false;`.
- Handle `/profile` deep links on desktop by setting `_desktopProfileActive = true` instead of pushing a new route.
- In `build(BuildContext context)`, if `isDesktop` is true and `_desktopProfileActive` is true, render `ProfilePage(isInline: true)` inline under the header and subheader.
- In `_buildDesktopSubNavBar`, add a `World Map` tab and set the active states accordingly. Toggling "My Profile" sets `_desktopProfileActive = true`.
- In `_buildNavigationDrawer` (mobile view), move the Log Out tile to the bottom (below the `Spacer`), and remove the theme toggle if logged in.
- Add a password recovery listener overlay: check if `authProvider.isPasswordRecoveryActive` is true, and show a dialog prompting the user to update their password. Once updated, call `authProvider.changePassword` and `authProvider.clearPasswordRecovery()`.

#### [MODIFY] [settings_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/views/settings_page.dart)
- Refactor `SettingsPage` to render settings items directly on the app background (no cards).
- Create subpages `AppearanceSettingsPage` and `ChangePasswordPage`.
- Move appearance/color mode preference dropdown to `AppearanceSettingsPage`.
- Move secure password update form, password validator, strength indicator, and password update button to `ChangePasswordPage`.
- On `ChangePasswordPage`, add a "Forgot Password?" button that sends a reset email to the user's current email.
- On the main `SettingsPage`, render buttons/ListTiles to navigate to the subpages.
- In the Log Out tile, remove the subtitle.

#### [MODIFY] [mobile_search_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/views/mobile_search_page.dart)
- In `_buildCompetitionsBody`:
  - Add a results indicator showing the number of competitions found.
  - Add a layout switcher popup menu toggling between Grid and Compact layouts.
  - Render list items as `CompetitionCompactRow` or `CompetitionCard` depending on selection.

#### [MODIFY] [user_compact_row.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/widgets/user_compact_row.dart)
- In mobile layout, stack the `@username` vertically under the full name.

#### [MODIFY] [profile_card.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/refactor-user-profile-settings/lib/widgets/profile_card.dart)
- In mobile layout:
  - Render the user's banner image at the top of the card (with flat color fallback).
  - Stack details (avatar, name, username, bio, badges) below the banner.
  - Remove the trailing arrow icon.

---

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure all existing tests pass.
- Write new widget/unit tests covering username/email taking validation, lowercase input formatting, Settings subpage navigation, results count indicators in mobile search, and forgot password dialog interactions.

### Manual Verification
- Test registration constraints (character limits, uppercase conversion to lowercase).
- Attempt registering with an existing username or email to verify blocking.
- Click "Forgot Password" on login and settings pages to verify reset flow.
- Click password recovery email link and verify reset password modal appears and successfully updates the password.
- Verify desktop navigation and inline profile presentation.
- Check mobile layouts (user compact row, user grid card with banner, competition search with popup layouts and counts).
