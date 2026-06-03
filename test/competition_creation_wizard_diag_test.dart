import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/views/competition_creation_page.dart';
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

    await tester.pumpWidget(harness.buildApp(const CompetitionCreationPage()));
    await tester.pumpAndSettle();

    // Step 1: Title
    await tester.enterText(
      find.byKey(const Key('comp_name_field')),
      'Date Test Meet',
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('comp_next_btn'));
    await tester.tap(nextButton); // 1 -> 2
    await tester.pumpAndSettle();

    // Step 2: Location
    await tester.enterText(
      find.byKey(const Key('comp_location_field')),
      'Alexanderplatz 1, 10178 Berlin, Germany',
    );
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 2 -> 3 (Sport & Format)
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();

    final context = tester.element(nextButton);
    ScaffoldMessenger.of(context).clearSnackBars();
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 3 -> 4 (Banner Image)
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 4 -> 5 (Dates)
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 5 -> 6 (Reg Settings)
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 6 -> 7 (Competition Group)
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 7 -> 8 (Athlete Groups)
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 8 -> 9 (Fees & Bank Details)
    await tester.pumpAndSettle();

    // Enable fees
    final feesToggle = find.byKey(const Key('comp_fees_toggle'));
    await tester.tap(
      find.descendant(of: feesToggle, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    // Fill fee amount & separate bank details
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fee Amount *'),
      '15.0',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'IBAN *'),
      'DE9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'BIC *'),
      'WELADEDDXXX',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bank Name *'),
      'Deutsche Bank',
    );
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 9 -> 10 (Payment Settings)
    await tester.pumpAndSettle();

    // Select custom reference using dropdown
    await tester.tap(find.byTooltip('Payment Reference Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom Reference Instructions').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Custom Payment Reference *'),
      'Date Test Reference',
    );
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 10 -> 11 (Volunteer Setup)
    await tester.pumpAndSettle();

    await tester.tap(nextButton); // 11 -> 12 (Disclaimers & Custom Fields)
    await tester.pumpAndSettle();

    // Submit the wizard in Step 12
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Check database
    debugPrint(
      'DATABASE COMPETITIONS: ${harness.db.competitions.values.map((c) => c.title).toList()}',
    );
  });
}
