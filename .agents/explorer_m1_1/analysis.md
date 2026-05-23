# R1 (Login & Forgot Password) Analysis Report

## Overview
This report provides a detailed read-only investigation and design plan for implementing case-insensitive username inputs and dual username/email forgot-password lookups in the authentication flow.

---

## 1. Lowercasing Username Input (`lib/views/login_page.dart`)

### Current Implementation
- **File**: `lib/views/login_page.dart` (Lines 275–298)
- **Controller**: `_loginIdController` is shared between Email and Username login forms.
- **State Switcher**: `_isUsernameLogin` (boolean) dynamically alters the validation logic and keyboard types.
- **Form Submission**: `_handleLogin` calls `authProvider.loginWithUsernameAndPassword(username: id, ...)` or `loginWithEmailAndPassword(email: id, ...)`.

### Analysis & Recommendation
To dynamically convert characters to lowercase as the user types:
- Use a `TextInputFormatter` on the `TextFormField`. Using `TextInputFormatter.withFunction(...)` is the standard Flutter method because it updates the text buffer instantly and preserves cursor positioning/selection offsets safely.
- Apply this formatter conditionally only when `_isUsernameLogin` is `true`.
- Requires importing `package:flutter/services.dart`.

**Proposed Code snippet (`TextFormField` in `lib/views/login_page.dart`):**
```dart
TextFormField(
  key: const Key('login_id_field'),
  controller: _loginIdController,
  inputFormatters: [
    if (_isUsernameLogin)
      TextInputFormatter.withFunction((oldValue, newValue) {
        return newValue.copyWith(text: newValue.text.toLowerCase());
      }),
  ],
  // ... rest of configuration
)
```

---

## 2. Username/Email Verification (`lib/providers/auth_provider.dart` & `lib/repositories/profile_repository.dart`)

### Current Implementation
- **Registration**: `AuthProvider.registerWithEmailAndPassword` checks `_profileRepository.getProfileByUsername(username)` at line 131 but does not sanitize the input to lowercase first.
- **Login**: `AuthProvider.loginWithUsernameAndPassword` resolves the username via `_profileRepository.getProfileByUsername(username)` at line 214 but does not sanitize.
- **Repository**: `ProfileRepository.getProfileByUsername` queries Supabase using `.eq('username', username)`.

### Analysis & Recommendation
- **Case-Insensitivity**: In Supabase (Postgrest), `.eq()` translates to a case-sensitive `=` operator in PostgreSQL. Thus, we must ensure consistency between saved username cases and query cases.
- **Normalization Choice**:
  - `register_page.dart` already forces lowercase usernames on sign-up using `TextInputFormatter` in its username form field (lines 467–471).
  - Therefore, the database stores lowercase usernames.
  - To be robust against other clients or direct DB writes, we must normalize inputs to lowercase in `AuthProvider` (trimming and converting to lowercase before invoking `_profileRepository` methods).
  - In `ProfileRepository.getProfileByUsername`, standard `.eq()` is the most performant and uses the index on `username`. Alternatively, `.ilike()` could be used if mixed-case usernames exist, but application-level lowercasing is preferred for performance.

**Proposed Sanitization points:**
- In `isUsernameTaken(username)`: convert to `username.trim().toLowerCase()`.
- In `registerWithEmailAndPassword(...)`: trim and lowercase `username`.
- In `loginWithUsernameAndPassword(...)`: trim and lowercase `username`.

---

## 3. Forgot Password Flow Username/Email Resolution

### Current Implementation
- **Dialog**: `_showForgotPasswordDialog` (lines 73–179) contains a `TextFormField` bound to a validation pattern that strictly checks for `@` (lines 111–113).
- **Execution**: The dialog calls `authProvider.sendPasswordResetEmail(dialogEmailController.text.trim())` directly.

### Resolution Strategy
To support both usernames and emails:
1. **Dialog Input Label**: Update from "Email Address" to "Username or Email Address".
2. **Validator**: Allow input without `@` if the length is at least 3 characters (matching username requirements in registration page):
   ```dart
   validator: (value) {
     if (value == null || value.trim().isEmpty) {
       return 'Please enter your username or email';
     }
     final trimmed = value.trim();
     if (!trimmed.contains('@') && trimmed.length < 3) {
       return 'Username must be at least 3 characters';
     }
     return null;
   }
   ```
3. **Email Resolution Logic**:
   - Introduce a new helper in `AuthProvider`:
     ```dart
     Future<String> resolveEmailFromUsername(String username) async {
       final cleanUsername = username.trim().toLowerCase();
       final profile = await _profileRepository.getProfileByUsername(cleanUsername);
       if (profile == null) {
         throw Exception("Username '$username' not found.");
       }
       return profile.email;
     }
     ```
   - In the "Send" action, check if the input contains `@`.
     - If it contains `@`, pass the email directly to `sendPasswordResetEmail(email)`.
     - If it does not contain `@`, call `resolveEmailFromUsername(input)` to retrieve the email, then call `sendPasswordResetEmail(email)`.
     - Properly catch errors (e.g. username not found) and display them in the dialog's ScaffoldMessenger.

---

## 4. Proposed Changes Artifact
A complete implementation patch has been created in:
`/.agents/explorer_m1_1/proposed_changes.patch`
