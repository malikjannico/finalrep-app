import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:flutter/material.dart';

class MockProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Profile>> searchProfiles(String query) async {
    return [];
  }
}

// A mock implementation of the repository
class MockCompetitionRepository implements CompetitionRepository {
  final List<Competition> _fakeCompetitions = [
    Competition(
      id: '1',
      title: 'Qualifier Hamburg',
      location: 'Hamburg, Germany',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      area: 'Europe',
      country: 'Germany',
      city: 'Hamburg',
      startDate: DateTime(2026, 6, 15),
      endDate: DateTime(2026, 6, 15),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '2',
      title: 'Underground Berlin',
      location: 'Berlin, Germany',
      sportSubtype: 'Classic',
      compGroupName: 'FinalRep Underground',
      area: 'Europe',
      country: 'Germany',
      city: 'Berlin',
      startDate: DateTime(2026, 7, 10),
      endDate: DateTime(2026, 7, 10),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '3',
      title: 'Classic Cup Vienna',
      location: 'Vienna, Austria',
      sportSubtype: 'Classic',
      compGroupName: null,
      area: 'Europe',
      country: 'Austria',
      city: 'Vienna',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '4',
      title: 'US Qualifier',
      location: 'New York, USA',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      area: 'North America',
      country: 'USA',
      city: 'New York',
      startDate: DateTime(2026, 9, 20),
      endDate: DateTime(2026, 9, 20),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
  }) async {
    return _fakeCompetitions.where((comp) {
      if (query != null && query.isNotEmpty) {
        final matchesTitle = comp.title.toLowerCase().contains(
          query.toLowerCase(),
        );
        final matchesLocation = comp.location.toLowerCase().contains(
          query.toLowerCase(),
        );
        if (!matchesTitle && !matchesLocation) return false;
      }
      if (sportSubtype != null &&
          sportSubtype != 'All' &&
          comp.sportSubtype != sportSubtype) {
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
}

void main() {
  group('CompetitionProvider Tests', () {
    late MockCompetitionRepository repository;
    late CompetitionProvider provider;

    setUp(() async {
      repository = MockCompetitionRepository();
      provider = CompetitionProvider(repository, MockProfileRepository());
      // Wait for the initial load to complete
      await Future.delayed(Duration.zero);
    });

    test('Initial State - Loads all competitions', () async {
      expect(provider.isLoading, false);
      expect(provider.competitions.length, 4);
      expect(provider.query, '');
      expect(provider.selectedSubtype, 'All');
      expect(provider.selectedGroup, 'All');
      expect(provider.selectedAreas, isEmpty);
      expect(provider.selectedCountries, isEmpty);
      expect(provider.selectedCities, isEmpty);
    });

    test('Filter by Subtype Modern', () {
      provider.setSelectedSubtype('Modern');
      expect(provider.selectedSubtype, 'Modern');
      expect(provider.competitions.length, 2);
      expect(
        provider.competitions.any((c) => c.title == 'Qualifier Hamburg'),
        true,
      );
      expect(provider.competitions.any((c) => c.title == 'US Qualifier'), true);
    });

    test('Filter by Group Individual', () {
      provider.setSelectedGroup('Individual');
      expect(provider.selectedGroup, 'Individual');
      expect(provider.competitions.length, 1);
      expect(provider.competitions.first.title, 'Classic Cup Vienna');
    });

    test('Multi-select Format (Modern & Classic)', () {
      provider.toggleSubtype('Modern');
      provider.toggleSubtype('Classic');
      expect(provider.selectedSubtypes, containsAll(['Modern', 'Classic']));
      expect(provider.competitions.length, 4);
    });

    test('Multi-select Group (Qualifier & Underground)', () {
      provider.toggleGroup('FinalRep Qualifier');
      provider.toggleGroup('FinalRep Underground');
      expect(
        provider.selectedGroups,
        containsAll(['FinalRep Qualifier', 'FinalRep Underground']),
      );
      expect(provider.competitions.length, 3);
      expect(
        provider.competitions.any((c) => c.title == 'Classic Cup Vienna'),
        false,
      );
    });

    test('Search by query "Berlin"', () {
      provider.setQuery('Berlin');
      expect(provider.query, 'Berlin');
      expect(provider.competitions.length, 1);
      expect(provider.competitions.first.title, 'Underground Berlin');
    });

    test(
      'Cascading Location Filters - Area filters Country & City option lists',
      () {
        expect(
          provider.availableAreas,
          containsAll(['Europe', 'North America']),
        );

        provider.toggleArea('North America');
        expect(provider.selectedAreas, contains('North America'));
        expect(provider.availableCountries, equals({'USA'}));
        expect(provider.availableCities, equals({'New York'}));
      },
    );

    test('Cascading Location Filters - Country filters City option list', () {
      provider.toggleArea('Europe');
      expect(provider.availableCountries, containsAll(['Germany', 'Austria']));

      provider.toggleCountry('Germany');
      expect(provider.selectedCountries, contains('Germany'));

      expect(provider.availableCities, containsAll(['Hamburg', 'Berlin']));
      expect(provider.availableCities, isNot(contains('Vienna')));
    });

    test('Cascading Location Filters - Pruning invalid selections', () {
      provider.toggleArea('Europe');
      provider.toggleCountry('Germany');
      provider.toggleCity('Berlin');

      expect(provider.selectedAreas, contains('Europe'));
      expect(provider.selectedCountries, contains('Germany'));
      expect(provider.selectedCities, contains('Berlin'));

      provider.toggleArea('Europe'); // deselect Europe
      provider.toggleArea('North America'); // select North America

      expect(provider.selectedCountries, isNot(contains('Germany')));
      expect(provider.selectedCities, isNot(contains('Berlin')));
    });

    test('Filter by Date Range', () {
      final range = DateTimeRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );

      provider.setDateRange(range);
      expect(provider.selectedDateRange, range);

      expect(provider.competitions.length, 1);
      expect(provider.competitions.first.title, 'Underground Berlin');

      provider.clearDateRange();
      expect(provider.selectedDateRange, isNull);
      expect(provider.competitions.length, 4);
    });
  });
}
