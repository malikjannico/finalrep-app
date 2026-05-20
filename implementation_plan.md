# Implementation Plan - FinalRep App Sport Competition Platform

Build a responsive sport competition platform named "FinalRep App" using Flutter and Supabase, based on the `design.md` color scheme. The initial version will feature a competition search feed supporting Streetlifting subtypes ("Modern" and "Classic") and competition groups (e.g., Qualifier, Underground, Final), accessible to unregistered users.

## User Review Required

> [!IMPORTANT]
> **Database Host & Keys**:
> - We will use the remote Supabase project `vnseudpajhkicezdcsuj` with URL `https://vnseudpajhkicezdcsuj.supabase.co` and the publishable/anon key.
> - Tables will be created directly on the remote database using the Supabase MCP server's `execute_sql` tool.
> - RLS (Row Level Security) will be enabled on all tables, permitting public read access for search functionality.

> [!WARNING]
> **Boilerplate and Assets**:
> - We will copy `finalrep_icon.svg` and `finalrep_logo.svg` into the assets directory of the newly created Flutter project.
> - We will define a Flutter theme that matches the Material 3 color tokens found in `design.md`.

## Proposed Changes

### Component 1: Database Setup (Supabase)

We will define the database schema for Streetlifting competitions and create the tables.

#### [NEW] Database Schema SQL
We will execute SQL to create the `competitions` table and set up RLS policies.

**Table `competitions`**:
- `id` (uuid, primary key, default `gen_random_uuid()`)
- `title` (text, not null)
- `description` (text)
- `start_date` (timestamptz, not null)
- `end_date` (timestamptz, not null)
- `location` (text, not null)
- `sport_type` (text, not null, default 'Streetlifting')
- `sport_subtype` (text, not null) -- 'Modern' or 'Classic'
- `comp_group_name` (text) -- e.g., 'FinalRep Underground', 'FinalRep Qualifier', 'FinalRep Final', or NULL for individual
- `status` (text, not null, default 'upcoming') -- 'upcoming', 'ongoing', 'completed'
- `created_at` (timestamptz, default `now()`)
- `updated_at` (timestamptz, default `now()`)

**RLS Policy**:
- Enable RLS.
- Add policy: `allow_public_read` -> `CREATE POLICY "Allow public read access" ON public.competitions FOR SELECT USING (true);`

---

### Component 2: Flutter Project Structure & Packages

Initialize a Flutter project at the root directory supporting `web`, `android`, and `ios`.

#### [NEW] `pubspec.yaml`
Add dependencies:
- `supabase_flutter: ^2.8.0` (or latest stable version)
- `flutter_svg: ^2.0.10` (to render `finalrep_icon.svg` and `finalrep_logo.svg`)
- `provider` or `flutter_riverpod` (for state management)
- `intl` (for date formatting)

Configure assets:
- `assets/finalrep_icon.svg`
- `assets/finalrep_logo.svg`

#### [NEW] Theme Configuration (`lib/theme.dart`)
Define `AppTheme` utilizing the Material Theme color tokens from `design.md`:
- Primary Color: `#8F4C37` (Light) / `#FFB59F` (Dark)
- Seed Color: `#E94E1B`
- Surface Colors and Typography scales mapped directly to the Flutter `ThemeData` to ensure rich, premium styling.

#### [NEW] Models (`lib/models/competition.dart`)
Define the `Competition` model with factory constructor `fromJson` and helper methods for Streetlifting disciplines (Modern vs. Classic) and attempt formats.

#### [NEW] Repositories (`lib/repositories/competition_repository.dart`)
Implement search and fetching using `SupabaseClient`:
- Filter by status (`upcoming`)
- Search query on title/location
- Filter by sport_subtype ('Modern', 'Classic')
- Filter by competition group (comp_group_name)

#### [NEW] State Management (`lib/providers/competition_provider.dart`)
Implement a provider to manage search queries, filters, loading states, and search results.

#### [NEW] UI Views & Components
- **Search Feed Page (`lib/views/search_feed_page.dart`)**:
  - Search bar.
  - Subtype filter chip (Modern, Classic, All).
  - Group filter chip (Underground, Qualifier, Final, All).
  - List/Grid layout of competition cards (responsive for mobile, tablet, and desktop).
- **Competition Card (`lib/widgets/competition_card.dart`)**:
  - Displays competition title, group, location, dates, and Streetlifting subtype.
  - Styled beautifully with glassmorphism touches and hover states using design system tokens.
- **Logo Widget (`lib/widgets/finalrep_logo.dart`)**:
  - Custom widget displaying the SVGs according to layout context.

---

### Component 3: Test Driven Development (TDD)

#### [NEW] Unit and Widget Tests
- **Unit Tests (`test/competition_model_test.dart`)**:
  - Verify JSON parsing of the competition model.
  - Verify subtype classification.
- **Mock Supabase Tests (`test/competition_repository_test.dart`)**:
  - Test searching and filtering of competitions with mock data.
- **Widget Tests (`test/search_feed_page_test.dart`)**:
  - Test rendering of the search feed, search bar, and filter chips.

## Verification Plan

### Automated Tests
We will run tests using the `dart-mcp-server` `run_tests` tool.
- Command: `flutter test` via MCP tool.

### Manual Verification
- We will build and run the web client using `dart-mcp-server/launch_app` to verify:
  - Responsive layout (scaling on mobile, tablet, and desktop).
  - Interactive search inputs and filter chips.
  - Visual fidelity (applying color system, SVGs, premium transitions).
