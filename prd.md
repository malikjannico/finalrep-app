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
  - **Desktop**: Main header features a centered search bar (with real-time dropdown results), left-aligned FinalRep Icon in brand color `#E94E1B`, and right-aligned zero-animation theme toggle. A dedicated navigation bar is positioned below the header, displaying centered navigation tabs for "Competitions" and "World Map" without active-item underline decoration.
  - **Mobile**: Top header has a centered FinalRep Icon, a hamburger menu icon (left) that opens a navigation/app drawer, and a search icon (right) that opens a full-screen mobile search view (with search placeholder "Search Competitions"). A bottom navigation bar with icons and labels switches between the "Competitions" and "World Map" views.
- **Dynamic Search & Filtering (Competitions View)**:
  - **Desktop Sidebar**: Left-aligned, always-visible filter panel with a "Filters" header title at the top, followed by collapsible sections for Sport, Format, Group, Location, and Date. Options are displayed as checkboxes with the count of matches next to them. The date filter uses a docked input selector.
  - **Mobile Filter Drawer**: A slide-in right drawer (`openEndDrawer`) triggered by a filter icon in the competitions view, mirroring the collapsible checkbox layout.
  - **Default Behavior**: No default filters are applied at startup (all competitions are shown initially).
  - **Results Indicator**: Displays results count as "X competitions" on mobile.
  - **Filter Chips**: All applied filters are displayed as chips categorized by type under the results header, with an easy remove `[x]` functionality.
  - **Sorting & Layouts**: A unified action button design: Sort button is a clean icon-only `PopupMenuButton` triggering sorting variations ("Date: Asc", "Date: Desc", "Name: A-Z", "Name: Z-A"), and Layout toggle switches between a visual Card grid layout and a high-density Compact list row layout. All action icons share identical size and styling (`onSurfaceVariant` color).
- **Single Competition Detail View**:
  - A premium detail page for individual competitions containing a hero banner, Floating Group/Individual badge, location address, date, disciplines explanation list, and registration status.
- **Interactive World Map View**:
  - An interactive vector-dot world map showing upcoming competition markers with pulsing radar rings. Clicking a marker reveals a popup card linking to that competition's detail view.
  - Fully constrained navigation: Zooming out is restricted (dynamically calculated `minZoom` based on viewport constraints, minimum 1.8), and a strict `cameraConstraint` restricts camera panning to keep the map centered and prevent background borders/empty space from being exposed.
- **Guest Access**: All upcoming competitions, map pins, and details must be searchable and viewable without user login or authentication.


---

## 4. Technical Stack
- **Frontend Framework**: Flutter (Multiplatform targeting Web, Android, and iOS).
- **Backend & Database**: Supabase (Remote PostgreSQL database with Row Level Security enabled).
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

---

## 7. Future Scope & Roadmap
- **User Authentication**: Athlete registration and profiles linked to Supabase Auth.
- **Competition Entry**: Payment and signup flow for athletes to register for upcoming meets.
- **Live Leaderboard**: Real-time score entry for attempts (1st, 2nd, 3rd) during ongoing meets.
- **Doping-Test Registry**: Integration of testing records to guarantee clean sports standards.
