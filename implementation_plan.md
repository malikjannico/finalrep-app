# Implementation Plan - Password Safety Rules & Custom Profile Image Upload

**Status:** Completed & Verified ✅

This plan details the design and implementation steps for:
1. Enforcing password rules at registration by design, showing a real-time indicator of rules met and password strength.
2. Allowing users to upload a custom profile picture using their device's photo gallery/file picker instead of choosing a preset avatar.

## User Review Required

> [!IMPORTANT]
> **Password Rules Enforced by Design:**
> The registration form will require passwords to meet the following safety criteria:
> - Minimum 8 characters.
> - At least one uppercase letter (A-Z).
> - At least one lowercase letter (a-z).
> - At least one numeric digit (0-9).
> - At least one special character (e.g. `!@#\$%^&*()_+-=[]{}|;':",./<>?`).
> The "NEXT" button on Step 1 will remain disabled, and the form will fail validation, until all requirements are met.

> [!TIP]
> **Custom Profile Image Upload Flow:**
> - We will add `file_picker` to `pubspec.yaml` to enable native file selection on Web, Mobile, and Desktop.
> - In Step 3 (Avatar), users can click "Upload Photo" to select a custom file.
> - The chosen photo will be uploaded to a new public Supabase Storage bucket named `avatars` post-signup (once the user's ID is authenticated).
> - The uploaded file URL will then be saved to the user's Profile record.

---

## Proposed Changes

### Database & Storage (Supabase)

---

#### [NEW] Supabase Storage Bucket & Policies Migration
We will run a SQL script via the Supabase MCP tool (`execute_sql`) to:
1. Create a public storage bucket named `avatars` if it does not already exist.
2. Define Row Level Security (RLS) policies on `storage.objects` for the `avatars` bucket:
   - **SELECT**: Allow public access so anyone can view profile pictures.
   - **INSERT / UPDATE**: Allow authenticated users to upload/overwrite images inside their own profile directory (`profiles/{user_id}/...`).

---

### Dependencies

#### [MODIFY] [pubspec.yaml](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/split-auth-multistep-registration/pubspec.yaml)
- Add `file_picker: ^8.1.3` to `dependencies` for cross-platform image picking.

---

### State Management & Repositories

---

#### [MODIFY] [auth_provider.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/split-auth-multistep-registration/lib/providers/auth_provider.dart)
- Update `registerWithEmailAndPassword` to accept an optional `Uint8List? customAvatarBytes` and `String? customAvatarExtension`.
- If custom image bytes are provided:
  1. Complete the `signUp` call as normal.
  2. Upload the bytes to Supabase Storage:
     - Path: `profiles/${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.${extension}`
  3. Retrieve the public URL for the uploaded file.
  4. Perform an update to the user's Profile record to set the `profilePictureUrl` to the newly retrieved URL.

---

### UI Views

---

#### [MODIFY] [register_page.dart](file:///Users/malikjannico/.gemini/antigravity/worktrees/finalrep-app/split-auth-multistep-registration/lib/views/register_page.dart)
- **Step 1 (Account Credentials)**:
  - Add state track variables for password requirements: length, uppercase, lowercase, number, special character.
  - Implement a real-time Password Strength Indicator widget:
    - Renders a strength indicator bar (3 segments: Red/Weak, Yellow/Medium, Green/Strong).
    - Lists the 5 rules with interactive validation states (green check icon if met, grey dot/info icon if not).
  - Disable the **NEXT** button if the password does not meet all rules.
- **Step 3 (Avatar Customization)**:
  - Add a card/button: "Upload Custom Photo" (invokes `FilePicker` to select an image).
  - Show a preview of the selected image in a circular avatar container with an option to remove/clear the custom selection and return to preset avatars.
  - Handle saving chosen file bytes and extension in local state.
  - Update the "CREATE ACCOUNT" handler to pass the picked image bytes and extension to `AuthProvider.registerWithEmailAndPassword`.

---

## Verification Plan

### Automated Tests
- Update widget tests in `test/widget_test.dart` to:
  - Mock custom file picking.
  - Verify that the Password Strength rules are displayed and correctly updated in real-time as text is entered.
  - Verify that Step 1 validation fails/Next is disabled if password rules are not fully met.

### Manual Verification
- Run migrations to create the storage bucket.
- Launch the application and:
  - Verify real-time password strength validation and rules feedback on Step 1.
  - Choose a custom image during Step 3, complete registration, and verify that the uploaded image displays correctly on the Profile page.
