# Walkthrough - Split Auth Pages and Multi-step Registration Flow

I have successfully separated the unified authentication page into two dedicated pages (`LoginPage` and `RegisterPage`), updated all application entry points to render separate "Sign In" and "Register" call-to-actions, built a premium multi-step registration flow, and resolved the image resource testing errors.

---

## 🛠️ Changes Implemented

### 1. Dedicated LoginPage (`lib/views/login_page.dart`)
- **Structure**: Clean, centered Card layout with Outfit typography and modern borders.
- **Toggle Mode**: Segments login by **Email** or **Username** using an interactive `SegmentedButton`.
- **Roadmap Integration**: Features Passkey, Google, Facebook, and Apple authentication buttons that show interactive roadmap info dialogs on tap.
- **Link**: Includes a navigation link to register an account, which dynamically adapts via `isInline` (used in mobile's guest profile tab).

### 2. Multi-step RegisterPage (`lib/views/register_page.dart`)
- **Visual Progress Stepper**: An elegant progress bar at the top showing the current step (Account ➔ Details ➔ Avatar) with brand orange styling and smooth active transitions.
- **Onboarding Wizard Steps**:
  - **Step 1 (Account)**: Form validation for Username (length >= 3), Email, and Password (length >= 6) with visibility toggle.
  - **Step 2 (Details)**: Form validation for Full Name, and dropdown pickers for Gender and Country.
  - **Step 3 (Avatar)**: Interactive horizontal-scrolling list of beautiful avatar presets fetched from Unsplash.
- **Validation & State Retention**: Each step requires successful validation to advance. Clicking the **Back** button preserves previously entered data.

### 3. Application Entry Points & Header Separation (`lib/views/search_feed_page.dart`)
- **Desktop Header**:
  - Replaced the single outlined "Login / Register" guest button with two side-by-side buttons:
    - Text/Outlined Button: **Sign In** (routes to `/login`).
    - Filled brand-orange (`#E94E1B`) button: **Register** (routes to `/register`).
- **Mobile Drawer**:
  - Replaced the single full-width button with a row containing side-by-side Outlined "Sign In" and Filled "Register" buttons.
- **Inline Profile Tab**:
  - Configured the guest state under the mobile bottom navbar profile tab to render `LoginPage(isInline: true)`. Tapping the "Create one" registration link pushes the full-screen `RegisterPage` correctly onto the stack.

### 4. Deep Linking & URL Synchronization
- Registered `/login` and `/register` routes.
- Configured redirection of the legacy `/auth` route to `/login` for backwards compatibility.

---

## 🧪 Verification & Test Results

### 1. Automated Tests
We added widget tests in `test/widget_test.dart` to verify the new buttons and registration wizard behavior:
- **Desktop Header Button Test**: Verifies separate Sign In and Register buttons are shown and Sign In navigates to `LoginPage`.
- **Mobile Drawer Button Test**: Verifies separate Sign In and Register buttons are displayed side-by-side in the drawer.
- **Wizard Progression & Validation Test**: Verifies validation blocks page advancement on invalid input, checks state transitions between Step 1, Step 2, and Step 3, and ensures back navigation works.

#### 💡 Resolving Flutter Painting Variable Leak
In Flutter widget tests, network image requests return status `400` by default. Overriding this requires mocking the `HttpClient` via `debugNetworkImageHttpClientProvider`. However, modifying global painting variables triggers a test framework invariant failure (`The value of a painting debug variable was changed by the test.`). 
To solve this, we wrapped the wizard widget test in a `try-finally` block:
```dart
debugNetworkImageHttpClientProvider = () => MockHttpClient();
try {
  // ... test body ...
} finally {
  debugNetworkImageHttpClientProvider = null;
}
```
This ensures the global test binding state is always reset to `null` before the test returns, satisfying the invariant checks.

All tests passed successfully!

---

## 🔒 Phase 2: Password Safety Rules & Custom Profile Image Upload

We implemented the second phase of user authentication improvements, enhancing security practices and personalization:

### 1. Password Safety Rules & Real-time Indicator
- **Enforcement by Design**: The registration form enforces 5 specific rules:
  - Minimum 8 characters.
  - At least one uppercase letter (`A-Z`).
  - At least one lowercase letter (`a-z`).
  - At least one numeric digit (`0-9`).
  - At least one special character.
- **Dynamic UI**:
  - Interactive checklists indicate met requirements in real-time (green check icon) and remaining ones (grey indicator).
  - A 3-stage visual strength bar (Red/Weak ➔ Yellow/Medium ➔ Green/Strong) updates dynamically as the user types.
  - The **NEXT** button in Step 1 remains disabled until all password rules are fully met.

### 2. Custom Profile Picture Upload
- **Platform-Agnostic File Picking**: Integrated `file_picker` for selecting custom pictures on mobile, web, and desktop.
- **Dynamic Preview Circle**: Displays the selected photo inside a bordered container with a delete option to clear the custom image and return to preset avatars.
- **Secure Supabase Integration**:
  - Created a public Supabase Storage bucket named `avatars`.
  - Added RLS policies permitting public select and authenticated insert/update at path `profiles/{user_id}/`.
  - Upon registration, the user's selected file bytes are securely uploaded to the bucket, and their Profile is updated with the resulting public URL.

### 3. Verification & Mocking Fixes
- **FilePicker Stub Invariant**: Wrapped retrieval of `FilePicker.platform` in a `try-catch` block during unit testing to avoid `LateInitializationError` on platforms where it's not initialized by default.
- **Mock Bytes Image Decodability**: Updated `MockFilePicker` to return base64-decoded bytes of a valid 1x1 transparent PNG instead of arbitrary mock bytes (`[0, 1, 2, 3]`), preventing `MemoryImage` codec decoder exceptions.

All **37 tests passed successfully**:
```bash
$ flutter test
00:03 +37: All tests passed!
```

---

### 📂 Branch Info
Use the command below to navigate directly to this workspace branch:
```bash
cd /Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/split-auth-multistep-registration
```
