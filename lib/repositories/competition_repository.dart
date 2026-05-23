import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/competition.dart';

import '../models/streetlifting_attempt.dart';
import '../models/flight.dart';
import '../models/schedule_item.dart';
import '../models/profile.dart';

class CompetitionRepository {
  final SupabaseClient _client;

  CompetitionRepository(this._client);

  SupabaseClient get client => _client;

  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype, // 'Modern', 'Classic', or null/empty for All
    String?
    compGroupName, // 'FinalRep Underground', 'FinalRep Qualifier', 'FinalRep Final', 'Individual', or null/empty for All
  }) async {
    try {
      var request = _client
          .from('competitions')
          .select()
          .eq('status', 'upcoming');

      // Filter by search query (title or location)
      if (query != null && query.trim().isNotEmpty) {
        final cleanQuery = query.trim();
        request = request.or(
          'title.ilike.%$cleanQuery%,location.ilike.%$cleanQuery%',
        );
      }

      // Filter by Streetlifting subtype
      if (sportSubtype != null &&
          sportSubtype.isNotEmpty &&
          sportSubtype != 'All') {
        request = request.eq('sport_subtype', sportSubtype);
      }

      // Filter by Competition Group Name
      if (compGroupName != null &&
          compGroupName.isNotEmpty &&
          compGroupName != 'All') {
        if (compGroupName == 'Individual') {
          request = request.isFilter('comp_group_name', null);
        } else {
          request = request.eq('comp_group_name', compGroupName);
        }
      }

      // Sort by start_date ascending (closest competition first)
      final response = await request.order('start_date', ascending: true);

      return (response as List)
          .map((data) => Competition.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return empty list on failure or log error
      debugPrint('Error fetching competitions: $e');
      return [];
    }
  }

  Future<Competition?> getCompetitionById(String id) async {
    try {
      final response = await _client
          .from('competitions')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Competition.fromJson(response);
    } catch (e) {
      debugPrint('Error getting competition by ID ($id): $e');
      return null;
    }
  }

  Future<Competition?> createCompetition(Competition competition) async {
    try {
      final response = await _client.from('competitions').insert(competition.toJson()).select().single();
      return Competition.fromJson(response);
    } catch (e) {
      debugPrint('Error creating competition: $e');
      return competition;
    }
  }

  Future<List<StreetliftingAttempt>> getAttempts(String competitionId) async {
    try {
      final response = await _client
          .from('attempts')
          .select()
          .eq('competition_id', competitionId);
      return (response as List)
          .map((data) => StreetliftingAttempt.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting attempts: $e');
      return [];
    }
  }

  Future<StreetliftingAttempt?> createAttempt(StreetliftingAttempt attempt) async {
    try {
      final response = await _client
          .from('attempts')
          .insert(attempt.toJson())
          .select()
          .single();
      return StreetliftingAttempt.fromJson(response);
    } catch (e) {
      debugPrint('Error creating attempt: $e');
      return attempt;
    }
  }

  Future<StreetliftingAttempt?> updateAttempt(StreetliftingAttempt attempt) async {
    try {
      final response = await _client
          .from('attempts')
          .update(attempt.toJson())
          .eq('id', attempt.id)
          .select()
          .single();
      return StreetliftingAttempt.fromJson(response);
    } catch (e) {
      debugPrint('Error updating attempt: $e');
      return attempt;
    }
  }

  Future<List<Flight>> getFlights(String competitionId) async {
    try {
      final response = await _client
          .from('flights')
          .select()
          .eq('competition_id', competitionId);
      return (response as List)
          .map((data) => Flight.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting flights: $e');
      return [];
    }
  }

  Future<Flight?> createFlight(Flight flight) async {
    try {
      final response = await _client
          .from('flights')
          .insert(flight.toJson())
          .select()
          .single();
      return Flight.fromJson(response);
    } catch (e) {
      debugPrint('Error creating flight: $e');
      return flight;
    }
  }

  Future<Flight?> updateFlight(Flight flight) async {
    try {
      final response = await _client
          .from('flights')
          .update(flight.toJson())
          .eq('id', flight.id)
          .select()
          .single();
      return Flight.fromJson(response);
    } catch (e) {
      debugPrint('Error updating flight: $e');
      return flight;
    }
  }

  Future<List<ScheduleItem>> getScheduleItems(String competitionId) async {
    try {
      final response = await _client
          .from('schedule_items')
          .select()
          .eq('competition_id', competitionId);
      return (response as List)
          .map((data) => ScheduleItem.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting schedule items: $e');
      return [];
    }
  }

  Future<ScheduleItem?> createScheduleItem(ScheduleItem item) async {
    try {
      final response = await _client
          .from('schedule_items')
          .insert(item.toJson())
          .select()
          .single();
      return ScheduleItem.fromJson(response);
    } catch (e) {
      debugPrint('Error creating schedule item: $e');
      return item;
    }
  }

  Future<ScheduleItem?> updateScheduleItem(ScheduleItem item) async {
    try {
      final response = await _client
          .from('schedule_items')
          .update(item.toJson())
          .eq('id', item.id)
          .select()
          .single();
      return ScheduleItem.fromJson(response);
    } catch (e) {
      debugPrint('Error updating schedule item: $e');
      return item;
    }
  }

  Future<List<Profile>> getCompetitionAthletes(String competitionId) async {
    try {
      final response = await _client
          .from('profiles')
          .select();
      return (response as List)
          .map((data) => Profile.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting competition athletes: $e');
      return [];
    }
  }

  Future<bool> registerAthlete(String competitionId, String userId) async {
    try {
      await _client.from('meet_registrations').insert({
        'id': 'reg-$competitionId-$userId-${DateTime.now().millisecondsSinceEpoch}',
        'competition_id': competitionId,
        'profile_id': userId,
        'status': 'registered',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error registering athlete in database: $e');
      return false;
    }
  }

  Future<List<String>> getRegisteredAthleteIds(String competitionId) async {
    try {
      final response = await _client
          .from('meet_registrations')
          .select('profile_id')
          .eq('competition_id', competitionId)
          .eq('status', 'registered');
      return (response as List).map((e) => e['profile_id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting registered athlete IDs: $e');
      return [];
    }
  }
}
