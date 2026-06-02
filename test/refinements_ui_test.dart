import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:finalrep_app/router.dart';
import 'package:finalrep_app/main.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/association_member.dart';
import 'package:finalrep_app/models/competition_group.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/association_library_page.dart';
import 'package:finalrep_app/views/association_detail_page.dart';
import 'package:finalrep_app/views/rankings_page.dart';
import 'package:finalrep_app/views/mobile_search_page.dart';
import 'package:finalrep_app/views/profile_page.dart';
import 'package:finalrep_app/models/permission_application.dart';
import 'package:finalrep_app/models/admin_config.dart';
import 'package:finalrep_app/views/admin_dashboard_page.dart';
import 'package:finalrep_app/views/formats_config_page.dart';
import 'package:finalrep_app/views/home_navigation_shell.dart';
import 'package:finalrep_app/views/competition_creation_page.dart';
import 'package:finalrep_app/views/association_creation_page.dart';
import 'package:finalrep_app/views/user_library_page.dart';
import 'package:finalrep_app/widgets/profile_card.dart';
import 'package:finalrep_app/widgets/user_compact_row.dart';
import 'package:finalrep_app/widgets/association_card.dart';
import 'mocks/shared_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://placeholder-refinements.supabase.co',
        anonKey: 'placeholder-key',
      );
    } catch (_) {}
  });

  group('UI UX Refinements Tests', () {
    late MockCompetitionRepository compRepo;
    late MockAssociationRepository assocRepo;
    late CompetitionProvider compProvider;
    late MockAuthProvider authProvider;

    setUp(() {
      compRepo = MockCompetitionRepository([
        Competition(
          id: 'comp-1',
          title: 'Hamburg Meet',
          location: 'Hamburg, Germany',
          sportSubtype: 'Modern',
          compGroupName: 'Hamburg Meet',
          startDate: DateTime(2026, 6, 15),
          endDate: DateTime(2026, 6, 15),
          status: 'upcoming',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      assocRepo = MockAssociationRepository();
      compProvider = CompetitionProvider(
        compRepo,
        MockProfileRepository(),
        associationRepository: assocRepo,
      );
      authProvider = MockAuthProvider();
    });

    testWidgets('MobileSearchPage renders scope dropdown and toggles scope', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: MobileSearchPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that the ChoiceChips are not displayed
      expect(find.byType(ChoiceChip), findsNothing);

      // Verify initial scope icon is emoji_events
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);

      // Tap on the Search scope tooltip to open the dropdown menu
      await tester.tap(find.byTooltip('Search scope'));
      await tester.pumpAndSettle();

      // Verify dropdown options are present
      expect(find.text('Competitions'), findsOneWidget);
      expect(find.text('Associations'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);

      // Tap on the Associations option
      await tester.tap(find.text('Associations'));
      await tester.pumpAndSettle();

      // Verify that the scope icon is updated to business (association icon)
      expect(find.byIcon(Icons.business), findsOneWidget);
    });

    testWidgets('AssociationManagementPage public view renders filter, sort, layout switches', (tester) async {
      // Set physical size to Desktop
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Load initial associations list
      await compProvider.fetchAssociations();
      await compProvider.searchAssociations('');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AssociationLibraryPage(isInline: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check result count indicator
      expect(find.text('2 Associations'), findsOneWidget);

      // Check sorting options button is present
      expect(find.byTooltip('Sort options'), findsOneWidget);

      // Check layout selector is present (with our trailing space)
      expect(find.byTooltip('Select layout '), findsOneWidget);

      // Check filter section header
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('SCOPE'), findsOneWidget);
    });

    testWidgets('RankingsPage renders filters and toggles layout modes', (tester) async {
      // Set physical size to Desktop to make filter panel visible
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: RankingsPage(showAppBar: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filters should be visible on desktop view
      expect(find.text('Filters'), findsOneWidget);
      expect(find.byKey(const Key('rankings_search_input')), findsOneWidget);

      // Check layout switcher button exists
      expect(find.byTooltip('Select layout '), findsOneWidget);

      // Check by default it is List/Compact layout
      expect(find.byType(ListTile), findsAtLeast(1));

      // Toggle to Table view
      await tester.tap(find.byTooltip('Select layout '));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Table View'));
      await tester.pumpAndSettle();

      // Verify Table is shown
      expect(find.byType(Table), findsOneWidget);

      // Toggle to Grid view
      await tester.tap(find.byTooltip('Select layout '));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grid View'));
      await tester.pumpAndSettle();

      // Verify Card widgets are shown (each athlete has a card in grid view)
      expect(find.byType(Card), findsAtLeast(1));
    });

    testWidgets('ProfilePage displays settings icon directly behind full name', (tester) async {
      final userProfile = Profile(
        id: 'user-1',
        username: 'johndoe',
        fullName: 'John Doe',
        email: 'john@example.com',
      );
      authProvider = MockAuthProvider(isAuthenticated: true, currentUserProfile: userProfile);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: ProfilePage(isInline: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify settings button is present by key
      expect(find.byKey(const Key('profile_settings_icon')), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('AdminDashboardPage has correct scroll physics on Desktop vs Mobile', (tester) async {
      final userProfile = Profile(
        id: 'user-admin',
        username: 'admin',
        fullName: 'Admin User',
        email: 'admin@example.com',
        isAdmin: true,
      );
      authProvider = MockAuthProvider(isAuthenticated: true, currentUserProfile: userProfile);

      // Desktop View
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AdminDashboardPage(isInline: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabViewFinder = find.byType(TabBarView);
      expect(tabViewFinder, findsOneWidget);
      final tabView = tester.widget<TabBarView>(tabViewFinder);
      expect(tabView.physics, isA<NeverScrollableScrollPhysics>());

      // Mobile View
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AdminDashboardPage(isInline: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabViewMobileFinder = find.byType(TabBarView);
      final tabViewMobile = tester.widget<TabBarView>(tabViewMobileFinder);
      expect(tabViewMobile.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('FormatsConfigPage creation form contains Map Disciplines label and Search disciplines field', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final userProfile = Profile(
        id: 'user-admin',
        username: 'admin',
        fullName: 'Admin User',
        email: 'admin@example.com',
        isAdmin: true,
      );
      authProvider = MockAuthProvider(isAuthenticated: true, currentUserProfile: userProfile);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: FormatsConfigPage(isEmbedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Create Format' button (ElevatedButton.icon with icon add)
      final createBtn = find.widgetWithText(ElevatedButton, 'Create Format');
      expect(createBtn, findsOneWidget);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Verify breadcrumb and subpage layout shows Create Format subpage
      expect(find.text('Map Disciplines'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Search disciplines...'), findsOneWidget);
    });

    testWidgets('HomeNavigationShell mobile drawer tab collection dropdown is decorated with a bottom border', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final userProfile = Profile(
        id: 'user-admin',
        username: 'admin',
        fullName: 'Admin User',
        email: 'admin@example.com',
        isAdmin: true,
      );
      authProvider = MockAuthProvider(isAuthenticated: true, currentUserProfile: userProfile);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: HomeNavigationShell(onToggleTheme: () {}, isDarkMode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the drawer by tapping the menu button
      final menuBtn = find.byIcon(Icons.menu);
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Verify drawer is open and the tab collection dropdown is present
      final dropdownFinder = find.byTooltip('Select tab collection');
      expect(dropdownFinder, findsOneWidget);

      // Verify that the parent container of the dropdown has a bottom border decoration
      final containerFinder = find.ancestor(
        of: dropdownFinder,
        matching: find.byType(Container),
      ).first;
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<Container>(containerFinder);
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.border!.bottom, isNotNull);
    });

    testWidgets('ProfilePage AppBar title opacity changes based on scroll offset', (tester) async {
      tester.view.physicalSize = const Size(400, 250);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final userProfile = Profile(
        id: 'user-123',
        username: 'johndoe',
        fullName: 'John Doe',
        email: 'john@example.com',
      );
      authProvider = MockAuthProvider(isAuthenticated: true, currentUserProfile: userProfile);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find AnimatedOpacity for the app bar title
      final titleOpacityFinder = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(AnimatedOpacity),
      );
      expect(titleOpacityFinder, findsOneWidget);

      // Verify that initially title has opacity 0.0
      var animatedOpacity = tester.widget<AnimatedOpacity>(titleOpacityFinder);
      expect(animatedOpacity.opacity, 0.0);

      // Scroll down by 350 pixels
      final scrollableFinder = find.byType(SingleChildScrollView);
      expect(scrollableFinder, findsOneWidget);
      await tester.drag(scrollableFinder, const Offset(0.0, -350.0));
      await tester.pumpAndSettle();

      // Verify that title now has opacity 1.0
      animatedOpacity = tester.widget<AnimatedOpacity>(titleOpacityFinder);
      expect(animatedOpacity.opacity, 1.0);
    });

    testWidgets('CompetitionCreationPage stepper progress starts at 0%', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CompetitionCreationPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0% Completed'), findsOneWidget);

      final progressFinder = find.byType(LinearProgressIndicator);
      expect(progressFinder, findsOneWidget);
      final progressIndicator = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(progressIndicator.value, 0.0);
    });

    testWidgets('AssociationCreationPage stepper progress starts at 0%', (tester) async {
      final adminProfile = Profile(
        id: 'user-admin',
        username: 'admin',
        fullName: 'Admin User',
        email: 'admin@example.com',
        isAdmin: true,
      );
      final adminAuthProvider = MockAuthProvider(isAuthenticated: true, currentUserProfile: adminProfile);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: adminAuthProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AssociationCreationPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0% Completed'), findsOneWidget);

      final progressFinder = find.byType(LinearProgressIndicator);
      expect(progressFinder, findsOneWidget);
      final progressIndicator = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(progressIndicator.value, 0.0);
    });

    testWidgets('AssociationCreationPage full form interaction and submission works', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminProfile = Profile(
        id: 'user-admin',
        username: 'admin',
        fullName: 'Admin User',
        email: 'admin@example.com',
        isAdmin: true,
      );
      final adminAuthProvider = MockAuthProvider(isAuthenticated: true, currentUserProfile: adminProfile);

      // Set up MockFilePicker
      FilePicker? originalPlatform;
      try {
        originalPlatform = FilePicker.platform;
      } catch (_) {}
      FilePicker.platform = MockFilePicker();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: adminAuthProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AssociationCreationPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify page title and step title
      expect(find.text('Create Association'), findsOneWidget);
      expect(find.text('General Informations'), findsOneWidget);

      // Enter Association Name
      await tester.enterText(find.byType(TextFormField).first, 'Test Association');
      await tester.pumpAndSettle();

      // Enter Description/Bio (optional field - verify it can be empty or filled)
      await tester.enterText(find.byType(TextFormField).at(1), 'Test Description');
      await tester.pumpAndSettle();

      // Proceed to Step 2 (Association Scope)
      final nextButtonFinder = find.text('NEXT');
      await tester.ensureVisible(nextButtonFinder);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      // Verify scope dropdown exists and is initial value "Local"
      expect(find.text('Local'), findsOneWidget);

      // Verify location fields exist initially for local scope: Country, City, ZIP Code
      expect(find.text('Country *'), findsOneWidget);
      expect(find.text('City *'), findsOneWidget);
      expect(find.text('ZIP Code *'), findsOneWidget);

      // Tap scope dropdown to select "Global"
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Global').last);
      await tester.pumpAndSettle();

      // Verify location fields are removed when "Global" scope is selected
      expect(find.text('Country *'), findsNothing);
      expect(find.text('City *'), findsNothing);

      // Let's test that "Global Scope: ..." hint is NOT shown when Global is selected
      expect(find.textContaining('Global Scope:'), findsNothing);

      // Proceed to Step 3 (Media Assets)
      await tester.ensureVisible(nextButtonFinder);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      // Upload Logo Image
      final uploadLogoFinder = find.text('Upload Logo');
      await tester.ensureVisible(uploadLogoFinder);
      await tester.tap(uploadLogoFinder);
      await tester.pumpAndSettle();
      expect(find.text('test_logo.png'), findsOneWidget);

      // Dismiss SnackBar from logo upload
      ScaffoldMessenger.of(tester.element(find.byType(AssociationCreationPage))).clearSnackBars();
      await tester.pumpAndSettle();

      // Upload Banner Image
      final uploadBannerFinder = find.text('Upload Banner');
      await tester.ensureVisible(uploadBannerFinder);
      await tester.tap(uploadBannerFinder);
      await tester.pumpAndSettle();

      // Dismiss SnackBar from banner upload
      ScaffoldMessenger.of(tester.element(find.byType(AssociationCreationPage))).clearSnackBars();
      await tester.pumpAndSettle();

      // Proceed to Step 4 (Sports & Rulebooks)
      await tester.ensureVisible(nextButtonFinder);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      // Step 4: Sports & Rulebooks
      expect(find.text('Sports & Rulebooks'), findsOneWidget);

      // Tap "Add Sport" button to open the modal
      final addSportBtn = find.widgetWithText(ElevatedButton, 'Add Sport');
      expect(addSportBtn, findsOneWidget);
      await tester.tap(addSportBtn);
      await tester.pumpAndSettle();

      // Verify dropdowns for Sport Type and Formats exist in modal
      expect(find.text('Select Sport Type'), findsOneWidget);
      expect(find.text('Select Formats *'), findsOneWidget);

      // Verify formats exist in modal
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Modern'), findsOneWidget);

      // Tap to select the formats since there is no default preselection
      await tester.tap(find.text('Classic'));
      await tester.tap(find.text('Modern'));
      await tester.pumpAndSettle();

      // Specify rulebook URL for selected sport in modal
      final rulebookFieldFinder = find.widgetWithText(TextFormField, 'Rulebook URL');
      expect(rulebookFieldFinder, findsOneWidget);
      await tester.enterText(rulebookFieldFinder, 'https://example.com/rulebook.pdf');
      await tester.pumpAndSettle();

      // Confirm in modal
      final confirmAddSportBtn = find.text('SAVE');
      expect(confirmAddSportBtn, findsOneWidget);
      await tester.tap(confirmAddSportBtn);
      await tester.pumpAndSettle();

      // Verify configured sport card list renders correct formats/disciplines
      expect(find.byKey(const ValueKey('sport_card_Streetlifting')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('sport_card_Streetlifting')), matching: find.text('Classic')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('sport_card_Streetlifting')), matching: find.text('Modern')), findsOneWidget);

      // Verify that edit and remove buttons exist with proper icons and design.md colors
      final editButtonFinder = find.descendant(
        of: find.byKey(const ValueKey('sport_card_Streetlifting')),
        matching: find.byIcon(Icons.edit_outlined),
      );
      expect(editButtonFinder, findsOneWidget);

      final deleteButtonFinder = find.descendant(
        of: find.byKey(const ValueKey('sport_card_Streetlifting')),
        matching: find.byIcon(Icons.delete_outline),
      );
      expect(deleteButtonFinder, findsOneWidget);

      // Retrieve context and theme to verify icon colors match design tokens
      final BuildContext context = tester.element(find.byType(AssociationCreationPage));
      final theme = Theme.of(context);
      final editIconWidget = tester.widget<Icon>(editButtonFinder);
      expect(editIconWidget.color, theme.colorScheme.primary);

      final deleteIconWidget = tester.widget<Icon>(deleteButtonFinder);
      expect(deleteIconWidget.color, theme.colorScheme.error);

      // Verify disciplines of selected formats are grouped by format (headings exist inside card)
      final cardClassicHeaderFinder = find.descendant(
        of: find.byKey(const ValueKey('sport_card_Streetlifting')),
        matching: find.text('Classic'),
      );
      expect(cardClassicHeaderFinder, findsAtLeast(1));

      final cardModernHeaderFinder = find.descendant(
        of: find.byKey(const ValueKey('sport_card_Streetlifting')),
        matching: find.text('Modern'),
      );
      expect(cardModernHeaderFinder, findsAtLeast(1));

      expect(find.text('Pull Up'), findsAtLeast(1));
      expect(find.text('Dip'), findsAtLeast(1));
      expect(find.text('Squat'), findsAtLeast(1));
      expect(find.text('Muscle Up'), findsAtLeast(1));

      // Verify editing is triggered via the edit button (opens modal with grouped disciplines)
      await tester.tap(editButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Edit Sport Configuration'), findsOneWidget);

      // Verify headings inside the active modal dialog
      final modalClassicHeaderFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Classic'),
      );
      expect(modalClassicHeaderFinder, findsOneWidget);

      final modalModernHeaderFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Modern'),
      );
      expect(modalModernHeaderFinder, findsOneWidget);

      // Close the modal by tapping SAVE
      final updateSportBtn = find.text('SAVE');
      expect(updateSportBtn, findsOneWidget);
      await tester.tap(updateSportBtn);
      await tester.pumpAndSettle();

      // Proceed to Step 5 (Social Channels)
      await tester.ensureVisible(nextButtonFinder);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      // Step 5: Social & Channels
      expect(find.text('Social & Digital Channels'), findsOneWidget);

      // Verify website field and social media handle fields exist
      expect(find.text('Official Website URL'), findsOneWidget);
      expect(find.text('Instagram Username / URL'), findsOneWidget);

      // Verify brand icons exist via FaIcon/FontAwesomeIcons
      expect(find.byType(FaIcon), findsAtLeastNWidgets(3));

      // Enter website URL
      await tester.enterText(find.widgetWithText(TextFormField, 'Official Website URL'), 'https://example.com');
      await tester.pumpAndSettle();

      // Submit
      final submitButtonFinder = find.text('SUBMIT');
      await tester.ensureVisible(submitButtonFinder);
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle();

      // Restore FilePicker platform
      if (originalPlatform != null) {
        FilePicker.platform = originalPlatform;
      }
    });

    testWidgets('AssociationCreationPage parent association and copy sports/rulebooks flow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminProfile = Profile(
        id: 'user-admin',
        username: 'admin',
        fullName: 'Admin User',
        email: 'admin@example.com',
        isAdmin: true,
      );
      final adminAuthProvider = MockAuthProvider(isAuthenticated: true, currentUserProfile: adminProfile);

      assocRepo.customAssociations = [
        Association(
          id: 'assoc-parent-1',
          name: 'Parent Fed',
          scope: 'global',
          supportedSports: ['Streetlifting'],
          supportedFormats: ['Modern'],
          rulebooks: {'Streetlifting': 'https://example.com/parent_rules.pdf'},
          socialChannels: {},
          ownerId: 'user-admin',
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: adminAuthProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AssociationCreationPage(),
            ),
          ),
        ),
      );
      // Enter Association Name
      await tester.enterText(find.byType(TextFormField).first, 'Test Association');
      await tester.pumpAndSettle();

      final nextButtonFinder = find.text('NEXT');
      await tester.ensureVisible(nextButtonFinder);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Parent Association'), findsOneWidget);
      expect(find.text('Parent Association (Optional)'), findsNothing);

      // Tap scope dropdown to select "Global"
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Global').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent Fed').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(nextButtonFinder);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      await tester.ensureVisible(nextButtonFinder);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      final applyParentBtn = find.text('Apply Sports & Rulebook of Parent Fed');
      expect(applyParentBtn, findsOneWidget);

      expect(find.byKey(const ValueKey('sport_card_Streetlifting')), findsNothing);

      await tester.tap(applyParentBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sport_card_Streetlifting')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('sport_card_Streetlifting')), matching: find.text('Modern')), findsOneWidget);
      expect(find.text('https://example.com/parent_rules.pdf'), findsOneWidget);
    });

    testWidgets('AssociationDetailPage displays header chips, share button, social chips, and switches tabs', (tester) async {
      final mockProfileRepo = MockProfileRepository();
      final assoc = Association(
        id: 'assoc-1',
        name: 'Alpha Association',
        description: 'Alpha Description',
        scope: 'national',
        supportedSports: ['Streetlifting'],
        supportedFormats: ['Modern'],
        country: 'Germany',
        rulebooks: {'Streetlifting': 'https://example.com/rulebook.pdf'},
        socialChannels: {'instagram': 'alphapower', 'youtube': 'https://youtube.com/@alpha_channel'},
        ownerId: 'user-1',
        website: 'https://alpha.org',
      );

      assocRepo.customAssociations = [assoc];

      compProvider = CompetitionProvider(
        compRepo,
        mockProfileRepo,
        associationRepository: assocRepo,
      );

      compProvider.associations.clear();
      compProvider.associations.add(assoc);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AssociationDetailPage(associationId: 'assoc-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert Scope Chip is visible
      expect(find.text('NATIONAL'), findsOneWidget);
      // Assert Territory Chip is visible
      expect(find.text('GERMANY'), findsOneWidget);

      // Assert Description text is visible
      expect(find.text('Alpha Description'), findsOneWidget);

      // Assert website & social media chips are present
      expect(find.text('alpha.org'), findsOneWidget);
      expect(find.text('@alphapower'), findsOneWidget);
      expect(find.text('@alpha_channel'), findsOneWidget);

      // Assert SHARE ASSOCIATION button is present
      expect(find.text('SHARE ASSOCIATION'), findsOneWidget);

      // Verify the tab menu items are visible
      expect(find.text('Competitions'), findsOneWidget);
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);

      // Tapping on 'Sports' tab and pump
      await tester.ensureVisible(find.text('Sports'));
      await tester.tap(find.text('Sports'));
      await tester.pumpAndSettle();

      // Assert sports information (rulebook, format) is displayed
      expect(find.text('STREETLIFTING'), findsOneWidget);
      expect(find.text('Rulebook'), findsOneWidget);
      expect(find.text('Modern'), findsOneWidget);
    });

    testWidgets('UserLibraryPage renders search result count, reordered ProfileCard chips, and compact sex chip', (tester) async {
      final mockProfileRepo = MockProfileRepository();
      compProvider = CompetitionProvider(
        compRepo,
        mockProfileRepo,
        associationRepository: assocRepo,
      );

      final testProfile = Profile(
        id: 'user-test-1',
        username: 'alex',
        fullName: 'Alex Carter',
        email: 'alex@example.com',
        sex: 'male',
        country: 'Germany',
      );
      mockProfileRepo.customProfiles = [testProfile];
      compProvider.searchedUsers.clear();
      compProvider.searchedUsers.add(testProfile);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UserLibraryPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify title is "1 Users"
      expect(find.text('1 Users'), findsOneWidget);

      // 2. Verify header Container decoration has no border
      final headerContainerFinder = find.ancestor(
        of: find.text('1 Users'),
        matching: find.byType(Container),
      ).first;
      final headerContainer = tester.widget<Container>(headerContainerFinder);
      final decoration = headerContainer.decoration as BoxDecoration?;
      expect(decoration?.border, isNull);

      // 3. Verify ProfileCard (Grid View initially) country & sex chips are present
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.descendant(of: find.byType(ProfileCard), matching: find.byIcon(Icons.location_on_outlined)), findsOneWidget);

      // 4. Verify no dark fade overlay (only banner image or default banner in the stack children)
      final bannerStackFinder = find.descendant(
        of: find.byType(ProfileCard),
        matching: find.byWidgetPredicate((w) => w is Stack && w.fit == StackFit.expand),
      );
      final bannerStack = tester.widget<Stack>(bannerStackFinder);
      expect(bannerStack.children.length, 1);

      // 5. Toggle layout to Compact List View
      final toggleButtonFinder = find.byTooltip('Select layout ');
      expect(toggleButtonFinder, findsOneWidget);
      await tester.tap(toggleButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compact View'));
      await tester.pumpAndSettle();

      // 6. Verify UserCompactRow sex chip is displayed next to country chip
      expect(find.byType(UserCompactRow), findsOneWidget);
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.descendant(of: find.byType(UserCompactRow), matching: find.byIcon(Icons.location_on_outlined)), findsOneWidget);
    });

    testWidgets('AssociationCompactRow displays scope and territory chips next to chevron icon with increased font size', (tester) async {
      final mockProfileRepo = MockProfileRepository();
      compProvider = CompetitionProvider(
        compRepo,
        mockProfileRepo,
        associationRepository: assocRepo,
      );

      final testAssoc = Association(
        id: 'assoc-test-1',
        name: 'Alpha Association',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-1',
        supportedSports: ['Streetlifting'],
      );

      assocRepo.customAssociations = [testAssoc];
      compProvider.searchedAssociations.clear();
      compProvider.searchedAssociations.add(testAssoc);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AssociationLibraryPage(isInline: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to compact layout
      final toggleButtonFinder = find.byTooltip('Select layout ');
      expect(toggleButtonFinder, findsOneWidget);
      await tester.tap(toggleButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compact View'));
      await tester.pumpAndSettle();

      // 1. Verify AssociationCompactRow is rendered
      expect(find.byType(AssociationCompactRow), findsOneWidget);

      // 2. Verify scope chip and territory chip exist
      expect(find.text('NATIONAL'), findsOneWidget);
      expect(find.text('GERMANY'), findsOneWidget);

      // 3. Verify text size is 10 for the chips
      final nationalText = tester.widget<Text>(find.text('NATIONAL'));
      expect(nationalText.style?.fontSize, 10);

      final germanyText = tester.widget<Text>(find.text('GERMANY'));
      expect(germanyText.style?.fontSize, 10);
    });

    testWidgets('Search query clearing logic is triggered on navigation, logout, and mobile back button', (tester) async {
      final mockProfileRepo = MockProfileRepository();
      compProvider = CompetitionProvider(
        compRepo,
        mockProfileRepo,
        associationRepository: assocRepo,
      );

      // Desktop layout first
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testAuthProvider = MockAuthProvider(
        isAuthenticated: true,
        currentUserProfile: Profile(
          id: 'user-1',
          username: 'johndoe',
          fullName: 'John Doe',
          email: 'john@example.com',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: testAuthProvider),
          ],
          child: MaterialApp(
            home: HomeNavigationShell(onToggleTheme: () {}, isDarkMode: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set query in provider
      compProvider.setSearchScopeAndQuery(SearchScope.users, 'marie');
      await tester.pumpAndSettle();

      // 1. Verify UserLibraryPage is active and query is set
      expect(find.byType(UserLibraryPage), findsOneWidget);
      expect(compProvider.query, 'marie');

      // 2. Click on "Rankings" to leave the page
      await tester.tap(find.text('Rankings'));
      await tester.pumpAndSettle();

      // 3. Verify RankingsPage is active and query is cleared
      expect(find.byType(RankingsPage), findsOneWidget);
      expect(compProvider.query, '');

      // 4. Now test mobile back button clearing
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: testAuthProvider),
          ],
          child: MaterialApp(
            home: HomeNavigationShell(onToggleTheme: () {}, isDarkMode: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set query in provider
      compProvider.setSearchScopeAndQuery(SearchScope.users, 'marie');
      await tester.pumpAndSettle();

      // On mobile, the hamburger menu icon (Icons.menu) should be replaced with Icons.arrow_back
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);

      // Tap the back arrow
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify query is cleared
      expect(compProvider.query, '');
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('AssociationManagementPage Network tab shows parent and child/sub-associations, and allows add/remove', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Prepare fake associations
      final currentAssoc = Association(
        id: 'current-1',
        name: 'Current Association',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );

      final otherAssoc = Association(
        id: 'other-1',
        name: 'Other Association',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'someone-else',
      );

      // Save them in the mock repo
      await assocRepo.createAssociation(currentAssoc);
      await assocRepo.createAssociation(otherAssoc);

      // Authenticate as owner
      authProvider.setAuthenticated(
        true,
        profile: Profile(
          id: 'owner-123',
          username: 'owneruser',
          fullName: 'Owner User',
          email: 'owner@example.com',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AssociationManagementPage(associationId: 'current-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Network tab (the 5th tab)
      expect(find.text('Network'), findsOneWidget);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Parent Association header should be visible
      expect(find.text('Parent Association'), findsOneWidget);
      expect(find.text('This association has no parent association. It is a root association in the network.'), findsOneWidget);

      // Sub-associations header should be visible
      expect(find.text('0 Sub-Associations'), findsOneWidget);

      // Tap on "Add Sub-Association"
      expect(find.text('Add Sub-Association'), findsOneWidget);
      await tester.tap(find.text('Add Sub-Association'));
      await tester.pumpAndSettle();

      // Check dialog is open
      expect(find.text('Add Sub-Associations'), findsOneWidget);
      expect(find.text('Other Association'), findsOneWidget);

      // Click checkbox next to "Other Association"
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // Click ADD
      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      // Verify sub-association was added
      expect(find.text('1 Sub-Associations'), findsOneWidget);
      expect(find.text('Other Association'), findsAtLeast(1));

      // Now tap "Remove" next to "Other Association"
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirmation dialog should show
      expect(find.text('Remove Sub-Association'), findsOneWidget);
      await tester.tap(find.text('REMOVE'));
      await tester.pumpAndSettle();

      // Verify sub-association was removed
      expect(find.text('0 Sub-Associations'), findsOneWidget);
    });

    testWidgets('AssociationManagementPage Delete Association flow requires typing confirmation word', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Prepare fake association
      final currentAssoc = Association(
        id: 'delete-1',
        name: 'DelAssociation',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );

      // Save in mock repo
      await assocRepo.createAssociation(currentAssoc);

      // Authenticate as owner
      authProvider.setAuthenticated(
        true,
        profile: Profile(
          id: 'owner-123',
          username: 'owneruser',
          fullName: 'Owner User',
          email: 'owner@example.com',
        ),
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox(),
          ),
          GoRoute(
            path: '/management/:id',
            builder: (context, state) => AssociationManagementPage(
              associationId: state.pathParameters['id']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      router.push('/management/delete-1');
      await tester.pumpAndSettle();

      // Find Delete Association button under the last section in Metadata tab (it\'s loaded by default)
      final deleteBtnFinder = find.byKey(const Key('delete_association_button'));
      expect(deleteBtnFinder, findsOneWidget);

      // Scroll the Metadata tab content to bring the delete button into view
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0.0, -600.0));
      await tester.pumpAndSettle();

      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      // Check dialog is open
      expect(find.text('Delete Association'), findsOneWidget);

      // Check confirm button is disabled initially
      final confirmBtnFinder = find.byKey(const Key('delete_confirm_button'));
      expect(confirmBtnFinder, findsOneWidget);
      ElevatedButton confirmBtn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(confirmBtn.onPressed, isNull);

      // Type wrong word
      await tester.enterText(find.byKey(const Key('delete_confirm_textfield')), 'WRONG');
      await tester.pumpAndSettle();
      confirmBtn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(confirmBtn.onPressed, isNull);

      // Type correct word
      await tester.enterText(find.byKey(const Key('delete_confirm_textfield')), 'DelAssociation');
      await tester.pumpAndSettle();
      confirmBtn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(confirmBtn.onPressed, isNotNull);

      // Tap confirm to delete
      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      // Check dialog closed
      expect(find.text('Delete Association'), findsNothing);
    });

    testWidgets('GoRouter sub-routes map correctly and synchronize with AssociationManagementPage tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testAssoc = Association(
        id: 'test-route-id',
        name: 'Test Routing Association',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );
      await assocRepo.createAssociation(testAssoc);

      authProvider.setAuthenticated(
        true,
        profile: Profile(
          id: 'owner-123',
          username: 'owneruser',
          fullName: 'Owner User',
          email: 'owner@example.com',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp.router(
            routerConfig: goRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      goRouter.go('/management/associations/test-route-id/members');
      await tester.pumpAndSettle();

      final stateFinder = find.byType(AssociationManagementPage);
      expect(stateFinder, findsOneWidget);

      TabBar getTabBar() {
        return tester.widget<TabBar>(find.byType(TabBar).first);
      }

      expect(getTabBar().controller!.index, 1);

      final compGroupsTab = find.text('Comp Groups');
      expect(compGroupsTab, findsOneWidget);
      await tester.tap(compGroupsTab);
      await tester.pumpAndSettle();

      expect(getTabBar().controller!.index, 2);
      expect(goRouter.state!.matchedLocation, '/management/associations/test-route-id/compgroups');

      goRouter.go('/management/associations/test-route-id/members');
      await tester.pumpAndSettle();

      expect(getTabBar().controller!.index, 1);
    });

    testWidgets('GoRouter handles asynchronous AuthProvider initialization correctly on deep-linked page', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testAssoc = Association(
        id: 'test-async-id',
        name: 'Async Routing Association',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );
      await assocRepo.createAssociation(testAssoc);

      authProvider.setAuthenticated(false);
      authProvider.setLoading(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp.router(
            routerConfig: goRouter,
          ),
        ),
      );
      await tester.pump();

      goRouter.go('/management/associations/test-async-id/members');
      await tester.pump();

      authProvider.setAuthenticated(
        true,
        profile: Profile(
          id: 'owner-123',
          username: 'owneruser',
          fullName: 'Owner User',
          email: 'owner@example.com',
        ),
      );
      authProvider.setLoading(false);
      await tester.pumpAndSettle();

      final stateFinder = find.byType(AssociationManagementPage);
      expect(stateFinder, findsOneWidget);

      final tabBar = tester.widget<TabBar>(find.byType(TabBar).first);
      expect(tabBar.controller!.index, 1);
    });

    testWidgets('AssociationCard (Grid View) displays territory/location chip directly below scope chip', (tester) async {
      final testAssoc = Association(
        id: 'assoc-grid-1',
        name: 'Grid Association',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-1',
        supportedSports: ['Streetlifting'],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AssociationCard(association: testAssoc),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Column that contains the chips on the right side of the card
      final columnFinder = find.descendant(
        of: find.byType(AssociationCard),
        matching: find.byWidgetPredicate((widget) =>
            widget is Column &&
            widget.crossAxisAlignment == CrossAxisAlignment.end &&
            widget.children.length == 3), // Scope chip, SizedBox, Location chip
      );
      expect(columnFinder, findsOneWidget);

      final column = tester.widget<Column>(columnFinder);
      // First child is scope badge container
      final scopeContainer = column.children[0] as Container;
      final scopeText = (scopeContainer.child as Text).data;
      expect(scopeText, 'NATIONAL');

      // Second child is SizedBox(height: 4)
      expect(column.children[1], isA<SizedBox>());

      // Third child is territory/location container
      final territoryContainer = column.children[2] as Container;
      final territoryText = (territoryContainer.child as Text).data;
      expect(territoryText, 'GERMANY');
    });

    testWidgets('AssociationCompactRow displays territory/location chip before scope chip', (tester) async {
      final testAssoc = Association(
        id: 'assoc-compact-1',
        name: 'Compact Association',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-1',
        supportedSports: ['Streetlifting'],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AssociationCompactRow(association: testAssoc),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify GERMANY is displayed before NATIONAL in the row
      final germanyFinder = find.text('GERMANY');
      final nationalFinder = find.text('NATIONAL');
      expect(germanyFinder, findsOneWidget);
      expect(nationalFinder, findsOneWidget);

      final germanyOffset = tester.getCenter(germanyFinder);
      final nationalOffset = tester.getCenter(nationalFinder);
      expect(germanyOffset.dx, lessThan(nationalOffset.dx));
    });

    testWidgets('AssociationManagementPage Network tab shows location before scope chip', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final currentAssoc = Association(
        id: 'current-2',
        name: 'Current Assoc',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );

      final parentAssoc = Association(
        id: 'parent-2',
        name: 'Parent Assoc',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );

      assocRepo.customAssociations = [currentAssoc, parentAssoc];
      await assocRepo.createAssociation(currentAssoc);
      await assocRepo.createAssociation(parentAssoc);

      // Link parent association
      final updated = currentAssoc.copyWith(parentAssociationId: 'parent-2');
      await assocRepo.updateAssociation(updated);

      authProvider.setAuthenticated(
        true,
        profile: Profile(
          id: 'owner-123',
          username: 'owneruser',
          fullName: 'Owner User',
          email: 'owner@example.com',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AssociationManagementPage(associationId: 'current-2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Network tab
      expect(find.text('Network'), findsOneWidget);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Verify Parent Assoc is displayed in the parent association section
      expect(find.text('Parent Assoc'), findsOneWidget);

      // Verify chips inside the _buildAssociationRow: GERMANY is displayed before NATIONAL
      final germanyFinder = find.text('GERMANY');
      final nationalFinder = find.text('NATIONAL');
      expect(germanyFinder, findsOneWidget);
      expect(nationalFinder, findsOneWidget);

      final germanyOffset = tester.getCenter(germanyFinder);
      final nationalOffset = tester.getCenter(nationalFinder);
      expect(germanyOffset.dx, lessThan(nationalOffset.dx));
    });

    testWidgets('AssociationDetailPage Network tab displays rows without chevron icon or scope subtitle and shows chips on the right', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final currentAssoc = Association(
        id: 'current-detail',
        name: 'Current Detail Assoc',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
        parentAssociationId: 'parent-detail',
      );

      final parentAssoc = Association(
        id: 'parent-detail',
        name: 'Parent Detail Assoc',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );

      final subAssoc = Association(
        id: 'sub-detail',
        name: 'Sub Detail Assoc',
        scope: 'local',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
        parentAssociationId: 'current-detail',
      );

      assocRepo.customAssociations = [currentAssoc, parentAssoc, subAssoc];
      compProvider.associations.clear();
      compProvider.associations.addAll([currentAssoc, parentAssoc, subAssoc]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AssociationDetailPage(associationId: 'current-detail'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Network tab
      expect(find.text('Network'), findsOneWidget);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Verify parent and sub associations are shown
      expect(find.text('Parent Detail Assoc'), findsOneWidget);
      expect(find.text('Sub Detail Assoc'), findsOneWidget);

      // Verify no chevron right icon is present in the network tab content
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      // Verify no subtitle texts containing the raw scope value
      final parentTileFinder = find.ancestor(of: find.text('Parent Detail Assoc'), matching: find.byType(ListTile));
      expect(parentTileFinder, findsOneWidget);
      final parentListTile = tester.widget<ListTile>(parentTileFinder);
      expect(parentListTile.subtitle, isNull);

      final subTileFinder = find.ancestor(of: find.text('Sub Detail Assoc'), matching: find.byType(ListTile));
      expect(subTileFinder, findsOneWidget);
      final subListTile = tester.widget<ListTile>(subTileFinder);
      expect(subListTile.subtitle, isNull);

      // Verify chips are present in the trailing Row
      expect(find.text('GERMANY'), findsNWidgets(3));
      expect(find.text('NATIONAL'), findsNWidgets(2));
      expect(find.text('LOCAL'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);

      // Verify Card margin is EdgeInsets.only(bottom: 8) for parent association
      final parentCardFinder = find.ancestor(of: find.text('Parent Detail Assoc'), matching: find.byType(Card));
      expect(parentCardFinder, findsOneWidget);
      final parentCard = tester.widget<Card>(parentCardFinder);
      expect(parentCard.margin, const EdgeInsets.only(bottom: 8));

      // Verify Sub-Association Card margin has left indentation of 16.0
      final subCardFinder = find.ancestor(of: find.text('Sub Detail Assoc'), matching: find.byType(Card));
      expect(subCardFinder, findsOneWidget);
      final subCard = tester.widget<Card>(subCardFinder);
      expect(subCard.margin, const EdgeInsets.only(left: 16.0, bottom: 8.0));

      // Verify Card height is 72
      final containerFinder = find.descendant(of: parentCardFinder, matching: find.byType(Container)).first;
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxHeight, 72.0);
    });

    testWidgets('AssociationDetailPage Team tab renders headers, role chips, and uppercase initials avatar correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final assoc = Association(
        id: 'assoc-team-detail',
        name: 'Team Detail Assoc',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );

      final member1 = AssociationMember(
        id: 'mem-1',
        associationId: 'assoc-team-detail',
        userId: 'user-id-1',
        role: 'owner',
        customTitle: 'Founder',
      );

      final member2 = AssociationMember(
        id: 'mem-2',
        associationId: 'assoc-team-detail',
        userId: 'user-id-2',
        role: 'editor',
        customTitle: 'Head Referee',
      );

      final member3 = AssociationMember(
        id: 'mem-3',
        associationId: 'assoc-team-detail',
        userId: 'user-id-3',
        role: 'editor',
        customTitle: null,
      );

      assocRepo.customAssociations = [assoc];
      assocRepo.mockMembers.clear();
      assocRepo.mockMembers.addAll([member1, member2, member3]);

      // Mock user profiles in the provider
      final mockProfileRepo = MockProfileRepository();
      mockProfileRepo.customProfiles = [
        Profile(id: 'user-id-1', username: 'owneruser', fullName: 'John Doe', email: 'owner@example.com'),
        Profile(id: 'user-id-2', username: 'editoruser', fullName: 'Jane Smith', email: 'editor@example.com'),
        Profile(id: 'user-id-3', username: 'otheruser', fullName: 'Other User', email: 'other@example.com'),
      ];

      compProvider = CompetitionProvider(
        compRepo,
        mockProfileRepo,
        associationRepository: assocRepo,
      );
      compProvider.associations.clear();
      compProvider.associations.add(assoc);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AssociationDetailPage(associationId: 'assoc-team-detail'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Team tab
      expect(find.text('Team'), findsOneWidget);
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      // Verify section headers and bold styling
      final ownerHeaderFinder = find.text('Owner');
      final editorHeaderFinder = find.text('Editors');
      expect(ownerHeaderFinder, findsOneWidget);
      expect(editorHeaderFinder, findsOneWidget);

      final ownerHeaderText = tester.widget<Text>(ownerHeaderFinder);
      expect(ownerHeaderText.style?.fontWeight, FontWeight.bold);

      // Verify count text chips
      expect(find.text('1 Member'), findsOneWidget);
      expect(find.text('2 Members'), findsOneWidget);

      // Verify member names
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);

      // Verify custom initials
      expect(find.text('JD'), findsOneWidget);
      expect(find.text('JS'), findsOneWidget);

      // Verify initials text colors and background container
      final jdAvatarFinder = find.descendant(of: find.byType(CircleAvatar), matching: find.text('JD'));
      expect(jdAvatarFinder, findsOneWidget);
      final jdText = tester.widget<Text>(jdAvatarFinder);
      expect(jdText.style?.fontWeight, FontWeight.bold);
      expect(jdText.style?.fontSize, 12);

      // Check trailing is a Chip (pill shaped with no borders)
      final ownerChipFinder = find.descendant(
        of: find.ancestor(of: find.text('John Doe'), matching: find.byType(Card)),
        matching: find.byType(Chip),
      );
      expect(ownerChipFinder, findsOneWidget);
      final ownerChip = tester.widget<Chip>(ownerChipFinder);
      expect(ownerChip.side, BorderSide.none);
      expect(ownerChip.shape, isA<RoundedRectangleBorder>());
      final ownerShape = ownerChip.shape as RoundedRectangleBorder;
      expect(ownerShape.borderRadius, BorderRadius.circular(20));
      expect((ownerChip.label as Text).data, 'FOUNDER');

      final editorChipFinder = find.descendant(
        of: find.ancestor(of: find.text('Jane Smith'), matching: find.byType(Card)),
        matching: find.byType(Chip),
      );
      expect(editorChipFinder, findsOneWidget);
      final editorChip = tester.widget<Chip>(editorChipFinder);
      expect((editorChip.label as Text).data, 'HEAD REFEREE');

      // Verify member3 (Other User) with no custom title does NOT render a Chip
      final otherCardFinder = find.ancestor(of: find.text('Other User'), matching: find.byType(Card));
      expect(otherCardFinder, findsOneWidget);
      final otherChipFinder = find.descendant(of: otherCardFinder, matching: find.byType(Chip));
      expect(otherChipFinder, findsNothing);

      // Verify TabBar is not scrollable and fills width
      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsOneWidget);
      final tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(tabBar.isScrollable, false);

      // Verify tapping the user card navigates to ProfilePage
      await tester.tap(find.text('John Doe'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('AssociationManagementPage members tab displays Owner header and custom title as chip', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final currentAssoc = Association(
        id: 'current-management-mem',
        name: 'Current Management Assoc',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );

      final member1 = AssociationMember(
        id: 'mem-m1',
        associationId: 'current-management-mem',
        userId: 'user-id-1',
        role: 'owner',
        customTitle: 'President',
      );

      final member2 = AssociationMember(
        id: 'mem-m2',
        associationId: 'current-management-mem',
        userId: 'user-id-2',
        role: 'editor',
        customTitle: null,
      );

      assocRepo.customAssociations = [currentAssoc];
      assocRepo.mockMembers.clear();
      assocRepo.mockMembers.addAll([member1, member2]);

      final mockProfileRepo = MockProfileRepository();
      mockProfileRepo.customProfiles = [
        Profile(id: 'user-id-1', username: 'presidentuser', fullName: 'President Name', email: 'pres@example.com'),
        Profile(id: 'user-id-2', username: 'regularuser', fullName: 'Regular User', email: 'reg@example.com'),
      ];

      compProvider = CompetitionProvider(
        compRepo,
        mockProfileRepo,
        associationRepository: assocRepo,
      );
      compProvider.associations.clear();
      compProvider.associations.add(currentAssoc);

      authProvider.setAuthenticated(
        true,
        profile: Profile(
          id: 'owner-123',
          username: 'owneruser',
          fullName: 'Owner User',
          email: 'owner@example.com',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AssociationManagementPage(associationId: 'current-management-mem'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Members tab
      expect(find.text('Members'), findsOneWidget);
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Verify the header is Owner (not Owners)
      expect(find.text('Owner'), findsOneWidget);

      // Verify the custom title PRESIDENT is displayed on the Chip instead of OWNER
      final cardFinder = find.ancestor(of: find.text('President Name'), matching: find.byType(Card));
      expect(cardFinder, findsOneWidget);
      final chipFinder = find.descendant(of: cardFinder, matching: find.byType(Chip));
      expect(chipFinder, findsOneWidget);
      final chip = tester.widget<Chip>(chipFinder);
      expect((chip.label as Text).data, 'PRESIDENT');

      // Verify that member2 (Regular User) without custom title does NOT display a Chip
      final regularCardFinder = find.ancestor(of: find.text('Regular User'), matching: find.byType(Card));
      expect(regularCardFinder, findsOneWidget);
      final regularChipFinder = find.descendant(of: regularCardFinder, matching: find.byType(Chip));
      expect(regularChipFinder, findsNothing);
    });

    testWidgets('AssociationManagementPage update owner custom title works', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final currentAssoc = Association(
        id: 'current-management-mem',
        name: 'Current Management Assoc',
        scope: 'national',
        country: 'Germany',
        rulebooks: {},
        socialChannels: {},
        ownerId: 'owner-123',
      );

      final member1 = AssociationMember(
        id: 'mem-m1',
        associationId: 'current-management-mem',
        userId: 'owner-123',
        role: 'owner',
        customTitle: 'President',
      );

      assocRepo.customAssociations = [currentAssoc];
      assocRepo.mockMembers.clear();
      assocRepo.mockMembers.add(member1);

      final mockProfileRepo = MockProfileRepository();
      mockProfileRepo.customProfiles = [
        Profile(id: 'owner-123', username: 'presidentuser', fullName: 'President Name', email: 'pres@example.com'),
      ];

      compProvider = CompetitionProvider(
        compRepo,
        mockProfileRepo,
        associationRepository: assocRepo,
      );
      compProvider.associations.clear();
      compProvider.associations.add(currentAssoc);

      authProvider.setAuthenticated(
        true,
        profile: Profile(
          id: 'owner-123',
          username: 'presidentuser',
          fullName: 'President Name',
          email: 'pres@example.com',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: compProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AssociationManagementPage(associationId: 'current-management-mem'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Members tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Verify member is rendered
      expect(find.text('President Name'), findsOneWidget);

      // Find and tap the edit button
      final editBtn = find.byIcon(Icons.edit_outlined);
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Enter new custom title
      final textFormField = find.widgetWithText(TextFormField, 'Custom Title');
      expect(textFormField, findsOneWidget);
      await tester.enterText(textFormField, 'CEO');
      await tester.pumpAndSettle();

      // Tap SAVE
      final saveBtn = find.widgetWithText(ElevatedButton, 'SAVE');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify custom title is updated to CEO on the card chip
      final cardFinder = find.ancestor(of: find.text('President Name'), matching: find.byType(Card));
      expect(cardFinder, findsOneWidget);
      final chipFinder = find.descendant(of: cardFinder, matching: find.byType(Chip));
      expect(chipFinder, findsOneWidget);
      final chip = tester.widget<Chip>(chipFinder);
      expect((chip.label as Text).data, 'CEO');
    });
  });
}

