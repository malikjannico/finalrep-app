import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/system_notification.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/permission_application.dart';
import 'package:finalrep_app/models/flight.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/admin_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/notifications_page.dart';

// --- Direct Mocks for Adversarial Testing ---

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Profile?> getProfile(String id) async {
    return profiles[id];
  }

  @override
  Future<Profile?> updateProfile(Profile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<Profile?> updatePermissions(
    String userId, {
    bool? isCompetitionCreator,
    bool? isAssociationCreator,
    bool? isAdmin,
  }) async {
    final current = profiles[userId];
    if (current == null) return null;
    final updated = current.copyWith(
      isCompetitionCreator: isCompetitionCreator,
      isAssociationCreator: isAssociationCreator,
      isAdmin: isAdmin,
    );
    profiles[userId] = updated;
    return updated;
  }
}

class MockCompetitionRepository implements CompetitionRepository {
  final Map<String, Competition> competitions = {};
  final List<Profile> athletes = [];
  final List<String> registeredAthleteIds = [];
  final List<Flight> createdFlights = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  SupabaseClient get client => MockSupabaseClient(
    auth: MockGoTrueClient(StreamController<AuthState>.broadcast()),
  );

  @override
  Future<Competition?> getCompetitionById(String id) async {
    return competitions[id];
  }

  @override
  Future<List<Profile>> getCompetitionAthletes(String competitionId) async {
    return athletes;
  }

  @override
  Future<bool> registerAthlete(String competitionId, String userId) async {
    if (!registeredAthleteIds.contains(userId)) {
      registeredAthleteIds.add(userId);
    }
    return true;
  }

  @override
  Future<List<String>> getRegisteredAthleteIds(String competitionId) async {
    return registeredAthleteIds;
  }

  @override
  Future<Flight?> createFlight(Flight flight) async {
    createdFlights.add(flight);
    return flight;
  }

  @override
  Future<Competition?> createCompetition(Competition competition) async {
    competitions[competition.id] = competition;
    return competition;
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
  Future<PermissionApplication?> approvePermissionApplication(
    String applicationId,
  ) async {
    final app = applications[applicationId];
    if (app == null) return null;
    return app.copyWith(status: 'approved');
  }

  @override
  Future<PermissionApplication?> rejectPermissionApplication(
    String applicationId,
  ) async {
    final app = applications[applicationId];
    if (app == null) return null;
    return app.copyWith(status: 'rejected');
  }
}

class FakeAssociationRepository implements AssociationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Association>> getAssociations() async => [];

  @override
  Future<Association?> getAssociationDetails(String id) async {
    return Association(
      id: id,
      name: 'Test Association',
      description: 'Test Description',
      scope: 'global',
      rulebooks: const {'Streetlifting': 'https://example.com/rulebook'},
      socialChannels: const {},
      ownerId: 'owner-1',
    );
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
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://placeholder-adversarial.supabase.co',
        anonKey: 'placeholder-key',
      );
    } catch (_) {}
  });

  group('Adversarial & Stress Notification Tests', () {
    late NotificationRepository notifRepo;

    setUp(() {
      notifRepo = NotificationRepository(null);
    });

    test(
      'Triggers check - registrations, volunteer applications, permission status updates, payments, schedule releases, flight assignments',
      () async {
        // 1. Permission status updates
        final mockAuthClient = MockGoTrueClient(
          StreamController<AuthState>.broadcast(),
        );
        final mockSupabaseClient = MockSupabaseClient(auth: mockAuthClient);
        final mockProfileRepo = MockProfileRepository();
        final mockAdminRepo = MockAdminRepository();

        final userId = 'user-perm-test';
        mockProfileRepo.profiles[userId] = Profile(
          id: userId,
          username: 'permuser',
          fullName: 'Permission User',
          email: 'perm@test.com',
        );

        final authProvider = AuthProvider(
          mockSupabaseClient,
          mockProfileRepo,
          adminRepository: mockAdminRepo,
          notificationRepository: notifRepo,
        );

        // Seed permission applications
        mockAdminRepo.applications['app-1'] = PermissionApplication(
          id: 'app-1',
          userId: userId,
          type: 'create_competition',
          reason: 'Reason',
          status: 'pending',
          createdAt: DateTime.now(),
        );
        mockAdminRepo.applications['app-2'] = PermissionApplication(
          id: 'app-2',
          userId: userId,
          type: 'create_association',
          reason: 'Reason 2',
          status: 'pending',
          createdAt: DateTime.now(),
        );

        // Approve Application
        final appApprove = await authProvider.approvePermissionApplication(
          'app-1',
        );
        expect(appApprove!.status, 'approved');
        final notifsApprove = await notifRepo.getNotifications(userId);
        expect(
          notifsApprove.any(
            (n) =>
                n.category == 'permissions' &&
                n.title == 'Permissions Approved',
          ),
          true,
        );

        // Reject Application
        final appReject = await authProvider.rejectPermissionApplication(
          'app-2',
        );
        expect(appReject!.status, 'rejected');
        final notifsReject = await notifRepo.getNotifications(userId);
        expect(
          notifsReject.any(
            (n) =>
                n.category == 'permissions' &&
                n.title == 'Permissions Application Update' &&
                n.message.contains('rejected'),
          ),
          true,
        );

        // 2. Registrations & Payments
        final mockCompRepo = MockCompetitionRepository();
        final mockAssocRepo = FakeAssociationRepository();
        final compProvider = CompetitionProvider(
          mockCompRepo,
          mockProfileRepo,
          associationRepository: mockAssocRepo,
          notificationRepository: notifRepo,
        );

        final comp = Competition(
          id: 'comp-1',
          title: 'Adversarial Pull Meet',
          location: 'Munich',
          sportType: 'Streetlifting',
          sportSubtype: 'Classic',
          requiresFees: true,
          feeAmount: 15.0,
          feeCurrency: 'EUR',
          registrationEnd: DateTime.now().add(const Duration(days: 2)),
          startDate: DateTime.now().add(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        mockCompRepo.competitions[comp.id] = comp;

        // Create competition (fires payment formulation)
        final created = await compProvider.createCompetition(comp);
        expect(created, isNotNull);
        final listPaymentNotif = await notifRepo.getNotifications('');
        expect(
          listPaymentNotif.any(
            (n) =>
                n.category == 'payments' &&
                n.title == 'Payment Details Formulated',
          ),
          true,
        );

        // Register Athlete (fires registration confirmation + payment action required)
        mockCompRepo.athletes.add(
          Profile(
            id: 'athlete-adversary',
            username: 'ath1',
            fullName: 'Athlete One',
            email: 'a1@test.com',
          ),
        );
        final regSuccess = await compProvider.registerAthlete(
          competitionId: 'comp-1',
          userId: 'athlete-adversary',
        );
        expect(regSuccess, true);

        final athleteNotifs = await notifRepo.getNotifications(
          'athlete-adversary',
        );
        expect(
          athleteNotifs.any(
            (n) =>
                n.category == 'registration' &&
                n.title == 'Registration Confirmed',
          ),
          true,
        );
        expect(
          athleteNotifs.any(
            (n) =>
                n.category == 'payments' &&
                n.title == 'Payment Action Required',
          ),
          true,
        );

        // 3. Volunteer applications
        final volSuccess = await compProvider.submitVolunteerApplication(
          competitionId: 'comp-1',
          userId: 'volunteer-adversary',
          preferredRoles: ['Judge'],
          shiftAvailability: {
            'All': ['Judge'],
          },
          customFieldAnswers: {},
          disclaimerAccepted: true,
        );
        expect(volSuccess, true);
        final volNotifs = await notifRepo.getNotifications(
          'volunteer-adversary',
        );
        expect(
          volNotifs.any(
            (n) =>
                n.category == 'registration' &&
                n.title == 'Volunteer Application Submitted',
          ),
          true,
        );

        // 4. Flight assignments
        await compProvider.balanceFlights('comp-1');
        final flightNotifs = await notifRepo.getNotifications(
          'athlete-adversary',
        );
        expect(
          flightNotifs.any(
            (n) =>
                n.category == 'flights' &&
                n.title == 'Flight Assignment Updated',
          ),
          true,
        );

        // 5. Schedule releases
        await compProvider.publishSchedule('comp-1', isPublic: true);
        final schedNotifs = await notifRepo.getNotifications(
          'athlete-adversary',
        );
        expect(
          schedNotifs.any(
            (n) =>
                n.category == 'schedule' &&
                n.title == 'Meet Schedule Published',
          ),
          true,
        );
      },
    );

    testWidgets('UI Filters check - settings toggles and category chips', (
      WidgetTester tester,
    ) async {
      final userId = 'ui-user';
      final profile = Profile(
        id: userId,
        username: 'uiuser',
        fullName: 'UI User',
        email: 'ui@test.com',
        notificationPreferences: {
          'registration': true,
          'permissions': true,
          'payments': true,
          'schedule': true,
          'flights': true,
        },
      );

      final authProvider = WidgetMockAuthProvider(currentUserProfile: profile);

      // Clear mock notifications and seed new ones
      final n1 = SystemNotification(
        id: 'n-reg',
        userId: userId,
        title: 'Registration OK',
        message: 'Registered',
        category: 'registration',
        createdAt: DateTime.now(),
      );
      final n2 = SystemNotification(
        id: 'n-flights',
        userId: userId,
        title: 'Flight Assigned',
        message: 'Assigned Flight',
        category: 'flights',
        createdAt: DateTime.now(),
      );

      // Mock notifications manually inserted via static mock cache
      await notifRepo.createNotification(n1);
      await notifRepo.createNotification(n2);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(home: NotificationsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both are displayed
      expect(find.text('Registration OK'), findsOneWidget);
      expect(find.text('Flight Assigned'), findsOneWidget);

      // Toggle off flights
      final expansionTile = find.byKey(const Key('alert_settings_tile'));
      await tester.tap(expansionTile);
      await tester.pumpAndSettle();

      final flightsSwitch = find.byKey(const Key('switch_flights'));
      await tester.tap(flightsSwitch);
      await tester.pumpAndSettle();

      // Preference updated
      expect(authProvider.updatePrefCalls, contains('flights:false'));

      // Flight Assigned should be filtered out from display
      expect(find.text('Registration OK'), findsOneWidget);
      expect(find.text('Flight Assigned'), findsNothing);

      // Select registration chip
      final regChip = find.byKey(const Key('chip_registration'));
      await tester.tap(regChip);
      await tester.pumpAndSettle();

      expect(find.text('Registration OK'), findsOneWidget);

      // Deselect registration chip
      await tester.tap(regChip);
      await tester.pumpAndSettle();
      expect(find.text('Registration OK'), findsOneWidget);
    });

    testWidgets('Unauthenticated behavior - switches disabled', (
      WidgetTester tester,
    ) async {
      // Unauthenticated provider
      final authProvider = WidgetMockAuthProvider(currentUserProfile: null);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(home: NotificationsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Open settings panel
      final expansionTile = find.byKey(const Key('alert_settings_tile'));
      await tester.tap(expansionTile);
      await tester.pumpAndSettle();

      // Verify all switches are disabled (onChanged is null)
      // SwitchListTile uses a Switch. To verify if SwitchListTile is disabled, we can check the Switch onChanged callback.
      final registrationSwitch = tester.widget<SwitchListTile>(
        find.byKey(const Key('switch_registration')),
      );
      expect(registrationSwitch.onChanged, isNull);

      final flightsSwitch = tester.widget<SwitchListTile>(
        find.byKey(const Key('switch_flights')),
      );
      expect(flightsSwitch.onChanged, isNull);

      // Verify fallbacks rendered because user is unauthenticated
      expect(find.text('Registration Approved'), findsOneWidget);
      expect(find.text('Payment Reminder'), findsOneWidget);
    });

    test('Edge cases & serialization - partial and empty JSON, empty values', () {
      // 1. Partial JSON mapping to profile preferences
      final jsonPartial = {
        'id': 'u-1',
        'username': 'u1',
        'full_name': 'U One',
        'email': 'u1@test.com',
        'notification_preferences': {'registration': false},
      };
      final profilePartial = Profile.fromJson(jsonPartial);
      expect(profilePartial.notificationPreferences['registration'], false);
      expect(
        profilePartial.notificationPreferences['permissions'],
        true,
      ); // default fallback
      expect(
        profilePartial.notificationPreferences['payments'],
        true,
      ); // default fallback
      expect(
        profilePartial.notificationPreferences['schedule'],
        true,
      ); // default fallback
      expect(
        profilePartial.notificationPreferences['flights'],
        true,
      ); // default fallback

      // 2. Missing JSON preferences mapping
      final jsonMissing = {
        'id': 'u-2',
        'username': 'u2',
        'full_name': 'U Two',
        'email': 'u2@test.com',
      };
      final profileMissing = Profile.fromJson(jsonMissing);
      expect(profileMissing.notificationPreferences['registration'], true);
      expect(profileMissing.notificationPreferences['permissions'], true);
      expect(profileMissing.notificationPreferences['payments'], true);
      expect(profileMissing.notificationPreferences['schedule'], true);
      expect(profileMissing.notificationPreferences['flights'], true);

      // 3. Database Sync error fallback (client is null)
      // When client is null, createNotification/getNotifications/markAsRead should fall back and not crash.
      final notif = SystemNotification(
        id: 'n-fallback-test',
        userId: 'u-fallback',
        title: 'Title',
        message: 'Message',
        category: 'schedule',
        createdAt: DateTime.now(),
      );

      expect(() async {
        await notifRepo.createNotification(notif);
        final list = await notifRepo.getNotifications('u-fallback');
        expect(list.length, 1);
        expect(list.first.id, 'n-fallback-test');

        await notifRepo.markAsRead('n-fallback-test');
        final updatedList = await notifRepo.getNotifications('u-fallback');
        expect(updatedList.first.isRead, true);
      }, returnsNormally);
    });
  });
}
