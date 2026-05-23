# Product Requirements Document (PRD) — FinalRep App

## 1. Product Overview
**FinalRep App** is a responsive, cross-platform sport competition management and search platform designed for **Streetlifting**. It enables organizers to manage meets and allows athletes, coaches, and spectators (both registered and unregistered) to search for upcoming events globally.

This update introduces modules for Profile customization, System Administration, Association creation and management, rich Competition creation and management (including flights and schedule planning), Streetlifting competition handling (attempt scoring, platform judging, video reviews), Ranking details, and System Notifications.

---

## 2. Target Audience
1. **Athletes:** Search meets, register, view personal records, manage attempts, and specify rack/box parameters.
2. **Spectators & Guest Users:** Browse competitions, view schedules, and track rankings without login.
3. **Coaches:** Help athletes register and submit attempt weight selections.
4. **Organizers / Association Managers:** Create associations, manage teams, organize competitions, manage flights/schedules, export data, and judge lifts.
5. **Administrators:** Grant creation permissions, manage sports, formats, disciplines, and add other admins.

---

## 3. Core Features & Functional Requirements

### A. Login & Forgot Password
- **Login Username Field:** Dynamically convert all characters entered in the username field to lowercase. Verify in lowercase.
- **Forgot Password:** Allow users to enter either their **username** or their **email** to initiate the recovery flow.

### B. Profile Customization
- **Social Media Profiles:** Users can add links to social media channels on their profile.
- **Social Media Display:** Display social media links on the profile page using platform-specific icons alongside channel names.
- **Settings Icon:** Position the settings icon immediately after the user's Full Name on the "My Profile" page.
- **Other User Profiles:** Render other user profiles inline under the header and subheader in desktop view, mimicking the "My Profile" desktop integration.
- **Layout Adjustments:**
  - In desktop view, the profile banner must touch the subheader with no spacing.
  - In mobile view, the navigation drawer profile link must navigate to the same profile view as the bottom navigation bar.
  - In mobile view, the top header must touch the top of the screen at the users page.
  - In mobile view, if the username under the full name is visible, hide it from the header. Show it in the header in smaller font when the user scrolls and the username in the main body is no longer visible.
  - Profile picture position: Display half of the profile picture above the header (shifted upwards). Left-align the Full Name, username, gender, and country underneath the profile picture.
- **Competitions & Achievements:**
  - Show sections for upcoming and completed competitions.
  - Show the highest ranking achieved per sport and format.
  - Show personal records (PRs) for each discipline per sport and format.

### C. System Administration
- **Permission Access:** Restrict competition creation and association creation to authorized users.
- **Permissions Application:** Allow users to apply separately with a text reason for competition creation and association creation permissions.
- **Administration Views:**
  - **Permissions Lists:** List accepted users (with their current permissions) and applied users (with application date and reason).
  - **Decision Actions:** Administrators can accept or reject pending permission applications.
  - **Admin Management:** Administrators can promote other users to administrators.
- **Configuration Management:**
  - Add and rename sports (with optional descriptions).
  - Add and rename sport formats (per sport, with optional descriptions).
  - Add and rename disciplines (with optional descriptions).
  - Link disciplines to sport formats.

### D. Associations & Management
- **Creation Flow:** An optimized multi-step wizard grouping fields:
  - Name, Profile Picture (optional), Banner (optional).
  - Scope Selection: Global, Area (e.g. Europe), or National (with country selection).
  - Sports & Formats: Select one to all supported.
  - Rulebooks: Add a web link to the rulebook for each selected sport.
  - Channels: Add website and optional social media links.
  - Details: Specify description and parent associations (submitting an application with a reason).
- **Association View:** Display Name, Profile Picture, Banner, Scope, upcoming/completed competitions, Rulebook links, Social Media, Website, Description, list of Sub-Associations, and Team Members.
- **Management Panel:**
  - Roles: **Owner** and **Editor**.
  - Member management: Owners and Editors can add/remove users from roles. Owners or Administrators can transfer ownership.
  - Metadata: Owner and Editors can update all fields from the creation flow.
  - Permission Applications: List of applied associations with owner, date, and reason. Administrators can accept or reject applications.
  - Team members: Add team members and specify their custom team roles.
  - Competition Groups: Add and activate/deactivate competition groups per sport and format. (Inactive groups cannot be chosen during competition creation).
  - Athlete Groups: Add and activate/deactivate athlete groups (e.g. weight classes).
  - Group requirements: Specify if added athlete groups for a competition group are required.

### E. Competition Creation
- **Registered Users:** Any registered user can initiate competition creation (subject to permission approval).
- **Creation Flow:** Organized step-by-step wizard capturing:
  - Name, location (with detail selector: country -> city -> address, with geolocated verification).
  - Dates: Competition Start/End DateTime and Registration Start/End DateTime (flexible input: text or calendar/clock picker).
  - Fees: Toggle fee requirement. If enabled, specify fee amount, currency, recipient name, bank, IBAN, BIC, and a generated description code (max 140 chars) per accepted athlete. Specify payment period start/end dates.
  - Approval Type: Select first-come-first-serve vs. manual approval.
  - RichText Editor: Description editor supporting H1, H2, Bold, Italic, Underline, and Bullet points.
  - Links: Social media channels (rendered on detail page with icons), website, and optional ticket shop link.
  - Sport details: Select Sport, Format, and optionally Association (only those where user is Owner/Manager).
  - Group details: Select optional Competition Group from selected association (or parent associations). Add Athlete Groups (if no association is selected, or if the association has no required athlete groups. Otherwise, apply required association groups; for non-required ones, let the user choose to apply them).
  - Limits: Set maximum athlete count type (per competition vs. per athlete group) and specify the limit.
  - Volunteers: Toggle volunteer needs. If enabled, list positions (default options: judges, spotters, livestream, media, commentators, administration) with name and description, select max volunteers type (per competition vs. per position), specify limits, and define volunteer registration periods.
  - Waiting List: Toggle waiting list capability if limits are exceeded.
  - Custom Fields: Add optional text/select fields to capture additional details for athletes and volunteers.
  - Disclaimers: Add required disclaimers (only text, text with links, or link-only) that must be accepted.
  - Rulebooks: Add custom rulebook link or inherit from selected association.
  - Banner: Banner image upload showing recommended sizes and layout safe zones for desktop/mobile crop grids.
  - Volunteer Application: Volunteers can apply for multiple positions and set a favorite order preference.

### F. Competitions Feed & Details
- **Detail Layout:** Single competition page matches profile page layout (rendered under header/subheader on desktop).
- **Mobile Header:** If the user scrolls and the competition name disappears, show a shortened version in the header.
- **Completed Feeds:** Competitions list can switch between upcoming and completed meets.
- **Completed Results:** Single completed competition displays a ranking table with filtering capabilities.
- **Favorites:** Authenticated users can save/favorite competitions.

### G. Competition Management
- **Access Roles:** **Owner** (full control), **Editor** (updates metadata, records scores), **Viewer** (read-only management access). Transfer ownership can be done by Owner or Admin.
- **Workflows:**
  - Publish competition, start registration, auto-start/end payment periods.
  - Accept athletes & volunteers, manage waiting lists (automatically or individually for sick replacements, defining custom payment periods for runner-ups).
  - Remove athletes (with text reason) or volunteers.
  - Publish athlete groups and flights (balanced groups).
  - Configure platform layouts (number of parallel flights).
  - Weigh-in toggling: Enable/disable weigh-in requirements.
  - Schedule: Plan weigh-in slots, flights, awards ceremonies, and staff assignments. Publish separate athlete schedules (public) vs. staff schedules (accepted volunteers only).
  - Data Exports: CSV exports for athletes by groups, athletes by flights, volunteers by position, and schedules.
  - Attempt parameters: Add optional metadata fields per athlete per discipline (e.g. rack height, dip width) editable by athletes and managers.
  - Execution controls: Start/end competition, start weigh-in slots, record weight, mark disqualified status (disqualified athletes can lift but are excluded from rankings), end weigh-ins, start flights, and execute exercises.

### H. Competition Handling (Streetlifting Rules)
- **Modern Streetlifting Subtype:** Disciplines: Muscle Up, Pull Up, Dip, Squat.
- **Attempts:** 3 attempts per discipline. Ascending weight order (weight cannot be lowered during an exercise). Smallest increments: 1.25kg (Muscle Up, Pull Up, Dip), 2.5kg (Squat).
- **Weight Plates:** Pre-calculate weight configurations from standard plates (1.25kg Silver, 2.5kg Black, 5kg White, 10kg Green, 15kg Yellow, 20kg Blue, 25kg Red). Allow managers to add micro-weights (0.25kg, 0.5kg, 0.75kg, 1kg) to attempts.
- **Attempt Weights Selection:** First attempt entered during weigh-in until flight start (default 0kg if blank). Subsequent attempts must be entered within 3 minutes of previous attempt (otherwise auto-incremented by smallest increment on success, or repeated on failure). After 3 minutes, only Owners/Editors can update weights. Coaches can also submit weights for their defined athletes.
- **Squats Exception:** During 3rd attempt squats, allow changing attempt weight up to two times before the technical timer starts (must be ascending).
- **Execution Timer:** Technical judge starts a 1-minute countdown. The athlete must start the lift within 1 minute.
- **Platform Judging:**
  - 3 Platform Judges (2 side, 1 front) and 1 Head Judge.
  - Judging is anonymous.
  - Platform judges must specify a category/reason on failure:
    - **Muscle Up:** Red (Chicken Wing), Black (Signal/Equipment), Yellow (Kipping/Loss of Control), Blue (Lockout/Bent Arms/Grip).
    - **Pull Up:** Red (Invalid Height), Black (Signal/Equipment), Yellow (Kipping), Blue (Downward Motion).
    - **Dip:** Red (Invalid Depth), Black (Signal/Equipment), Yellow (Kipping/Loss of Control), Blue (Downward Motion/Bent Arms).
    - **Squat:** Red (Invalid Depth), Black (Signal/Equipment), Yellow (Support/Dropping/Foot Motion), Blue (Downward Motion/Bent Knees/Spotter contact).
  - **Voting Rules:**
    - Majority (2:1): Dips (Invalid Depth) and Squats (Bent Knees & Invalid Depth).
    - Unanimous (3:0): All other failure reasons.
- **Disqualification:** 0 of 3 valid attempts in any single discipline results in overall competition disqualification.
- **Video Assisted Referee (VAR):** Athletes/coaches can request 1 VAR per meet after an invalid attempt. Head judge reviews the footage. If overruled, the VAR credit is restored.
- **Custom Handling Rules:** Associations/organizers can modify handlers/judging configurations to comply with rulebook variations.

### I. Rankings & Notifications
- **Rankings Feed:** Render rankings by sport/format. Details display overall score and discipline scores. Filters for competition, group, and athlete classes.
- **Notifications System:** Notify users of registration status, permission outcomes, payment reminders, schedule releases, and flight details. Allow toggling categories in settings.

---

## 4. Technical Stack
- **Frontend:** Flutter.
- **Backend:** Supabase (mock fallbacks for local/widget tests).
- **State Management:** Provider.

---

## 5. Notes & Specific Configurations
- **FinalRep Underground:** The *FinalRep Underground* competition group has been configured to exist **exclusively in the Modern format** (which includes Muscle Up, Pull Up, Dip, and Squat). All classic format representations have been removed.

