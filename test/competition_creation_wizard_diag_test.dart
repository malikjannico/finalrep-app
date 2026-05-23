import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/views/competition_creation_wizard.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  testWidgets('Diag submission failure in Test 1', (tester) async {
    final harness = E2ETestHarness();
    await harness.initialize();
    harness.db.competitions.clear();

    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      harness.dispose();
    });

    await tester.pumpWidget(harness.buildApp(const CreateCompetitionWizard()));
    await tester.pumpAndSettle();

    // Step 1
    await tester.enterText(find.byKey(const Key('comp_name_field')), 'Date Test Meet');
    await tester.enterText(find.byKey(const Key('comp_location_field')), 'Berlin Gym');
    final verifyLocBtn = find.widgetWithText(ElevatedButton, 'Verify Location');
    await tester.tap(verifyLocBtn);
    await tester.pumpAndSettle();
    
    final nextButton = find.byKey(const Key('comp_next_btn'));
    final context = tester.element(nextButton);
    ScaffoldMessenger.of(context).clearSnackBars();
    await tester.pumpAndSettle();

    // Step 1 -> Step 2
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Step 2 -> Step 3
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Step 3 -> Step 4
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Enable fees
    final feesToggle = find.byKey(const Key('comp_fees_toggle'));
    await tester.tap(find.descendant(of: feesToggle, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    // Fill fee amount & IBAN & payment description
    await tester.enterText(find.widgetWithText(TextFormField, 'Fee Amount *'), '15.0');
    await tester.enterText(find.widgetWithText(TextFormField, 'IBAN / Bank Details *'), 'DE9876543210');
    await tester.enterText(find.widgetWithText(TextFormField, 'Payment Reference / Description *'), 'Date Test Reference');
    await tester.pumpAndSettle();

    // Step 4 -> Step 5
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    debugPrint('After Step 4 Next. Current text: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');

    // Step 5 -> Step 6
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    debugPrint('After Step 5 Next. Current text: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');

    // Submit the wizard in Step 6
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Check Snackbar and database
    final snackbars = find.byType(SnackBar).evaluate().map((e) => ((e.widget as SnackBar).content as Text).data).toList();
    debugPrint('SNACKBARS: $snackbars');
    debugPrint('DATABASE COMPETITIONS: ${harness.db.competitions.values.map((c) => c.title).toList()}');
  });
}
