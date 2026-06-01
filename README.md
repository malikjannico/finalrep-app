# FinalRep Streetlifting App

FinalRep is a responsive, cross-platform sport competition management and search application designed specifically for **Streetlifting**. It provides unregistered users with guest search/filter feeds for meets, and offers registered users personalized profiles, layout customization, and secure authentication flows.

---

## 🚀 Key Features

### 🔐 Authentication & Security
- **Multi-step Onboarding**: User accounts are registered through a 3-step wizard (Account ➔ Details ➔ Avatar) with built-in state preservation.
- **Registration Constraints**: Dynamically enforces lowercase-only usernames, used/max character limits, and real-time database checks.
- **Forgot Password**: Password reset triggers on the Login page supporting either username or email.
- **Deep-Linked Password Recovery**: Intercepts recovery links directly in-app, presenting a 5-rule secure password update wizard.
- **Database Query Safety & UUID Validation**: Validates dynamic path parameters and database queries checking UUID columns (such as profile, competition, or association IDs) against a standard UUID format before querying the PostgreSQL database, preventing database syntax errors (22P02) and improving API resilience.
- **Sex and Gender Field Standardization**: Profile `gender` field is renamed to `sex` across user accounts, registration inputs, profiles, and database tables. Profile `sex` values are stored strictly lowercase in the database (`'male'`, `'female'`, `'other'`, `'prefer not to say'`), and formatted/capitalized in the presentation layer (UI) for displays. Similarly, athlete group `gender` values are stored as strictly lowercase (`'men'`, `'women'`, `'open'`).
- **Database Schema Table Renames**: Renamed the database tables `public.meet_registrations` $\rightarrow$ `public.athlete_registrations` and `public.meet_results` $\rightarrow$ `public.competition_results` across the database DDL, helper queries, frontend repositories, mock setups, and documentation for improved domain model alignment.

### 👤 Profile Customization
- **Modern Layout**: Renders profile information directly on the scaffold background for a premium, clean aesthetic.
- **Profile Banner**: Slot for user banner images at the top of the profile page, incorporating pick-and-upload options.
- **Competitions & Achievements**: Tabs showing upcoming/completed meets, highest rankings per sport/format, and personal records (PRs) per discipline.
- **Inline Desktop Mode**: Renders user profiles inline under the header/subheader when selecting "My Profile".
- **Visual Alignments & Scroll Effects**: Placed the settings icon directly behind the Full Name, tightened avatar-to-text gaps (12px), and configured `extendBodyBehindAppBar: true` with a transparent header app bar that fades in the `@username` title and solid background only after scrolling past `230` pixels, eliminating top-edge gaps on mobile. Includes circular semi-transparent back button overlay on the banner.
- **State Initialization Protection**: Initialized TextEditingControllers inline to prevent JS runtime null reference errors during widget unmounting and disposal.
- **Searchable Country & Premium Sex Selectors**: The profile edit mode incorporates a dynamic searchable country selector dialog overlay filtering list elements in real-time, and a premium custom `PopupMenuButton`-based sex dropdown complying with Material Design and Google UI/UX guidelines.

### 👑 System Administration & Configurator
- **Permissions Access & Applications**: Organizers and federations apply for creation permissions (competition and/or association) with a reason.
- **Admin Dashboard**: Panel for administrators to accept/reject applications, configure sports, formats, and disciplines, and manage users. Disabled swipe gestures on administration tabs.
- **Desktop Inline Config & Creation**: Subpage configuration details (Sports, Formats, Disciplines) and creation forms render inline under the subheader on desktop viewports with a breadcrumb trail (`Configuration / Formats / Create Format`) and top-right save/cancel actions, while mobile layouts use compact card lists and bottom Floating Action Buttons.
- **Discipline Search/Filtering**: Search and filter disciplines dynamically during format mapping while preserving current checkbox selection states.
- **Brand Design Sync**: Configurator action buttons styled using brand orange (`#E94E1B`), bold text, and 20px rounded corners.

### 🏢 Associations & Management
- **Scroll-Free 5-Step Stepper**: Split association registration into 5 scroll-free steps: General Info ➔ Scope & Address ➔ Media Assets ➔ Sports & Rulebooks ➔ Social Channels.
- **Local Scope Address Side-by-Side**: Places ZIP Code and City fields side-by-side in Step 2.
- **Multi-Select Sports**: Supports configuring multiple sports. Added sports are listed in cards with their selected formats, rulebook URLs, and linked disciplines.
- **Centered Brand Icons**: Social media prefix brand icons centered inside containers to prevent clipping and align correctly.
- **Association View Layout Refactoring**: Redesigned the association detail view (`lib/views/association_detail_page.dart`) to mirror the user profile design, incorporating a 150-height banner, 40-radius overlapping logo, flat info sections (un-carded description block, vertical scope/territory dividers, grouped sports/formats, and carded rulebooks list), and relocated settings/share action buttons to a body-aligned row.
- **Unified Website & Social Channels**: Displays website and social channels under a single section title using brand icons and clean handles (removing platform prefix labels and extracting handles from full URLs).
- **Management Panel**: Manage user roles (Owner, Editor), athlete weight classes, and active competition groups.
- **Unified Sidebar UI**: Placed warning banners and unified search-less filtering (Scope, Country, Sport), sorting (A-Z/Z-A), and layout switching (Grid vs List) options in a left sidebar on desktop and an end drawer on mobile, matching the Competitions feed.
- **Expanded Dialog Widths**: Increased width constraint of the add/update member dialogs, competition group dialogs, and athlete group dialogs from 650px to 800px to enhance text readability and modal spacing.
- **Permission Casing Normalization**: Corrected selected permission levels in dropdowns (e.g. "Owner", "Editor" instead of "OWNER", "EDITOR") to match exactly how items appear in the selection menu list.
- **Athlete Groups Decoupling**: Completely decoupled athlete groups from competition groups by removing the `competition_group_id` foreign key column from the database schema and models. Renders flat, decoupled lists of athlete groups grouped directly by `Sport -> Format -> Gender` under the Association Management Page, and removed all competition group selectors from athlete group creation/update modals.
- **Bulk Creation Flow ("Save + Create")**: Competition and athlete group creation modals feature a "Save + Create" button that validates, registers, and resets input fields while keeping the modal open, and always reloads parent dashboard data upon modal dismissal.
- **Custom Member Title & Owner Management**: Supports editing owner custom titles from the Member Tab card, placing custom title cards in front of the permission chips (`[Member Title Chip] [Permission Chip]`), while disabling role modifications or removal for the single primary owner.
- **Inline Athlete Groups Reordering**: Tapping the **Reorder** button in the Athlete Groups management tab enters an inline edit state replacing default edit/delete actions with **Save Order** and **Cancel** buttons. Supports drag-and-drop sequencing within subsections (Sport/Format/Gender) utilizing a custom `Material` drag proxy decorator (to maintain shadow elevation and rounded border aesthetics) and a leading drag handle (`Icons.drag_handle`) to prevent margin overflows.
- **Share Modal Static Footer**: Restructured the layout of the share modal (`ShareResourceDialog`) to restrict height to a maximum of 600px with an independent scrollable body and moved the Cancel and Save action buttons to the bottom-right corner as a static footer, aligning with the Explore Shared Modal layout.
- **Sport Configuration Search & Multi-Selection**: Upgraded the sport configuration dialog (`SportConfigDialog`) to display format selections as a vertical list of cards (showing checkboxes, shared badges, and discipline chips) and integrated a dynamic search bar (`TextField`) to filter formats in real-time.
- **Applied Shared Resource Restrictions**: Applied shared sports, formats, and rulebooks are locked as read-only. Shows a `SHARED` badge next to shared formats and disables checkbox changes. Hides the configured sports "Edit" button if all formats are applied shared, and hides the "Delete" button if any format is applied shared. Renders applied shared rulebooks as grayed-out blocks without share actions, and limits rulebook sharing to local resources only.
- **Configured Sports Cards Redesign**: Updated the configured sports card layout on the association metadata tab to render formats as individual Cards containing their disciplines as compact chips, separated from rulebooks using a clean `Divider` line.
- **Layout Overflow Protection**: Wrapped the configured sports header section in a `Wrap` layout instead of a `Row` to resolve and prevent rendering overflows.


### 🏆 Competition Setup & Streetlifting Rules Engine
- **Step-by-step Stepper**: Setup names, geocoded addresses, flexible date pickers, registration modes (FCFS vs approval), rich-text description edits, disclaimers, and volunteer shifting plans.
- **Backend Nominatim Proxy**: Replaced all direct Nominatim client lookups (CORS blocked on web) with a secure GET `/location/search` endpoint on the Dart Frog backend. Implements recursive comma-segmented address sanitization retries to dynamically ignore prefixed venue names (like `"WYSH.Fitness"`) if initial lookups yield empty results.
- **Location Name Field Removal**: Eliminated the redundant "Location Name" field from both competition creation and management panels, using the verified geolocated address as the single source of truth.
- **Ranking Type dropdown**: Cleaned up the competition creation page dropdown labels to list `"Open"`, `"By Gender"`, and `"By Athlete Group"` with mapped UI selection bindings.
- **Modern Rules Engine**: Supports Muscle Up, Pull Up, Dip, and Squat lifts under ascending weight orders.
- **Plate Calculator**: Computes plate loadings (1.25kg to 25kg) and micro-weights.
- **Judging Panel**: Referees vote on attempts; rules enforce majority (2:1 dips/squats depth) vs unanimous (3:0 other rules) scoring.
- **Video Assisted Referee (VAR):** Managers and coaches track and resolve 1 video review request per meet.
- **FinalRep Underground**: This competition group has been configured to exist **exclusively in the Modern format** (Muscle Up, Pull Up, Dip, Squat) in all mock repositories, test suites, and remote PostgreSQL tables.
- **Sex-Based Athlete Group Registration Eligibility**: Enforces registration rules that check a user's profile `sex` against an athlete group's `gender`. Men athlete groups (lowercase `'men'`) allow users with sex `'male'` or `'other'`. Women athlete groups (lowercase `'women'`) allow users with sex `'female'` or `'other'`. Open athlete groups are eligible for all users. Users with unset or `'prefer not to say'` sex settings are blocked from registering for restricted Men/Women groups with an validation error prompting them to update their settings.

### 🔍 Navigation & Global Search
- **Navigator 2.0 & Declarative Routing**: Replaced traditional imperative navigation (Navigator 1.0) with declarative routing using the `go_router` package. This supports native browser back/forward flows, deep linking, and synchronized URL state management.
- **Association Management Sub-Routes & Deep Linking**: Added five explicit sub-routes for each management tab under `/management/associations/:id` (`/metadata`, `/members`, `/compgroups`, `/athletegroups`, `/network`), redirecting the parent route to `/metadata` by default. Includes a responsive page-builder helper and asynchronous AuthProvider loading verification to preserve route state during initial startup session resolution.
- **Top-Level Flat Routes**: Registered subpages (`/settings/appearance`, `/settings/updatesecurity`, `/login`, `/register`) as flat, top-level paths in the global GoRouter configuration to ensure clean, direct path matching and correct URL formatting.
- **Imperative URL Synchronization**: Configured `GoRouter.optionURLReflectsImperativeAPIs = true` in the application entrypoint (`lib/main.dart`) to ensure that imperative navigation operations (`goRouter.push` / `goRouter.pushReplacement`) dynamically update and synchronize the browser's address bar.
- **GoRouter Context Validation & Test Fallbacks**: Guarded all GoRouter navigation triggers with a try-catch pattern that explicitly invokes `GoRouter.of(context)`. If the context does not contain a GoRouter (which is standard when running isolated unit/widget tests under a standard `MaterialApp`), the system gracefully catches the assertion error and falls back to traditional imperative `Navigator` routing. Similarly, shell navigation calls in `HomeNavigationShell` check for router presence to guarantee isolated widget test compatibility.
- **Deep Link Back Button Fallbacks**: Refactored the AppBar back button action (leading back arrow) on `/login`, `/register`, `/settings`, `/settings/appearance`, and `/settings/updatesecurity` to query `Navigator.of(context).canPop()`. If the route cannot be popped (meaning the user landed on the route directly via a browser URL deep link or refresh), the back button performs fallback routing using `goRouter.go` to prevent popping to a blank/white screen:
  - `/login`, `/register`, and `/settings` go back to the root route `/` (competitions library page).
  - `/settings/appearance` and `/settings/updatesecurity` go back to the parent `/settings` page.
- **Tab State Persistence**: Refactored active explorer and management tabs inside `HomeNavigationShell` to render using `IndexedStack`. This keeps components like Rankings and Associations active in memory, preventing visual page flickers/reloads and preserving scroll positions and filter states during tab switches.
- **Search Query Tab Clearing**: Refactored tab navigation to automatically clear active search queries when switching to non-searchable tabs like "Rankings" and "Profile".
- **Desktop Inline Detail Views**: Embeds all user profiles and association detailed pages inline under the subheader in desktop viewports instead of executing global route pushes, and removed the inline "Back to search feed" back panel.
- **Search Recommendation Clicks**: Intercepts recommendations and overlays clicks on desktop view to update provider selection states (`selectProfile` / `selectAssociation`) directly inline under the subheader.
- **Scope Icon Indicators & Search Dropdown**: Desktop and mobile search bars display the selected scope's icon in the closed state and utilize a dropdown select menu to switch between search scopes ("Competitions", "Users", "Associations"), with active dropdown menu offset alignments. Switching search scope with an empty query only updates the active search scope state (hint text and suggestions list) without navigating away.
- **Hover-Active Navigation Components**: Implemented pointer cursor styles, opacity shifts, and text underlines on hover for association detail breadcrumbs and configuration page subheader tabs (Sports, Formats, and Disciplines).
- **Tab Collection Navigation**: Supports switching tab collections (All, Management, Administration) via a globe icon (`Icons.public`) selector.
- **Navigation Highlights Silencing**: Removed the "Users" navigation tab/item from bottom navigation, navigation drawer, and subheader nav bars. When user search results are open, silences navigation tab highlighting by setting the explorer tab index to `-1` and dynamically updating bottom navigation selection colors.
- **Mobile Bottom Navigation Labels**: Hidden to only show icons on mobile viewports for a cleaner layout.
- **Drawer Tab Collection Dropdown**: Styled as a standard navigation `ListTile` with matching icons and fonts. Wrapped in a container with a solid bottom border decoration.

### 📊 Rankings & Notifications
- **Global Rankings View**: Includes responsive Left Sidebar filter panel on desktop and `endDrawer` on mobile with Sport, Format, and Gender filters.
- **Rankings Layouts**: Multi-view layout switching between:
  - **Table View**: Constrained full-width table showing rank, bold headers, and links to competition and athlete profile details.
  - **Compact View**: Clean vertical list of cards.
  - **Grid View**: Responsive card grid of athletes and lift details.
- **Athlete Auto-scroll**: Incorporates an Autocomplete query search for athletes that automatically scrolls the viewport to target the selected athlete's row/card.
- **System Notifications**: Organizers and athletes receive live alerts for payment deadlines, registration approvals, schedule releases, and flight listings.
- **Database Notification Security**: Avoids database foreign key `user_id` constraint violations on the `notifications` table by conditionally resolving the notification target to `assoc.ownerId` in production. Wraps all notification writes in `try-catch` blocks to protect the main user transaction against database notification write issues.

---

## 🛠️ Tech Stack
- **Frontend**: Flutter (targeting Web and Mobile)
- **Backend**: Dart Frog (Dart backend server framework)
- **Database**: Google Cloud SQL (PostgreSQL 15)
- **Auth**: Google Cloud Identity Platform (Firebase Auth)
- **Storage**: Google Cloud Storage (GCS)
- **State Management**: Provider

---

## 🏁 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.12.0 or newer recommended)
- Android Studio / Xcode (for mobile emulator testing)

### Installation
1. Clone the repository and navigate to the project directory:
   ```bash
   git clone <repository-url>
   cd finalrep-app
   ```
2. Retrieve the dependencies:
   ```bash
   flutter pub get
   ```

### Running Locally

#### 1. Start the Backend API
Navigate to the `backend/` directory, get dependencies, and start the Dart Frog development server:
```bash
cd backend
dart pub get
dart pub global run dart_frog_cli:dart_frog dev
```

*Note: Ensure the local Cloud SQL proxy or local PostgreSQL database is running on port 5432. Local media uploads (avatars, banners) are stored under the root `backend/uploads/` folder and served dynamically via `/uploads/[name]`. Do NOT create a `backend/public/uploads` folder, as Dart Frog's static file handler will intercept requests and serve them without CORS headers, breaking image rendering in the web app.*

#### 2. Start the Flutter Web Client
Launch the Flutter application targeting Chrome, passing the environment configuration file:
```bash
flutter run -d chrome --dart-define-from-file=config/env_dev.json
```

---

## 🧪 Running Tests
The project features a comprehensive widget, unit, and integration testing suite.

To execute the test suite:
```bash
flutter test
```
