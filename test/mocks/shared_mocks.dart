import 'dart:collection';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/association_member.dart';
import 'package:finalrep_app/models/competition_group.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/models/streetlifting_attempt.dart';
import 'package:finalrep_app/models/flight.dart';
import 'package:finalrep_app/models/schedule_item.dart';
import 'package:finalrep_app/models/system_notification.dart';
import 'package:finalrep_app/models/permission_application.dart';
import 'package:finalrep_app/models/admin_config.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/repositories/admin_repository.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

// === File Picker Mock ===

class MockFilePicker extends FilePicker {
  final FilePickerResult? customResult;
  MockFilePicker({this.customResult});

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    if (customResult != null) return customResult;
    
    String fileName = 'test_file.png';
    final stack = StackTrace.current.toString();
    if (stack.contains('register_page')) {
      fileName = 'test_avatar.png';
    } else if (stack.contains('association_creation_page') || stack.contains('association_management_page') || stack.contains('association_management')) {
      fileName = 'test_logo.png';
    }
    
    return FilePickerResult([
      PlatformFile(
        name: fileName,
        size: 100,
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
        ),
      ),
    ]);
  }
}

// === Repository Mocks ===

class MockProfileRepository implements ProfileRepository {
  final Map<String, Profile> profilesMap = {};
  Map<String, Profile> get profiles => profilesMap;
  Profile? defaultProfile;
  List<Profile>? customProfiles;
  final List<Profile> profilesToReturn = [];

  MockProfileRepository({List<Profile>? initialProfiles, this.defaultProfile, List<Profile>? profilesToReturn}) {
    if (initialProfiles != null) {
      for (var p in initialProfiles) {
        profilesMap[p.id] = p;
        if (p.username.isNotEmpty) {
          profilesMap[p.username] = p;
        }
      }
    }
    if (profilesToReturn != null) {
      this.profilesToReturn.addAll(profilesToReturn);
      for (var p in profilesToReturn) {
        profilesMap[p.id] = p;
        if (p.username.isNotEmpty) {
          profilesMap[p.username] = p;
        }
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Profile>> searchProfiles(String query) async {
    if (profilesToReturn.isNotEmpty) return profilesToReturn;
    if (customProfiles != null) return customProfiles!;
    return [];
  }

  @override
  Future<Profile?> getProfile(String id) async {
    if (profilesToReturn.isNotEmpty) {
      try {
        return profilesToReturn.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    if (customProfiles != null) {
      try {
        return customProfiles!.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    return profilesMap[id] ?? defaultProfile ?? Profile(
      id: id,
      username: 'testuser',
      fullName: 'Test User',
      email: 'test@example.com',
    );
  }

  @override
  Future<Profile?> getProfileByUsername(String username) async {
    if (profilesToReturn.isNotEmpty) {
      try {
        return profilesToReturn.firstWhere((p) => p.username.toLowerCase() == username.toLowerCase());
      } catch (_) {}
    }
    return profilesMap[username] ?? defaultProfile ?? Profile(
      id: 'user-1',
      username: username,
      fullName: 'Test User',
      email: 'test@example.com',
    );
  }

  @override
  Future<Profile?> getProfileByEmail(String email) async => null;

  @override
  Future<Profile?> updateProfile(Profile profile) async {
    profilesMap[profile.id] = profile;
    return profile;
  }

  @override
  Future<Profile?> updatePermissions(
    String userId, {
    bool? isCompetitionCreator,
    bool? isAssociationCreator,
    bool? isAdmin,
  }) async {
    final current = profilesMap[userId];
    if (current == null) return null;
    final updated = current.copyWith(
      isCompetitionCreator: isCompetitionCreator ?? current.isCompetitionCreator,
      isAssociationCreator: isAssociationCreator ?? current.isAssociationCreator,
      isAdmin: isAdmin ?? current.isAdmin,
    );
    profilesMap[userId] = updated;
    return updated;
  }

  @override
  Future<List<Competition>> getUserUpcomingMeets(String profileId) async => [];

  @override
  Future<List<Competition>> getUserCompletedMeets(String profileId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getUserHighestRankings(String profileId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getUserPersonalRecords(String profileId) async => [];

  @override
  Future<String?> uploadFile(List<int> bytes, String fileName) async {
    return 'https://mock.storage/uploads/$fileName';
  }

  @override
  Future<bool> deleteFile(String url) async => true;
}

class MockAssociationRepository implements AssociationRepository {
  final List<Association> fakeAssociations;
  final Map<String, List<AssociationMember>> associationMembersMap = {};
  final Map<String, List<AthleteGroup>> athleteGroupsMap = {};
  List<Association>? customAssociations;
  final List<AssociationMember> mockMembers = [];

  MockAssociationRepository({List<Association>? initialAssociations})
      : fakeAssociations = initialAssociations ?? [
          Association(
            id: 'assoc-1',
            name: 'Global Streetlifting Federation (GSF)',
            scope: 'global',
            description: 'The main global governing body for streetlifting.',
            rulebooks: {},
            socialChannels: {},
            ownerId: 'user-1',
            supportedSports: ['Streetlifting'],
          ),
          Association(
            id: 'assoc-2',
            name: 'European Streetlifting Association (ESA)',
            scope: 'area',
            areaName: 'Europe',
            description: 'Continental governing body for Europe.',
            rulebooks: {},
            socialChannels: {},
            ownerId: 'user-2',
            supportedSports: ['Calisthenics'],
          ),
        ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Association>> getAssociations() async => customAssociations ?? fakeAssociations;

  @override
  Future<List<AssociationMember>> getAssociationMembers(
    String associationId,
  ) async {
    if (mockMembers.isNotEmpty) {
      return mockMembers.where((m) => m.associationId == associationId).toList();
    }
    return associationMembersMap[associationId] ?? [];
  }

  @override
  Future<AssociationMember?> addAssociationMember(
    String associationId,
    String userId,
    String role, {
    String? customTitle,
  }) async {
    final m = AssociationMember(
      id: 'member-${DateTime.now().millisecondsSinceEpoch}',
      associationId: associationId,
      userId: userId,
      role: role,
      customTitle: customTitle,
    );
    mockMembers.add(m);
    final list = associationMembersMap.putIfAbsent(associationId, () => []);
    list.add(m);
    return m;
  }

  @override
  Future<Association?> transferAssociationOwnership(
    String associationId,
    String newOwnerId, {
    String? customTitle,
  }) async {
    final list = await getAssociations();
    final idx = list.indexWhere((a) => a.id == associationId);
    if (idx != -1) {
      final current = list[idx];
      final updated = current.copyWith(ownerId: newOwnerId);
      list[idx] = updated;
      
      final oldOwnerId = current.ownerId;
      mockMembers.removeWhere((element) =>
          element.associationId == associationId &&
          element.userId == oldOwnerId &&
          element.role == 'owner');

      final oIdx = mockMembers.indexWhere((element) =>
          element.associationId == associationId &&
          element.userId == newOwnerId &&
          element.role == 'owner');
      if (oIdx != -1) {
        mockMembers[oIdx] = mockMembers[oIdx].copyWith(customTitle: customTitle);
      } else {
        mockMembers.add(AssociationMember(
          id: 'member-$associationId-$newOwnerId-owner',
          associationId: associationId,
          userId: newOwnerId,
          role: 'owner',
          customTitle: customTitle,
        ));
      }
      return updated;
    }
    return null;
  }

  @override
  Future<List<CompetitionGroup>> getCompetitionGroups(String associationId) async => [];

  @override
  Future<Association?> createAssociation(Association association) async {
    customAssociations ??= [];
    customAssociations!.add(association);
    if (!fakeAssociations.any((a) => a.id == association.id)) {
      fakeAssociations.add(association);
    }
    return association;
  }

  @override
  Future<Association?> updateAssociation(Association association) async {
    customAssociations ??= [];
    final idx = customAssociations!.indexWhere((a) => a.id == association.id);
    if (idx != -1) {
      customAssociations![idx] = association;
    } else {
      customAssociations!.add(association);
    }
    final fIdx = fakeAssociations.indexWhere((a) => a.id == association.id);
    if (fIdx != -1) {
      fakeAssociations[fIdx] = association;
    } else {
      fakeAssociations.add(association);
    }
    return association;
  }

  @override
  Future<bool> deleteAssociation(String id) async {
    if (customAssociations != null) {
      customAssociations!.removeWhere((a) => a.id == id);
    }
    fakeAssociations.removeWhere((a) => a.id == id);
    return true;
  }

  @override
  Future<Association?> getAssociationDetails(String id) async {
    final list = await getAssociations();
    try {
      return list.firstWhere((a) => a.id == id);
    } catch (_) {
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

  @override
  Future<List<AthleteGroup>> getAthleteGroups(String associationId) async {
    return athleteGroupsMap[associationId] ?? [];
  }
}

class MockCompetitionRepository implements CompetitionRepository {
  final List<Competition> fakeCompetitions;
  List<Map<String, dynamic>> fakeMeetResults = [];
  final Map<String, Competition> competitionsMap = {};
  Map<String, Competition> get competitions => competitionsMap;
  final Map<String, List<Profile>> competitionAthletesMap = {};
  final List<Profile> athletes = [];
  final List<String> registeredAthleteIds = [];
  final List<Flight> createdFlights = [];

  MockCompetitionRepository([List<Competition>? initialCompetitions])
      : fakeCompetitions = initialCompetitions ?? [] {
    for (var comp in fakeCompetitions) {
      competitionsMap[comp.id] = comp;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);


  @override
  Future<Competition?> getCompetitionById(String id) async {
    return competitionsMap[id];
  }

  @override
  Future<List<Profile>> getCompetitionAthletes(String competitionId) async {
    if (athletes.isNotEmpty) return athletes;
    return competitionAthletesMap[competitionId] ?? [];
  }

  @override
  Future<bool> registerAthlete(
    String competitionId,
    String userId, {
    String status = 'registered',
  }) async {
    if (!registeredAthleteIds.contains(userId)) {
      registeredAthleteIds.add(userId);
    }
    final athletesList = competitionAthletesMap[competitionId] ?? [];
    if (!athletesList.any((a) => a.id == userId)) {
      athletesList.add(
        Profile(
          id: userId,
          username: 'user-$userId',
          fullName: 'Athlete $userId',
          email: '$userId@test.com',
        ),
      );
      competitionAthletesMap[competitionId] = athletesList;
    }
    return true;
  }

  @override
  Future<List<String>> getRegisteredAthleteIds(String competitionId) async {
    if (registeredAthleteIds.isNotEmpty) return registeredAthleteIds;
    return (competitionAthletesMap[competitionId] ?? []).map((a) => a.id).toList();
  }

  @override
  Future<Flight?> createFlight(Flight flight) async {
    createdFlights.add(flight);
    return flight;
  }

  @override
  Future<Competition?> createCompetition(Competition competition) async {
    competitionsMap[competition.id] = competition;
    if (!fakeCompetitions.any((c) => c.id == competition.id)) {
      fakeCompetitions.add(competition);
    }
    return competition;
  }

  @override
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status = 'upcoming',
  }) async {
    final comps = competitionsMap.isNotEmpty ? competitionsMap.values.toList() : fakeCompetitions;
    return comps.where((comp) {
      if (query != null && query.isNotEmpty) {
        final matchesTitle = comp.title.toLowerCase().contains(query.toLowerCase());
        final matchesLocation = comp.location.toLowerCase().contains(query.toLowerCase());
        if (!matchesTitle && !matchesLocation) return false;
      }
      if (sportSubtype != null && sportSubtype != 'All' && comp.sportSubtype != sportSubtype) {
        return false;
      }
      if (compGroupName != null && compGroupName != 'All') {
        if (compGroupName == 'Individual') {
          if (comp.compGroupName != null) return false;
        } else if (comp.compGroupName != compGroupName) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Future<List<Competition>> fetchCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status,
  }) async {
    return competitionsMap.isNotEmpty ? competitionsMap.values.toList() : fakeCompetitions;
  }

  @override
  String get baseUrl => '';

  @override
  Future<List<Map<String, dynamic>>> getMeetResults() async => fakeMeetResults;

  @override
  Future<int> getVolunteerCount(String competitionId) async => 5;

  @override
  Future<bool> submitVolunteerApplication(Map<String, dynamic> payload) async => true;

  @override
  Future<bool> publishSchedule(String competitionId, {required bool isPublic}) async => true;
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
  Future<PermissionApplication?> approvePermissionApplication(
    String id,
  ) async {
    final app = applications[id];
    if (app == null) {
      return PermissionApplication(
        id: id,
        userId: '00000000-0000-0000-0000-000000000003',
        type: 'create_competition',
        reason: 'Test reason',
        status: 'approved',
        createdAt: DateTime.now(),
      );
    }
    final updated = app.copyWith(status: 'approved');
    applications[id] = updated;
    return updated;
  }

  @override
  Future<PermissionApplication?> rejectPermissionApplication(
    String id,
  ) async {
    final app = applications[id];
    if (app == null) {
      return PermissionApplication(
        id: id,
        userId: '00000000-0000-0000-0000-000000000003',
        type: 'create_competition',
        reason: 'Test reason',
        status: 'rejected',
        createdAt: DateTime.now(),
      );
    }
    final updated = app.copyWith(status: 'rejected');
    applications[id] = updated;
    return updated;
  }
}

class MockNotificationRepository implements NotificationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// === Provider Mocks ===

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  bool _isAuthenticated;
  Profile? _currentUserProfile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordRecoveryActive = false;
  late ProfileRepository _profileRepository;
  AuthStatus _status;
  bool Function(String)? onIsUsernameTaken;
  bool Function(String)? onIsEmailTaken;

  MockAuthProvider({
    bool isAuthenticated = false,
    Profile? currentUserProfile,
    ProfileRepository? profileRepository,
    AuthStatus status = AuthStatus.unauthenticated,
    this.onIsUsernameTaken,
    this.onIsEmailTaken,
  })  : _isAuthenticated = isAuthenticated,
        _currentUserProfile = currentUserProfile,
        _status = status,
        _profileRepository = profileRepository ?? MockProfileRepository();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Profile? get currentUserProfile => _currentUserProfile;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isPasswordRecoveryActive => _isPasswordRecoveryActive;

  @override
  bool get isAdmin => _currentUserProfile?.isAdmin ?? false;

  @override
  bool get isAssociationCreator =>
      _currentUserProfile?.isAssociationCreator ?? false;

  @override
  bool get isCompetitionCreator =>
      _currentUserProfile?.isCompetitionCreator ?? false;

  @override
  ProfileRepository get profileRepository => _profileRepository;

  @override
  AuthStatus get status => _status;

  String _timeFormat = '24h';
  @override
  String get timeFormat => _timeFormat;
  @override
  void setTimeFormat(String format) {
    _timeFormat = format;
    notifyListeners();
  }

  @override
  Future<bool> isUsernameTaken(String username) async {
    return onIsUsernameTaken?.call(username) ?? false;
  }

  @override
  Future<bool> isEmailTaken(String email) async {
    return onIsEmailTaken?.call(email) ?? false;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> changePassword(String newPassword) async {}

  @override
  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? sex,
    String? country,
    String? description,
    required String colorMode,
    String? profilePictureUrl,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  AdminRepository get adminRepository => MockAdminRepository();

  @override
  Future<PermissionApplication?> applyForPermissions(
    String type,
    String reason,
  ) async {
    return null;
  }

  @override
  Future<List<PermissionApplication>> getPermissionApplications() async {
    return [];
  }

  @override
  Future<PermissionApplication?> approvePermissionApplication(
    String applicationId,
  ) async {
    return null;
  }

  @override
  Future<PermissionApplication?> rejectPermissionApplication(
    String applicationId,
  ) async {
    return null;
  }

  @override
  Future<Profile?> promoteToAdmin(String userId) async {
    return null;
  }

  @override
  Future<SportConfig> loadSportsConfig() async {
    return SportConfig(
      sports: [SportDefinition(name: 'Streetlifting', description: 'Strength sport')],
      formats: [FormatDefinition(sportName: 'Streetlifting', name: 'Modern', description: 'Standard modern format')],
      disciplines: [DisciplineDefinition(name: 'Pull Up', description: 'Pull up exercise')],
      links: [FormatDisciplineLink(sportName: 'Streetlifting', formatName: 'Modern', disciplineName: 'Pull Up')],
    );
  }

  @override
  Future<bool> saveSportsConfig(SportConfig config) async {
    return true;
  }

  @override
  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    required String fullName,
    String? sex,
    String? country,
    String? profilePictureUrl,
    Uint8List? customAvatarBytes,
    String? customAvatarExtension,
  }) async {}

  @override
  void clearError() {}

  @override
  Future<void> loginWithUsernameAndPassword({
    required String username,
    required String password,
  }) async {}

  @override
  Future<String> resolveEmailFromUsername(String username) async => '';

  @override
  dynamic get session => null;

  @override
  void clearPasswordRecovery() {}

  void setAuthenticated(bool val, {Profile? profile}) {
    _isAuthenticated = val;
    _currentUserProfile = profile;
    notifyListeners();
  }

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void setErrorMessage(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }
}

class FakeCompetitionRepository extends MockCompetitionRepository {
  FakeCompetitionRepository() : super([
    Competition(
      id: '1',
      title: 'Hamburg Streetlifting Meet',
      location: 'Hamburg, Germany',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      startDate: DateTime.now().add(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '2',
      title: 'Classic Pull & Dip Cup',
      location: 'Berlin, Germany',
      sportSubtype: 'Classic',
      compGroupName: null,
      startDate: DateTime.now().add(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ]);
}

// === Firebase Auth Mock Classes ===

class MockUser implements fb.User {
  @override
  final String uid;
  @override
  final String? email;

  MockUser({required this.uid, this.email});

  final List<String> updateEmailCalls = [];
  final List<String> updatePasswordCalls = [];

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail, [fb.ActionCodeSettings? actionCodeSettings]) async {
    updateEmailCalls.add(newEmail);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatePasswordCalls.add(newPassword);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserCredential implements fb.UserCredential {
  @override
  final fb.User? user;

  MockUserCredential({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAuth implements fb.FirebaseAuth {
  final StreamController<fb.User?> _authStateController;
  final bool yieldImmediately;
  MockUser? _currentUser;

  MockFirebaseAuth(this._authStateController, {MockUser? currentUser, this.yieldImmediately = false})
      : _currentUser = currentUser;

  final List<Map<String, dynamic>> signUpCalls = [];
  final List<Map<String, dynamic>> signInCalls = [];
  final List<String> sendResetPasswordCalls = [];
  int signOutCallCount = 0;

  fb.UserCredential? signUpResult;
  fb.UserCredential? signInResult;
  Object? signUpError;
  Object? signInError;

  @override
  MockUser? get currentUser => _currentUser;

  void setCurrentUser(MockUser? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  @override
  Stream<fb.User?> authStateChanges() async* {
    if (yieldImmediately) {
      yield _currentUser;
    }
    yield* _authStateController.stream;
  }

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signUpCalls.add({'email': email, 'password': password});
    if (signUpError != null) throw signUpError!;
    final user = MockUser(uid: 'user-created', email: email);
    setCurrentUser(user);
    return signUpResult ?? MockUserCredential(user: user);
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls.add({'email': email, 'password': password});
    if (signInError != null) throw signInError!;
    final user = MockUser(uid: 'user-signedin', email: email);
    setCurrentUser(user);
    return signInResult ?? MockUserCredential(user: user);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    setCurrentUser(null);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    fb.ActionCodeSettings? actionCodeSettings,
  }) async {
    sendResetPasswordCalls.add(email);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

