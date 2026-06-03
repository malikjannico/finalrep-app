import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/competition_group.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/views/association/dialogs/sport_config_dialog.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/association/dialogs/explore_shared_resources_dialog.dart';
import 'package:finalrep_app/views/association/dialogs/share_athlete_groups_selection_dialog.dart';
import 'package:finalrep_app/views/association/widgets/competition_groups_tab_view.dart';
import 'package:finalrep_app/views/association/widgets/athlete_groups_tab_view.dart';
import 'package:finalrep_app/widgets/association_card.dart';
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
        expect(find.byIcon(Icons.link_off), findsOneWidget); // Remove applied button on the Modern format card

        // 2. Verify rulebooks display inside format cards when they are different, and the share button is hidden
        expect(find.text('http://local-rulebook.pdf'), findsNWidgets(2)); // Once in format card, once under Rulebooks section
        expect(find.text('http://shared-rulebook.pdf'), findsOneWidget); // Inside Modern format card
        expect(find.byIcon(Icons.share), findsNothing); // Share button should be hidden since rulebook was applied

        // 3. Since there is an applied shared rulebook in the sport card, the delete button must be hidden
        await tester.tap(find.text('EDIT'));
        await tester.pumpAndSettle();
        
        expect(find.byIcon(Icons.delete_outline), findsNothing); // Should be hidden

        harness.dispose();
      },
    );

    testWidgets(
      'Verify ExploreSharedResourcesDialog rulebook filtering, collapsibility, and chip styling',
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

        // 1. Seed two associations: current and a neighbor
        final currentAssoc = Association(
          id: 'assoc-current',
          name: 'My Local Association',
          description: 'Current association',
          scope: 'national',
          ownerId: 'user-1',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic'],
          rulebooks: const {},
          socialChannels: const {},
          appliedSharedResources: const {
            'rulebooks': {
              'Streetlifting:Classic': {
                'rulebook_url': 'http://shared-classic.pdf',
                'owning_association_id': 'assoc-neighbor'
              }
            },
            'competition_groups': [],
            'athlete_groups': []
          },
        );

        final neighborAssoc = Association(
          id: 'assoc-neighbor',
          name: 'Global Governing Body',
          description: 'Neighbor sharing rulebooks',
          scope: 'global',
          ownerId: 'user-2',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic', 'Modern'],
          rulebooks: const {
            'Streetlifting': 'http://shared-streetlifting.pdf',
          },
          socialChannels: const {},
          rulebooksSharing: const {
            'Streetlifting': {'mode': 'specific', 'targets': ['assoc-current']},
          },
          appliedSharedResources: const {
            'rulebooks': {},
            'competition_groups': [],
            'athlete_groups': []
          },
        );

        // Make neighbor a parent of current, so they are related neighbors
        final currentAssocWithParent = currentAssoc.copyWith(parentAssociationId: 'assoc-neighbor');

        await harness.competitionProvider.createAssociation(currentAssocWithParent);
        await harness.competitionProvider.createAssociation(neighborAssoc);

        await tester.pumpWidget(
          harness.buildApp(
            Material(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ExploreSharedResourcesDialog(
                          currentAssociation: currentAssocWithParent,
                          allAssociations: [currentAssocWithParent, neighborAssoc],
                          resourceType: 'rulebooks',
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

        // 1. Verify "Streetlifting:Classic" is NOT visible (since it is already in currentAssoc's applied rulebooks)
        // Only Streetlifting:Modern should show.
        expect(find.text('Streetlifting - Classic'), findsNothing);
        expect(find.text('Streetlifting - Modern'), findsOneWidget);

        // 2. Verify custom chip text is "Shared by Global Governing Body"
        expect(find.text('Shared by Global Governing Body'), findsOneWidget);

        // Verify select-all checkbox toggling
        final selectAllRow = find.ancestor(
          of: find.text('Select All shown'),
          matching: find.byType(Row),
        );
        final selectAllCheckbox = find.descendant(
          of: selectAllRow,
          matching: find.byType(Checkbox),
        );
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isFalse);

        // Tap the select-all checkbox (this should select 'Modern' format rulebook)
        await tester.tap(selectAllCheckbox);
        await tester.pumpAndSettle();

        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isTrue);

        final modernRow = find.ancestor(
          of: find.text('Streetlifting - Modern'),
          matching: find.byType(CheckboxListTile),
        );
        expect(tester.widget<CheckboxListTile>(modernRow).value, isTrue);

        // Tap the select-all checkbox again to deselect
        await tester.tap(selectAllCheckbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isFalse);
        expect(tester.widget<CheckboxListTile>(modernRow).value, isFalse);

        // Verify search filtering
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'notfound');
        await tester.pumpAndSettle();
        expect(find.text('Streetlifting - Modern'), findsNothing);

        await tester.enterText(searchField, '');
        await tester.pumpAndSettle();
        expect(find.text('Streetlifting - Modern'), findsOneWidget);

        harness.dispose();
      },
    );

    testWidgets(
      'Verify ExploreSharedResourcesDialog competition groups collapsible, select all, filtering, and chip styling',
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

        final currentAssoc = Association(
          id: 'assoc-current',
          name: 'My Local Association',
          description: 'Current association',
          scope: 'national',
          ownerId: 'user-1',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic', 'Modern'],
          rulebooks: const {},
          socialChannels: const {},
          appliedSharedResources: const {
            'rulebooks': {},
            'competition_groups': [
              {
                'id': 'group-applied',
                'owning_association_id': 'assoc-neighbor'
              }
            ],
            'athlete_groups': []
          },
        );

        final neighborAssoc = Association(
          id: 'assoc-neighbor',
          name: 'Global Governing Body',
          description: 'Neighbor sharing comp groups',
          scope: 'global',
          ownerId: 'user-2',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic', 'Modern'],
          rulebooks: const {},
          socialChannels: const {},
          appliedSharedResources: const {
            'rulebooks': {},
            'competition_groups': [],
            'athlete_groups': []
          },
        );

        final currentAssocWithParent = currentAssoc.copyWith(parentAssociationId: 'assoc-neighbor');

        await harness.competitionProvider.createAssociation(currentAssocWithParent);
        await harness.competitionProvider.createAssociation(neighborAssoc);

        // Add a group that is already applied, and one that is not applied
        await harness.competitionProvider.associationRepository.createCompetitionGroup(
          CompetitionGroup(
            id: 'group-applied',
            associationId: 'assoc-neighbor',
            name: 'Applied Comp Group',
            sport: 'Streetlifting',
            format: 'Classic',
            isActive: true,
            isAthleteGroupsRequired: false,
            sharingConfig: const {
              'mode': 'specific',
              'targets': ['assoc-current']
            },
          ),
        );

        await harness.competitionProvider.associationRepository.createCompetitionGroup(
          CompetitionGroup(
            id: 'group-not-applied',
            associationId: 'assoc-neighbor',
            name: 'New Comp Group',
            sport: 'Streetlifting',
            format: 'Modern',
            isActive: true,
            isAthleteGroupsRequired: false,
            sharingConfig: const {
              'mode': 'specific',
              'targets': ['assoc-current']
            },
          ),
        );

        await tester.pumpWidget(
          harness.buildApp(
            Material(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ExploreSharedResourcesDialog(
                          currentAssociation: currentAssocWithParent,
                          allAssociations: [currentAssocWithParent, neighborAssoc],
                          resourceType: 'competition_groups',
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

        // 1. Verify "Applied Comp Group" is NOT visible
        expect(find.text('Applied Comp Group'), findsNothing);

        // 2. Verify "New Comp Group" is visible
        expect(find.text('New Comp Group'), findsOneWidget);

        // 3. Verify custom chip text is "Shared by Global Governing Body"
        expect(find.text('Shared by Global Governing Body'), findsOneWidget);

        // Verify select-all checkbox toggling
        final selectAllRow = find.ancestor(
          of: find.text('Select All shown'),
          matching: find.byType(Row),
        );
        final selectAllCheckbox = find.descendant(
          of: selectAllRow,
          matching: find.byType(Checkbox),
        );
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isFalse);

        final newGroupRow = find.ancestor(
          of: find.text('New Comp Group'),
          matching: find.byType(CheckboxListTile),
        );
        expect(tester.widget<CheckboxListTile>(newGroupRow).value, isFalse);

        // Tap the select-all checkbox
        await tester.tap(selectAllCheckbox);
        await tester.pumpAndSettle();

        // Verify both checkboxes are checked
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isTrue);
        expect(tester.widget<CheckboxListTile>(newGroupRow).value, isTrue);

        // Tap select-all checkbox to deselect
        await tester.tap(selectAllCheckbox);
        await tester.pumpAndSettle();

        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isFalse);
        expect(tester.widget<CheckboxListTile>(newGroupRow).value, isFalse);

        // Verify search filtering
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'notfound');
        await tester.pumpAndSettle();
        expect(find.text('New Comp Group'), findsNothing);

        await tester.enterText(searchField, '');
        await tester.pumpAndSettle();
        expect(find.text('New Comp Group'), findsOneWidget);

        harness.dispose();
      },
    );

    testWidgets(
      'Verify ExploreSharedResourcesDialog athlete groups collapsible, select all, filtering, and chip styling',
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

        final currentAssoc = Association(
          id: 'assoc-current',
          name: 'My Local Association',
          description: 'Current association',
          scope: 'national',
          ownerId: 'user-1',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic', 'Modern'],
          rulebooks: const {},
          socialChannels: const {},
          appliedSharedResources: const {
            'rulebooks': {},
            'competition_groups': [],
            'athlete_groups': [
              {
                'id': 'athlete-applied',
                'owning_association_id': 'assoc-neighbor'
              }
            ],
          },
        );

        final neighborAssoc = Association(
          id: 'assoc-neighbor',
          name: 'Global Governing Body',
          description: 'Neighbor sharing athlete groups',
          scope: 'global',
          ownerId: 'user-2',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic', 'Modern'],
          rulebooks: const {},
          socialChannels: const {},
          appliedSharedResources: const {
            'rulebooks': {},
            'competition_groups': [],
            'athlete_groups': []
          },
        );

        final currentAssocWithParent = currentAssoc.copyWith(parentAssociationId: 'assoc-neighbor');

        await harness.competitionProvider.createAssociation(currentAssocWithParent);
        await harness.competitionProvider.createAssociation(neighborAssoc);

        // Add applied and new athlete groups
        await harness.competitionProvider.associationRepository.createAthleteGroup(
          AthleteGroup(
            id: 'athlete-applied',
            associationId: 'assoc-neighbor',
            name: 'Applied Athlete Class',
            sport: 'Streetlifting',
            format: 'Classic',
            gender: 'men',
            isActive: true,
            sortOrder: 0,
            sharingConfig: const {
              'mode': 'specific',
              'targets': ['assoc-current']
            },
          ),
        );

        await harness.competitionProvider.associationRepository.createAthleteGroup(
          AthleteGroup(
            id: 'athlete-not-applied',
            associationId: 'assoc-neighbor',
            name: 'New Athlete Class',
            sport: 'Streetlifting',
            format: 'Modern',
            gender: 'women',
            isActive: true,
            sortOrder: 0,
            sharingConfig: const {
              'mode': 'specific',
              'targets': ['assoc-current']
            },
          ),
        );

        await harness.competitionProvider.associationRepository.createAthleteGroup(
          AthleteGroup(
            id: 'athlete-not-applied-2',
            associationId: 'assoc-neighbor',
            name: 'New Athlete Class 2',
            sport: 'Streetlifting',
            format: 'Modern',
            gender: 'women',
            isActive: true,
            sortOrder: 1,
            sharingConfig: const {
              'mode': 'specific',
              'targets': ['assoc-current']
            },
          ),
        );

        await tester.pumpWidget(
          harness.buildApp(
            Material(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ExploreSharedResourcesDialog(
                          currentAssociation: currentAssocWithParent,
                          allAssociations: [currentAssocWithParent, neighborAssoc],
                          resourceType: 'athlete_groups',
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

        // 1. Verify "Applied Athlete Class" is NOT visible
        expect(find.text('Applied Athlete Class'), findsNothing);

        // 2. Verify both eligible athlete classes are visible
        expect(find.text('New Athlete Class'), findsOneWidget);
        expect(find.text('New Athlete Class 2'), findsOneWidget);

        // 3. Verify custom chip text is "Shared by Global Governing Body"
        expect(find.text('Shared by Global Governing Body'), findsNWidgets(2));

        // Find child checkboxes
        final childRow1 = find.ancestor(of: find.text('New Athlete Class'), matching: find.byType(CheckboxListTile));
        final childRow2 = find.ancestor(of: find.text('New Athlete Class 2'), matching: find.byType(CheckboxListTile));

        // Find select-all checkbox
        final selectAllRow = find.ancestor(
          of: find.text('Select All shown'),
          matching: find.byType(Row),
        );
        final selectAllCheckbox = find.descendant(
          of: selectAllRow,
          matching: find.byType(Checkbox),
        );

        // Verify initially unchecked
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isFalse);
        expect(tester.widget<CheckboxListTile>(childRow1).value, isFalse);
        expect(tester.widget<CheckboxListTile>(childRow2).value, isFalse);

        // Tap child 1 -> select-all checkbox should become indeterminate (null)
        await tester.tap(childRow1);
        await tester.pumpAndSettle();

        expect(tester.widget<CheckboxListTile>(childRow1).value, isTrue);
        expect(tester.widget<CheckboxListTile>(childRow2).value, isFalse);
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isNull);

        // Tap child 2 -> select-all checkbox should become fully checked (true)
        await tester.tap(childRow2);
        await tester.pumpAndSettle();

        expect(tester.widget<CheckboxListTile>(childRow1).value, isTrue);
        expect(tester.widget<CheckboxListTile>(childRow2).value, isTrue);
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isTrue);

        // Tap select-all checkbox (checked -> unchecked) -> all children become unchecked
        await tester.tap(selectAllCheckbox);
        await tester.pumpAndSettle();

        expect(tester.widget<CheckboxListTile>(childRow1).value, isFalse);
        expect(tester.widget<CheckboxListTile>(childRow2).value, isFalse);
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isFalse);

        // Tap select-all checkbox again (unchecked -> checked) -> all children become checked
        await tester.tap(selectAllCheckbox);
        await tester.pumpAndSettle();

        expect(tester.widget<CheckboxListTile>(childRow1).value, isTrue);
        expect(tester.widget<CheckboxListTile>(childRow2).value, isTrue);
        expect(tester.widget<Checkbox>(selectAllCheckbox).value, isTrue);

        // Tap select-all checkbox again to uncheck all
        await tester.tap(selectAllCheckbox);
        await tester.pumpAndSettle();

        // Verify filtering
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'Class 2');
        await tester.pumpAndSettle();

        expect(find.text('New Athlete Class'), findsNothing);
        expect(find.text('New Athlete Class 2'), findsOneWidget);

        harness.dispose();
      },
    );

    testWidgets(
      'Verify ShareAthleteGroupsSelectionDialog tristate select all checkbox behavior',
      (tester) async {
        final ownGroups = [
          AthleteGroup(
            id: 'g-1',
            associationId: 'assoc-1',
            name: 'Men Open',
            sport: 'Streetlifting',
            format: 'Classic',
            gender: 'men',
            isActive: true,
            sortOrder: 0,
            sharingConfig: const {},
          ),
          AthleteGroup(
            id: 'g-2',
            associationId: 'assoc-1',
            name: 'Men Under 80kg',
            sport: 'Streetlifting',
            format: 'Classic',
            gender: 'men',
            isActive: true,
            sortOrder: 1,
            sharingConfig: const {},
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ShareAthleteGroupsSelectionDialog(
                          genderTitle: 'Men',
                          ownGroups: ownGroups,
                        ),
                      );
                    },
                    child: const Text('OPEN'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();

        // Initially both are selected (since in initState we add all to selectedIds)
        // Verify Select All is checked
        final selectAllFinder = find.widgetWithText(CheckboxListTile, 'Select All');
        expect(tester.widget<CheckboxListTile>(selectAllFinder).value, isTrue);

        // Tap the first group to deselect it (which is a CheckboxListTile)
        final firstGroupFinder = find.widgetWithText(CheckboxListTile, 'Men Open');
        await tester.tap(firstGroupFinder);
        await tester.pumpAndSettle();

        // Verify Select All is now indeterminate (null)
        expect(tester.widget<CheckboxListTile>(selectAllFinder).value, isNull);

        // Tap the second group to deselect it
        final secondGroupFinder = find.widgetWithText(CheckboxListTile, 'Men Under 80kg');
        await tester.tap(secondGroupFinder);
        await tester.pumpAndSettle();

        // Verify Select All is now unchecked (false)
        expect(tester.widget<CheckboxListTile>(selectAllFinder).value, isFalse);

        // Tap Select All to select all
        await tester.tap(selectAllFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<CheckboxListTile>(selectAllFinder).value, isTrue);
        expect(tester.widget<CheckboxListTile>(firstGroupFinder).value, isTrue);
        expect(tester.widget<CheckboxListTile>(secondGroupFinder).value, isTrue);
      },
    );

    testWidgets(
      'Verify AssociationCompactRow layout in desktop and mobile views',
      (tester) async {
        final assoc = Association(
          id: 'assoc-1',
          name: 'German Association',
          description: 'A test association',
          scope: 'national',
          country: 'Germany',
          ownerId: 'user-1',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic'],
          rulebooks: const {},
          socialChannels: const {},
          appliedSharedResources: const {},
        );

        // 1. Desktop View (width >= 900)
        tester.view.physicalSize = const Size(1000, 600);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1000, 600));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AssociationCompactRow(
                association: assoc,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify scope chip "NATIONAL" is rendered
        expect(find.text('NATIONAL'), findsOneWidget);
        expect(find.text('GERMANY'), findsOneWidget);

        // Verify chips are next to chevron (which means they are not underneath the name)
        // We can check that the chips are descendants of the Row, and the Column containing the name does NOT contain the chips.
        final nameTileColumn = find.ancestor(
          of: find.text('German Association'),
          matching: find.byType(Column),
        );
        final chipInColumn = find.descendant(
          of: nameTileColumn,
          matching: find.text('NATIONAL'),
        );
        expect(chipInColumn, findsNothing); // Under desktop view, chips should NOT be in the name Column

        // 2. Mobile View (width < 900)
        tester.view.physicalSize = const Size(500, 600);
        await tester.binding.setSurfaceSize(const Size(500, 600));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AssociationCompactRow(
                association: assoc,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Under mobile view, chips should be inside the Column underneath the name
        final chipInColumnMobile = find.descendant(
          of: nameTileColumn,
          matching: find.text('NATIONAL'),
        );
        expect(chipInColumnMobile, findsOneWidget); // On mobile, chips should be under the name inside the Column

        // Reset view size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'Verify applied comp group and athlete group cards render Shared by chip',
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

        final currentAssoc = Association(
          id: 'assoc-current',
          name: 'My Local Association',
          description: 'Current association',
          scope: 'national',
          ownerId: 'user-1',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic', 'Modern'],
          rulebooks: const {},
          socialChannels: const {},
          appliedSharedResources: const {
            'rulebooks': {},
            'competition_groups': [
              {
                'id': 'group-applied-unique-test',
                'owning_association_id': 'assoc-neighbor'
              }
            ],
            'athlete_groups': [
              {
                'id': 'athlete-applied-unique-test',
                'owning_association_id': 'assoc-neighbor'
              }
            ]
          },
        );

        final neighborAssoc = Association(
          id: 'assoc-neighbor',
          name: 'Global Governing Body',
          description: 'Neighbor sharing resources',
          scope: 'global',
          ownerId: 'user-2',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Classic', 'Modern'],
          rulebooks: const {},
          socialChannels: const {},
          appliedSharedResources: const {
            'rulebooks': {},
            'competition_groups': [],
            'athlete_groups': []
          },
        );

        await harness.competitionProvider.createAssociation(currentAssoc);
        await harness.competitionProvider.createAssociation(neighborAssoc);

        await harness.competitionProvider.associationRepository.createCompetitionGroup(
          CompetitionGroup(
            id: 'group-applied-unique-test',
            associationId: 'assoc-neighbor',
            name: 'Unique Applied Comp Group',
            sport: 'Streetlifting',
            format: 'Classic',
            isActive: true,
            isAthleteGroupsRequired: false,
            sharingConfig: const {},
          ),
        );

        await harness.competitionProvider.associationRepository.createAthleteGroup(
          AthleteGroup(
            id: 'athlete-applied-unique-test',
            associationId: 'assoc-neighbor',
            name: 'Unique Applied Athlete Group',
            sport: 'Streetlifting',
            format: 'Classic',
            gender: 'men',
            isActive: true,
            sortOrder: 0,
            sharingConfig: const {},
          ),
        );

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
        harness.mockAuth.triggerAuthStateChange(AuthChangeEvent.signedIn, session);
        await harness.waitForAuthSettle(tester);

        // Render page
        await tester.pumpWidget(
          harness.buildApp(AssociationManagementPage(associationId: 'assoc-current', initialTab: 'compgroups')),
        );
        await tester.pumpAndSettle();

        // 1. Verify "Shared by Global Governing Body" chip is rendered inside trailing area of comp group card
        final compChip = find.descendant(
          of: find.byType(CompetitionGroupsTabView),
          matching: find.text('Shared by Global Governing Body'),
        );
        expect(compChip, findsOneWidget);

        // Verify subtitle is shown and is not null
        final compListTile = tester.widget<ListTile>(find.ancestor(of: find.text('Unique Applied Comp Group'), matching: find.byType(ListTile)));
        expect(compListTile.subtitle, isNotNull);

        // 2. Go to athletegroups tab
        await tester.pumpWidget(
          harness.buildApp(AssociationManagementPage(associationId: 'assoc-current', initialTab: 'athletegroups')),
        );
        await tester.pumpAndSettle();

        // Verify chip in athlete group card
        final athleteChip = find.descendant(
          of: find.byType(AthleteGroupsTabView),
          matching: find.text('Shared by Global Governing Body'),
        );
        expect(athleteChip, findsOneWidget);
        final athleteListTile = tester.widget<ListTile>(find.ancestor(of: find.text('Unique Applied Athlete Group'), matching: find.byType(ListTile)));
        expect(athleteListTile.subtitle, isNotNull);

        harness.dispose();
      },
    );
  });
}
