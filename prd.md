# Product Requirements Document (PRD) — FinalRep App

## 1. Product Overview
**FinalRep App** is a responsive, cross-platform sport competition management and search platform designed for **Streetlifting**. It enables organizers to manage meets and allows athletes, coaches, and spectators (both registered and unregistered) to search for upcoming events globally.

The platform is designed to promote Streetlifting from grassroots local meets up to international championships.

---

## 2. Target Audience
1. **Athletes:** Search for upcoming meets, view event details, and review formats.
2. **Spectators & Unregistered Users:** Search and browse upcoming competitions without needing to register or authenticate.
3. **Coaches & Teams:** Track events for scheduling athlete preparations.
4. **Organizers (Future):** List events, manage athlete weight registrations, and record attempt results.

---

## 3. Core Features (MVP & Enhancements)
- **Responsive Header & Navigation**:
  - **Desktop**: Main header features a centered search bar (with real-time dropdown results and search scope selector), left-aligned FinalRep Icon in brand color `#E94E1B`, right-aligned profile page navigation shortcut (avatar/icon) which opens a dropdown with options to go to "My Profile", "Settings", or "Log Out" when logged in (or Login/Register buttons when guest), and a zero-animation Color Mode toggle (visible only to guest users). A dedicated navigation bar is positioned below the header, displaying centered navigation tabs for "Competitions", "World Map", and "My Profile" (visible only when logged in) without active-item underline decoration. Selecting "My Profile" displays the user profile page inline directly under the header and subheader in desktop view, rather than on an individual screen or modal.
  - **Mobile**: Top header has a centered FinalRep Icon, a hamburger menu icon (left) that opens a navigation/app drawer, and a search icon (right) that opens a full-screen mobile search view. The navigation/app drawer header displays the user's full name and username on the right side of their profile image. In the navigation drawer, the Logout button is positioned at the very bottom. A bottom navigation bar with icons and labels switches between the "Competitions" and "My Profile" views.
- **Dynamic Search & Filtering (Competitions View)**:
  - **Desktop Sidebar**: Left-aligned, always-visible filter panel with collapsible sections.
  - **Mobile Filter Drawer**: Slide-in right drawer triggered by a filter icon.
  - **Results Indicator**: Displays results count as "[Number of Competitions] Competitions" on both mobile and desktop views.
  - **Sorting & Layouts**: Popup menu buttons for sorting and layouts.
- **Search Bar Selection (Competition vs. User)**:
  - Toggle search scope between "Competitions" and "Users".
- **Single Competition Detail View**:
  - Hero banner, disciplines explanation list, and clipboard sharing matching the pattern `/competitions/{id}`.
- **Interactive World Map View**:
  - Dot world map with pulsing markers, constrained zoom and camera constraints.
- **Guest Access**: All upcoming competitions, map pins, and details must be searchable and viewable without user login or authentication.
- **User Authentication & Profiles**:
  - **Register & Login**: Dedicated pages (`LoginPage` and `RegisterPage`) with mutual navigation links.
  - **Forgot Password**: Added forgot password/recovery capabilities at the `LoginPage` and `SettingsPage`/`ChangePasswordPage`. When a password reset link is triggered, users receive an email. Upon clicking the link, the app detects the recovery state and shows a secure password update dialog/overlay enforcing the 5 password safety rules.
  - **Multi-step Registration Flow**:
    - **Step 1 (Account)**: Form validation for Username, Email, and Password.
      - **Availability Checks**: Validates if the username and email are already taken before allowing the user to proceed to Step 2.
      - **Lowercase Username**: Enforces lowercase-only usernames dynamically on input and saves them in lowercase.
      - **Character Limits**: Enforces and indicates used vs. max characters for Username (max 15 characters).
      - **Password Safety Rules**: Enforced by design (min 8 chars, uppercase, lowercase, digit, special character) with a strength indicator.
    - **Step 2 (Details)**: Form validation for Full Name, Gender, and Country.
      - **Character Limits**: Enforces and indicates used vs. max characters for Full Name (max 30 characters).
    - **Step 3 (Avatar)**: Support for custom avatar uploading.
  - **Profile Page & Customization**:
    - **Background Rendering**: Shows profile picture, full name, username, gender, country, and description directly on the app background (no cards/containers).
    - **Profile Banner**: Added a profile banner at the top of the profile page, showing a flat color fallback if no banner is uploaded. Users can upload custom banners in edit mode.
    - **Settings Icon**: Shows a settings icon next to the user's Full Name instead of username.
    - **Actions**: Removed the top-right share button. Added a filled "SHARE PROFILE" button right next to the "EDIT PROFILE" button under the bio.
    - **Button Styling**: Applied the premium update password button design (primary colored, filled, padding 16, border radius 12, bold uppercase text) to both the edit and share profile buttons.
    - **No Title**: Removed the title "My Profile" at the top of the My Profile page.
    - **Bio editing**: The description bio field enforces a max length of 150 characters with a live character counter.
  - **Settings Page**:
    - **Background Rendering**: Render settings options directly on the app background (no cards/containers).
    - **Subpages**: Appearance and Change Password options are moved to subpages with navigation buttons on the main Settings page.
    - **Change Password**: Secured change password flow verifying current credentials and enforcing the 5 safety rules.
    - **Logout**: The logout button has no subtitle.
  - **Mobile Search UX Tweaks**:
    - **User Search - Compact**: Stacks the username vertically under the full name.
    - **User Search - Grid**: Shows the banner above the profile picture, username, and full name, and removes the trailing chevron/arrow.
    - **Competition Search**: Added compact/grid layout toggles via a popup menu and a results count indicator. Shows list items as `CompetitionCompactRow` or `CompetitionCard` respectively.

---

## 4. Technical Stack
- **Frontend**: Flutter.
- **Backend & Database**: Supabase. Banners are stored client-side deterministically in the public `avatars` bucket at `profiles/{userId}/banner.jpg` to avoid DDL schema changes.
- **State Management**: Provider.

---

## 5. Domain Rules (Streetlifting)
(Unchanged)
