import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/views/association/dialogs/sport_config_dialog.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('Sport Config Enhancements & Restrictions Tests', () {
    testWidgets(
      'Verify format search, format card disciplines, and shared badges in SportConfigDialog',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();

        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
        });

        // Seed sport config on competition provider
        final sportConfig = harness.competitionProvider.sportConfig;

        // Render SportConfigDialog
        final selectedSportsFormats = {
          'Streetlifting': ['Classic']
        };
        final rulebookControllers = {
          'Streetlifting': TextEditingController()
        };
        final appliedSharedResources = {
          'rulebooks': {
            'Streetlifting:Modern': {
              'rulebook_url': 'http://example.com/modern.pdf',
              'owning_association_id': 'other-assoc'
            }
          }
        };

        await tester.pumpWidget(
          harness.buildApp(
            Material(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => SportConfigDialog(
                          editSportType: 'Streetlifting',
                          sports: const ['Streetlifting'],
                          sportConfig: sportConfig,
                          selectedSportsFormats: selectedSportsFormats,
                          rulebookControllers: rulebookControllers,
                          activeSportType: 'Streetlifting',
                          appliedSharedResources: appliedSharedResources,
                        ),
                      );
                    },
                    child: const Text('OPEN DIALOG'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('OPEN DIALOG'));
        await tester.pumpAndSettle();



        // 1. Verify search field exists
        expect(find.byType(TextField), findsNWidgets(2)); // Rulebook url and search formats
        expect(find.widgetWithText(TextField, 'Search Formats'), findsOneWidget);

        // 2. Verify format cards display disciplines (Classic: Pull-up, Dip, Modern: Squat...)
        expect(find.text('Classic'), findsOneWidget);
        expect(find.text('Modern'), findsOneWidget);
        expect(find.text('Squat'), findsOneWidget);
        expect(find.text('Muscle Up'), findsOneWidget);

        // 3. Verify applied shared format shows SHARED badge
        expect(find.text('SHARED'), findsOneWidget);

        // 4. Test format search filter
        await tester.enterText(find.widgetWithText(TextField, 'Search Formats'), 'Classic');
        await tester.pumpAndSettle();
        expect(find.text('Classic'), findsNWidgets(2));
        expect(find.text('Modern'), findsNothing);

        harness.dispose();
      },
    );

    testWidgets(
      'Verify configured sports card formatting and edit/delete restrictions in MetadataTabView',
      (tester) async {
        final harness = E2ETestHarness();
        await harness.initialize();

        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
        });

        // 1. Seed association with applied shared rulebook (Modern format is shared, Classic is local)
        final assoc = Association(
          id: 'assoc-test-1',
          name: 'Olympic Federation',
          description: 'Testing association',
          scope: 'national',
          ownerId: 'user-1',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic', 'Modern'],
          rulebooks: const {
            'Streetlifting': 'http://local-rulebook.pdf'
          },
          socialChannels: const {},
          appliedSharedResources: const {
            'rulebooks': {
              'Streetlifting:Modern': {
                'rulebook_url': 'http://shared-rulebook.pdf',
                'owning_association_id': 'other-assoc'
              }
            },
            'competition_groups': [],
            'athlete_groups': []
          },
        );
         await harness.competitionProvider.createAssociation(assoc);

         // Authenticate as owner
         final session = Session(
           accessToken: 'token-user-1',
           tokenType: 'bearer',
           user: User(
             id: 'user-1',
             appMetadata: const {},
             userMetadata: const {},
             aud: 'authenticated',
             createdAt: '',
             email: 'john@example.com',
           ),
         );
         harness.mockAuth.triggerAuthStateChange(
           AuthChangeEvent.signedIn,
           session,
         );
         await harness.waitForAuthSettle(tester);

        // Render Association Management Page
        await tester.pumpWidget(
          harness.buildApp(AssociationManagementPage(associationId: 'assoc-test-1')),
        );
        await tester.pumpAndSettle();
 
        // Expand the Sports & Rulebooks collapsible section
        await tester.tap(find.text('Sports & Rulebooks'));
        await tester.pumpAndSettle();

        // 1. Verify "Configured Sports" renders formats as cards with their disciplines
        expect(find.text('Streetlifting'), findsOneWidget);
        expect(find.text('Classic'), findsOneWidget);
        expect(find.text('Modern'), findsOneWidget);
        expect(find.text('Applied Shared'), findsOneWidget);

        // 2. Verify rulebooks display separated by a line and local is shareable while shared is not
        expect(find.text('Local Rulebook: http://local-rulebook.pdf'), findsOneWidget);
        expect(find.text('Modern (Shared): http://shared-rulebook.pdf\n(Shared by Other)'), findsOneWidget);

        // 3. Since there is an applied shared rulebook in the sport card, the delete button must be hidden
        await tester.tap(find.text('EDIT'));
        await tester.pumpAndSettle();
        
        expect(find.byIcon(Icons.delete_outline), findsNothing); // Should be hidden

        harness.dispose();
      },
    );
  });
}
