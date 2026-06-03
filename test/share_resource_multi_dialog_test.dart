import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/views/association/dialogs/share_resource_multi_dialog.dart';

void main() {
  testWidgets('ShareResourceMultiDialog shows sharing state chip and SHARED badge', (tester) async {
    final currentAssoc = Association(
      id: 'assoc-1',
      name: 'Test Association',
      scope: 'local',
      supportedSports: ['Streetlifting'],
      supportedFormats: ['Modern'],
      rulebooks: {},
      socialChannels: {},
      ownerId: 'user-1',
    );

    final allAssociations = [currentAssoc];
    final ownItems = ['Rulebook A', 'Rulebook B'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ShareResourceMultiDialog<String>(
                      title: 'Share Resources',
                      ownItems: ownItems,
                      itemHeadline: (s) => s,
                      itemSubtitles: (s) => ['Modern'],
                      itemSport: (s) => 'Streetlifting',
                      itemIsShared: (s) => s == 'Rulebook A',
                      filterSports: const ['Streetlifting'],
                      filterFormats: const ['Modern', 'Classic'],
                      currentAssociation: currentAssoc,
                      allAssociations: allAssociations,
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to open the dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify sharing state filter chip is visible
    expect(find.text('Sharing State'), findsOneWidget);

    // Verify Shared badge is visible for 'Rulebook A' (which is shared)
    expect(find.text('Shared'), findsOneWidget);

    // Verify items correspond to their headlines
    expect(find.text('Rulebook A'), findsOneWidget);
    expect(find.text('Rulebook B'), findsOneWidget);

    // Initially, nothing is selected. UNSHARE button should not be visible.
    expect(find.text('UNSHARE'), findsNothing);

    // Tap 'Rulebook B' (not shared) to select it
    await tester.tap(find.text('Rulebook B'));
    await tester.pumpAndSettle();

    // UNSHARE button should still not be visible (no shared items selected)
    expect(find.text('UNSHARE'), findsNothing);

    // Tap 'Rulebook A' (shared) to select it
    await tester.tap(find.text('Rulebook A'));
    await tester.pumpAndSettle();

    // Now a shared item is selected. UNSHARE button should be visible.
    expect(find.text('UNSHARE'), findsOneWidget);

    // Tap 'Rulebook A' again to deselect it
    await tester.tap(find.text('Rulebook A'));
    await tester.pumpAndSettle();

    // UNSHARE button should disappear again
    expect(find.text('UNSHARE'), findsNothing);

    // Deselect 'Rulebook B' as well to return to initial state
    await tester.tap(find.text('Rulebook B'));
    await tester.pumpAndSettle();

    // Tap Sharing State dropdown chip using its tooltip
    await tester.tap(find.byTooltip('Sharing State'));
    await tester.pumpAndSettle();

    // Tap 'Shared' option to filter for shared items
    await tester.tap(find.text('Shared').last);
    await tester.pumpAndSettle();

    // Verify only 'Rulebook A' is shown
    expect(find.text('Rulebook A'), findsOneWidget);
    expect(find.text('Rulebook B'), findsNothing);

    // Tap the chip again to toggle off Shared
    await tester.tap(find.byTooltip('Sharing State'));
    await tester.pumpAndSettle();

    // Toggle Shared off
    await tester.tap(find.text('Shared').last);
    await tester.pumpAndSettle();

    // Re-open dropdown menu to toggle Not Shared on
    await tester.tap(find.byTooltip('Sharing State'));
    await tester.pumpAndSettle();

    // Toggle Not Shared on
    await tester.tap(find.text('Not Shared').last);
    await tester.pumpAndSettle();

    // Close the dropdown popup by tapping the dialog title
    await tester.tap(find.text('Share Resources'));
    await tester.pumpAndSettle();

    // Now verify only 'Rulebook B' is shown
    expect(find.text('Rulebook B'), findsOneWidget);
    expect(find.text('Rulebook A'), findsNothing);
  });
}
