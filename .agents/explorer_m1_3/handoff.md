# Handoff Report: User Profiles Customization (R2) UI Requirements Analysis

## 1. Observation
- File: `lib/views/profile_page.dart`
  - Name and Settings gear layout: lines 517–528 shows the full name text uses `Expanded`, pushing the settings gear to the far right.
  - Avatar positioning: lines 353–362 and 493–509 shows the banner is rendered above the profile header column, with no overlap.
  - AppBar configuration: lines 309–317 shows an `AppBar` is rendered even when `widget.isInline` is true.
- File: `lib/views/search_feed_page.dart`
  - Inline routing logic: lines 732–748 has logic only for the current user's profile inline view (`_desktopProfileActive`). Other profiles are navigated using `Navigator.push`.
  - Drawer menu click: lines 1283–1288 shows "My Profile" click in the drawer uses `Navigator.push` on mobile.
  - Top header SafeArea: lines 721–726 shows `SafeArea` wraps the entire Column containing the top header.
- File: `lib/widgets/profile_card.dart` and `lib/widgets/user_compact_row.dart`
  - Card clicks: lines 59–65 (in `profile_card.dart`) and lines 41–47 (in `user_compact_row.dart`) use `Navigator.push` to open `ProfilePage`.
- File: `lib/models/profile.dart`
  - Social media and athlete stats: no current fields for meets, rankings, or personal records. `socialLinks` field needs to be parsed from model JSON maps.

## 2. Logic Chain
- **Name and Settings Icon**: Changing the name's layout widget from `Expanded` to `Flexible` allows it to size according to its content, positioning the gear immediately after the text. The `Row` layout configuration `mainAxisSize: MainAxisSize.min` prevents overflow while centering/left-aligning the block.
- **Overlapping Avatar**: Wrapping the banner container and avatar in a `Stack` with `clipBehavior: Clip.none` enables placing the avatar partly above the bottom edge of the banner. Placing a spacer (`SizedBox`) inside the details column below the Stack prevents the overlapping avatar from colliding with the text labels.
- **Desktop Inline Rendering**: Introducing a `_selectedProfileUsername` state tracking field in `SearchFeedPage` allows the UI layout block to display the corresponding `ProfilePage` inline on desktop, while hiding the profile's internal Scaffold `appBar` so the banner touches the feed subheader directly. Adding an optional callback to user list cards enables redirecting click actions to inline rendering when on desktop.
- **Mobile UX Details**:
  - Hiding/showing the AppBar on scroll is achieved natively using a floating `SliverAppBar` inside a `NestedScrollView`.
  - Aligning drawer menu links to change bottom navigation tabs prevents routing duplicate routes and respects standard tab structures.
  - Disabling the top SafeArea on the parent Column and applying status-bar height padding locally to the search header enables a edge-to-edge layout where the header touches the viewport top.
- **Social Media and Athlete Sections**: Mapping keys from `Profile.socialLinks` to corresponding platform icons (Instagram, Youtube, etc.) inside horizontal Wrap chips gives the profile page access to multiple links. Using custom Cards, TabBarViews, and ListViews for PRs, Rankings, and Meets organizes performance data neatly.

## 3. Caveats
- This investigation assumes that the database tables for Meets, Rankings, and PRs do not yet exist, and thus suggests using mock details in the UI code before full database schemas are linked.
- The url strategy plugin (`flutter_web_plugins/url_strategy.dart`) is active. Updating inline state for desktop should ideally update the browser URL bar gracefully without reloading.

## 4. Conclusion
The analyzed UI requirements for milestone R2 are fully actionable. The implementation requires modifications in:
- `lib/views/profile_page.dart` (layout adjustments, stack overlap, sliver header, sections, social chips).
- `lib/views/search_feed_page.dart` (navigation, drawer tabs, top safe area adjustments).
- `lib/widgets/profile_card.dart` and `lib/widgets/user_compact_row.dart` (conditional desktop callback tap redirection).

## 5. Verification Method
- Execute the project tests:
  ```bash
  flutter test
  ```
- To inspect layout behavior:
  - Verify that the settings gear icon key (`profile_settings_icon`) is present directly adjacent to the full name widget.
  - Verify that when inline mode is active on screen width >= 900, `ProfilePage` does not render an `AppBar`.
