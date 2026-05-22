# Tasks - Profile Customization & Password Recovery Refactoring

**Status:** Completed ✅ (100% passing tests)

- [x] Implement Forgot Password capabilities
  - [x] Password reset dialog on `LoginPage`
  - [x] Reset email trigger on `ChangePasswordPage`
  - [x] Recovery state detection in `SearchFeedPage` via `AuthChangeEvent.passwordRecovery`
  - [x] 5-rule password dialog with strength indicator and checklist on recovery flow
- [x] Add Registration Username & Full Name Constraints
  - [x] Validate username and email availability in Step 1
  - [x] Enforce lowercase-only username input dynamically and save as lowercase
  - [x] Used/max character counters for Username (15) and Full Name (30) in Steps 1 and 2
- [x] Refactor Profile Page Layout (Direct background rendering, no cards)
  - [x] Remove Card wrappers for profile details
  - [x] Add user profile banner (150px height) with flat color fallback and upload trigger
  - [x] Position settings icon next to Full Name instead of username
  - [x] Remove app bar title ("My Profile" if current user) and top-right share button
  - [x] Place adjacent "EDIT PROFILE" and "SHARE PROFILE" buttons under bio with primary color & premium styling
  - [x] Enforce bio description counter (150 max length)
- [x] Refactor Settings Page Subpages
  - [x] Split settings into `AppearanceSettingsPage` and `ChangePasswordPage`
  - [x] Add buttons pointing to subpages on main `SettingsPage`
  - [x] Render list tiles directly on background (no Cards)
  - [x] Remove subtitle on the Logout button
- [x] Adapt Mobile Viewport Layouts
  - [x] Navigation Drawer: Relocate Logout button to bottom (below Spacer)
  - [x] User search compact: Stack username vertically under full name
  - [x] User search grid: Display banner above profile picture/name/username, remove chevron arrow
  - [x] Competition search: Add compact/grid popup toggle and results count indicator
- [x] Implement Desktop Inline Profile Page
  - [x] Render `ProfilePage(isInline: true)` inline under header/subheader when selecting "My Profile"
  - [x] Hide inline profile when a search query is typed or submitted
- [x] Verification
  - [x] Add new automated widget tests for availability checks, layouts, and password recovery
  - [x] Run test suite and ensure all tests pass successfully
