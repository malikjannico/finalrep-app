import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/competition.dart';

class CompetitionRepository {
  final SupabaseClient _client;

  CompetitionRepository(this._client);

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
}
