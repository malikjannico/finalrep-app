## Challenge Summary

**Overall risk assessment**: MEDIUM

We have stress-tested the assumptions behind the implementation of R1 and R2 to identify edge cases, vulnerabilities, and failure modes under negative inputs or unexpected database states.

---

## Challenges

### [High] Challenge 1: Type Cast Crash in Profile Model for Invalid DB social_links

- **Assumption challenged**: The `social_links` field in the Supabase database is always stored as a valid JSON object/map.
- **Attack scenario**: If a database administrator or another system inserts an invalid structure (e.g., a JSON array like `['instagram', 'youtube']` or a plain string) into the `social_links` column, fetching the profile will trigger a runtime `TypeError` due to the strict cast `(json['social_links'] as Map<dynamic, dynamic>)`. This will crash the profile loading screen entirely for that user.
- **Blast radius**: High. The profile details screen will fail to render, showing a blank/error screen to any user viewing that profile.
- **Mitigation**: Update `lib/models/profile.dart` to perform a type check before casting:
  ```dart
  socialLinks: json['social_links'] is Map
      ? (json['social_links'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        )
      : null,
  ```

### [Medium] Challenge 2: Missing Email Validation on Password Reset Resolution

- **Assumption challenged**: User accounts always have a valid, non-empty email associated with them.
- **Attack scenario**: If a user attempts to reset the password for a username that exists but contains a null or empty email address in the database, `authProvider.resolveEmailFromUsername` will return an empty or invalid string. Calling `authProvider.sendPasswordResetEmail(email)` with an empty or invalid email will fail with a Supabase exception.
- **Blast radius**: Medium. The reset password loader will spin indefinitely or display a confusing raw database error message to the user.
- **Mitigation**: Add a validation step in the password reset dialog to check that the resolved email is non-empty and matches basic email format before calling `sendPasswordResetEmail`.

### [Low] Challenge 3: Incomplete Mocking in Tests Masking NoSuchMethodErrors

- **Assumption challenged**: Using `try-catch` when fetching `widget.profileRepository.client` is sufficient to avoid all `NoSuchMethodError`s in testing.
- **Attack scenario**: If any widget or helper method inside `ProfilePage` (or its child components) tries to call `_getSupabaseClient()` and expects a non-null return value to instantiate sub-repositories or perform direct queries, it will fail because the mock repository in tests throws a `NoSuchMethodError` which is caught and returns `null`.
- **Blast radius**: Low. Limited to widget testing environments where mock repositories are used.
- **Mitigation**: In tests, implement the `client` getter on `MockProfileRepository` to return a dummy or mock client (as done in `test/widget_test.dart` recently) to ensure all components can access the client safely if needed.

---

## Stress Test Results

- **Case-Insensitive Username Resolution** → Input: `   JoHnDoE   ` → Resolved to `johndoe` and matched database → **PASS**
- **Non-existent Username Reset** → Input: `nonexistent_user_123` → Handled cleanly by returning "Username 'nonexistent_user_123' not found." error → **PASS**
- **Toggling Login Mode with Text** → Toggled from Email to Username with existing invalid email → Text field cleared dynamically → **PASS**
