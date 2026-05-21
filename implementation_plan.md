# Implementation Plan - Competition Filtering and Header Redesign

We will enhance the FinalRep Sport Platform by updating the header layout, accelerating theme switching, adding navigation, moving the search bar to the header, replacing page titles, implementing cascading multi-select location filters (Area -> Country -> City), adding a calendar date-range filter, and supporting optional title images for each competition.

## User Review Required

> [!IMPORTANT]
> **Database Alterations:**
> We will add the following columns to the `public.competitions` table in Supabase:
> - `area` (text, nullable)
> - `country` (text, nullable)
> - `city` (text, nullable)
> - `title_image_url` (text, nullable)
>
> We will also insert two new mock competitions (one in New York, USA, and one in Tokyo, Japan) to demonstrate the cascading Area -> Country -> City filter behavior.

> [!TIP]
> **Cascading Filter UX:**
> Selecting an Area will limit the available Country options. Selecting a Country will limit the available City options. If a previously selected Country or City becomes invalid due to changing the parent selection, it will be automatically removed from the active selections to ensure a consistent filtering state.

## Proposed Changes

### Database & Models

---

#### [MODIFY] Supabase Database Schema
We will run a SQL script via the Supabase MCP tool to:
1. Alter the `public.competitions` table, adding `area`, `country`, `city`, and `title_image_url` columns.
2. Update the existing 5 competition rows to populate correct location details and sample title image paths/URLs.
3. Insert two new mock competitions:
   - `FinalRep USA Qualifier 2026` (Area: North America, Country: United States, City: New York)
   - `FinalRep Tokyo Streetlifting Cup 2026` (Area: Asia, Country: Japan, City: Tokyo)

#### [MODIFY] [competition.dart](file:///Users/malikjannico/Desktop/Development/finalrep-app/lib/models/competition.dart)
- Add nullable properties: `final String? area;`, `final String? country;`, `final String? city;`, and `final String? titleImageUrl;`.
- Update the constructor, `fromJson`, and `toJson` methods to parse and map these new fields.

---

### Repositories & State Management

---

#### [MODIFY] [competition_provider.dart](file:///Users/malikjannico/Desktop/Development/finalrep-app/lib/providers/competition_provider.dart)
- Add state properties:
  - `Set<String> _selectedAreas = {}`
  - `Set<String> _selectedCountries = {}`
  - `Set<String> _selectedCities = {}`
  - `DateTimeRange? _selectedDateRange`
- Implement getters and setters for the new filters.
- Update `clearFilters` to reset location and date range filters.
- Update `fetchCompetitions()` to fetch the upcoming competitions, then apply all filters client-side to dynamically generate the:
  - `availableAreas` (all unique areas from all upcoming competitions)
  - `availableCountries` (reduced based on `selectedAreas`)
  - `availableCities` (reduced based on `selectedAreas` and `selectedCountries`)
  - `filteredCompetitions` (the list of competitions displayed in the UI, filtered by subtype, group, search query, areas, countries, cities, and date range).

---

### UI Components

---

#### [MODIFY] [main.dart](file:///Users/malikjannico/Desktop/Development/finalrep-app/lib/main.dart)
- Set `themeAnimationDuration: Duration.zero` on the `MaterialApp` widget to make the light/dark mode transition instantaneous without fade animations.

#### [MODIFY] [search_feed_page.dart](file:///Users/malikjannico/Desktop/Development/finalrep-app/lib/views/search_feed_page.dart)
- **Header Redesign**:
  - Remove the double logo + icon setup. Use only the logo (`assets/finalrep_logo.svg`) and color it with `#E94E1B` using a ColorFilter.
  - Move the search bar `TextField` into the header.
  - Add a Navigation Bar next to the logo/search bar with "Competitions" as an active navigation element.
  - Remove the Hero section with "FinaRep Sport Platform" title.
  - Add the page title "Competitions" in the main body where the results are listed.
- **Cascading Multi-Select Filters**:
  - Add multi-select dropdown chips or a beautiful expansion filter panel for **Area**, **Country**, and **City**.
  - Show checkbox menus or multi-select option overlays for each.
- **Calendar Date Filter**:
  - Add a button that shows a calendar icon and the selected date range (or "All Dates").
  - Trigger Flutter's native `showDateRangePicker` when clicked to select the start and end dates.
  - Show a clear button ("x") to reset the date filter.

#### [MODIFY] [competition_card.dart](file:///Users/malikjannico/Desktop/Development/finalrep-app/lib/widgets/competition_card.dart)
- Check if `competition.titleImageUrl` is set.
- If set, render the image at the top of the card (height ~140px, rounded corners).
- If not set, show a beautiful premium gradient (seed color/primary container gradient) as a fallback.
- Overlay the Modern/Classic badge and Group name badge on top of the image/gradient.
- Position description, location, date, and disciplines details neatly below the image section.

---

### Assets

---

#### [NEW] Streetlifting Competition Images
- Generate 4-5 premium Streetlifting images using the `generate_image` tool and place them in `assets/images/`.
- Add the directory to `pubspec.yaml` assets so they can be loaded locally or referenced as fallback paths, or use public image URLs.

---

### Tests

---

#### [MODIFY] [competition_model_test.dart](file:///Users/malikjannico/Desktop/Development/finalrep-app/test/competition_model_test.dart)
- Update JSON payloads to include the new location fields (`area`, `country`, `city`) and `title_image_url`.
- Add test assertions verifying correct parsing of the new fields.

#### [MODIFY] [competition_provider_test.dart](file:///Users/malikjannico/Desktop/Development/finalrep-app/test/competition_provider_test.dart)
- Update mock competitions list in `MockCompetitionRepository` with the new fields.
- Add unit tests for cascading location filter behavior (Area -> Country -> City reduction).
- Add unit tests for the date range calendar filter.

#### [MODIFY] [widget_test.dart](file:///Users/malikjannico/Desktop/Development/finalrep-app/test/widget_test.dart)
- Update expectation to look for the "Competitions" page title instead of "FinalRep Sport Platform".
- Update widget interaction assertions to match the new header layout.

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure all unit and widget tests pass.

### Manual Verification
- Launch the application locally: `flutter run -d macos` or `flutter run -d chrome`.
- Click the theme toggle button to verify instant light/dark mode switching.
- Type in the header search bar and verify filtering works.
- Click the calendar filter, select date ranges, and verify competitions filter correctly.
- Test the Area, Country, City cascading multi-select filters:
  - Select "North America" and verify only "United States" and "New York" show up as options.
  - Select "Europe" and verify "Germany" and "Austria" are the country options, and their respective cities are the city options.
- Inspect the competition card layout to verify the title images display properly and fallback gracefully.
