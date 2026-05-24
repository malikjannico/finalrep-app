import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/competition.dart';
import '../models/streetlifting_attempt.dart';
import '../models/flight.dart';
import '../models/schedule_item.dart';
import '../models/profile.dart';
import '../utils/mock_safety.dart';
import '../utils/api_client.dart';

class CompetitionRepository {
  final dynamic _client;
  final ApiClient _api;

  static final List<Competition> _mockCompetitions = [
    Competition(
      id: 'comp-1',
      title: 'Qualifier Hamburg',
      location: 'Hamburg, Germany',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      area: 'Europe',
      country: 'Germany',
      city: 'Hamburg',
      status: 'upcoming',
      startDate: DateTime(2026, 6, 15),
      endDate: DateTime(2026, 6, 15),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    Competition(
      id: 'comp-2',
      title: 'Underground Berlin',
      location: 'Berlin, Germany',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Underground',
      area: 'Europe',
      country: 'Germany',
      city: 'Berlin',
      status: 'upcoming',
      startDate: DateTime(2026, 7, 10),
      endDate: DateTime(2026, 7, 10),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    Competition(
      id: 'comp-3',
      title: 'Classic Cup Vienna',
      location: 'Vienna, Austria',
      sportSubtype: 'Classic',
      compGroupName: null,
      area: 'Europe',
      country: 'Austria',
      city: 'Vienna',
      status: 'upcoming',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    Competition(
      id: 'comp-4',
      title: 'US Qualifier',
      location: 'New York, USA',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      area: 'North America',
      country: 'USA',
      city: 'New York',
      status: 'upcoming',
      startDate: DateTime(2026, 9, 20),
      endDate: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    Competition(
      id: 'comp-5',
      title: 'Underground Munich',
      location: 'Munich, Germany',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Underground',
      area: 'Europe',
      country: 'Germany',
      city: 'Munich',
      status: 'upcoming',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 5),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  CompetitionRepository(dynamic client, {ApiClient? api})
      : _client = client,
        _api = api ?? ApiClient();

  dynamic get client => _client;

  String get baseUrl => _api.baseUrl;

  bool get _useMockFallback => MockSafety.isMockAllowed;


  List<Competition> _getMockCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status,
  }) {
    var list = List<Competition>.from(_mockCompetitions);
    if (status != null && status.isNotEmpty) {
      list = list.where((c) => c.status == status).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((c) =>
          c.title.toLowerCase().contains(q) ||
          c.location.toLowerCase().contains(q)).toList();
    }
    if (sportSubtype != null && sportSubtype.isNotEmpty && sportSubtype != 'All') {
      list = list.where((c) => c.sportSubtype == sportSubtype).toList();
    }
    if (compGroupName != null && compGroupName.isNotEmpty && compGroupName != 'All') {
      if (compGroupName == 'Individual') {
        list = list.where((c) => c.compGroupName == null).toList();
      } else {
        list = list.where((c) => c.compGroupName == compGroupName).toList();
      }
    }
    return list;
  }

  void _syncCompetitionToMock(Competition comp) {
    final idx = _mockCompetitions.indexWhere((element) => element.id == comp.id);
    if (idx != -1) {
      _mockCompetitions[idx] = comp;
    } else {
      _mockCompetitions.add(comp);
    }
  }

  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype, // 'Modern', 'Classic', or null/empty for All
    String?
    compGroupName, // 'FinalRep Underground', 'FinalRep Qualifier', 'FinalRep Final', 'Individual', or null/empty for All
    String? status = 'upcoming',
  }) async {
    if (_useMockFallback && _client != null) {
      try {
        var queryBuilder = _client.from('competitions').select();
        if (status != null && status.isNotEmpty) {
          queryBuilder = queryBuilder.eq('status', status);
        }
        final response = await queryBuilder;
        final list = (response as List)
            .map((data) => Competition.fromJson(data as Map<String, dynamic>))
            .toList();
        var filtered = list;
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          filtered = filtered.where((c) => c.title.toLowerCase().contains(q) || c.location.toLowerCase().contains(q)).toList();
        }
        if (sportSubtype != null && sportSubtype.isNotEmpty && sportSubtype != 'All') {
          filtered = filtered.where((c) => c.sportSubtype == sportSubtype).toList();
        }
        if (compGroupName != null && compGroupName.isNotEmpty && compGroupName != 'All') {
          if (compGroupName == 'Individual') {
            filtered = filtered.where((c) => c.compGroupName == null).toList();
          } else {
            filtered = filtered.where((c) => c.compGroupName == compGroupName).toList();
          }
        }
        return filtered.isNotEmpty ? filtered : _getMockCompetitions(query: query, sportSubtype: sportSubtype, compGroupName: compGroupName, status: status);
      } catch (_) {
        return _getMockCompetitions(
          query: query,
          sportSubtype: sportSubtype,
          compGroupName: compGroupName,
          status: status,
        );
      }
    }
    try {
      final Map<String, String> queryParameters = {};
      if (status != null && status.isNotEmpty) {
        queryParameters['status'] = status;
      }
      if (query != null && query.trim().isNotEmpty) {
        queryParameters['query'] = query.trim();
      }
      if (sportSubtype != null && sportSubtype.isNotEmpty && sportSubtype != 'All') {
        queryParameters['sportSubtype'] = sportSubtype;
      }
      if (compGroupName != null && compGroupName.isNotEmpty && compGroupName != 'All') {
        queryParameters['compGroupName'] = compGroupName;
      }

      final response = await _api.get('/competitions', queryParameters: queryParameters);
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List)
            .map((data) => Competition.fromJson(data as Map<String, dynamic>))
            .toList();
        for (final comp in list) {
          _syncCompetitionToMock(comp);
        }
        return list;
      }
      throw Exception('Failed to get competitions: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error fetching competitions: $e');
      return _getMockCompetitions(
        query: query,
        sportSubtype: sportSubtype,
        compGroupName: compGroupName,
        status: status,
      );
    }
  }

  Future<Competition?> getCompetitionById(String id) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('competitions').select().eq('id', id).maybeSingle();
        if (response == null) return null;
        return Competition.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        try {
          return _mockCompetitions.firstWhere((element) => element.id == id);
        } catch (_) {
          return null;
        }
      }
    }
    try {
      final response = await _api.get('/competitions/$id');
      if (response.statusCode == 200) {
        final comp = Competition.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncCompetitionToMock(comp);
        return comp;
      }
      if (response.statusCode == 404) return null;
      throw Exception('Failed to get competition by ID: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error getting competition by ID ($id): $e');
      try {
        return _mockCompetitions.firstWhere((element) => element.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<Competition?> createCompetition(Competition competition) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('competitions').insert(competition.toJson()).select().single();
        return Competition.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        _syncCompetitionToMock(competition);
        return competition;
      }
    }
    try {
      final response = await _api.post('/competitions', body: competition.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = Competition.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncCompetitionToMock(created);
        return created;
      }
      throw Exception('Failed to create competition: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error creating competition: $e');
      _syncCompetitionToMock(competition);
      return competition;
    }
  }

  Future<List<StreetliftingAttempt>> getAttempts(String competitionId) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('attempts').select().eq('competition_id', competitionId);
        return (response as List).map((data) => StreetliftingAttempt.fromJson(data as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }
    try {
      final response = await _api.get('/attempts', queryParameters: {'competitionId': competitionId});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((data) => StreetliftingAttempt.fromJson(data as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to get attempts: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error getting attempts: $e');
      return [];
    }
  }

  Future<StreetliftingAttempt?> createAttempt(
    StreetliftingAttempt attempt,
  ) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('attempts').insert(attempt.toJson()).select().single();
        return StreetliftingAttempt.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return attempt;
      }
    }
    try {
      final response = await _api.post('/attempts', body: attempt.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return StreetliftingAttempt.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to create attempt: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error creating attempt: $e');
      return attempt;
    }
  }

  Future<StreetliftingAttempt?> updateAttempt(
    StreetliftingAttempt attempt,
  ) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('attempts').update(attempt.toJson()).eq('id', attempt.id).select().single();
        return StreetliftingAttempt.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return attempt;
      }
    }
    try {
      final response = await _api.put('/attempts', body: attempt.toJson());
      if (response.statusCode == 200) {
        return StreetliftingAttempt.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to update attempt: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error updating attempt: $e');
      return attempt;
    }
  }

  Future<List<Flight>> getFlights(String competitionId) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('flights').select().eq('competition_id', competitionId);
        return (response as List).map((data) => Flight.fromJson(data as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }
    try {
      final response = await _api.get('/flights', queryParameters: {'competitionId': competitionId});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((data) => Flight.fromJson(data as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to get flights: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error getting flights: $e');
      return [];
    }
  }

  Future<Flight?> createFlight(Flight flight) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('flights').insert(flight.toJson()).select().single();
        return Flight.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return flight;
      }
    }
    try {
      final response = await _api.post('/flights', body: flight.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Flight.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to create flight: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error creating flight: $e');
      return flight;
    }
  }

  Future<Flight?> updateFlight(Flight flight) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('flights').update(flight.toJson()).eq('id', flight.id).select().single();
        return Flight.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return flight;
      }
    }
    try {
      final response = await _api.put('/flights', body: flight.toJson());
      if (response.statusCode == 200) {
        return Flight.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to update flight: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error updating flight: $e');
      return flight;
    }
  }

  Future<List<ScheduleItem>> getScheduleItems(String competitionId) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('schedule_items').select().eq('competition_id', competitionId);
        return (response as List).map((data) => ScheduleItem.fromJson(data as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }
    try {
      final response = await _api.get('/schedule', queryParameters: {'competitionId': competitionId});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((data) => ScheduleItem.fromJson(data as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to get schedule items: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error getting schedule items: $e');
      return [];
    }
  }

  Future<ScheduleItem?> createScheduleItem(ScheduleItem item) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('schedule_items').insert(item.toJson()).select().single();
        return ScheduleItem.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return item;
      }
    }
    try {
      final response = await _api.post('/schedule', body: item.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ScheduleItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to create schedule item: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error creating schedule item: $e');
      return item;
    }
  }

  Future<ScheduleItem?> updateScheduleItem(ScheduleItem item) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('schedule_items').update(item.toJson()).eq('id', item.id).select().single();
        return ScheduleItem.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return item;
      }
    }
    try {
      final response = await _api.put('/schedule', body: item.toJson());
      if (response.statusCode == 200) {
        return ScheduleItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to update schedule item: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error updating schedule item: $e');
      return item;
    }
  }

  Future<List<Profile>> getCompetitionAthletes(String competitionId) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('meet_registrations').select('*, profile:profiles(*)').eq('competition_id', competitionId);
        final list = response as List? ?? [];
        return list
            .map((data) => data['profile'])
            .where((profile) => profile != null)
            .map((profileJson) => Profile.fromJson(profileJson as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
    try {
      final response = await _api.get('/competitions/$competitionId/athletes');
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((data) => Profile.fromJson(data as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to get competition athletes: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error getting competition athletes: $e');
      return [];
    }
  }

  Future<bool> registerAthlete(String competitionId, String userId) async {
    if (_useMockFallback && _client != null) {
      try {
        final regId = 'reg-${DateTime.now().millisecondsSinceEpoch}';
        await _client.from('meet_registrations').insert({
          'id': regId,
          'competition_id': competitionId,
          'profile_id': userId,
          'status': 'registered',
        });
        return true;
      } catch (_) {
        return false;
      }
    }
    try {
      final response = await _api.post('/competitions/$competitionId/register', body: {'userId': userId});
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['success'] == true;
      }
      throw Exception('Failed to register athlete: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error registering athlete in database: $e');
      return false;
    }
  }

  Future<List<String>> getRegisteredAthleteIds(String competitionId) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('meet_registrations').select('profile_id').eq('competition_id', competitionId);
        final list = response as List? ?? [];
        return list.map((data) => data['profile_id'] as String).toList();
      } catch (_) {
        return [];
      }
    }
    try {
      final response = await _api.get('/competitions/$competitionId/registrations');
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.cast<String>();
      }
      throw Exception('Failed to get registered athlete IDs: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error getting registered athlete IDs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMeetResults() async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('meet_results').select('*, competition:competitions(*), profile:profiles(*)');
        final list = response as List? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        return [];
      }
    }
    try {
      final response = await _api.get('/rankings');
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return list;
      }
      throw Exception('Failed to get meet results: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      debugPrint('Error getting meet results: $e');
      return [];
    }
  }
}

