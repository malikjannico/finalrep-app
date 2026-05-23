import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/permission_application.dart';
import 'package:finalrep_app/models/admin_config.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/association_member.dart';
import 'package:finalrep_app/models/competition_group.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/repositories/admin_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';

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
  Future<Profile?> updatePermissions(
    String userId, {
    bool? isCompetitionCreator,
    bool? isAssociationCreator,
    bool? isAdmin,
  }) async {
    final existing = profiles[userId];
    if (existing == null) return null;
    final updated = existing.copyWith(
      isCompetitionCreator: isCompetitionCreator ?? existing.isCompetitionCreator,
      isAssociationCreator: isAssociationCreator ?? existing.isAssociationCreator,
      isAdmin: isAdmin ?? existing.isAdmin,
    );
    profiles[userId] = updated;
    return updated;
  }
}

class MockCompetitionRepository implements CompetitionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Milestone 2 - System Administration (R3) Tests', () {
    late AdminRepository adminRepository;
    late MockProfileRepository profileRepository;
    late AuthProvider authProvider;
    late StreamController<AuthState> authStateController;

    setUp(() {
      adminRepository = AdminRepository(null); // Force in-memory mock fallback
      profileRepository = MockProfileRepository();
      authStateController = StreamController<AuthState>.broadcast();
      final mockAuth = MockGoTrueClient(authStateController);
      final mockClient = MockSupabaseClient(auth: mockAuth);
      authProvider = AuthProvider(
        mockClient,
        profileRepository,
        adminRepository: adminRepository,
      );
    });

    tearDown(() {
      authProvider.dispose();
      authStateController.close();
    });

    test('AdminRepository applyForPermissions and status update cycle', () async {
      // Clear or check initial state
      final initialApps = await adminRepository.getPermissionApplications();
      final initialCount = initialApps.length;

      // Apply
      final app = await adminRepository.applyForPermissions('user-test-1', 'create_competition', 'I want to organize meets');
      expect(app, isNotNull);
      expect(app!.userId, 'user-test-1');
      expect(app.type, 'create_competition');
      expect(app.status, 'pending');

      // Verify listed
      final apps = await adminRepository.getPermissionApplications();
      expect(apps.length, initialCount + 1);
      expect(apps.any((a) => a.id == app.id), true);

      // Approve
      final approvedApp = await adminRepository.approvePermissionApplication(app.id);
      expect(approvedApp, isNotNull);
      expect(approvedApp!.status, 'approved');

      // Reject
      final anotherApp = await adminRepository.applyForPermissions('user-test-2', 'create_association', 'I want to run a federation');
      final rejectedApp = await adminRepository.rejectPermissionApplication(anotherApp!.id);
      expect(rejectedApp, isNotNull);
      expect(rejectedApp!.status, 'rejected');
    });

    test('AdminRepository load and save global sports configs', () async {
      final config = await adminRepository.loadSportsConfig();
      expect(config, isNotNull);

      // Add a new sport
      final updatedSports = List<SportDefinition>.from(config.sports)
        ..add(SportDefinition(name: 'Powerlifting', description: 'Squat, Bench, Deadlift'));
      final updatedConfig = SportConfig(
        sports: updatedSports,
        formats: config.formats,
        disciplines: config.disciplines,
        links: config.links,
      );

      final success = await adminRepository.saveSportsConfig(updatedConfig);
      expect(success, true);

      final reloadedConfig = await adminRepository.loadSportsConfig();
      expect(reloadedConfig.sports.any((s) => s.name == 'Powerlifting'), true);
    });

    test('AuthProvider promote to admin and handle approved permission applications', () async {
      // Set current user profile in MockProfileRepository
      final testProfile = Profile(
        id: 'user-admin-1',
        username: 'testadmin',
        fullName: 'Test Admin',
        email: 'admin@test.com',
        isCompetitionCreator: false,
        isAssociationCreator: false,
        isAdmin: false,
      );
      profileRepository.profiles['user-admin-1'] = testProfile;

      // Simulate logged in user
      // We manually override the private fields in AuthProvider by mocking authentication
      // But we can test promoteToAdmin directly:
      final updated = await authProvider.promoteToAdmin('user-admin-1');
      expect(updated, isNotNull);
      expect(updated!.isAdmin, true);

      // Verify in repo
      final repoProfile = await profileRepository.getProfile('user-admin-1');
      expect(repoProfile!.isAdmin, true);
    });
  });

  group('Milestone 2 - Associations & Management (R4) Tests', () {
    late AssociationRepository associationRepository;
    late CompetitionProvider competitionProvider;

    setUp(() {
      associationRepository = AssociationRepository(null); // Force in-memory fallback
      competitionProvider = CompetitionProvider(
        MockCompetitionRepository(),
        MockProfileRepository(),
        associationRepository: associationRepository,
      );
    });

    test('Association CRUD cycle', () async {
      final initialAssocs = await associationRepository.getAssociations();
      final count = initialAssocs.length;

      final newAssoc = Association(
        id: 'new-assoc-123',
        name: 'Deutsche Streetlifting Association',
        scope: 'national',
        country: 'Germany',
        description: 'German national organization',
        rulebooks: {'Rules': 'https://example.com/german-rules.pdf'},
        socialChannels: {'Web': 'https://streetlifting.de'},
        status: 'pending',
        ownerId: 'user-german-owner',
        supportedSports: ['Streetlifting'],
        supportedFormats: ['Classic'],
      );

      final created = await associationRepository.createAssociation(newAssoc);
      expect(created, isNotNull);
      expect(created!.name, 'Deutsche Streetlifting Association');

      // Read details
      final details = await associationRepository.getAssociationDetails('new-assoc-123');
      expect(details, isNotNull);
      expect(details!.scope, 'national');

      // Update details
      final updatedAssoc = details.copyWith(description: 'Updated Description');
      final updated = await associationRepository.updateAssociation(updatedAssoc);
      expect(updated, isNotNull);
      expect(updated!.description, 'Updated Description');

      // Get all
      final all = await associationRepository.getAssociations();
      expect(all.length, count + 1);
    });

    test('Association Member management', () async {
      // Add member
      final member = await associationRepository.addAssociationMember(
        'assoc-1',
        'user-new-member',
        'editor',
        customTitle: 'Content Editor',
      );
      expect(member, isNotNull);
      expect(member!.role, 'editor');
      expect(member.customTitle, 'Content Editor');

      // Get members
      final members = await associationRepository.getAssociationMembers('assoc-1');
      expect(members.any((m) => m.userId == 'user-new-member'), true);

      // Remove member
      final success = await associationRepository.removeAssociationMember('assoc-1', 'user-new-member');
      expect(success, true);

      final membersAfterRemove = await associationRepository.getAssociationMembers('assoc-1');
      expect(membersAfterRemove.any((m) => m.userId == 'user-new-member'), false);
    });

    test('Association Ownership Transfer', () async {
      // Initial owner is user-1
      final assoc = await associationRepository.getAssociationDetails('assoc-1');
      expect(assoc!.ownerId, 'user-1');

      // Transfer to user-2
      final updated = await associationRepository.transferAssociationOwnership('assoc-1', 'user-2');
      expect(updated, isNotNull);
      expect(updated!.ownerId, 'user-2');

      // Check member role updates
      final members = await associationRepository.getAssociationMembers('assoc-1');
      final oldOwnerMember = members.firstWhere((m) => m.userId == 'user-1');
      final newOwnerMember = members.firstWhere((m) => m.userId == 'user-2');
      expect(oldOwnerMember.role, 'editor');
      expect(newOwnerMember.role, 'owner');
    });

    test('Competition Groups & Athlete Weight Class Groups', () async {
      // Create Competition Group
      final newGroup = CompetitionGroup(
        id: 'new-group-999',
        associationId: 'assoc-1',
        name: 'National Championships',
        sport: 'Streetlifting',
        format: 'Modern',
        isActive: true,
        isAthleteGroupsRequired: true,
      );

      final createdGroup = await associationRepository.createCompetitionGroup(newGroup);
      expect(createdGroup, isNotNull);
      expect(createdGroup!.name, 'National Championships');

      // Load Competition Groups
      final compGroups = await associationRepository.getCompetitionGroups('assoc-1');
      expect(compGroups.any((g) => g.id == 'new-group-999'), true);

      // Create Athlete Group
      final newAthleteGroup = AthleteGroup(
        id: 'new-ag-999',
        associationId: 'assoc-1',
        competitionGroupId: 'new-group-999',
        name: '-70kg Male',
        sport: 'Streetlifting',
        format: 'Modern',
        gender: 'Male',
        maxWeight: 70.0,
        isActive: true,
      );

      final createdAthleteGroup = await associationRepository.createAthleteGroup(newAthleteGroup);
      expect(createdAthleteGroup, isNotNull);
      expect(createdAthleteGroup!.name, '-70kg Male');

      // Load Athlete Groups
      final athleteGroups = await associationRepository.getAthleteGroups('assoc-1');
      expect(athleteGroups.any((ag) => ag.id == 'new-ag-999'), true);
    });
  });
}
