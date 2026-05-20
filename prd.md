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
- **Responsive Search Feed:** A premium dashboard that scales dynamically across Desktop (3-column grid), Tablet (2-column grid), and Mobile (1-column list).
- **Guest Access:** All upcoming competitions must be searchable and viewable without user login or authentication.
- **Dynamic Search & Filtering:**
  - Full-text search matching competition title or location.
  - Filter by Streetlifting Subtype: **Modern** or **Classic**.
  - Filter by Competition Group: **FinalRep Underground**, **FinalRep Qualifier**, **FinalRep Final**, or **Individual** (independent meets).
- **Event Detail & Card Layout:**
  - Clear labeling of disciplines (MU, PU, DP, SQ) based on the format.
  - Highlighting of the associated Competition Group (if any).
  - Dynamic visual interaction (hover glow, movement offsets, responsive color themes).
  - Direct details overlay summarizing competition schedules and official weight classes.

---

## 4. Technical Stack
- **Frontend Framework:** Flutter (Multiplatform targeting Web, Android, and iOS).
- **Backend & Database:** Supabase (Remote PostgreSQL database with Row Level Security enabled).
- **State Management:** Provider pattern for reactive search state and data flow.
- **Assets:** Custom SVGs (`finalrep_icon.svg` and `finalrep_logo.svg`) for official branding representation.
- **Hosting/Runtime:** Cross-platform web compiler output.

---

## 5. Domain Rules (Streetlifting)
Streetlifting is a young, urban strength sport based on the **One-Rep-Max (1RM)** format. 

### Disciplines
1. **Modern Format (4 Disciplines):**
   - Muscle Up
   - Pull Up
   - Dip
   - Squat
2. **Classic Format (2 Disciplines):**
   - Pull Up
   - Dip

### Competition Format
- Each athlete gets **3 attempts** per discipline.
- Only the highest valid attempt weight per discipline counts toward the total.
- Total = Sum of the highest valid attempts.
- Winners are determined per weight class based on the highest total.

### Official Weight Classes
- **Men:** -66 kg, -73 kg, -80 kg, -87 kg, -101 kg, +101 kg
- **Women:** -52 kg, -57 kg, -63 kg, -70 kg, +70 kg

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
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

---

## 7. Future Scope & Roadmap
- **User Authentication:** Athlete registration and profiles linked to Supabase Auth.
- **Competition Entry:** Payment and signup flow for athletes to register for upcoming meets.
- **Live Leaderboard:** Real-time score entry for attempts (1st, 2nd, 3rd) during ongoing meets.
- **Doping-Test Registry:** Integration of testing records to guarantee clean sports standards.
