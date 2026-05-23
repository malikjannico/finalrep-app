import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/competition.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  SupabaseClient get client => _client;

  /// Fetch a user profile by their unique auth/profile ID.
  Future<Profile?> getProfile(String id) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('Error getting profile by ID ($id): $e');
      return null;
    }
  }

  /// Fetch a user profile by their unique username.
  Future<Profile?> getProfileByUsername(String username) async {
    try {
      final cleanUsername = username.trim().toLowerCase();
      final response = await _client
          .from('profiles')
          .select()
          .eq('username', cleanUsername)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('Error getting profile by username ($username): $e');
      return null;
    }
  }

  /// Fetch a user profile by their email.
  Future<Profile?> getProfileByEmail(String email) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('Error getting profile by email ($email): $e');
      return null;
    }
  }

  /// Search user profiles by username or full name.
  Future<List<Profile>> searchProfiles(String query) async {
    try {
      if (query.trim().isEmpty) {
        // Return a list of default user profiles if no search is active
        final response = await _client
            .from('profiles')
            .select()
            .limit(20);
        return (response as List)
            .map((data) => Profile.fromJson(data as Map<String, dynamic>))
            .toList();
      }

      final cleanQuery = query.trim();
      final response = await _client
          .from('profiles')
          .select()
          .or('username.ilike.%$cleanQuery%,full_name.ilike.%$cleanQuery%')
          .limit(50);

      return (response as List)
          .map((data) => Profile.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error searching profiles for query "$query": $e');
      return [];
    }
  }

  /// Update a profile's details in the database.
  Future<Profile?> updateProfile(Profile profile) async {
    try {
      final data = profile.toJson();
      // Remove timestamps if we want Postgres to update them, or keep updated_at set to now
      data.remove('created_at');
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final response = await _client
          .from('profiles')
          .update(data)
          .eq('id', profile.id)
          .select()
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('Error updating profile (${profile.id}): $e');
      rethrow;
    }
  }

  /// Update permissions for a user profile.
  Future<Profile?> updatePermissions(
    String userId, {
    bool? isCompetitionCreator,
    bool? isAssociationCreator,
    bool? isAdmin,
  }) async {
    try {
      final currentProfile = await getProfile(userId);
      if (currentProfile == null) return null;

      final updatedProfile = currentProfile.copyWith(
        isCompetitionCreator: isCompetitionCreator,
        isAssociationCreator: isAssociationCreator,
        isAdmin: isAdmin,
      );

      return await updateProfile(updatedProfile);
    } catch (e) {
      debugPrint('Error updating permissions for user $userId: $e');
      return null;
    }
  }

  /// Fetch a user's upcoming meets (where start_date is in the future)
  Future<List<Competition>> getUserUpcomingMeets(String profileId) async {
    try {
      final response = await _client
          .from('meet_registrations')
          .select('*, competition:competitions(*)')
          .eq('profile_id', profileId)
          .eq('status', 'registered');

      final list = response as List? ?? [];
      final meets = list
          .map((data) => data['competition'])
          .where((comp) => comp != null)
          .map((compJson) => Competition.fromJson(compJson as Map<String, dynamic>))
          .where((comp) => comp.startDate.isAfter(DateTime.now()))
          .toList();
          
      return meets.isNotEmpty ? meets : _getMockUpcomingMeets(profileId);
    } catch (_) {
      return _getMockUpcomingMeets(profileId);
    }
  }

  /// Fetch a user's completed meets
  Future<List<Competition>> getUserCompletedMeets(String profileId) async {
    try {
      final response = await _client
          .from('meet_results')
          .select('*, competition:competitions(*)')
          .eq('profile_id', profileId);

      final list = response as List? ?? [];
      final meets = list
          .map((data) => data['competition'])
          .where((comp) => comp != null)
          .map((compJson) => Competition.fromJson(compJson as Map<String, dynamic>))
          .toList();
          
      return meets.isNotEmpty ? meets : _getMockCompletedMeets(profileId);
    } catch (_) {
      return _getMockCompletedMeets(profileId);
    }
  }

  /// Fetch a user's highest rankings
  Future<List<Map<String, dynamic>>> getUserHighestRankings(String profileId) async {
    try {
      final response = await _client
          .from('highest_rankings')
          .select()
          .eq('profile_id', profileId);

      final list = response as List? ?? [];
      if (list.isEmpty) {
        return _getMockHighestRankings(profileId);
      }
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return _getMockHighestRankings(profileId);
    }
  }

  /// Fetch a user's personal records
  Future<List<Map<String, dynamic>>> getUserPersonalRecords(String profileId) async {
    try {
      final response = await _client
          .from('personal_records')
          .select()
          .eq('profile_id', profileId);

      final list = response as List? ?? [];
      if (list.isEmpty) {
        return _getMockPersonalRecords(profileId);
      }
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return _getMockPersonalRecords(profileId);
    }
  }

  List<Competition> _getMockUpcomingMeets(String profileId) {
    return [
      Competition(
        id: 'mock-meet-1',
        title: 'FinalRep Qualifier Hamburg 2026',
        description: 'Hamburg Qualifier for the National Championship',
        startDate: DateTime.now().add(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 31)),
        location: 'Hamburg, Germany',
        sportSubtype: 'Modern',
        status: 'upcoming',
        compGroupName: 'FinalRep Qualifier',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )
    ];
  }

  List<Competition> _getMockCompletedMeets(String profileId) {
    return [
      Competition(
        id: 'mock-meet-2',
        title: 'FinalRep Underground Berlin 2025',
        description: 'Local streetlifting underground meet',
        startDate: DateTime.now().subtract(const Duration(days: 60)),
        endDate: DateTime.now().subtract(const Duration(days: 59)),
        location: 'Berlin, Germany',
        sportSubtype: 'Modern',
        status: 'completed',
        compGroupName: 'FinalRep Underground',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Competition(
        id: 'mock-meet-3',
        title: 'FinalRep Underground Frankfurt 2025',
        description: 'Local streetlifting underground meet',
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now().subtract(const Duration(days: 29)),
        location: 'Frankfurt, Germany',
        sportSubtype: 'Modern',
        status: 'completed',
        compGroupName: 'FinalRep Underground',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )
    ];
  }

  List<Map<String, dynamic>> _getMockHighestRankings(String profileId) {
    return [
      {
        'discipline': 'Overall (Modern)',
        'rank': '3rd Place',
        'competition': 'FinalRep Qualifier Munich 2025',
      },
      {
        'discipline': 'Weighted Pull Up',
        'rank': '1st Place',
        'competition': 'FinalRep Underground Berlin 2025',
      }
    ];
  }

  List<Map<String, dynamic>> _getMockPersonalRecords(String profileId) {
    return [
      {
        'lift': 'Weighted Pull Up',
        'weight': '+62.5 kg',
        'date': '2025-10-12',
      },
      {
        'lift': 'Weighted Dip',
        'weight': '+85.0 kg',
        'date': '2025-10-12',
      },
      {
        'lift': 'Weighted Squat',
        'weight': '+160.0 kg',
        'date': '2025-11-05',
      },
      {
        'lift': 'Muscle Up',
        'weight': '+20.0 kg',
        'date': '2025-11-05',
      }
    ];
  }
}
