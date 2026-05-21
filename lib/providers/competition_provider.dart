import 'package:flutter/material.dart';
import '../models/competition.dart';
import '../models/profile.dart';
import '../repositories/competition_repository.dart';
import '../repositories/profile_repository.dart';

enum CompetitionsLayout { grid, list, map }
enum SearchScope { competitions, users }

class CompetitionProvider extends ChangeNotifier {
  final CompetitionRepository _repository;
  final ProfileRepository _profileRepository;

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

  CompetitionProvider(this._repository, this._profileRepository) {
    fetchCompetitions();
  }

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
}
