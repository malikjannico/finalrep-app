# FinalRep Streetlifting App

FinalRep is a responsive, cross-platform sport competition management and search application designed specifically for **Streetlifting**. It provides unregistered users with guest search/filter feeds for meets, and offers registered users personalized profiles, layout customization, and secure authentication flows.

---

## 🚀 Key Features

### 🔐 Authentication & Security
- **Multi-step Onboarding**: User accounts are registered through a 3-step wizard (Account ➔ Details ➔ Avatar) with built-in state preservation.
- **Registration Constraints**: Dynamically enforces lowercase-only usernames, used/max character limits, and real-time database checks.
- **Forgot Password**: Password reset triggers on the Login page supporting either username or email.
- **Deep-Linked Password Recovery**: Intercepts recovery links directly in-app, presenting a 5-rule secure password update wizard.

### 👤 Profile Customization
- **Modern Layout**: Renders profile information directly on the scaffold background for a premium, clean aesthetic.
- **Profile Banner**: Slot for user banner images at the top of the profile page, incorporating pick-and-upload options.
- **Competitions & Achievements**: Tabs showing upcoming/completed meets, highest rankings per sport/format, and personal records (PRs) per discipline.
- **Inline Desktop Mode**: Renders user profiles inline under the header/subheader when selecting "My Profile".

### 👑 System Administration & Configurator
- **Permissions Access & Applications**: Organizers and federations apply for creation permissions (competition and/or association) with a reason.
- **Admin Dashboard**: Panel for administrators to accept/reject applications, promote other admins, and configure sports, formats, and disciplines.

### 🏢 Associations & Management
- **Creation Wizard**: Capture Name, images, scope (Global, Area, National), rules links, and parent association applications.
- **Association View**: Displays metadata, Rulebook links, sub-associations, and team members.
- **Management Panel**: Manage user roles (Owner, Editor), athlete weight classes, and active competition groups.

### 🏆 Competition Setup & Streetlifting Rules Engine
- **Step-by-step Stepper**: Setup names, geocoded addresses, flexible date pickers, registration modes (FCFS vs approval), rich-text description edits, disclaimers, and volunteer shifting plans.
- **Modern Rules Engine**: Supports Muscle Up, Pull Up, Dip, and Squat lifts under ascending weight orders.
- **Plate Calculator**: Computes plate loadings (1.25kg to 25kg) and micro-weights.
- **Judging Panel**: Referees vote on attempts; rules enforce majority (2:1 dips/squats depth) vs unanimous (3:0 other rules) scoring.
- **Video Assisted Referee (VAR):** Managers and coaches track and resolve 1 video review request per meet.
- **FinalRep Underground:** This competition group has been configured to exist **exclusively in the Modern format** (Muscle Up, Pull Up, Dip, Squat) in all mock repositories, test suites, and remote Supabase tables.

### 📊 Rankings & Notifications
- **Rankings Feed**: Filter rankings by sport, format, and weight class, showing overall totals and discipline details.
- **System Notifications**: Organizers and athletes receive live alerts for payment deadlines, registration approvals, schedule releases, and flight listings.

---

## 🛠️ Tech Stack
- **Frontend**: Flutter (targeting Web and Mobile)
- **Backend & Auth**: Supabase (Database, Auth, Storage)
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
To launch the app on your default connected device/emulator:
```bash
```bash
flutter run
```

To run specifically on the web platform:
```bash
flutter run -d chrome
```

---

## 🧪 Running Tests
The project features a comprehensive widget and unit testing suite verifying authentication, settings, profiles, and registration constraints.

To execute the test suite (153 tests):
```bash
flutter test
```
