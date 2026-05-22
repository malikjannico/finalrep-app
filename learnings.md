# Technical Learnings & Best Practices - FinalRep App

During the user profile and password recovery refactoring, several technical challenges were addressed, yielding valuable lessons for Flutter development.

---

## 1. ScaffoldMessenger Snackbar Queueing
- **Behavior**: Multiple sequential validation calls in registration (e.g. step validations) could trigger consecutive snackbars. By default, Flutter queues snackbars, causing outdated notifications to linger on the screen long after their triggers.
- **Solution**: Always invoke `ScaffoldMessenger.of(context).clearSnackBars();` immediately before triggering a new SnackBar to ensure the UI updates instantly and remains highly responsive.

---

## 2. Flutter Painting Invariant Leaks in Widget Tests
- **Behavior**: Overriding the `debugNetworkImageHttpClientProvider` (to stub out network image requests in tests) can leak across tests. If the mock provider is restored using standard `addTearDown` blocks, it executes *after* the framework runs its painting checks, resulting in a paint invariant leak crash.
- **Solution**: Wrap the test execution body in a `try-finally` block, ensuring that the original `debugNetworkImageHttpClientProvider` value is restored synchronously before the test completes.

---

## 3. Storage Bucket Client Mock Fallbacks
- **Behavior**: Accessing Supabase Storage client-side (`Supabase.instance.client.storage`) to load profile banners works in production, but triggers uninitialized mock exceptions during standard unit/widget tests.
- **Solution**: Implement try-catch structures around storage requests that immediately fallback to standard local placeholders (or default gradient color palettes) if the storage client cannot resolve.

---

## 4. BuildContext across Async Gaps
- **Behavior**: Accessing `BuildContext` after asynchronous operations (like `await showDialog` or `await authProvider.logout()`) triggers the `use_build_context_synchronously` warning because the widget might have been unmounted during the async gap.
- **Solution**: 
  - Capture references like `final navigator = Navigator.of(context);` and `final messenger = ScaffoldMessenger.of(context);` *before* entering the asynchronous action, OR
  - Perform a direct check `if (!context.mounted) return;` immediately after the async gap before accessing the context.

---

## 5. Dart Map Null-Aware Element Syntax
- **Behavior**: Previously, optional parameters in maps were appended using inline `if` blocks (e.g., `if (gender != null) 'gender': gender`), which could trigger linter suggestions.
- **Solution**: Dart 3.12+ supports null-aware map literal syntax `'key':? value`. This ensures the key-value pair is only included if `value` is non-null, creating much cleaner and more readable initialization blocks.
