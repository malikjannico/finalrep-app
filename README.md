# FinalRep Streetlifting App

FinalRep is a responsive, cross-platform sport competition management and search application designed specifically for **Streetlifting**. It provides unregistered users with guest search/filter feeds for meets, and offers registered users personalized profiles, layout customization, and secure authentication flows.

---

## 🚀 Key Features

### 🔐 Authentication & Security
- **Multi-step Onboarding**: User accounts are registered through a 3-step wizard (Account ➔ Details ➔ Avatar) with built-in state preservation.
- **Registration Constraints**: Dynamically enforces lowercase-only usernames, used/max character limits (15 for usernames, 30 for full names), and real-time database checks for username/email availability.
- **Forgot Password**: Password reset triggers on the Login page and a reset request mechanism in security settings.
- **Deep-Linked Password Recovery**: Intercepts recovery links directly in-app, presenting a 5-rule secure password update wizard (length >= 8, uppercase, lowercase, digits, special characters) with a colored strength bar indicator.

### 👤 Profile Customization
- **Modern Layout**: Renders profile information directly on the scaffold background (without wrapping details in Card views) for a premium, clean aesthetic.
- **Profile Banner**: Slot for user banner images (height 150px) at the top of the profile page, incorporating pick-and-upload options and color gradient fallbacks.
- **Social Integration**: Premium, adjacent "EDIT PROFILE" and "SHARE PROFILE" buttons under the bio.
- **Inline Desktop Mode**: Renders the current user's profile inline beneath the header/subheader when selecting "My Profile". Automatically collapses if any search query is entered.

### ⚙️ Settings Subpages
- **Appearance Settings**: Dedicated configuration page to toggle preferences (System, Light, Dark mode) which are synchronized back to the Supabase database.
- **Change Password**: Dedicated subpage to change passwords securely by verifying current credentials first.
- **Minimalist Styling**: Settings items render directly on the background without Card containers, and the Log Out button is presented without subtitles.

### 📱 Responsive Layouts & Search
- **Mobile Drawer**: Relocates the Log Out button to the bottom of the drawer below a Spacer element.
- **Adaptive List & Grid Formats**:
  - Compact lists stack usernames vertically below full names.
  - Grid rows display profile banners above avatar elements and omit chevron arrows.
  - Competition searches feature results-count labels and layout toggles.

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
flutter run
```

To run specifically on the web platform:
```bash
flutter run -d chrome
```

---

## 🧪 Running Tests
The project features a comprehensive widget and unit testing suite verifying authentication, settings, profiles, and registration constraints.

To execute the test suite:
```bash
flutter test
```
