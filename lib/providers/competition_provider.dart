import 'package:flutter/material.dart';
import '../models/competition.dart';
import '../models/profile.dart';
import '../repositories/competition_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/association_repository.dart';
import '../models/association.dart';
import '../models/association_member.dart';
import '../models/competition_group.dart';
import '../models/athlete_group.dart';
import '../models/streetlifting_attempt.dart';
import '../models/flight.dart';
import '../models/schedule_item.dart';
import '../utils/streetlifting_rules_engine.dart';
import '../repositories/notification_repository.dart';
import '../models/system_notification.dart';

enum CompetitionsLayout { grid, list, map }
enum SearchScope { competitions, users }

class CompetitionProvider extends ChangeNotifier {
  final CompetitionRepository _repository;
  final ProfileRepository _profileRepository;
  final AssociationRepository _associationRepository;
  final NotificationRepository _notificationRepository;

  String _query = '';
  final Set<String> _selectedSubtypes = {};
  final Set<String> _selectedGroups = {};

  // Location filters
  final Set<String> _selectedAreas = {};
  final Set<String> _selectedCountries = {};
  final Set<String> _selectedCities = {};

  // Date range filter
  DateTimeRange? _selectedDateRange;

  // Layout and sorting
  CompetitionsLayout _layout = CompetitionsLayout.grid;
  String _sortOrder = 'date_asc'; // 'date_asc', 'date_desc', 'name_asc', 'name_desc'
  final Set<String> _selectedSports = {};

  // Search scope
  SearchScope _searchScope = SearchScope.competitions;
  List<Profile> _searchedUsers = [];
  bool _isLoadingUsers = false;
  String _lastUserQuery = '';

  bool _isLoading = false;
  List<Competition> _allCompetitions = [];
  List<Competition> _filteredCompetitions = [];
  String? _errorMessage;

  List<Association> _associations = [];
  bool _isLoadingAssociations = false;

  CompetitionProvider(
    this._repository,
    this._profileRepository, {
    AssociationRepository? associationRepository,
    NotificationRepository? notificationRepository,
  }) : _associationRepository = associationRepository ??
            (() {
              try {
                return AssociationRepository(_repository.client);
              } catch (_) {
                return AssociationRepository(null as dynamic);
              }
            }()),
       _notificationRepository = notificationRepository ??
            (() {
              try {
                return NotificationRepository(_repository.client);
              } catch (_) {
                return NotificationRepository(null as dynamic);
              }
            }()) {
    fetchCompetitions();
    fetchAssociations();
  }

  // Association Getters
  List<Association> get associations => _associations;
  bool get isLoadingAssociations => _isLoadingAssociations;
  AssociationRepository get associationRepository => _associationRepository;

  // Getters
  String get query => _query;
  Set<String> get selectedSubtypes => _selectedSubtypes;
  Set<String> get selectedGroups => _selectedGroups;

  String get selectedSubtype {
    if (_selectedSubtypes.isEmpty) return 'All';
    if (_selectedSubtypes.length == 1) return _selectedSubtypes.first;
    return _selectedSubtypes.join(', ');
  }

  String get selectedGroup {
    if (_selectedGroups.isEmpty) return 'All';
    if (_selectedGroups.length == 1) return _selectedGroups.first;
    return _selectedGroups.join(', ');
  }

  bool get isLoading => _isLoading;
  List<Competition> get competitions => _filteredCompetitions;
  List<Competition> get allCompetitions => _allCompetitions;
  String? get errorMessage => _errorMessage;

  Set<String> get selectedAreas => _selectedAreas;
  Set<String> get selectedCountries => _selectedCountries;
  Set<String> get selectedCities => _selectedCities;
  DateTimeRange? get selectedDateRange => _selectedDateRange;

  CompetitionsLayout get layout => _layout;
  int get activeTab => _layout == CompetitionsLayout.map ? 1 : 0;
  bool get isCompactLayout => _layout == CompetitionsLayout.list;
  String get sortOrder => _sortOrder;
  Set<String> get selectedSports => _selectedSports;

  // Scope Getters
  SearchScope get searchScope => _searchScope;
  List<Profile> get searchedUsers => _searchedUsers;
  bool get isLoadingUsers => _isLoadingUsers;
  ProfileRepository get profileRepository => _profileRepository;

  void setLayout(CompetitionsLayout newLayout) {
    if (_layout != newLayout) {
      _layout = newLayout;
      notifyListeners();
    }
  }

  void setActiveTab(int tab) {
    final targetLayout = tab == 1
        ? CompetitionsLayout.map
        : CompetitionsLayout.grid;
    if (_layout != targetLayout) {
      _layout = targetLayout;
      notifyListeners();
    }
  }

  void setIsCompactLayout(bool val) {
    final targetLayout = val
        ? CompetitionsLayout.list
        : CompetitionsLayout.grid;
    if (_layout != targetLayout) {
      _layout = targetLayout;
      notifyListeners();
    }
  }

  void setSortOrder(String order) {
    if (_sortOrder != order) {
      _sortOrder = order;
      _applyFilters();
      notifyListeners();
    }
  }

  void toggleSport(String sport) {
    if (_selectedSports.contains(sport)) {
      _selectedSports.remove(sport);
    } else {
      _selectedSports.add(sport);
    }
    _applyFilters();
    notifyListeners();
  }

  // Search scope setter
  void setSearchScope(SearchScope scope) {
    if (_searchScope != scope) {
      _searchScope = scope;
      if (_searchScope == SearchScope.users) {
        searchUsers(_query);
      } else {
        _applyFilters();
      }
      notifyListeners();
    }
  }

  void setSearchScopeAndQuery(SearchScope scope, String newQuery) {
    bool changed = false;
    if (_searchScope != scope) {
      _searchScope = scope;
      changed = true;
    }
    if (_query != newQuery) {
      _query = newQuery;
      changed = true;
    }
    if (changed) {
      if (_searchScope == SearchScope.users) {
        searchUsers(_query);
      } else {
        _applyFilters();
      }
      notifyListeners();
    }
  }

  // Get counts for filters
  int getSportCount(String sport) {
    return _allCompetitions
        .where((c) => c.sportType.toLowerCase() == sport.toLowerCase())
        .length;
  }

  int getSubtypeCount(String subtype) {
    return _allCompetitions
        .where((c) => c.sportSubtype.toLowerCase() == subtype.toLowerCase())
        .length;
  }

  int getGroupCount(String group) {
    if (group == 'Individual') {
      return _allCompetitions.where((c) => !c.isPartOfGroup).length;
    }
    return _allCompetitions.where((c) => c.compGroupName == group).length;
  }

  int getAreaCount(String area) {
    return _allCompetitions
        .where(
          (c) => c.area != null && c.area!.toLowerCase() == area.toLowerCase(),
        )
        .length;
  }

  int getCountryCount(String country) {
    return _allCompetitions
        .where(
          (c) =>
              c.country != null &&
              c.country!.toLowerCase() == country.toLowerCase(),
        )
        .length;
  }

  int getCityCount(String city) {
    return _allCompetitions
        .where(
          (c) => c.city != null && c.city!.toLowerCase() == city.toLowerCase(),
        )
        .length;
  }

  // Setters and action handlers
  void setQuery(String newQuery) {
    if (_query != newQuery) {
      _query = newQuery;
      if (_searchScope == SearchScope.competitions) {
        _applyFilters();
      } else {
        searchUsers(newQuery);
      }
      notifyListeners();
    }
  }

  void setSelectedSubtype(String subtype) {
    _selectedSubtypes.clear();
    if (subtype != 'All') {
      _selectedSubtypes.add(subtype);
    }
    _applyFilters();
    notifyListeners();
  }

  void setSelectedGroup(String group) {
    _selectedGroups.clear();
    if (group != 'All') {
      _selectedGroups.add(group);
    }
    _applyFilters();
    notifyListeners();
  }

  void toggleSubtype(String subtype) {
    if (_selectedSubtypes.contains(subtype)) {
      _selectedSubtypes.remove(subtype);
    } else {
      _selectedSubtypes.add(subtype);
    }
    _applyFilters();
    notifyListeners();
  }

  void toggleGroup(String group) {
    if (_selectedGroups.contains(group)) {
      _selectedGroups.remove(group);
    } else {
      _selectedGroups.add(group);
    }
    _applyFilters();
    notifyListeners();
  }

  void toggleArea(String area) {
    if (_selectedAreas.contains(area)) {
      _selectedAreas.remove(area);
    } else {
      _selectedAreas.add(area);
    }
    _pruneInvalidSelections();
    _applyFilters();
    notifyListeners();
  }

  void toggleCountry(String country) {
    if (_selectedCountries.contains(country)) {
      _selectedCountries.remove(country);
    } else {
      _selectedCountries.add(country);
    }
    _pruneInvalidSelections();
    _applyFilters();
    notifyListeners();
  }

  void toggleCity(String city) {
    if (_selectedCities.contains(city)) {
      _selectedCities.remove(city);
    } else {
      _selectedCities.add(city);
    }
    _applyFilters();
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _selectedDateRange = range;
    _applyFilters();
    notifyListeners();
  }

  void clearDateRange() {
    if (_selectedDateRange != null) {
      _selectedDateRange = null;
      _applyFilters();
      notifyListeners();
    }
  }

  // Cascading lists computation
  Set<String> get availableAreas {
    return _allCompetitions
        .map((c) => c.area)
        .whereType<String>()
        .where((a) => a.trim().isNotEmpty)
        .toSet();
  }

  Set<String> get availableCountries {
    Iterable<Competition> comps = _allCompetitions;
    if (_selectedAreas.isNotEmpty) {
      comps = comps.where(
        (c) => c.area != null && _selectedAreas.contains(c.area),
      );
    }
    return comps
        .map((c) => c.country)
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toSet();
  }

  Set<String> get availableCities {
    Iterable<Competition> comps = _allCompetitions;
    if (_selectedAreas.isNotEmpty) {
      comps = comps.where(
        (c) => c.area != null && _selectedAreas.contains(c.area),
      );
    }
    if (_selectedCountries.isNotEmpty) {
      comps = comps.where(
        (c) => c.country != null && _selectedCountries.contains(c.country),
      );
    }
    return comps
        .map((c) => c.city)
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toSet();
  }

  void _pruneInvalidSelections() {
    final validCountries = availableCountries;
    _selectedCountries.retainWhere((c) => validCountries.contains(c));

    final validCities = availableCities;
    _selectedCities.retainWhere((c) => validCities.contains(c));
  }

  Future<Competition?> getCompetitionById(String id) async {
    try {
      return await _repository.getCompetitionById(id);
    } catch (e) {
      debugPrint('Error getting competition by ID: $e');
      return null;
    }
  }

  Future<void> fetchCompetitions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch all upcoming competitions
      final results = await _repository.getUpcomingCompetitions();
      _allCompetitions = results;
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to load competitions. Please try again.';
      _allCompetitions = [];
      _filteredCompetitions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchUsers(String query) async {
    _lastUserQuery = query;
    _isLoadingUsers = true;
    notifyListeners();

    try {
      final results = await _profileRepository.searchProfiles(query);
      if (_lastUserQuery == query) {
        _searchedUsers = results;
      }
    } catch (e) {
      if (_lastUserQuery == query) {
        _errorMessage = 'Failed to load users: $e';
        _searchedUsers = [];
      }
    } finally {
      if (_lastUserQuery == query) {
        _isLoadingUsers = false;
        notifyListeners();
      }
    }
  }

  void _applyFilters() {
    List<Competition> temp = List.from(_allCompetitions);

    // 1. Search Query
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      temp = temp
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.location.toLowerCase().contains(q) ||
                (c.description != null &&
                    c.description!.toLowerCase().contains(q)) ||
                (c.city != null && c.city!.toLowerCase().contains(q)) ||
                (c.country != null && c.country!.toLowerCase().contains(q)) ||
                (c.area != null && c.area!.toLowerCase().contains(q)),
          )
          .toList();
    }

    // 2. Subtypes
    if (_selectedSubtypes.isNotEmpty) {
      temp = temp
          .where(
            (c) => _selectedSubtypes.any(
              (s) => s.toLowerCase() == c.sportSubtype.toLowerCase(),
            ),
          )
          .toList();
    }

    // 3. Groups
    if (_selectedGroups.isNotEmpty) {
      temp = temp.where((c) {
        if (!c.isPartOfGroup) {
          return _selectedGroups.any((g) => g.toLowerCase() == 'individual');
        } else {
          return _selectedGroups.any(
            (g) => g.toLowerCase() == c.compGroupName?.toLowerCase(),
          );
        }
      }).toList();
    }

    // 4. Area (Multi-select)
    if (_selectedAreas.isNotEmpty) {
      temp = temp
          .where((c) => c.area != null && _selectedAreas.contains(c.area))
          .toList();
    }

    // 5. Country (Multi-select)
    if (_selectedCountries.isNotEmpty) {
      temp = temp
          .where(
            (c) => c.country != null && _selectedCountries.contains(c.country),
          )
          .toList();
    }

    // 6. City (Multi-select)
    if (_selectedCities.isNotEmpty) {
      temp = temp
          .where((c) => c.city != null && _selectedCities.contains(c.city))
          .toList();
    }

    // 7. Date Range Filter
    if (_selectedDateRange != null) {
      final filterStart = DateTime(
        _selectedDateRange!.start.year,
        _selectedDateRange!.start.month,
        _selectedDateRange!.start.day,
      );
      final filterEnd = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
        23,
        59,
        59,
      );

      temp = temp.where((c) {
        final compStart = c.startDate;
        final compEnd = c.endDate;
        return (compEnd.isAfter(filterStart) ||
                compEnd.isAtSameMomentAs(filterStart)) &&
            (compStart.isBefore(filterEnd) ||
                compStart.isAtSameMomentAs(filterEnd));
      }).toList();
    }

    // 8. Sport Filter
    if (_selectedSports.isNotEmpty) {
      temp = temp.where((c) => _selectedSports.contains(c.sportType)).toList();
    }

    // 9. Sorting
    if (_sortOrder == 'date_asc') {
      temp.sort((a, b) => a.startDate.compareTo(b.startDate));
    } else if (_sortOrder == 'date_desc') {
      temp.sort((a, b) => b.startDate.compareTo(a.startDate));
    } else if (_sortOrder == 'name_asc') {
      temp.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    } else if (_sortOrder == 'name_desc') {
      temp.sort(
        (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
      );
    }

    _filteredCompetitions = temp;
  }

  void clearFilters() {
    _query = '';
    _selectedSubtypes.clear();
    _selectedGroups.clear();
    _selectedAreas.clear();
    _selectedCountries.clear();
    _selectedCities.clear();
    _selectedDateRange = null;
    _selectedSports.clear();
    _sortOrder = 'date_asc';
    _applyFilters();
    notifyListeners();
  }

  // === Association Management Methods ===

  Future<void> fetchAssociations() async {
    _isLoadingAssociations = true;
    notifyListeners();
    try {
      final list = await _associationRepository.getAssociations();
      _associations = list;
    } catch (e) {
      debugPrint('Error fetching associations: $e');
    } finally {
      _isLoadingAssociations = false;
      notifyListeners();
    }
  }

  Future<Association?> createAssociation(Association association) async {
    _isLoadingAssociations = true;
    notifyListeners();
    try {
      final result = await _associationRepository.createAssociation(association);
      await fetchAssociations();
      return result;
    } catch (e) {
      debugPrint('Error creating association: $e');
      return null;
    } finally {
      _isLoadingAssociations = false;
      notifyListeners();
    }
  }

  Future<Association?> updateAssociation(Association association) async {
    _isLoadingAssociations = true;
    notifyListeners();
    try {
      final result = await _associationRepository.updateAssociation(association);
      await fetchAssociations();
      return result;
    } catch (e) {
      debugPrint('Error updating association: $e');
      return null;
    } finally {
      _isLoadingAssociations = false;
      notifyListeners();
    }
  }

  Future<Association?> getAssociationDetails(String id) async {
    try {
      return await _associationRepository.getAssociationDetails(id);
    } catch (e) {
      debugPrint('Error getting association details: $e');
      return null;
    }
  }

  Future<List<AssociationMember>> getAssociationMembers(String associationId) async {
    try {
      return await _associationRepository.getAssociationMembers(associationId);
    } catch (e) {
      debugPrint('Error getting association members: $e');
      return [];
    }
  }

  Future<AssociationMember?> addAssociationMember(
    String associationId,
    String userId,
    String role, {
    String? customTitle,
  }) async {
    try {
      final result = await _associationRepository.addAssociationMember(
        associationId,
        userId,
        role,
        customTitle: customTitle,
      );
      return result;
    } catch (e) {
      debugPrint('Error adding association member: $e');
      return null;
    }
  }

  Future<bool> removeAssociationMember(String associationId, String userId) async {
    try {
      return await _associationRepository.removeAssociationMember(associationId, userId);
    } catch (e) {
      debugPrint('Error removing association member: $e');
      return false;
    }
  }

  Future<Association?> transferAssociationOwnership(String associationId, String newOwnerId) async {
    try {
      final result = await _associationRepository.transferAssociationOwnership(associationId, newOwnerId);
      await fetchAssociations();
      return result;
    } catch (e) {
      debugPrint('Error transferring association ownership: $e');
      return null;
    }
  }

  Future<List<CompetitionGroup>> getCompetitionGroups(String associationId) async {
    try {
      return await _associationRepository.getCompetitionGroups(associationId);
    } catch (e) {
      debugPrint('Error getting competition groups: $e');
      return [];
    }
  }

  Future<CompetitionGroup?> createCompetitionGroup(CompetitionGroup group) async {
    try {
      return await _associationRepository.createCompetitionGroup(group);
    } catch (e) {
      debugPrint('Error creating competition group: $e');
      return null;
    }
  }

  Future<CompetitionGroup?> updateCompetitionGroup(CompetitionGroup group) async {
    try {
      return await _associationRepository.updateCompetitionGroup(group);
    } catch (e) {
      debugPrint('Error updating competition group: $e');
      return null;
    }
  }

  Future<List<AthleteGroup>> getAthleteGroups(String associationId) async {
    try {
      return await _associationRepository.getAthleteGroups(associationId);
    } catch (e) {
      debugPrint('Error getting athlete groups: $e');
      return [];
    }
  }

  Future<AthleteGroup?> createAthleteGroup(AthleteGroup group) async {
    try {
      return await _associationRepository.createAthleteGroup(group);
    } catch (e) {
      debugPrint('Error creating athlete group: $e');
      return null;
    }
  }

  Future<AthleteGroup?> updateAthleteGroup(AthleteGroup group) async {
    try {
      return await _associationRepository.updateAthleteGroup(group);
    } catch (e) {
      debugPrint('Error updating athlete group: $e');
      return null;
    }
  }

  Future<Competition?> createCompetition(Competition competition) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      Competition compToCreate = competition;
      if (competition.associationId != null && competition.associationId!.isNotEmpty) {
        final assoc = await _associationRepository.getAssociationDetails(competition.associationId!);
        if (assoc != null) {
          // Inherit rulebook if not provided
          String? rulebookUrl = competition.rulebookUrl;
          if (rulebookUrl == null || rulebookUrl.isEmpty) {
            rulebookUrl = assoc.rulebooks[competition.sportType];
          }

          // Inherit active athlete groups for this sport & format
          List<String>? athleteGroupIds = competition.athleteGroupIds;
          if (athleteGroupIds == null || athleteGroupIds.isEmpty) {
            final groups = await _associationRepository.getAthleteGroups(competition.associationId!);
            athleteGroupIds = groups
                .where((g) => g.isActive && g.sport == competition.sportType && g.format == competition.sportSubtype)
                .map((g) => g.id)
                .toList();
          }

          compToCreate = competition.copyWith(
            athleteGroupIds: athleteGroupIds,
            rulebookUrl: rulebookUrl,
          );
        }
      }

      final created = await _repository.createCompetition(compToCreate);
      if (created != null) {
        _allCompetitions.add(created);
        _applyFilters();

        if (created.requiresFees) {
          final deadline = created.paymentEnd ?? created.registrationEnd;
          final creatorUserId = _repository.client.auth.currentUser?.id ?? created.associationId ?? '';
          final notif = SystemNotification(
            id: 'notif-pay-setup-${DateTime.now().millisecondsSinceEpoch}',
            userId: creatorUserId,
            title: 'Payment Details Formulated',
            message: 'Competition "${created.title}" created with fee ${created.feeAmount} ${created.feeCurrency}. Deadline: $deadline.',
            category: 'payments',
            createdAt: DateTime.now(),
          );
          await _notificationRepository.createNotification(notif);
        }
      }
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> triggerPaymentDeadlineNotification({
    required String userId,
    required Competition competition,
  }) async {
    final deadline = competition.paymentEnd ?? competition.registrationEnd;
    final currency = competition.feeCurrency ?? 'EUR';
    final amount = competition.feeAmount;
    
    final paymentNotification = SystemNotification(
      id: 'notif-pay-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: 'Payment Action Required',
      message: 'A registration fee of $amount $currency is due for ${competition.title}. Deadline: $deadline.',
      category: 'payments',
      createdAt: DateTime.now(),
    );
    await _notificationRepository.createNotification(paymentNotification);
  }

  Future<bool> registerAthlete({
    required String competitionId,
    required String userId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final competition = await _repository.getCompetitionById(competitionId);
      if (competition != null && competition.maxAthletes != null) {
        final registeredIds = await _repository.getRegisteredAthleteIds(competitionId);
        if (registeredIds.length >= competition.maxAthletes!) {
          _errorMessage = 'Competition capacity limit reached!';
          return false;
        }
      }

      final success = await _repository.registerAthlete(competitionId, userId);
      if (success) {
        final comp = competition ?? await _repository.getCompetitionById(competitionId);
        if (comp != null) {
          // Trigger Registration Notification
          final regNotification = SystemNotification(
            id: 'notif-reg-${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            title: 'Registration Confirmed',
            message: 'You have successfully registered for the meet "${comp.title}".',
            category: 'registration',
            createdAt: DateTime.now(),
          );
          await _notificationRepository.createNotification(regNotification);

          // Handle Payments notification if fees are required
          if (comp.requiresFees) {
            await triggerPaymentDeadlineNotification(
              userId: userId,
              competition: comp,
            );
          }
        }
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitVolunteerApplication({
    required String competitionId,
    required String userId,
    required List<String> preferredRoles,
    required Map<String, List<String>> shiftAvailability,
    required Map<String, dynamic> customFieldAnswers,
    required bool disclaimerAccepted,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final payload = {
        'id': 'vol-app-${DateTime.now().millisecondsSinceEpoch}',
        'competition_id': competitionId,
        'user_id': userId,
        'preferred_roles': preferredRoles,
        'shift_availability': shiftAvailability,
        'custom_field_answers': customFieldAnswers,
        'disclaimer_accepted': disclaimerAccepted,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      try {
        await _repository.client.from('volunteer_applications').insert(payload);
      } catch (e) {
        debugPrint('Error inserting volunteer application: $e');
      }
      
      final competition = await _repository.getCompetitionById(competitionId);
      if (competition != null) {
        final notif = SystemNotification(
          id: 'notif-vol-${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          title: "Volunteer Application Submitted",
          message: "Your application to volunteer for the meet \"${competition.title}\" has been submitted.",
          category: "registration",
          createdAt: DateTime.now(),
        );
        await _notificationRepository.createNotification(notif);
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // === Competition Handling (Streetlifting) States ===
  String? _activeDiscipline;
  int _attemptNum = 1;
  double _attemptWeight = 0.0;
  final List<double> _submittedAttempts = [];
  bool _disqualified = false;
  final List<bool> _judgeVotes = [true, true, true];
  String? _failureReason;
  bool _judgingComplete = false;
  bool _liftPassed = false;
  bool _varRequested = false;
  int _varCredits = 1;
  double? _lastAttemptWeight;
  String? _attemptDiscipline;

  final Map<String, Map<String, dynamic>> _weighIns = {};

  // Getters
  String? get activeDiscipline => _activeDiscipline;
  int get attemptNum => _attemptNum;
  double get attemptWeight => _attemptWeight;
  List<double> get submittedAttempts => _submittedAttempts;
  bool get disqualified => _disqualified;
  List<bool> get judgeVotes => _judgeVotes;
  String? get failureReason => _failureReason;
  bool get judgingComplete => _judgingComplete;
  bool get liftPassed => _liftPassed;
  bool get varRequested => _varRequested;
  int get varCredits => _varCredits;
  Map<String, Map<String, dynamic>> get weighIns => _weighIns;

  void initCompetitionHandling(String competitionId) {
    _activeDiscipline = 'Muscle Up';
    _attemptNum = 1;
    _attemptWeight = 0.0;
    _submittedAttempts.clear();
    _lastAttemptWeight = null;
    _attemptDiscipline = null;
    _disqualified = false;
    _judgeVotes[0] = true;
    _judgeVotes[1] = true;
    _judgeVotes[2] = true;
    _failureReason = null;
    _judgingComplete = false;
    _liftPassed = false;
    _varRequested = false;
    _varCredits = 1;
    notifyListeners();
  }

  String? selectAttemptWeight(String athleteId, String discipline, int attemptNumber, double weight) {
    final incrementError = StreetliftingRulesEngine.validateIncrement(weight, discipline);
    if (incrementError != null) {
      return incrementError;
    }
    
    if (!StreetliftingRulesEngine.isAscending(weight, _lastAttemptWeight)) {
      return 'Attempt weight must be ascending!';
    }
    
    _attemptWeight = weight;
    _lastAttemptWeight = weight;
    _attemptDiscipline = discipline;
    _judgingComplete = false;
    notifyListeners();
    return null;
  }

  void toggleJudgeVote(int index) {
    if (index >= 0 && index < 3) {
      _judgeVotes[index] = !_judgeVotes[index];
      notifyListeners();
    }
  }

  void setFailureReason(String? reason) {
    _failureReason = reason;
    notifyListeners();
  }

  void submitJudgingVotes({required String discipline}) {
    if (_judgingComplete) return;

    final passed = StreetliftingRulesEngine.evaluateJudging(
      discipline: discipline,
      votes: _judgeVotes,
      failureReason: _failureReason,
    );

    _liftPassed = passed;
    _judgingComplete = true;
    if (passed) {
      _submittedAttempts.add(_attemptWeight);
    }
    
    // Regardless of pass/fail, progress attempts
    if (_attemptNum < 3) {
      _attemptNum++;
    } else {
      if (_submittedAttempts.isEmpty) {
        _disqualified = true;
      } else {
        // Next discipline
        final disciplines = ['Muscle Up', 'Pull Up', 'Dip', 'Squat'];
        int idx = disciplines.indexOf(_activeDiscipline ?? 'Muscle Up');
        if (idx < 3) {
          _activeDiscipline = disciplines[idx + 1];
          _attemptNum = 1;
          _submittedAttempts.clear();
          _lastAttemptWeight = null;
        }
      }
    }
    notifyListeners();
  }

  void requestVARReview() {
    if (_varCredits > 0) {
      _varRequested = true;
      _varCredits--;
      notifyListeners();
    }
  }

  void resolveVARReview(bool overrule) {
    if (overrule) {
      _varCredits++;
      _liftPassed = true;
      _disqualified = false;
      
      if (_attemptDiscipline == _activeDiscipline) {
        if (!_submittedAttempts.contains(_attemptWeight)) {
          _submittedAttempts.add(_attemptWeight);
        }
        
        // Advance discipline if they finished the 3rd attempt
        if (_attemptNum == 3) {
          final disciplines = ['Muscle Up', 'Pull Up', 'Dip', 'Squat'];
          int idx = disciplines.indexOf(_activeDiscipline ?? 'Muscle Up');
          if (idx < 3) {
            _activeDiscipline = disciplines[idx + 1];
            _attemptNum = 1;
            _submittedAttempts.clear();
            _lastAttemptWeight = null;
          }
        }
      }
    }
    _varRequested = false;
    notifyListeners();
  }

  Future<void> balanceFlights(String competitionId) async {
    final athletes = await _repository.getCompetitionAthletes(competitionId);
    if (athletes.isEmpty) return;

    final competition = await _repository.getCompetitionById(competitionId);
    final compTitle = competition?.title ?? 'Competition';
    
    final numFlights = (athletes.length / 12).ceil();
    final athletesPerFlight = (athletes.length / numFlights).ceil();
    
    for (int i = 0; i < numFlights; i++) {
      final startIndex = i * athletesPerFlight;
      final endIndex = (startIndex + athletesPerFlight > athletes.length) ? athletes.length : startIndex + athletesPerFlight;
      final flightAthletes = athletes.sublist(startIndex, endIndex).map((a) => a.id).toList();
      final flightName = 'Flight ${String.fromCharCode(65 + i)}';
      
      final flight = Flight(
        id: 'flight-$competitionId-${DateTime.now().millisecondsSinceEpoch}-$i',
        competitionId: competitionId,
        name: flightName,
        athleteIds: flightAthletes,
        status: 'pending',
      );
      await _repository.createFlight(flight);

      // Trigger Flight Assignment System Notification for each athlete in this flight
      for (final athleteId in flightAthletes) {
        final notif = SystemNotification(
          id: 'notif-flight-$competitionId-$athleteId-${DateTime.now().millisecondsSinceEpoch}',
          userId: athleteId,
          title: 'Flight Assignment Updated',
          message: 'You have been assigned to $flightName for the meet $compTitle.',
          category: 'flights',
          createdAt: DateTime.now(),
        );
        await _notificationRepository.createNotification(notif);
      }
    }
    notifyListeners();
  }

  void recordWeighIn(String athleteId, double weight, String rackHeight, String dipWidth, {bool isDisqualified = false}) {
    if (weight <= 0) {
      throw ArgumentError('Weight must be positive');
    }
    _weighIns[athleteId] = {
      'weight': weight,
      'rackHeight': rackHeight,
      'dipWidth': dipWidth,
      'isDisqualified': isDisqualified,
    };
    notifyListeners();
  }

  Future<void> publishSchedule(String competitionId, {bool isPublic = true}) async {
    _isLoading = true;
    notifyListeners();
    try {
      try {
        await _repository.client
            .from('competitions')
            .update({'schedule_published': isPublic})
            .eq('id', competitionId);
      } catch (e) {
        debugPrint('Error updating competition schedule in DB: $e');
      }

      final comp = await _repository.getCompetitionById(competitionId);
      if (comp != null && isPublic) {
        final athleteIds = await _repository.getRegisteredAthleteIds(competitionId);
        for (final athleteId in athleteIds) {
          final notif = SystemNotification(
            id: 'notif-sched-$competitionId-$athleteId-${DateTime.now().millisecondsSinceEpoch}',
            userId: athleteId,
            title: 'Meet Schedule Published',
            message: 'The official schedule for ${comp.title} has been published. Check the agenda now!',
            category: 'schedule',
            createdAt: DateTime.now(),
          );
          await _notificationRepository.createNotification(notif);
        }
      }
    } catch (e) {
      debugPrint('Error publishing schedule: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
