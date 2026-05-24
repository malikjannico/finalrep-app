# Original User Request

## Initial Request — 2026-05-23T22:27:44+02:00

Implement a set of refinements, UX improvements, bug fixes, and feature additions to the Profile, Navigation, and Administration sections of the FinalRep Streetlifting application.

Working directory: `/Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/profile-navigation-dashboard-updates`
Integrity mode: development

## Requirements

### R1. Profile Page UX & Alignment Improvements
- **Profile Photo Placement:** Position the profile image above the Full Name and username, left-aligned (rather than shifted too far to the left).
- **Personal Records (PRs):**
  - Increase the font/display size of the PR scores.
  - Standardize and correct the names and order of disciplines: Muscle Up > Pull Up > Dip > Squat (remove "Weighted" from all names).
  - Include the competition name and competition date next to/within each personal record.
- **Highest Rankings:** Show only the "Overall" ranking with its associated Competition Name, location, and date.
- **Visual & Icons:** Use cleaner, monocolor icons instead of the current colorful icons on the profile page.
- **Competition Section Titles:**
  - Update "Upcoming Meets" to "Upcoming Competitions".
  - Update "Completed Meets" to "Completed Competitions".
- **Upcoming Competition Rankings Bug:** Fix the bug where user `@malikjannico` has rankings displayed from "FinalRep Qualifier Hamburg 2026", even though that competition is upcoming and has not completed.
- **Edit Profile Mode Changes:**
  - Profile Picture Hover: Fix the bug where hovering over "upload profile picture" displays a square outline rather than matching the circle shape.
  - Dashboard Visibility: In edit mode, hide the athlete dashboard.
  - Navigation Links: Configure each element/card in the athlete dashboard to navigate to its respective single competition details page.
- **Mobile Scrolling UX:** On mobile, the profile header should start hidden (or collapse) and only become visible when scrolling down (mimicking the header scrolling behavior in the single competition page).
- **Mobile Spacing:** Reduce the layout gap between the Full Name and the profile picture.

### R2. Navigation, Layout & Views Refactoring
- **Desktop/Mobile Navigation:**
  - Fix the bug where "Associations" is missing from the desktop subheader and the mobile bottom navigation bar.
  - Fix the navigation drawer theme bug where "Associations" displays in a different color from other nav items.
  - Add a "Ranking" navigation item to the desktop subheader, mobile bottom nav, and mobile drawer.
- **Navigation Item Ordering:**
  - Desktop Subheader: Competitions, Associations, Ranking, My Profile
  - Mobile bottom nav bar: Competitions, Associations, Ranking, My Profile
  - Mobile navigation drawer: Competitions, Associations, Ranking, My Profile, Settings (with logout separated by a horizontal divider).
- **Desktop Subheader Alignment:** Left-align all nav items on the subheader.
- **Dynamic View Mode Dropdown:**
  - Add a dropdown button at the beginning (left) of the desktop subheader and in the mobile drawer (above all nav items, below the profile details, separated by a line).
  - Dropdown values: "All" (global normal user view), "Management", "Administration", with matching icons.
  - Visibility rules:
    - If the user has management privileges, show "All" and "Management".
    - If the user has administration privileges, show all three.
    - Otherwise, hide the dropdown.
  - Filtering rules:
    - Management view: subheader, drawer, and nav bar must only display "Competition Mgmt" and "Association Mgmt" items.
    - Administration view: subheader, drawer, and nav bar must only display administration page items.
- **Associations View:**
  - Implement a paginated/filtered list of created associations (similar to the competitions list).
  - Set the navigation bar/drawer links to direct to this view.
  - If a user lacks permission to create associations, display a small banner with a link to the application page.
- **Competitions View:**
  - Allow all users (including unregistered/guests) to toggle between "Upcoming" and "Completed" events using a toggle switch (matching the style of the mobile admin dashboard).
  - If a user lacks permission to create competitions, display a small banner with a link to the application page.

### R3. Administration Dashboard Improvements
- **Permission Requests:** In the permission requests table, show the user's Full Name and username instead of just their User ID.
- **Sports Configuration:**
  - Rename the "Sport Config" navigation item to "Configuration".
  - Redesign the mobile configuration page layout to optimize the user experience under Google quality standards.
- **User Management Page:**
  - Add a "Users" page under Admin Dashboard listing all users.
  - Clicking a user must navigate to a single user administration page.
  - The user admin page must contain a Privileges section allowing admins to manually toggle/grant creator and admin privileges directly without going through the requests flow.

### R4. Search Functionality Expansion
- Add the ability to search for and view Associations inside both the desktop and mobile search bars.

### R5. Settings Page Adjustments
- **Creator Privileges Button:**
  - Update the subtitle/description to "Apply to create associations or competitions".
  - If a user has one privilege (e.g. competition creator), update the description to reflect this.
  - If a user has both privileges, hide the button/section.
- **Apply Privileges Modal:** Update the Submit button color to align with `design.md` style guidelines and other system buttons.

## Acceptance Criteria

### Verification Rules
- [ ] All existing 153 tests in the test suite pass successfully.
- [ ] New unit and widget tests are written to verify the new/updated views, dropdown filters, privileges management, and associations search.
- [ ] The app builds cleanly on Flutter without analysis errors or layout overflow warnings.

## Follow-up — 2026-05-23T21:09:51Z

Hi! The user has requested to add an additional requirement to the current project: "R6. Environment Configuration Setup".

I have updated the prompt_draft.md file with this new requirement:
### R6. Environment Configuration Setup
- Environment JSON Files: Create environment-specific configurations in JSON files under config/: config/env_dev.json, config/env_staging.json, and config/env_prod.json. Each file must define ENV, SUPABASE_URL, and SUPABASE_ANON_KEY.
- Application Startup Injection: Refactor lib/main.dart (or the startup/repository initialization flow) to load these environment variables dynamically using String.fromEnvironment.
- Strict Mock Safety: If the environment is staging or production, require valid Supabase keys and throw/assert an error if initialization fails or if fallback mock databases are triggered. Allow mock database configurations only when the environment is explicitly set to dev and Supabase keys are empty.

Please update the project sentinel plan and the orchestrator's requirements to include this environment configuration task, so that it is implemented and verified together with the rest of the refinements.

