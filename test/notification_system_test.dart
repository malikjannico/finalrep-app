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
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/admin_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/notifications_page.dart';

// --- Mocks ---

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

class MockAdminRepository implements AdminRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PermissionApplication?> approvePermissionApplication(String applicationId) async {
    return PermissionApplication(
      id: applicationId,
      userId: 'user-test-perm',
      type: 'create_competition',
      reason: 'I want to organize meets.',
      status: 'approved',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<PermissionApplication?> rejectPermissionApplication(String applicationId) async {
    return PermissionApplication(
      id: applicationId,
      userId: 'user-test-perm',
      type: 'create_association',
      reason: 'I want to create an association.',
      status: 'rejected',
      createdAt: DateTime.now(),
    );
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
  SupabaseClient get client => MockSupabaseClient(auth: MockGoTrueClient(StreamController<AuthState>.broadcast()));

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
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
  }) async {
    return competitions.values.toList();
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
      rulebooks: {'Streetlifting': 'https://example.com/rulebook'},
      socialChannels: {},
      ownerId: 'owner-1',
    );
  }

  @override
  Future<List<AthleteGroup>> getAthleteGroups(String associationId) async {
    return [
      AthleteGroup(
        id: 'group-1',
        associationId: associationId,
        name: 'Open modern format group',
        sport: 'Streetlifting',
        format: 'Modern',
        gender: 'Mixed',
        isActive: true,
      )
    ];
  }
}

class WidgetMockAuthProvider extends ChangeNotifier implements AuthProvider {
  Profile? _currentUserProfile;
  final List<String> updatePrefCalls = [];

  WidgetMockAuthProvider({Profile? currentUserProfile}) : _currentUserProfile = currentUserProfile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Profile? get currentUserProfile => _currentUserProfile;

  @override
  Future<void> updateNotificationPreference(String category, bool enabled) async {
    updatePrefCalls.add('$category:$enabled');
    if (_currentUserProfile != null) {
      final updatedPrefs = Map<String, bool>.from(_currentUserProfile!.notificationPreferences);
      updatedPrefs[category] = enabled;
      _currentUserProfile = _currentUserProfile!.copyWith(notificationPreferences: updatedPrefs);
      notifyListeners();
    }
  }
}

void main() {
  setUpAll(() async {
    // Initialize Supabase configuration locally to prevent StateErrors during widget tests.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://vnseudpajhkicezdcsuj.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuc2V1ZHBhamhraWNlemRjc3VqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTQ4NjIsImV4cCI6MjA5NDg3MDg2Mn0.qaIyqbVOH_qXvUfz7iCvUvBsywyviFVaIYjt6MG-lsE',
    );
  });

  group('System Notification System Tests', () {
    late NotificationRepository notifRepo;

    setUp(() {
      // NotificationRepository initialized with null fallback client.
      notifRepo = NotificationRepository(null);
    });

    test('NotificationRepository fallback CRUD works correctly', () async {
      final userId = 'user-crud-test';
      final notification = SystemNotification(
        id: 'notif-1',
        userId: userId,
        title: 'Test Title',
        message: 'Test Message',
        category: 'registration',
        createdAt: DateTime.now(),
      );

      // Create Notification
      final created = await notifRepo.createNotification(notification);
      expect(created, isNotNull);
      expect(created!.id, 'notif-1');

      // Get Notifications
      final list = await notifRepo.getNotifications(userId);
      expect(list.length, 1);
      expect(list.first.title, 'Test Title');
      expect(list.first.isRead, false);

      // Mark As Read
      await notifRepo.markAsRead('notif-1');
      final updatedList = await notifRepo.getNotifications(userId);
      expect(updatedList.length, 1);
      expect(updatedList.first.isRead, true);
    });

    test('AuthProvider triggers fire correctly on permission status updates', () async {
      final mockAuthClient = MockGoTrueClient(StreamController<AuthState>.broadcast());
      final mockSupabaseClient = MockSupabaseClient(auth: mockAuthClient);
      final mockProfileRepo = MockProfileRepository();
      final mockAdminRepo = MockAdminRepository();

      // Configure a test user profile
      final testUserId = 'user-test-perm';
      final userProfile = Profile(
        id: testUserId,
        username: 'permuser',
        fullName: 'Permission User',
        email: 'perm@test.com',
      );
      mockProfileRepo.profiles[testUserId] = userProfile;

      final authProvider = AuthProvider(
        mockSupabaseClient,
        mockProfileRepo,
        adminRepository: mockAdminRepo,
        notificationRepository: notifRepo,
      );

      // Mock user is signed in
      // Set private field using a mock session or login flow if possible, or trigger action directly
      // In AuthProvider, approvePermissionApplication can run without user logged in (as it acts as admin)
      
      // 1. Approve Permission Application
      final appApprove = await authProvider.approvePermissionApplication('app-123');
      expect(appApprove, isNotNull);
      expect(appApprove!.status, 'approved');

      // Verify trigger created a notification
      final listApprove = await notifRepo.getNotifications(testUserId);
      expect(listApprove.length, 1);
      expect(listApprove.first.category, 'permissions');
      expect(listApprove.first.title, 'Permissions Approved');
      expect(listApprove.first.message, contains('Competition Creator'));

      // 2. Reject Permission Application
      final appReject = await authProvider.rejectPermissionApplication('app-456');
      expect(appReject, isNotNull);
      expect(appReject!.status, 'rejected');

      // Verify trigger created a notification
      final listReject = await notifRepo.getNotifications(testUserId);
      expect(listReject.length, 2);
      expect(listReject.any((n) => n.message.contains('rejected')), true);
    });

    test('CompetitionProvider triggers fire correctly on registration, payments, flights, and schedule', () async {
      final mockCompRepo = MockCompetitionRepository();
      final mockProfileRepo = MockProfileRepository();
      final mockAssocRepo = FakeAssociationRepository();

      final provider = CompetitionProvider(
        mockCompRepo,
        mockProfileRepo,
        associationRepository: mockAssocRepo,
        notificationRepository: notifRepo,
      );

      final athlete1 = Profile(id: 'athlete-1', username: 'athlete1', fullName: 'Athlete One', email: 'a1@test.com');
      final athlete2 = Profile(id: 'athlete-2', username: 'athlete2', fullName: 'Athlete Two', email: 'a2@test.com');
      mockCompRepo.athletes.addAll([athlete1, athlete2]);

      final competition = Competition(
        id: 'comp-1',
        title: 'Summer Pull Meet',
        location: 'Berlin',
        sportType: 'Streetlifting',
        sportSubtype: 'Modern',
        requiresFees: true,
        feeAmount: 30.0,
        feeCurrency: 'EUR',
        registrationEnd: DateTime.now().add(const Duration(days: 5)),
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockCompRepo.competitions['comp-1'] = competition;

      // 1. Create Competition trigger (Payments formulation)
      final createdComp = await provider.createCompetition(competition);
      expect(createdComp, isNotNull);
      // Verify payment details formulated trigger fired for the association/creator
      final creatorNotifs = await notifRepo.getNotifications(''); // associationId is empty in competition
      expect(creatorNotifs.length, 1);
      expect(creatorNotifs.first.category, 'payments');
      expect(creatorNotifs.first.title, 'Payment Details Formulated');

      // 2. Register Athlete trigger (Registration confirmed + Payment deadline notification)
      final regSuccess = await provider.registerAthlete(competitionId: 'comp-1', userId: 'athlete-1');
      expect(regSuccess, true);

      // Verify athlete-1 received registration notification
      final athlete1Notifs = await notifRepo.getNotifications('athlete-1');
      expect(athlete1Notifs.any((n) => n.category == 'registration'), true);
      expect(athlete1Notifs.any((n) => n.title == 'Registration Confirmed'), true);

      // Verify athlete-1 received payment reminder notification (since requiresFees is true)
      expect(athlete1Notifs.any((n) => n.category == 'payments'), true);
      expect(athlete1Notifs.any((n) => n.title == 'Payment Action Required'), true);

      // 3. Balance Flights trigger (Flight assignments updated)
      await provider.balanceFlights('comp-1');
      expect(mockCompRepo.createdFlights.length, 1);
      
      // Verify flights notification was sent to both athlete-1 and athlete-2
      final a1NotifsAfterFlight = await notifRepo.getNotifications('athlete-1');
      expect(a1NotifsAfterFlight.any((n) => n.category == 'flights'), true);
      expect(a1NotifsAfterFlight.firstWhere((n) => n.category == 'flights').title, 'Flight Assignment Updated');

      final a2NotifsAfterFlight = await notifRepo.getNotifications('athlete-2');
      expect(a2NotifsAfterFlight.any((n) => n.category == 'flights'), true);

      // 4. Publish Schedule trigger (Meet schedule published)
      await provider.publishSchedule('comp-1', isPublic: true);
      
      // Verify schedule notifications sent to registered athletes
      final a1NotifsAfterSchedule = await notifRepo.getNotifications('athlete-1');
      expect(a1NotifsAfterSchedule.any((n) => n.category == 'schedule'), true);
      expect(a1NotifsAfterSchedule.firstWhere((n) => n.category == 'schedule').title, 'Meet Schedule Published');
    });

    test('CompetitionProvider triggers fire correctly on volunteer application submission', () async {
      final mockCompRepo = MockCompetitionRepository();
      final mockProfileRepo = MockProfileRepository();
      final mockAssocRepo = FakeAssociationRepository();

      final provider = CompetitionProvider(
        mockCompRepo,
        mockProfileRepo,
        associationRepository: mockAssocRepo,
        notificationRepository: notifRepo,
      );

      final competition = Competition(
        id: 'comp-vol-1',
        title: 'Volunteer Meet',
        location: 'Berlin',
        sportType: 'Streetlifting',
        sportSubtype: 'Modern',
        requiresFees: false,
        registrationEnd: DateTime.now().add(const Duration(days: 5)),
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockCompRepo.competitions['comp-vol-1'] = competition;

      // Submit volunteer application
      final success = await provider.submitVolunteerApplication(
        competitionId: 'comp-vol-1',
        userId: 'volunteer-1',
        preferredRoles: const ['Spotter'],
        shiftAvailability: const {'Morning': ['Spotter']},
        customFieldAnswers: const {},
        disclaimerAccepted: true,
      );

      expect(success, true);

      // Verify volunteer-1 received volunteer confirmation notification
      final volunteerNotifs = await notifRepo.getNotifications('volunteer-1');
      expect(volunteerNotifs.length, 1);
      expect(volunteerNotifs.first.category, 'registration');
      expect(volunteerNotifs.first.title, 'Volunteer Application Submitted');
      expect(
        volunteerNotifs.first.message,
        'Your application to volunteer for the meet "Volunteer Meet" has been submitted.',
      );
    });

    testWidgets('NotificationsPage renders seed list on empty notifications and filters correctly on toggles and chips', (WidgetTester tester) async {
      final userProfile = Profile(
        id: 'user-notif-page-test',
        username: 'notiftester',
        fullName: 'Notification Tester',
        email: 'notif@test.com',
        notificationPreferences: {
          'registration': true,
          'permissions': true,
          'payments': true,
          'schedule': true,
          'flights': true,
        },
      );

      final authProvider = WidgetMockAuthProvider(currentUserProfile: userProfile);

      // Seed mock notifications for user-notif-page-test
      final testUserId = 'user-notif-page-test';
      final n1 = SystemNotification(
        id: 'n-reg',
        userId: testUserId,
        title: 'Registration Approved',
        message: 'Application accepted.',
        category: 'registration',
        createdAt: DateTime.now(),
      );
      final n2 = SystemNotification(
        id: 'n-pay',
        userId: testUserId,
        title: 'Fee Required',
        message: 'Pay fee.',
        category: 'payments',
        createdAt: DateTime.now(),
      );

      // Clear static cache for clean page rendering check
      final listBeforeSeed = await notifRepo.getNotifications(testUserId);
      for (final n in listBeforeSeed) {
        // Mock fallback contains elements if run sequentially, but since we query by user-notif-page-test,
        // it should be empty initially.
      }
      
      // Run with notifications loaded from repository
      await notifRepo.createNotification(n1);
      await notifRepo.createNotification(n2);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: NotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title is rendered
      expect(find.text('Notifications'), findsOneWidget);

      // Verify seeded notifications are rendered
      expect(find.text('Registration Approved'), findsOneWidget);
      expect(find.text('Fee Required'), findsOneWidget);

      // 1. Test Filter Chip (Select 'Registration')
      final regChip = find.byKey(const Key('chip_registration'));
      expect(regChip, findsOneWidget);
      await tester.tap(regChip);
      await tester.pumpAndSettle();

      // Only 'Registration Approved' should remain, 'Fee Required' is filtered out
      expect(find.text('Registration Approved'), findsOneWidget);
      expect(find.text('Fee Required'), findsNothing);

      // Deselect chip
      await tester.tap(regChip);
      await tester.pumpAndSettle();
      expect(find.text('Fee Required'), findsOneWidget);

      // 2. Test Settings Toggle (Turn off Payments switch)
      // Open settings panel
      final settingsTile = find.byKey(const Key('alert_settings_tile'));
      expect(settingsTile, findsOneWidget);
      await tester.tap(settingsTile);
      await tester.pumpAndSettle();

      // Toggle Payments switch off
      final paymentsSwitch = find.byKey(const Key('switch_payments'));
      expect(paymentsSwitch, findsOneWidget);
      await tester.tap(paymentsSwitch);
      await tester.pumpAndSettle();

      // Verify authProvider updated preference call
      expect(authProvider.updatePrefCalls, contains('payments:false'));

      // Verify 'Fee Required' notification (payments category) is filtered out
      expect(find.text('Registration Approved'), findsOneWidget);
      expect(find.text('Fee Required'), findsNothing);
    });
  });
}
