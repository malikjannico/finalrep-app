import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/providers/competition_provider.dart';

// A mock implementation of the repository
class MockCompetitionRepository implements CompetitionRepository {
  final List<Competition> _fakeCompetitions = [
    Competition(
      id: '1',
      title: 'Qualifier Hamburg',
      location: 'Hamburg',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '2',
      title: 'Underground Berlin',
      location: 'Berlin',
      sportSubtype: 'Classic',
      compGroupName: 'FinalRep Underground',
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '3',
      title: 'Classic Cup Vienna',
      location: 'Vienna',
      sportSubtype: 'Classic',
      compGroupName: null,
      startDate: DateTime.now(),
      endDate: DateTime.now(),
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
}

void main() {
  group('CompetitionProvider Tests', () {
    late MockCompetitionRepository repository;
    late CompetitionProvider provider;

    setUp(() {
      repository = MockCompetitionRepository();
      provider = CompetitionProvider(repository);
    });

    test('Initial State - Loads all competitions', () async {
      expect(provider.isLoading, false);
      expect(provider.competitions.length, 3);
      expect(provider.query, '');
      expect(provider.selectedSubtype, 'All');
      expect(provider.selectedGroup, 'All');
    });

    test('Filter by Subtype Modern', () async {
      await Future.delayed(Duration.zero); // Load initial
      
      provider.setSelectedSubtype('Modern');
      expect(provider.selectedSubtype, 'Modern');
      expect(provider.isLoading, true);

      await Future.delayed(Duration.zero);

      expect(provider.isLoading, false);
      expect(provider.competitions.length, 1);
      expect(provider.competitions.first.title, 'Qualifier Hamburg');
    });

    test('Filter by Group Individual', () async {
      await Future.delayed(Duration.zero); // Load initial
      
      provider.setSelectedGroup('Individual');
      expect(provider.selectedGroup, 'Individual');

      await Future.delayed(Duration.zero);

      expect(provider.competitions.length, 1);
      expect(provider.competitions.first.title, 'Classic Cup Vienna');
    });

    test('Search by query "Berlin"', () async {
      await Future.delayed(Duration.zero); // Load initial
      
      provider.setQuery('Berlin');
      expect(provider.query, 'Berlin');

      await Future.delayed(Duration.zero);

      expect(provider.competitions.length, 1);
      expect(provider.competitions.first.title, 'Underground Berlin');
    });
  });
}
