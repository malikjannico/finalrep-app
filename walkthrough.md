# Walkthrough — FinalRep Streetlifting Platform Features Update

We have implemented a comprehensive set of features for the FinalRep Streetlifting application, covering authentication, profile statistics, administration controls, association setups, competition wizard options, Streetlifting Modern rules engine, platform judging panel, rankings, and notification alerts.

---

## 🛠️ Changes Implemented

### 1. Authentication & Custom Profile Customization (Milestone 1)
- **Login & Forgot Password**: 
  - Dynamically forces username input fields to lowercase on the login page.
  - Allows inputs of email OR username for forgotten password recoveries.
- **Profile Enhancements**:
  - Shifts profile pictures upwards by half of their height overlaying the banner.
  - Aligns full name, username, gender, and country underneath the profile image.
  - Renders settings gears next to full name instead of username.
  - Displays social channels with brand-specific icons and names.
  - Shows tabs/lists for upcoming/completed meets, personal records, and highest ranks per sport/format.
  - Renders other user profiles inline under headers on desktop with zero-gap banners.

### 2. System Administration & Configurator (Milestone 2)
- Restricts competition and association creation to users with approved permissions.
- Provides forms for users to apply for permissions with text reasons.
- Dashboard for administrators to list applied/accepted users, approve/reject applications, and promote other users to admin status.
- Configurator for adding/renaming sports, format types, and disciplines, and mapping disciplines to formats.

### 3. Associations & Management (Milestone 2)
- Multi-step creation flow specifying Name, Picture, Banner, Scope (Global, Area, National), website, and parent associations.
- Detail page showing upcoming/completed meets, rulebooks, sub-associations, and team lists.
- Management panel for role configurations (Owner/Editor), transfer of ownership, team role assignments, and creating competition groups or athlete weight categories.

### 4. Competition Wizard & Setup (Milestone 3)
- Multi-step wizard capturing verified geocoded locations, pickers for dates, fee status, automatic description codes, rich-text description edits, limits, waiting list toggles, and safety zone banner uploads.
- Volunteer role applications allowing multiple choices and favorite priority rankings.
- Option to capture custom fields for athletes and volunteers, and disclaimer configurations.

### 5. Competition Handling & Streetlifting Rules Engine (Milestone 4)
- Manage access roles: Owner, Editor, and Viewer. Publish schedules, plan weigh-in slots/flights/ceremonies, and export roster data as CSV.
- Track weigh-in details (recorded bodyweights, disqualification markers).
- **Rules Engine**:
  - Muscle Up, Pull Up, Dip, Squat disciplines with 3 attempts under ascending weight orders.
  - Plate Calculator from standard plates (1.25kg to 25kg) and micro-weights.
  - Automatic attempt entry defaults and time limit overrides.
  - 1-minute attempt countdown timer.
  - Judging Panel (3 referees + 1 head judge) enforcing majority (2:1 for squats/dips depth) vs unanimous (3:0 for other rules) scoring.
  - VAR (Video Assistant Referee) request tracking (restores token if overruled).

### 6. Rankings & System Notifications (Milestone 5)
- Dynamic rankings feed filtering meets by sport/format and displaying total and discipline scores.
- System Notifications sending alerts on registration, payments, flight allocations, and schedule releases. Allows toggling category settings.

---

## 🧪 Verification & Test Results

### 1. E2E Test Suite (`test/e2e/`)
We added **30 comprehensive E2E tests** (Tiers 1-4) simulating the complete user experience:
- **Tier 1 (Feature Coverage)**: Validates Login & Forgot Password, Profile Customization, and Competitions feeds.
- **Tier 2 (Boundary & Corner)**: Tests validation limits and the Streetlifting scoreboard/voting logic.
- **Tier 3 (Cross-Feature)**: Validates authentication syncs, deep links, and onboarding wizards.
- **Tier 4 (Real-World)**: Simulates spectator meet discovery and athlete registration paths.

### 2. Unit and Widget Tests
Added comprehensive test configurations covering:
- Streetlifting rules engine calculations (ascending attempts, plate selection).
- Platform judging and VAR overrule state validations.
- Administration roles, permission flows, and notification alerts.

Total project test suite has been successfully expanded to **153 tests**, all passing cleanly.

### 7. Exclusive Modern Format Support for FinalRep Underground
- Updated the `FinalRep Underground` competition group to exist exclusively in the **Modern** format in the local mock repository as well as the remote Supabase database.
- Removed `group-2` (the Classic format version of `FinalRep Underground`) from the database and the mock competition groups.
- Set the format subtype of mock completed competitions under `FinalRep Underground` (such as `mock-meet-2` and `mock-meet-3`) to **Modern** format.
- Updated unit test mock competitions and count assertions to verify that all competitions in `FinalRep Underground` filter as Modern format meets.
