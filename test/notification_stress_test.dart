import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/system_notification.dart';
import 'package:finalrep_app/models/permission_application.dart';
import 'package:finalrep_app/models/flight.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/admin_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/notifications_page.dart';

// --- Direct Mocks for Stress Testing ---

class MockSupabaseClient implements SupabaseClient {
  @override
  final MockGoTrueClient auth;

  MockSupabaseClient({required this.auth});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoTrueClient implements GoTrueClient {
  final StreamController<AuthState> _authStateController;
  MockGoTrueClient(this._authStateController);

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockProfileRepository implements ProfileRepository {
  final Map<String, Profile> profiles = {};
  final List<Profile> updateCalls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Profile?> getProfile(String id) async {
    return profiles[id];
  }

  @override
  Future<Profile?> getProfileByUsername(String username) async {
    try {
      return profiles.values.firstWhere((p) => p.username == username);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Profile?> updateProfile(Profile profile) async {
    profiles[profile.id] = profile;
    updateCalls.add(profile);
    return profile;
  }

  @override
  Future<Profile?> updatePermissions(
    String userId, {
    bool? isCompetitionCreator,
    bool? isAssociationCreator,
    bool? isAdmin,
  }) async {
    final existing = profiles[userId];
    if (existing == null) return null;
    final updated = existing.copyWith(
      isCompetitionCreator:
          isCompetitionCreator ?? existing.isCompetitionCreator,
      isAssociationCreator:
          isAssociationCreator ?? existing.isAssociationCreator,
      isAdmin: isAdmin ?? existing.isAdmin,
    );
    profiles[userId] = updated;
    return updated;
  }
}

class MockCompetitionRepository implements CompetitionRepository {
  final Map<String, Competition> competitions = {};
  final Map<String, List<Profile>> competitionAthletes = {};
  final List<Flight> createdFlights = [];

  @override
  SupabaseClient get client => MockSupabaseClient(
    auth: MockGoTrueClient(StreamController<AuthState>.broadcast()),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Competition?> getCompetitionById(String id) async {
    return competitions[id];
  }

  @override
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status = 'upcoming',
  }) async {
    return competitions.values.toList();
  }

  @override
  Future<Competition?> createCompetition(Competition competition) async {
    competitions[competition.id] = competition;
    return competition;
  }

  @override
  Future<bool> registerAthlete(String competitionId, String userId) async {
    final list = competitionAthletes[competitionId] ?? [];
    if (!list.any((a) => a.id == userId)) {
      list.add(
        Profile(
          id: userId,
          username: 'user-$userId',
          fullName: 'Athlete $userId',
          email: '$userId@test.com',
        ),
      );
      competitionAthletes[competitionId] = list;
    }
    return true;
  }

  @override
  Future<List<Profile>> getCompetitionAthletes(String competitionId) async {
    return competitionAthletes[competitionId] ?? [];
  }

  @override
  Future<List<String>> getRegisteredAthleteIds(String competitionId) async {
    return (competitionAthletes[competitionId] ?? []).map((a) => a.id).toList();
  }

  @override
  Future<Flight?> createFlight(Flight flight) async {
    createdFlights.add(flight);
    return flight;
  }

  @override
  String get baseUrl => '';

  @override
  Future<List<Map<String, dynamic>>> getMeetResults() async => [];
}

class MockAdminRepository implements AdminRepository {
  final Map<String, PermissionApplication> applications = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<PermissionApplication>> getPermissionApplications() async {
    return applications.values.toList();
  }

  @override
  Future<PermissionApplication?> applyForPermissions(
    String userId,
    String type,
    String reason,
  ) async {
    final id = 'app-${DateTime.now().millisecondsSinceEpoch}';
    final app = PermissionApplication(
      id: id,
      userId: userId,
      type: type,
      reason: reason,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    applications[id] = app;
    return app;
  }

  @override
  Future<PermissionApplication?> approvePermissionApplication(String id) async {
    final app = applications[id];
    if (app == null) return null;
    final updated = PermissionApplication(
      id: app.id,
      userId: app.userId,
      type: app.type,
      reason: app.reason,
      status: 'approved',
      createdAt: app.createdAt,
    );
    applications[id] = updated;
    return updated;
  }

  @override
  Future<PermissionApplication?> rejectPermissionApplication(String id) async {
    final app = applications[id];
    if (app == null) return null;
    final updated = PermissionApplication(
      id: app.id,
      userId: app.userId,
      type: app.type,
      reason: app.reason,
      status: 'rejected',
      createdAt: app.createdAt,
    );
    applications[id] = updated;
    return updated;
  }
}

class WidgetMockAuthProvider extends ChangeNotifier implements AuthProvider {
  Profile? _currentUserProfile;
  final List<String> updatePrefCalls = [];

  WidgetMockAuthProvider({Profile? currentUserProfile})
    : _currentUserProfile = currentUserProfile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  NotificationRepository get notificationRepository => NotificationRepository(null);

  @override
  Profile? get currentUserProfile => _currentUserProfile;

  @override
  Future<void> updateNotificationPreference(
    String category,
    bool enabled,
  ) async {
    updatePrefCalls.add('$category:$enabled');
    if (_currentUserProfile != null) {
      final updatedPrefs = Map<String, bool>.from(
        _currentUserProfile!.notificationPreferences,
      );
      updatedPrefs[category] = enabled;
      _currentUserProfile = _currentUserProfile!.copyWith(
        notificationPreferences: updatedPrefs,
      );
      notifyListeners();
    }
  }
}

void main() {
  group('Notification System Trigger Stress Tests', () {
    late MockProfileRepository mockProfileRepo;
    late MockCompetitionRepository mockCompRepo;
    late MockAdminRepository mockAdminRepo;
    late NotificationRepository notificationRepo;
    late AuthProvider authProvider;
    late CompetitionProvider compProvider;
    late StreamController<AuthState> authStateController;

    setUp(() async {
      mockProfileRepo = MockProfileRepository();
      mockCompRepo = MockCompetitionRepository();
      mockAdminRepo = MockAdminRepository();

      // Use null client to test the local/mock fallback cache of NotificationRepository
      notificationRepo = NotificationRepository(null);

      authStateController = StreamController<AuthState>.broadcast();
      final mockAuth = MockGoTrueClient(authStateController);
      final mockClient = MockSupabaseClient(auth: mockAuth);

      authProvider = AuthProvider(
        mockClient,
        mockProfileRepo,
        adminRepository: mockAdminRepo,
        notificationRepository: notificationRepo,
      );

      compProvider = CompetitionProvider(
        mockCompRepo,
        mockProfileRepo,
        notificationRepository: notificationRepo,
      );

      // Seed a user profile for the auth state
      final userProfile = Profile(
        id: 'athlete-123',
        username: 'streetlifter',
        fullName: 'John Doe',
        email: 'john@streetlifting.com',
      );
      mockProfileRepo.profiles[userProfile.id] = userProfile;
    });

    tearDown(() {
      authProvider.dispose();
      compProvider.dispose();
      authStateController.close();
    });

    test('1. Registration Trigger Fires Successfully', () async {
      // Setup competition
      final comp = Competition(
        id: 'comp-101',
        title: 'Frankfurt Open',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        location: 'Frankfurt',
        sportSubtype: 'Classic',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        requiresFees: false,
      );
      mockCompRepo.competitions[comp.id] = comp;

      // Register athlete
      final success = await compProvider.registerAthlete(
        competitionId: comp.id,
        userId: 'athlete-123',
      );

      expect(success, true);

      // Get notifications
      final notifications = await notificationRepo.getNotifications(
        'athlete-123',
      );
      expect(notifications.length, 1);
      expect(notifications.first.category, 'registration');
      expect(notifications.first.title, 'Registration Confirmed');
      expect(notifications.first.message, contains('Frankfurt Open'));
    });

    test(
      '2. Permission Approval/Rejection Triggers Fire Successfully',
      () async {
        // 2.1 Approval Trigger
        final app = await mockAdminRepo.applyForPermissions(
          'athlete-123',
          'create_competition',
          'To organize regional meets.',
        );
        expect(app, isNotNull);

        // Approve application
        await authProvider.approvePermissionApplication(app!.id);

        final notifsApproval = await notificationRepo.getNotifications(
          'athlete-123',
        );
        expect(
          notifsApproval.any(
            (n) =>
                n.category == 'permissions' &&
                n.title == 'Permissions Approved',
          ),
          true,
        );

        // 2.2 Rejection Trigger
        final app2 = await mockAdminRepo.applyForPermissions(
          'athlete-123',
          'create_association',
          'To run federation.',
        );
        expect(app2, isNotNull);

        // Reject application
        await authProvider.rejectPermissionApplication(app2!.id);

        final notifsRejection = await notificationRepo.getNotifications(
          'athlete-123',
        );
        expect(
          notifsRejection.any(
            (n) =>
                n.category == 'permissions' &&
                n.title == 'Permissions Application Update',
          ),
          true,
        );
      },
    );

    test(
      '3. Payment Triggers (Formulation & Registration Action Required) Fire Successfully',
      () async {
        final associationRepo = AssociationRepository(null);
        // Seed association in mock fallback to avoid the getAssociationDetails TypeError
        final testAssoc = Association(
          id: 'assoc-owner-999',
          name: 'Test Association',
          scope: 'national',
          description: 'Test assoc desc',
          rulebooks: const {},
          socialChannels: const {},
          status: 'approved',
          ownerId: 'athlete-123',
          supportedSports: const ['Streetlifting'],
          supportedFormats: const ['Modern'],
        );
        await associationRepo.createAssociation(testAssoc);

        // Re-initialize compProvider with associationRepository explicitly
        compProvider = CompetitionProvider(
          mockCompRepo,
          mockProfileRepo,
          associationRepository: associationRepo,
          notificationRepository: notificationRepo,
        );

        // 3.1 Payment details formulated when creating a competition requiring fees
        final feeComp = Competition(
          id: 'comp-fee-1',
          title: 'Paid Meet 2026',
          startDate: DateTime.now().add(const Duration(days: 15)),
          endDate: DateTime.now().add(const Duration(days: 15)),
          location: 'Munich',
          sportSubtype: 'Modern',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          requiresFees: true,
          feeAmount: 30.0,
          feeCurrency: 'EUR',
          associationId: 'assoc-owner-999',
        );

        final created = await compProvider.createCompetition(feeComp);
        expect(created, isNotNull);

        final ownerNotifs = await notificationRepo.getNotifications(
          'assoc-owner-999',
        );
        expect(ownerNotifs.length, 1);
        expect(ownerNotifs.first.category, 'payments');
        expect(ownerNotifs.first.title, 'Payment Details Formulated');

        // 3.2 Action required triggered when an athlete registers for a competition requiring fees
        mockCompRepo.competitions[feeComp.id] = feeComp;

        // Seed a profile for athlete-fee-test
        final athleteProfile = Profile(
          id: 'athlete-fee-test',
          username: 'athletefeetest',
          fullName: 'Fee Athlete',
          email: 'fee@test.com',
        );
        mockProfileRepo.profiles[athleteProfile.id] = athleteProfile;

        final success = await compProvider.registerAthlete(
          competitionId: feeComp.id,
          userId: 'athlete-fee-test',
        );
        expect(success, true);

        final athleteNotifs = await notificationRepo.getNotifications(
          'athlete-fee-test',
        );
        // Athlete should receive: 1 registration notification + 1 payment notification
        expect(athleteNotifs.length, 2);
        expect(athleteNotifs.any((n) => n.category == 'registration'), true);
        expect(
          athleteNotifs.any(
            (n) =>
                n.category == 'payments' &&
                n.title == 'Payment Action Required',
          ),
          true,
        );
      },
    );

    test('4. Schedule Release Trigger Fires Successfully', () async {
      final comp = Competition(
        id: 'comp-sched-1',
        title: 'Championship Berlin',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 5)),
        location: 'Berlin',
        sportSubtype: 'Classic',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockCompRepo.competitions[comp.id] = comp;

      // Register athlete
      await compProvider.registerAthlete(
        competitionId: comp.id,
        userId: 'athlete-123',
      );

      // Publish schedule
      await compProvider.publishSchedule(comp.id, isPublic: true);

      final notifs = await notificationRepo.getNotifications('athlete-123');
      expect(
        notifs.any(
          (n) =>
              n.category == 'schedule' && n.title == 'Meet Schedule Published',
        ),
        true,
      );
    });

    test('5. Flight Assignment Trigger Fires Successfully', () async {
      final comp = Competition(
        id: 'comp-flight-1',
        title: 'Championship Hamburg',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 5)),
        location: 'Hamburg',
        sportSubtype: 'Modern',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockCompRepo.competitions[comp.id] = comp;

      // Seed 15 athletes to trigger splitting into multiple flights
      for (int i = 1; i <= 15; i++) {
        await mockCompRepo.registerAthlete(comp.id, 'athlete-$i');
      }

      // Balance flights
      await compProvider.balanceFlights(comp.id);

      // Verify athlete 1 got assigned to Flight A
      final athlete1Notifs = await notificationRepo.getNotifications(
        'athlete-1',
      );
      expect(
        athlete1Notifs.any(
          (n) =>
              n.category == 'flights' &&
              n.title == 'Flight Assignment Updated' &&
              n.message.contains('Flight A'),
        ),
        true,
      );

      // Verify athlete 13 got assigned to Flight B
      final athlete13Notifs = await notificationRepo.getNotifications(
        'athlete-13',
      );
      expect(
        athlete13Notifs.any(
          (n) =>
              n.category == 'flights' &&
              n.title == 'Flight Assignment Updated' &&
              n.message.contains('Flight B'),
        ),
        true,
      );
    });

    test('6. Volunteer Application Trigger Fires Successfully', () async {
      final comp = Competition(
        id: 'comp-vol-1',
        title: 'Volunteer Meet',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 5)),
        location: 'Berlin',
        sportSubtype: 'Classic',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockCompRepo.competitions[comp.id] = comp;

      // Submit volunteer application
      final success = await compProvider.submitVolunteerApplication(
        competitionId: comp.id,
        userId: 'volunteer-1',
        preferredRoles: const ['Spotter'],
        shiftAvailability: const {
          'Morning': ['Spotter'],
        },
        customFieldAnswers: const {},
        disclaimerAccepted: true,
      );

      expect(success, true);

      // Verify volunteer-1 received volunteer confirmation notification
      final volunteerNotifs = await notificationRepo.getNotifications(
        'volunteer-1',
      );
      expect(volunteerNotifs.length, 1);
      expect(volunteerNotifs.first.category, 'registration');
      expect(volunteerNotifs.first.title, 'Volunteer Application Submitted');
      expect(
        volunteerNotifs.first.message,
        'Your application to volunteer for the meet "Volunteer Meet" has been submitted.',
      );
    });
  });

  group('Profile Notification Preferences Deserialization & Sync', () {
    test(
      '1. Partial preferences JSON correctly parses and merges with default switches',
      () {
        final json = {
          'id': 'user-partial-123',
          'username': 'partialguy',
          'full_name': 'Partial Guy',
          'email': 'partial@test.com',
          'notification_preferences': {
            'registration': false,
            'permissions': false,
            // Missing payments, schedule, flights
          },
        };

        final profile = Profile.fromJson(json);

        expect(profile.notificationPreferences['registration'], false);
        expect(profile.notificationPreferences['permissions'], false);
        expect(
          profile.notificationPreferences['payments'],
          true,
        ); // default fallback
        expect(
          profile.notificationPreferences['schedule'],
          true,
        ); // default fallback
        expect(
          profile.notificationPreferences['flights'],
          true,
        ); // default fallback
      },
    );

    test(
      '2. Missing preferences JSON correctly initializes all toggles to true',
      () {
        final json = {
          'id': 'user-missing-123',
          'username': 'missingguy',
          'full_name': 'Missing Guy',
          'email': 'missing@test.com',
        };

        final profile = Profile.fromJson(json);

        expect(profile.notificationPreferences.length, 5);
        expect(profile.notificationPreferences['registration'], true);
        expect(profile.notificationPreferences['permissions'], true);
        expect(profile.notificationPreferences['payments'], true);
        expect(profile.notificationPreferences['schedule'], true);
        expect(profile.notificationPreferences['flights'], true);
      },
    );
  });

  group('NotificationsPage Widget Stress Tests', () {
    late NotificationRepository notificationRepo;
    late WidgetMockAuthProvider authProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      try {
        await Supabase.initialize(
          url: 'https://placeholder.supabase.co',
          anonKey: 'placeholder-key',
        );
      } catch (_) {
        // Already initialized in test run
      }

      notificationRepo = NotificationRepository(null); // use mock fallback
    });

    Widget makeTestableWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: NotificationsPage()),
      );
    }

    testWidgets('1. Settings toggles correctly filter notifications on display', (
      WidgetTester tester,
    ) async {
      final userId = 'test-user-settingstoggle';
      final profile = Profile(
        id: userId,
        username: 'tester',
        fullName: 'Test User',
        email: 'tester@test.com',
        notificationPreferences: {
          'registration': true,
          'permissions': true,
          'payments': true,
          'schedule': true,
          'flights': true,
        },
      );

      authProvider = WidgetMockAuthProvider(currentUserProfile: profile);

      // Seed notifications in mock database for this specific user
      final registrationNotif = SystemNotification(
        id: 'notif-st-1',
        userId: userId,
        title: 'Hamburg Registration',
        message: 'Registered successfully',
        category: 'registration',
        createdAt: DateTime.now(),
      );
      final paymentsNotif = SystemNotification(
        id: 'notif-st-2',
        userId: userId,
        title: 'Munich Payment',
        message: 'Payment of 20 EUR due',
        category: 'payments',
        createdAt: DateTime.now(),
      );

      await notificationRepo.createNotification(registrationNotif);
      await notificationRepo.createNotification(paymentsNotif);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Verify both notifications are displayed in list
      expect(find.text('Hamburg Registration'), findsOneWidget);
      expect(find.text('Munich Payment'), findsOneWidget);

      // Expand Alert Settings tile
      final expansionTile = find.byKey(const Key('alert_settings_tile'));
      expect(expansionTile, findsOneWidget);
      await tester.tap(expansionTile);
      await tester.pumpAndSettle();

      // Find switch for payments and toggle it off
      final paymentsSwitch = find.byKey(const Key('switch_payments'));
      expect(paymentsSwitch, findsOneWidget);

      // Tap switch to disable payments notifications
      await tester.tap(paymentsSwitch);
      await tester.pumpAndSettle();

      // Verify updateNotificationPreference was called and payments notification disappeared
      expect(authProvider.updatePrefCalls, contains('payments:false'));
      expect(find.text('Hamburg Registration'), findsOneWidget);
      expect(
        find.text('Munich Payment'),
        findsNothing,
      ); // Payments notification should be filtered out!
    });

    testWidgets('2. Category chips filter notifications correctly', (
      WidgetTester tester,
    ) async {
      final userId = 'test-user-categorychips';
      final profile = Profile(
        id: userId,
        username: 'tester',
        fullName: 'Test User',
        email: 'tester@test.com',
        notificationPreferences: {
          'registration': true,
          'permissions': true,
          'payments': true,
          'schedule': true,
          'flights': true,
        },
      );

      authProvider = WidgetMockAuthProvider(currentUserProfile: profile);

      final registrationNotif = SystemNotification(
        id: 'notif-cc-1',
        userId: userId,
        title: 'Hamburg Registration',
        message: 'Registered successfully',
        category: 'registration',
        createdAt: DateTime.now(),
      );
      final paymentsNotif = SystemNotification(
        id: 'notif-cc-2',
        userId: userId,
        title: 'Munich Payment',
        message: 'Payment of 20 EUR due',
        category: 'payments',
        createdAt: DateTime.now(),
      );

      await notificationRepo.createNotification(registrationNotif);
      await notificationRepo.createNotification(paymentsNotif);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Hamburg Registration'), findsOneWidget);
      expect(find.text('Munich Payment'), findsOneWidget);

      // Select 'Registration' chip to filter
      final regChip = find.byKey(const Key('chip_registration'));
      expect(regChip, findsOneWidget);
      await tester.tap(regChip);
      await tester.pumpAndSettle();

      // Now only Hamburg Registration should be shown
      expect(find.text('Hamburg Registration'), findsOneWidget);
      expect(find.text('Munich Payment'), findsNothing);

      // Deselect chip
      await tester.tap(regChip);
      await tester.pumpAndSettle();

      // Both should be shown again
      expect(find.text('Hamburg Registration'), findsOneWidget);
      expect(find.text('Munich Payment'), findsOneWidget);
    });

    testWidgets(
      '3. Unauthenticated settings switch toggles are disabled and cannot be changed',
      (WidgetTester tester) async {
        // Initialize with null profile (unauthenticated)
        authProvider = WidgetMockAuthProvider(currentUserProfile: null);

        await tester.pumpWidget(makeTestableWidget());
        await tester.pumpAndSettle();

        // Expand Alert Settings tile
        final expansionTile = find.byKey(const Key('alert_settings_tile'));
        expect(expansionTile, findsOneWidget);
        await tester.tap(expansionTile);
        await tester.pumpAndSettle();

        // Find switch for registration and verify its onChanged is null/disabled
        final regSwitchFinder = find.byKey(const Key('switch_registration'));
        expect(regSwitchFinder, findsOneWidget);

        final SwitchListTile regSwitchTile = tester.widget<SwitchListTile>(
          regSwitchFinder,
        );
        expect(regSwitchTile.onChanged, isNull);

        // Try to tap the disabled switch and verify no preference change calls were made
        await tester.tap(regSwitchFinder);
        await tester.pumpAndSettle();

        expect(authProvider.updatePrefCalls, isEmpty);
      },
    );
  });
}
