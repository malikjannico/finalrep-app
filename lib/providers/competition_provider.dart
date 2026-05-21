import 'package:flutter/material.dart';
import '../models/competition.dart';
import '../repositories/competition_repository.dart';

class CompetitionProvider extends ChangeNotifier {
  final CompetitionRepository _repository;

  String _query = '';
  String _selectedSubtype = 'All'; // 'All', 'Modern', 'Classic'
  String _selectedGroup = 'All'; // 'All', 'FinalRep Underground', 'FinalRep Qualifier', 'FinalRep Final', 'Individual'
  
  // Location filters
  final Set<String> _selectedAreas = {};
  final Set<String> _selectedCountries = {};
  final Set<String> _selectedCities = {};
  
  // Date range filter
  DateTimeRange? _selectedDateRange;

  bool _isLoading = false;
  List<Competition> _allCompetitions = [];
  List<Competition> _filteredCompetitions = [];
  String? _errorMessage;

  CompetitionProvider(this._repository) {
    fetchCompetitions();
  }

  // Getters
  String get query => _query;
  String get selectedSubtype => _selectedSubtype;
  String get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  List<Competition> get competitions => _filteredCompetitions;
  List<Competition> get allCompetitions => _allCompetitions;
  String? get errorMessage => _errorMessage;

  Set<String> get selectedAreas => _selectedAreas;
  Set<String> get selectedCountries => _selectedCountries;
  Set<String> get selectedCities => _selectedCities;
  DateTimeRange? get selectedDateRange => _selectedDateRange;

  // Setters and action handlers
  void setQuery(String newQuery) {
    if (_query != newQuery) {
      _query = newQuery;
      _applyFilters();
      notifyListeners();
    }
  }

  void setSelectedSubtype(String subtype) {
    if (_selectedSubtype != subtype) {
      _selectedSubtype = subtype;
      _applyFilters();
      notifyListeners();
    }
  }

  void setSelectedGroup(String group) {
    if (_selectedGroup != group) {
      _selectedGroup = group;
      _applyFilters();
      notifyListeners();
    }
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
      comps = comps.where((c) => c.area != null && _selectedAreas.contains(c.area));
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
      comps = comps.where((c) => c.area != null && _selectedAreas.contains(c.area));
    }
    if (_selectedCountries.isNotEmpty) {
      comps = comps.where((c) => c.country != null && _selectedCountries.contains(c.country));
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

  void _applyFilters() {
    List<Competition> temp = List.from(_allCompetitions);

    // 1. Search Query
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      temp = temp.where((c) =>
        c.title.toLowerCase().contains(q) ||
        c.location.toLowerCase().contains(q) ||
        (c.description != null && c.description!.toLowerCase().contains(q)) ||
        (c.city != null && c.city!.toLowerCase().contains(q)) ||
        (c.country != null && c.country!.toLowerCase().contains(q)) ||
        (c.area != null && c.area!.toLowerCase().contains(q))
      ).toList();
    }

    // 2. Subtype
    if (_selectedSubtype != 'All') {
      temp = temp.where((c) => c.sportSubtype.toLowerCase() == _selectedSubtype.toLowerCase()).toList();
    }

    // 3. Group
    if (_selectedGroup != 'All') {
      if (_selectedGroup == 'Individual') {
        temp = temp.where((c) => !c.isPartOfGroup).toList();
      } else {
        temp = temp.where((c) => c.compGroupName == _selectedGroup).toList();
      }
    }

    // 4. Area (Multi-select)
    if (_selectedAreas.isNotEmpty) {
      temp = temp.where((c) => c.area != null && _selectedAreas.contains(c.area)).toList();
    }

    // 5. Country (Multi-select)
    if (_selectedCountries.isNotEmpty) {
      temp = temp.where((c) => c.country != null && _selectedCountries.contains(c.country)).toList();
    }

    // 6. City (Multi-select)
    if (_selectedCities.isNotEmpty) {
      temp = temp.where((c) => c.city != null && _selectedCities.contains(c.city)).toList();
    }

    // 7. Date Range Filter
    if (_selectedDateRange != null) {
      final filterStart = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
      final filterEnd = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);

      temp = temp.where((c) {
        final compStart = c.startDate;
        final compEnd = c.endDate;
        return (compEnd.isAfter(filterStart) || compEnd.isAtSameMomentAs(filterStart)) &&
               (compStart.isBefore(filterEnd) || compStart.isAtSameMomentAs(filterEnd));
      }).toList();
    }

    _filteredCompetitions = temp;
  }

  void clearFilters() {
    _query = '';
    _selectedSubtype = 'All';
    _selectedGroup = 'All';
    _selectedAreas.clear();
    _selectedCountries.clear();
    _selectedCities.clear();
    _selectedDateRange = null;
    _applyFilters();
    notifyListeners();
  }
}
