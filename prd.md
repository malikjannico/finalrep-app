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

## 3. Core Features (MVP)
- **Responsive Header & Navigation**:
  - **Desktop**: Main header features a centered search bar (with real-time dropdown results and search scope selector), left-aligned FinalRep Icon in brand color `#E94E1B`, right-aligned profile page navigation shortcut (avatar/icon) when logged in (or Login/Register buttons when guest), and a zero-animation Color Mode toggle. A dedicated navigation bar is positioned below the header, displaying centered navigation tabs for "Competitions" and "World Map" without active-item underline decoration.
  - **Mobile**: Top header has a centered FinalRep Icon, a hamburger menu icon (left) that opens a navigation/app drawer (containing links to "Competitions", "World Map", and "Profile" if logged in), and a search icon (right) that opens a full-screen mobile search view (with search placeholder and scope selector). A bottom navigation bar with icons and labels switches between the "Competitions" and "Profile" views. In mobile view, users can open the navigation/app drawer (hamburger menu) with a swipe to the right and close it with a swipe to the left (right-to-left), and open the filters drawer with a swipe to the left and close it with a swipe to the right (left-to-right) from the competitions feed page.
- **Dynamic Search & Filtering (Competitions View)**:
  - **Desktop Sidebar**: Left-aligned, always-visible filter panel with a "Filters" header title at the top, followed by collapsible sections for Sport, Format, Group, Location, and Date. Options are displayed as checkboxes enabling multi-selection across all filter sections (e.g. multi-selecting formats, groups, locations), with the count of matches next to them. The date filter uses a docked input selector.
  - **Mobile Filter Drawer**: A slide-in right drawer (`openEndDrawer`) triggered by a filter icon in the competitions view, mirroring the collapsible checkbox layout. Filters are applied immediately on selection; the redundant "Apply" and "Reset All" drawer buttons are removed, with the "Reset All" action exposed at the end of the active filter chips list.
  - **Default Behavior**: No default filters are applied at startup (all competitions are shown initially).
  - **Results Indicator**: Displays results count as "[Number of Competitions] Competitions" on both mobile and desktop views.
  - **Filter Chips**: All applied filters are displayed as chips categorized by type under the results header, with an easy remove `[x]` functionality.
  - **Sorting & Layouts**: A unified action button design: Sort button is a clean icon-only `PopupMenuButton` triggering sorting variations ("Date: Asc", "Date: Desc", "Name: A-Z", "Name: Z-A"). Layout selection is combined into a single, premium `PopupMenuButton<CompetitionsLayout>` dropdown: the trigger button displays only the icon of the active layout (Grid, Compact, or Map) in standard `onSurfaceVariant` theme color (no orange accent), whereas the dropdown items list displays both the icon and text labels (Grid Layout, Compact Layout, Map Layout) with the active selection highlighted in bold. Hover effects (active state translation, border, and shadow changes) on cards and compact rows are automatically disabled in mobile view.
- **Search Bar Selection (Competition vs. User)**:
  - In both mobile and desktop views, the search bar includes a toggle/dropdown allowing users to switch the search scope between "Competitions" and "Users".
  - Searching for "Users" queries active user profiles by username or full name, returning matching user profiles.
- **Single Competition Detail View**:
  - A premium detail page for individual competitions containing a hero banner, Floating Group/Individual badge, location address, date, disciplines explanation list, and registration status.
  - **Sharing & Deep Linking**: Users can share the competition by copying its URL to the clipboard. The shared URL matches the pattern `/competitions/{id}` across all environments:
    - **Web**: Uses `Uri.base.origin` to dynamically determine the host/port (e.g. `http://localhost:52900/competitions/UUID` in dev or `https://app.final-rep.com/competitions/UUID` in production).
    - **Mobile**: Configurable via compile-time definition `--dart-define=APP_DOMAIN=...` (defaults to `app.final-rep.com`).
    When navigating directly to a shared URL path (e.g. at startup or reload), the app automatically intercepts the path/query parameters and routes the user directly to that competition's detail view.
  - **Volunteer Application**: An "Apply as Volunteer" button is available below other call-to-actions to register spectator interest.
- **Interactive World Map View**:
  - An interactive vector-dot world map showing upcoming competition markers with pulsing radar rings. The map view shares the same sidebar/drawer filters and active filter chips as the competitions feed view. The static map title and description are removed, displaying the unified results number indicator ("[Number of Competitions] Competitions") instead. Clicking a marker reveals a popup card linking to that competition's detail view.
  - Fully constrained navigation: Zooming out is restricted (dynamically calculated `minZoom` based on viewport constraints, minimum 1.8), and a strict `cameraConstraint` restricts camera panning to keep the map centered and prevent background borders/empty space from being exposed.
- **Guest Access**: All upcoming competitions, map pins, and details must be searchable and viewable without user login or authentication.
- **User Authentication & Profiles**:
  - **Register & Login**: Users can register and log in to the application.
  - **Registration Fields**: Registration requires username, full name, email, gender, country, and an optional profile picture.
  - **Login Methods**: Users can log in using either:
    - Email + Password
    - Username + Password
  - **Profile Page & Customization**:
    - A profile page is available for each registered user.
    - Users can add and edit a text description/bio on their profile page.
    - Users can update their profile fields: full name, email, gender, country, and manage active login methods.
  - **Default Color Mode**:
    - Users can define their preferred default color mode (System, Light, or Dark) in their profile settings.
    - Once a user logs in, the app automatically applies their preferred color mode.
  - **Logout**: Users can log out to end their session and return to guest mode.
  - **User Search**: Users can search for other user profiles using the unified search bar (by toggling search scope to "Users").
  - **Profile Sharing**: Users can share user profiles by copying a shareable profile URL (matching `/users/{username}` or `/profiles/{username}`). Navigating directly to this URL opens the corresponding profile page.


---

## 4. Technical Stack
- **Frontend Framework**: Flutter (Multiplatform targeting Web, Android, and iOS). Suppresses browser-deprecated `Intl.v8BreakIterator` warnings at launch to enforce standard native text segmenter fallback.
- **Backend, Database & Authentication**: Supabase (Remote PostgreSQL database with Row Level Security enabled, and Supabase Auth for managing user sessions and email/password credentials).
- **State Management**: Provider pattern for reactive search state, cascading logic, and filtering.
- **Assets**: Custom SVGs (`finalrep_icon.svg` and `finalrep_logo.svg`) and premium local photo assets for default competition images.
- **Hosting/Runtime**: Cross-platform web compiler output.

---

## 5. Domain Rules (Streetlifting)
Streetlifting is a young, urban strength sport based on the **One-Rep-Max (1RM)** format. 

### Disciplines
1. **Modern Format (4 Disciplines)**:
   - Muscle Up
   - Pull Up
   - Dip
   - Squat
2. **Classic Format (2 Disciplines)**:
   - Pull Up
   - Dip

### Competition Format
- Each athlete gets **3 attempts** per discipline.
- Only the highest valid attempt weight per discipline counts toward the total.
- Total = Sum of the highest valid attempts.
- Winners are determined per weight class based on the highest total.

### Official Weight Classes
- **Men**: -66 kg, -73 kg, -80 kg, -87 kg, -101 kg, +101 kg
- **Women**: -52 kg, -57 kg, -63 kg, -70 kg, +70 kg

---

## 6. Database Schema (Remote PostgreSQL)
The database contains a `competitions` table configured with Row Level Security (RLS) enabling public read-only access:

```sql
CREATE TABLE public.competitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    location TEXT NOT NULL,
    sport_type TEXT NOT NULL DEFAULT 'Streetlifting',
    sport_subtype TEXT NOT NULL CHECK (sport_subtype IN ('Modern', 'Classic')),
    comp_group_name TEXT,
    status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed')),
    area TEXT,
    country TEXT,
    city TEXT,
    title_image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

### Profiles Table
A `profiles` table stores user details and is linked to the Supabase Auth `users` table:

```sql
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL CHECK (char_length(username) >= 3),
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    gender TEXT,
    country TEXT,
    profile_picture_url TEXT,
    description TEXT,
    color_mode TEXT NOT NULL DEFAULT 'system' CHECK (color_mode IN ('system', 'light', 'dark')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Row Level Security (RLS) Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to profiles" 
ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Allow users to update their own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);
```

---

## 7. Future Scope & Roadmap
- **Passkey & SSO Authentication**: Passwordless login via Email/Username + Passkey (WebAuthn) and Single-Sign-On (SSO) via Google, Meta (Facebook, Instagram), or Apple.
- **Competition Entry**: Payment and signup flow for athletes to register for upcoming meets.
- **Live Leaderboard**: Real-time score entry for attempts (1st, 2nd, 3rd) during ongoing meets.
- **Doping-Test Registry**: Integration of testing records to guarantee clean sports standards.

---

## 8. Developer Guide & Environment Configuration

### Domain Configurations & URL Sharing
When a user clicks "Share" in a competition detail page, the app generates a shareable web link. The URL structure is dynamically resolved to ensure compatibility across web and mobile platforms.

- **Web Platform**: Automatically uses `Uri.base.origin` to match the exact environment (local development port or hosted production/staging domain).
- **Mobile Platforms (Android/iOS)**: Uses the `APP_DOMAIN` environment variable injected during compilation. If not specified, it defaults to the production domain `app.final-rep.com`.

### Compilation & Build Commands

For development and deployment across different environments (e.g. production, staging), developers must specify the domain variable when running or building the app:

- **Local Web / Development**:
  ```bash
  flutter run -d chrome
  ```
- **Staging Mobile Build (Android)**:
  ```bash
  flutter build apk --dart-define=APP_DOMAIN=staging.final-rep.com
  ```
- **Staging Mobile Build (iOS)**:
  ```bash
  flutter build ipa --dart-define=APP_DOMAIN=staging.final-rep.com
  ```
- **Production Mobile Build**:
  ```bash
  flutter build apk --dart-define=APP_DOMAIN=app.final-rep.com
  ```

> [!WARNING]
> **Dynamic Redirect Integration:** Remember to ensure that Universal Links (iOS) and App Links (Android) configurations are synchronized with the chosen `APP_DOMAIN` in their respective native hosting setups (e.g. `.well-known/apple-app-site-association` and `.well-known/assetlinks.json`) so the OS can intercept shared links and open them directly in the app.

---

## 9. Implementation Status
All MVP features described in this document have been fully implemented and verified on the branch `implement-user-authentication-system`:
- **User Authentication**: Login (email/username + password) and Sign Up are complete.
- **Profiles**: Edit bio, settings, color mode preferences, and share profile features are complete.
- **Deep Linking & URL Sync**: Handled startup deep link routing (`/competitions/:id`, `/profile`, `/auth`, `/users/:username`) and browser URL address bar synchronization without duplicate path or hash-fragment bugs.
- **Layout dropdowns**: Integrated layouts into a unified dropdown.
- **Search Race Conditions**: Resolved atomically.


