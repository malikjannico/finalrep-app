import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  /// Fetch a user profile by their unique auth/profile ID.
  Future<Profile?> getProfile(String id) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting profile by ID ($id): $e');
      return null;
    }
  }

  /// Fetch a user profile by their unique username.
  Future<Profile?> getProfileByUsername(String username) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting profile by username ($username): $e');
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

      return Profile.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error updating profile (${profile.id}): $e');
      rethrow;
    }
  }
}
