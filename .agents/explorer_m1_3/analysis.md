# UI Requirement Analysis Report: User Profiles Customization (R2)

This report details the technical analysis and proposed architectural changes for the **User Profiles Customization (R2)** milestone of the FinalRep app. It addresses layout positioning, desktop inline navigation, mobile UX enhancements, social media link display, and athlete sections.

---

## 1. settings Gear Icon Position on "My Profile"

### Problem Statement
Currently, on the "My Profile" screen, the settings gear icon is pushed to the far right side of the screen. The requirement is to position it directly after the user's full name.

### File Location
- File: `lib/views/profile_page.dart`
- Lines: 517–549 (`_buildProfileHeader` method)

### Code Analysis
The full name and settings gear are currently structured as follows:
```dart
Row(
  children: [
    Expanded(
      child: Text(
        _profile!.fullName,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    if (_isCurrentUser) ...[
      const SizedBox(width: 8),
      GestureDetector(
        key: const Key('profile_settings_icon'),
        ...
```
Because the `Text` widget is wrapped in `Expanded`, it takes up all remaining horizontal space in the `Row`, pushing the settings gear to the far right.

### Proposed Solution
Replace `Expanded` with `Flexible` and explicitly set `mainAxisSize: MainAxisSize.min` on the `Row`. This causes the `Row` to hug its content's intrinsic width (aligning the gear immediately after the text), while still allowing the text to truncate with an ellipsis if it exceeds the available space.

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Flexible(
      child: Text(
        _profile!.fullName,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    if (_isCurrentUser) ...[
      const SizedBox(width: 8),
      GestureDetector(
        key: const Key('profile_settings_icon'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/settings'),
              builder: (_) => const SettingsPage(),
            ),
          );
        },
        child: Icon(
          Icons.settings,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  ],
)
```

---

## 2. Avatar Position Shifted Up (Half Over Banner)

### Problem Statement
The avatar should be positioned shifted up (half above the banner) with details left-aligned below or next to the avatar.

### File Location
- File: `lib/views/profile_page.dart`
- Lines: 349–363 (`build` method) & 477–607 (`_buildProfileHeader` method)

### Proposed Solution
Change the profile page header structure to use a `Stack` with `clipBehavior: Clip.none` for overlapping layout, and shift the avatar down.

1. **Stack Layout for Banner and Avatar**:
   ```dart
   Stack(
     clipBehavior: Clip.none,
     children: [
       _buildBanner(theme),
       Positioned(
         left: 24,
         bottom: -40, // Avatar has radius 40 (diameter 80), shift down by half
         child: CircleAvatar(
           radius: 40,
           backgroundColor: theme.colorScheme.primaryContainer,
           backgroundImage: _profile!.profilePictureUrl != null
               ? NetworkImage(_profile!.profilePictureUrl!)
               : null,
           child: _profile!.profilePictureUrl == null
               ? Text(
                   initials,
                   style: TextStyle(
                     fontSize: 28,
                     fontWeight: FontWeight.bold,
                     color: theme.colorScheme.onPrimaryContainer,
                   ),
                 )
               : null,
         ),
       ),
     ],
   )
   ```

2. **Left-aligned Details Column**:
   In the main body `Column` below the `Stack`, insert a `SizedBox(height: 48)` to reserve vertical space for the bottom half of the overlapping avatar, followed by the left-aligned profile details:
   ```dart
   Column(
     crossAxisAlignment: CrossAxisAlignment.start, // Align details to the left
     children: [
       const SizedBox(height: 48), // Reserve space for the shifted avatar
       // Left-aligned details
       Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Flexible(
             child: Text(
               _profile!.fullName,
               style: theme.textTheme.headlineSmall?.copyWith(
                 fontWeight: FontWeight.bold,
               ),
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ),
           ),
           if (_isCurrentUser) ...[
             const SizedBox(width: 8),
             // Settings gear icon
             ...
           ],
         ],
       ),
       Text(
         '@${_profile!.username}',
         style: theme.textTheme.bodyMedium?.copyWith(
           color: theme.colorScheme.onSurfaceVariant,
         ),
       ),
       // Gender and Country Badges, Bio, etc.
     ],
   )
   ```

---

## 3. Desktop Inline Layout with Banner Touching Subheader

### Problem Statement
On desktop, clicking another user's profile card should render their profile inline in the search feed layout rather than pushing a new route. The banner must touch the subheader/sub-navbar without any empty space.

### File Locations
- File: `lib/views/search_feed_page.dart`
- File: `lib/views/profile_page.dart`
- File: `lib/widgets/profile_card.dart`
- File: `lib/widgets/user_compact_row.dart`

### Proposed Solution

1. **State Tracking in `SearchFeedPage`**:
   Add a state variable `String? _selectedProfileUsername` (and helper methods to clear it or set it).
   In `SearchFeedPage`'s main build method, update the inline content switch:
   ```dart
   child: (isDesktop && _desktopProfileActive && authProvider.isAuthenticated)
       ? const ProfilePage(isInline: true)
       : (isDesktop && _selectedProfileUsername != null)
           ? ProfilePage(username: _selectedProfileUsername, isInline: true)
           : showProfileTab
               ...
   ```

2. **Pass Callback to Profile Cards**:
   Modify `ProfileCard` and `UserCompactRow` constructors to accept an optional `onTap` callback. If the screen is desktop and `onTap` is provided, call it to update the parent state instead of pushing the route.
   ```dart
   // Inside SearchFeedPage (_buildUsersListGrid)
   UserCompactRow(
     profile: user,
     onTap: isDesktop ? () {
       setState(() {
         _selectedProfileUsername = user.username;
         _desktopProfileActive = false;
       });
     } : null,
   )
   ```

3. **Make Banner Touch the Subheader**:
   Currently, the inline profile still renders `ProfilePage`'s `AppBar` even if `isInline` is true, causing a spacing gap. Modify `ProfilePage`'s `Scaffold.appBar` to be `null` when inline on desktop:
   ```dart
   appBar: (widget.isInline && MediaQuery.of(context).size.width >= 900)
       ? null
       : AppBar(
           automaticallyImplyLeading: !widget.isInline,
           title: _isCurrentUser
               ? null
               : Text(
                   _profile?.username ?? 'Profile',
                   style: const TextStyle(fontWeight: FontWeight.bold),
                 ),
         ),
   ```
   This allows the body to stretch to the absolute top of the inline viewport, making the banner touch the subheader perfectly.

---

## 4. Mobile UX Enhancements

### Requirement 4a: AppBar scroll hides/shows username
Currently, the `AppBar` in `ProfilePage` is static.
**Proposed Solution**: Convert the `ProfilePage` body from `SingleChildScrollView` to a `NestedScrollView` with a `SliverAppBar`. Set `floating: true` and `snap: true` on the `SliverAppBar` so scrolling down hides it and scrolling up shows it.

```dart
Widget build(BuildContext context) {
  return Scaffold(
    body: NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: false,
            automaticallyImplyLeading: !widget.isInline,
            title: Text('@${_profile?.username ?? ""}'),
            backgroundColor: theme.colorScheme.surface,
          ),
        ];
      },
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildBanner(theme),
            // Avatar and Details Column
          ],
        ),
      ),
    ),
  );
}
```

### Requirement 4b: Drawer navigation matching the profile tab
Currently, clicking 'My Profile' in the drawer pushes a new full-screen `ProfilePage`.
**Proposed Solution**: In `_buildNavigationDrawer` of `SearchFeedPage`, change the `ListTile.onTap` for 'My Profile' to set the state index:
```dart
onTap: () {
  if (_scaffoldKey.currentState?.isDrawerOpen == true) {
    Navigator.of(context).pop(); // Close drawer
  }
  if (isDesktop) {
    setState(() {
      _desktopProfileActive = true;
    });
  } else {
    setState(() {
      _currentMobileTabIndex = 1; // Align to bottom nav tab index
    });
  }
}
```

### Requirement 4c: Users search header touching the viewport top
Currently, `SafeArea` is applied around the entire `Column` in `SearchFeedPage`.
**Proposed Solution**: Remove the top padding applied by `SafeArea` from the header block by setting `SafeArea(top: false, ...)` or selectively wrapping widgets. To make the header background fill the status bar area (touching the viewport top) without text clipping, add `MediaQuery.of(context).padding.top` to the top padding of the header container:
```dart
Container(
  padding: EdgeInsets.only(
    left: 24,
    right: 24,
    top: MediaQuery.of(context).padding.top + 12,
    bottom: 12,
  ),
  decoration: BoxDecoration(
    color: theme.colorScheme.surface,
    border: Border(
      bottom: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        width: 1,
      ),
    ),
  ),
  child: ...
)
```

---

## 5. Displaying Social Media Links & Athlete Sections

### Requirement 5a: Displaying social media links with names and icons
- Data field: `Map<String, String>? socialLinks` on the `Profile` model.
- Mapping: We match common platform keys to corresponding icon indicators (e.g., `'instagram'` to `Icons.camera_alt_outlined`, `'youtube'` to `Icons.video_library_outlined`, `'tiktok'` to `Icons.music_note_outlined`, `'twitter'` or `'x'` to `Icons.alternate_email`, defaulting to `Icons.link`).
- Display: Render them horizontally inside a Wrap container using `ActionChip` or clickable icons under the bio.

```dart
Widget _buildSocialLinks(ThemeData theme) {
  if (_profile!.socialLinks == null || _profile!.socialLinks!.isEmpty) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      children: _profile!.socialLinks!.entries.map((entry) {
        final name = entry.key;
        final handle = entry.value;
        IconData iconData;
        switch (name.toLowerCase()) {
          case 'instagram':
            iconData = Icons.camera_alt_outlined;
            break;
          case 'twitter':
          case 'x':
            iconData = Icons.alternate_email;
            break;
          case 'youtube':
            iconData = Icons.video_library_outlined;
            break;
          case 'tiktok':
            iconData = Icons.music_note_outlined;
            break;
          default:
            iconData = Icons.link;
        }
        return ActionChip(
          avatar: Icon(iconData, size: 16),
          label: Text('$name: $handle'),
          onPressed: () {
            // URL helper or web browser launcher link mapping
          },
        );
      }).toList(),
    ),
  );
}
```

### Requirement 5b: rendering Upcoming/Completed Meets, Highest Rankings, Personal Records sections
Since the current data models only support basic user details, these sections should be implemented as clean, modular UI list/grid sections that load from the profile's stats data structure (or a future joint database table query):

1. **Personal Records (PRs)**: Grid of verified lifts (Pull Up, Dip, Muscle Up, Squat) with weight.
2. **Highest Rankings**: Vertical list highlighting event podium finishes.
3. **Upcoming & Completed Meets**: horizontal scrolling list separated into two views via `TabBar` or segment switcher.

Proposed components:
```dart
Widget _buildAthleteDashboard(ThemeData theme) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 32),
      _buildPersonalRecords(theme),
      const SizedBox(height: 24),
      _buildHighestRankings(theme),
      const SizedBox(height: 24),
      _buildMeetsSection(theme),
    ],
  );
}
```
*(Reference mock implementations for `_buildPersonalRecords`, `_buildHighestRankings`, and `_buildMeetsSection` are structured within `lib/views/profile_page.dart` using native components like Card, ListView, and TabBarView).*
