# Scope: Milestone 1 - Auth & Profile Enhancements

## Architecture
- **Authentication & User Lookup**: Modifying `login_page.dart` and `auth_provider.dart` to support case-insensitive logins (lowercasing username) and dual username/email forgot-password lookup via `profile_repository.dart`.
- **Profiles Customization**:
  - Modifying `profile.dart` (data model) to add social media links.
  - Updating `profile_repository.dart` to support persisting and fetching new profile fields.
  - Enhancing `profile_page.dart` with new desktop layout, mobile UX features (AppBar scroll hides/shows username, drawer navigation matching profile tab, Users search header touching viewport top), and sections (PRs, Rankings, Meets).
  - Showing social media links with names and icons.
  - Repositioning settings gear icon directly after the full name on "My Profile".
  - Repositioning the avatar shifted up (half above banner) with left-aligned details.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | R1: Login & Forgot Password | Lowercase username field dynamically, verify username in lowercase, support username/email in forgot password lookup. | None | DONE |
| 2 | R2: Profiles Customization | Add social media links, adjust avatar/gear positions, render inline desktop layout, mobile UX changes, and add meets/rankings/PRs sections. | M1 | DONE |

## Interface Contracts
### `AuthProvider` ↔ `ProfileRepository`
- `Future<Profile?> getProfileByUsername(String username)`: returns Profile? matching username (case-insensitive checks).
- `Future<Profile?> getProfileByEmail(String email)`: returns Profile? matching email.
- `Future<void> sendPasswordResetEmail(String email)`: unchanged, but called after username resolving.
- `Future<void> loginWithUsernameAndPassword({required String username, required String password})`: converts username to lowercase first.

### `Profile` Model
- New field `Map<String, String>? socialLinks`: stores social media channel names and handles/links.
