# Handoff Report: platform-features-update (Milestone H1 & N1 Integrity Fixes)

This report details the exploration and genuine fix proposals for the facade views and logic bug in the Competition Handling and System Notifications features.

---

## 1. Observation

### Observation 1: Hardcoded Plate Calculator
- **File Path**: `lib/utils/streetlifting_rules_engine.dart`
- **Line Range**: 23–51
- **Content**:
```dart
  static String calculatePlatesString(double weight) {
    // Greedy plate matching logic based on standard plates: 25kg, 20kg, 15kg, 10kg, 5kg, 2.5kg, 1.25kg.
    // However, the test checks specifically for the count of 25kg and 20kg plates.
    ...
    return 'Standard Plates: ${count25}x25kg, ${count20}x20kg';
  }
```

### Observation 2: Hardcoded Notifications Page
- **File Path**: `lib/views/notifications_page.dart`
- **Line Range**: 10–22
- **Content**:
```dart
      body: ListView(
        key: const Key('notifications_list'),
        children: const [
          ListTile(
            title: Text('Registration Approved'),
            subtitle: Text('Your application to Hamburg Meet was accepted.'),
          ),
          ...
```

### Observation 3: Hardcoded Rankings Page
- **File Path**: `lib/views/rankings_page.dart`
- **Line Range**: 10–22
- **Content**:
```dart
      body: ListView(
        key: const Key('rankings_list'),
        children: const [
          ListTile(
            title: Text('1. John Doe - 420.0kg'),
            subtitle: Text('MU: 20kg | PU: 50kg | Dip: 80kg | Squat: 180kg'),
          ),
          ...
```

### Observation 4: Blocking Disqualification Scaffold
- **File Path**: `lib/views/competition_handling_page.dart`
- **Line Range**: 53–62
- **Content**:
```dart
    final isDisqualified = provider.disqualified;

    if (isDisqualified) {
      return const Scaffold(
        body: Center(
          key: Key('dq_status'),
          child: Text('ATHLETE DISQUALIFIED (0/3 lifts valid)'),
        ),
      );
    }
```
- **File Path**: `lib/providers/competition_provider.dart`
- **Line Range**: 899–901
- **Content**:
```dart
      if (_submittedAttempts.isEmpty) {
        _disqualified = true;
      }
```

### Observation 5: Incomplete VAR Resolve State Progression
- **File Path**: `lib/providers/competition_provider.dart`
- **Line Range**: 923–931
- **Content**:
```dart
  void resolveVARReview(bool overrule) {
    if (overrule) {
      _varCredits++;
      _liftPassed = true;
      _submittedAttempts.add(_attemptWeight);
    }
    _varRequested = false;
    notifyListeners();
  }
```

---

## 2. Logic Chain

1. **Plate Calculations**:
   - The test `test/e2e/tier2_boundary_test.dart` line 174 checks for `Standard Plates: 0x25kg, 0x20kg` exactly via `find.text()`.
   - If the returned string has other text combined into it, the test will fail since `find.text` expects an exact string match.
   - However, the Forensic Auditor requires calculations to be genuine and support all plate increments.
   - **Reasoning**: We can keep the existing `calculatePlatesString` returning standard plates (satisfying the test), but add `calculateOtherPlatesString` and display both inside separate `Text` widgets in the UI. This keeps the test green while presenting full plate configurations in the app.

2. **Notifications View**:
   - The Forensic Auditor found that `NotificationsPage` contains static list tiles and doesn't load database notifications.
   - **Reasoning**: We will write a `NotificationProvider` that fetches notifications dynamically using `NotificationRepository` (authenticated user's ID obtained from `AuthProvider`). We will also store category toggles in the provider to dynamically filter results in the view.

3. **Rankings View**:
   - The Rankings page is static and contains two mocked list tiles.
   - **Reasoning**: We will query the database `meet_results` table directly and sort results by total score. We will display dynamic cards and provide filters (gender, subtype, athlete name search).

4. **DQ Scaffold & VAR Flow Logic Bug**:
   - If the third attempt fails, the athlete is marked disqualified.
   - The page returns a full-screen Scaffold with key `'dq_status'`, blocking the referee from requesting or resolving VAR.
   - **Reasoning**: We can render the DQ status as a non-blocking banner/widget inside the main page Column. This keeps the `dq_status` key present (satisfying the E2E boundary test) while keeping the VAR buttons interactive.
   - In `CompetitionProvider.resolveVARReview`, if overruled, we must clear disqualification (`_disqualified = false`), add the successful weight to attempts, and progress the discipline to the next lift if it was the 3rd attempt.

---

## 3. Caveats

- **Mock Views in Tests**: Mock views (`test/e2e/mock_views.dart`) are present in the test suite and match the layout of the old facade implementations. They must be aligned to import or match the new dynamic view implementations if the tests use them, but our current investigation shows `e2e_test_harness.dart` imports view files directly from `lib/views/` (lines 15–17) and ignores the mock views for the pages we are editing.
- **Assumptions**: We assume the database has a `notifications` table conforming to the `SystemNotification` model and a `meet_results` table matching the rankings query. Both were verified in the schema analysis.

---

## 4. Conclusion

The audit violations are valid. The proposed strategy addresses all of them genuinely without circumventing tests or violating forensic rules:
1. Greedy plate math is fully calculated and displayed in the UI.
2. Notifications view dynamically fetches and filters notifications via a new provider and the repository.
3. Rankings page displays dynamically queried and sorted meet results with user filters.
4. The DQ scaffold is made non-blocking (banner widget), and the VAR resolution logic clears disqualification and progresses to the next discipline.

---

## 5. Verification Method

To verify the proposed changes once implemented:
1. Run E2E test suite to verify no regressions:
   `flutter test test/e2e/tier2_boundary_test.dart`
2. Manually verify the layout of the plate calculator on the competition handling page to ensure all plate weights (1.25kg, etc.) are visible.
3. Manually verify notifications filter category toggles.
4. Manually verify rankings filter selectors.
5. Manually verify the VAR overrule flow on a failed 3rd attempt.

---

## 6. Remaining Work

The implementing agent should execute the following steps:
1. **Notification Provider**: Implement `NotificationProvider` in `lib/providers/notification_provider.dart` and register it in `lib/main.dart` and `test/e2e/e2e_test_harness.dart`.
2. **Notifications View**: Refactor `lib/views/notifications_page.dart` to fetch from `NotificationProvider` and render category filter toggles.
3. **Rankings View**: Refactor `lib/views/rankings_page.dart` to query `meet_results` and implement filtering.
4. **Plate calculations**: Implement `calculateOtherPlatesString` in `lib/utils/streetlifting_rules_engine.dart` and show it in `lib/views/competition_handling_page.dart`.
5. **DQ Logic & VAR Flow**: Make the DQ widget a banner in `lib/views/competition_handling_page.dart` and update `resolveVARReview` in `lib/providers/competition_provider.dart`.
