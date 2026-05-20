import 'package:flutter/material.dart';
import '../models/competition.dart';
import '../repositories/competition_repository.dart';

class CompetitionProvider extends ChangeNotifier {
  final CompetitionRepository _repository;

  String _query = '';
  String _selectedSubtype = 'All'; // 'All', 'Modern', 'Classic'
  String _selectedGroup = 'All'; // 'All', 'FinalRep Underground', 'FinalRep Qualifier', 'FinalRep Final', 'Individual'
  bool _isLoading = false;
  List<Competition> _competitions = [];
  String? _errorMessage;

  CompetitionProvider(this._repository) {
    fetchCompetitions();
  }

  // Getters
  String get query => _query;
  String get selectedSubtype => _selectedSubtype;
  String get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  List<Competition> get competitions => _competitions;
  String? get errorMessage => _errorMessage;

  // Setters and action handlers
  void setQuery(String newQuery) {
    if (_query != newQuery) {
      _query = newQuery;
      notifyListeners();
      fetchCompetitions();
    }
  }

  void setSelectedSubtype(String subtype) {
    if (_selectedSubtype != subtype) {
      _selectedSubtype = subtype;
      notifyListeners();
      fetchCompetitions();
    }
  }

  void setSelectedGroup(String group) {
    if (_selectedGroup != group) {
      _selectedGroup = group;
      notifyListeners();
      fetchCompetitions();
    }
  }

  Future<void> fetchCompetitions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _repository.getUpcomingCompetitions(
        query: _query,
        sportSubtype: _selectedSubtype,
        compGroupName: _selectedGroup,
      );
      _competitions = results;
    } catch (e) {
      _errorMessage = 'Failed to load competitions. Please try again.';
      _competitions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearFilters() {
    _query = '';
    _selectedSubtype = 'All';
    _selectedGroup = 'All';
    notifyListeners();
    fetchCompetitions();
  }
}
