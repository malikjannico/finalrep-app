## 2026-05-23T12:04:12Z

Implement a comprehensive suite of platform features for the FinalRep Streetlifting application in Flutter. This includes login adjustments, forgot password, profile enhancements, system administration settings, association creation and management, competition creation and management, Streetlifting Modern rules competition handling (attempt weight configurations, judging, flight planning), rankings, and system notifications.

Working directory: `/Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/platform-features-update`
Integrity mode: development

## Requirements

### R1. Login & Forgot Password
- convert all characters typed in the username field to lowercase dynamically at the login page and verify in lowercase.
- Allow users to enter either username or email on the forgot password flow.

### R2. User Profiles Customization
- Add social media profile links (website and channels) to user profiles and render them on profile pages with icons and names.
- Place the settings gear icon immediately after the full name on the "My Profile" page.
- Render other user profiles inline under the header and subheader in desktop view (like "My Profile"). Banners must touch subheaders directly with no gap in desktop layout.
- Align profile picture: show half above header (shifted up), and left-align the full name, username, gender, and country under the profile picture.
- Mobile UX improvements:
  - In mobile layout, ensure the navigation drawer items forward users to the same profile page as the bottom navigation bar.
  - Users page top header must touch the top of the viewport in mobile layout.
  - Scroll behavior: hide username from header if the username under the full name is visible. If the user scrolls and the username is no longer visible, render it in the header.
- Add sections on profiles for upcoming/completed competitions, highest rankings per sport/format, and personal records per discipline.

### R3. System Administration
- Admin permissions toggle: restrict competition/association creation to authorized users. Provide an application form where users can apply for either permission separately with a reason.
- Admin Panel:
  - List accepted users (with permissions) and applied users (with application date and reason).
  - Admin controls to accept/reject applications and promote users to admins.
  - Configurator: Add/rename sports, formats per sport, and disciplines. Associate disciplines to formats.

### R4. Associations & Management
- Association Creation: Wizard capturing name, profile photo, banner, scope (Global, Area, National with country selector), sports and formats, rulebook link per sport, website, social channels, description, and parent associations (requiring permission application with reason).
- Association Details: display metadata, upcoming/completed meets, rulebook link, team members, and sub-associations.
- Association Management:
  - Roles: Owner and Editor. Manage roles and edit details. Transfer ownership (by Owner or Admin).
  - Admin List: list of accepted and applied associations. Accept/reject applications.
  - Team members list: add users with custom roles.
  - Competition & Athlete Groups: create, activate/deactivate competition groups and athlete groups per sport and format. Specify if athlete groups are required.

### R5. Competition Creation & Custom Fields
- Step-by-step wizard for competition creation:
  - Name, location verification (detail selector: country -> city -> address).
  - DateTime pickers (text vs calendar/clock) for start/end and registration periods.
  - Payments: toggle fees. Specify amount, currency, bank details, and auto-generated description (max 140 chars) per athlete. Start/end payment dates.
  - Registration mode: First-come-first-serve vs manual approval.
  - Description: RichText editor (H1, H2, Bold, Italic, Underline, Bullets).
  - Social media, website, ticket shop link.
  - Sport selection: sport/format, association (only owned/managed), competition group, athlete groups.
  - Limits: max athletes (per competition vs per group), max volunteers (per competition vs per position), toggle waiting lists.
  - Volunteer setup: toggle volunteer needs, list positions (judges, spotters, livestream, media, commentators, administration), and configure periods.
  - Custom fields: define text/dropdown inputs for athletes and volunteers.
  - Disclaimers: configure disclaimers (text/link/both) to accept during registration.
  - Safe zone guides for banner uploads in desktop/mobile feeds.
  - Volunteer applications: multi-role applications with preference ordering.

### H1. Competition Management & Handling (Streetlifting Rules)
- Manage roles: Owner, Editor, Viewer. Publish competition, auto-start/end registration & payment.
- Roster: accept athletes, manage waiting list replacements, remove athletes with reason.
- Scheduling: plan slots (weigh-in, flights, awards, staff). Public public schedules vs private staff schedules. CSV exports.
- Weigh-in: record athlete bodyweight, enable disqualification status.
- Modern Streetlifting rules engine:
  - Muscle Up, Pull Up, Dip, Squat. 3 attempts. Ascending weight order. Smallest increments (1.25kg, 2.5kg).
  - Weight configuration plate calculator from standard plates (1.25kg to 25kg) and micro-weights.
  - Attempts weight selection: first attempt during weigh-in, subsequent attempts within 3 minutes (auto-fill defaults). Squats 3rd attempt can be changed twice (must be ascending).
  - 1-minute execution timer control.
  - 3 Platform Judges + 1 Head Judge voting panel. Voting rules: Dips (Invalid Depth) and Squats (Bent Knees & Invalid Depth) use majority 2:1 voting. Other failure reasons require unanimous 3:0. Anonymous judging options.
  - Disqualification check: 0 of 3 valid attempts in a discipline.
  - VAR: 1 request per meet, Head Judge reviews and overrules/confirms (restores VAR if overruled).
  - Rankings feed: overall total and discipline scores with filters.

### N1. System Notifications
- Notify users of registration/permission updates, payment deadlines, schedule releases, flight listings.
- User settings: enable/disable system notification categories.

## Verification & Testing Criteria
- Implement comprehensive widget and unit tests verifying the business logic of:
  - Convert username to lowercase on login page and login with username or email.
  - Streetlifting Modern attempt rules (ascending attempts, plate selection, defaults).
  - Judging majority vs unanimous voting results.
  - Admin/Association permissions and role validations.
- Run `flutter test` and ensure all tests compile and pass.
