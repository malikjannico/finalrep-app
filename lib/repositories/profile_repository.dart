import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/profile.dart';
import '../models/competition.dart';
import '../utils/mock_safety.dart';
import '../utils/api_client.dart';


class ProfileRepository {
  final dynamic _client;
  final ApiClient _api;

  ProfileRepository(dynamic client, {ApiClient? api})
      : _client = client,
        _api = api ?? ApiClient();

  dynamic get client => _client;

  bool get _useMockFallback => MockSafety.isMockAllowed;

  /// Fetch a user profile by their unique auth/profile ID.
  Future<Profile?> getProfile(String id) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('profiles').select().eq('id', id).maybeSingle();
        if (response == null) return null;
        return Profile.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }
    try {
      final response = await _api.get('/profiles/$id');
      if (response.statusCode == 200) {
        return Profile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      if (response.statusCode == 404) return null;
      throw Exception('Failed to load profile: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return null;
      }
      rethrow;
    }
  }

  /// Fetch a user profile by their unique username.
  Future<Profile?> getProfileByUsername(String username) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('profiles').select().eq('username', username.trim().toLowerCase()).maybeSingle();
        if (response == null) return null;
        return Profile.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }
    try {
      final cleanUsername = username.trim().toLowerCase();
      final response = await _api.get('/profiles', queryParameters: {'username': cleanUsername});
      if (response.statusCode == 200) {
        return Profile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      if (response.statusCode == 404) return null;
      throw Exception('Failed to load profile: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return null;
      }
      rethrow;
    }
  }

  /// Fetch a user profile by their email.
  Future<Profile?> getProfileByEmail(String email) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('profiles').select().eq('email', email.trim().toLowerCase()).maybeSingle();
        if (response == null) return null;
        return Profile.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }
    try {
      final response = await _api.get('/profiles', queryParameters: {'email': email.trim().toLowerCase()});
      if (response.statusCode == 200) {
        return Profile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      if (response.statusCode == 404) return null;
      throw Exception('Failed to load profile: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return null;
      }
      rethrow;
    }
  }

  /// Search user profiles by username or full name.
  Future<List<Profile>> searchProfiles(String query) async {
    if (_useMockFallback && _client != null) {
      try {
        if (query.trim().isEmpty) {
          final response = await _client.from('profiles').select().limit(20);
          return (response as List).map((data) => Profile.fromJson(data as Map<String, dynamic>)).toList();
        }
        final response = await _client.from('profiles').select().or('username.ilike.%${query}%,full_name.ilike.%${query}%');
        return (response as List).map((data) => Profile.fromJson(data as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }
    try {
      final cleanQuery = query.trim();
      final response = await _api.get('/profiles', queryParameters: {'search': cleanQuery});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((data) => Profile.fromJson(data as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to search profiles: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return [];
      }
      rethrow;
    }
  }

  /// Update a profile's details in the database.
  Future<Profile?> updateProfile(Profile profile) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('profiles').update(profile.toJson()).eq('id', profile.id).select().single();
        return Profile.fromJson(response as Map<String, dynamic>);
      } catch (_) {
        return profile;
      }
    }
    try {
      final response = await _api.post('/profiles', body: profile.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Profile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to update profile: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return profile;
      }
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
    if (_useMockFallback && _client != null) {
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
    try {
      final response = await _api.get('/profiles', queryParameters: {'userId': profileId, 'type': 'upcoming'});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((compJson) => Competition.fromJson(compJson as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to load upcoming meets: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return _getMockUpcomingMeets(profileId);
      }
      rethrow;
    }
  }

  /// Fetch a user's completed meets
  Future<List<Competition>> getUserCompletedMeets(String profileId) async {
    if (_useMockFallback && _client != null) {
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
    try {
      final response = await _api.get('/profiles', queryParameters: {'userId': profileId, 'type': 'completed'});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((compJson) => Competition.fromJson(compJson as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to load completed meets: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return _getMockCompletedMeets(profileId);
      }
      rethrow;
    }
  }

  /// Fetch a user's highest rankings
  Future<List<Map<String, dynamic>>> getUserHighestRankings(
    String profileId,
  ) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('highest_rankings').select().eq('profile_id', profileId);
        final list = response as List? ?? [];
        if (list.isEmpty) {
          return _getMockHighestRankings(profileId);
        }

        final compsRes = await _client.from('competitions').select();
        final completedTitles = (compsRes as List)
            .where((c) => c['status'] == 'completed')
            .map((c) => c['title']?.toString())
            .whereType<String>()
            .toSet();

        final filtered = list.where((r) {
          final title = r['competition']?.toString();
          if (title == null || title.isEmpty) return true;
          return completedTitles.contains(title);
        }).toList();

        return filtered.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        return _getMockHighestRankings(profileId);
      }
    }
    try {
      final response = await _api.get('/profiles', queryParameters: {'userId': profileId, 'type': 'rankings'});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List? ?? [];
        final rankings = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final titles = rankings
            .map((r) => r['competition']?.toString())
            .where((t) => t != null && t.isNotEmpty)
            .cast<String>()
            .toList();

        if (titles.isNotEmpty) {
          try {
            final compsRes = await _api.get('/competitions', queryParameters: {'status': 'completed'});
            if (compsRes.statusCode == 200) {
              final compsList = jsonDecode(compsRes.body) as List? ?? [];
              final completedTitles = compsList
                  .map((c) => (c as Map)['title']?.toString())
                  .whereType<String>()
                  .toSet();

              return rankings.where((r) {
                final title = r['competition']?.toString();
                if (title == null || title.isEmpty) return true;
                return completedTitles.contains(title);
              }).toList();
            }
          } catch (e) {
            debugPrint('Error filtering rankings: $e');
          }
        }
        return rankings;
      }
      throw Exception('Failed to load rankings: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error getting highest rankings for profile $profileId: $e');
      if (_useMockFallback) {
        return _getMockHighestRankings(profileId);
      }
      rethrow;
    }
  }

  /// Fetch a user's personal records
  Future<List<Map<String, dynamic>>> getUserPersonalRecords(
    String profileId,
  ) async {
    if (_useMockFallback && _client != null) {
      try {
        final response = await _client.from('personal_records').select().eq('profile_id', profileId);
        final list = response as List? ?? [];
        if (list.isEmpty) {
          return _getMockPersonalRecords(profileId);
        }
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        return _getMockPersonalRecords(profileId);
      }
    }
    try {
      final response = await _api.get('/profiles', queryParameters: {'userId': profileId, 'type': 'records'});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      throw Exception('Failed to load records: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return _getMockPersonalRecords(profileId);
      }
      rethrow;
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
      ),
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
      ),
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
      },
    ];
  }

  List<Map<String, dynamic>> _getMockPersonalRecords(String profileId) {
    return [
      {
        'lift': 'Weighted Pull Up',
        'weight': '+62.5 kg',
        'date': '2025-10-12',
        'competition': 'FinalRep Underground Berlin 2025',
      },
      {
        'lift': 'Weighted Dip',
        'weight': '+85.0 kg',
        'date': '2025-10-12',
        'competition': 'FinalRep Underground Berlin 2025',
      },
      {
        'lift': 'Weighted Squat',
        'weight': '+160.0 kg',
        'date': '2025-11-05',
        'competition': 'FinalRep Underground Frankfurt 2025',
      },
      {
        'lift': 'Muscle Up',
        'weight': '+20.0 kg',

        'date': '2025-11-05',
        'competition': 'FinalRep Underground Frankfurt 2025',
      },
    ];
  }

  Future<String?> uploadFile(List<int> bytes, String fileName) async {
    if (_useMockFallback && _client != null) {
      try {
        final path = 'profiles/uploads/$fileName';
        await _client.storage.from('images').uploadBinary(path, Uint8List.fromList(bytes));
        final url = _client.storage.from('images').getPublicUrl(path);
        return url;
      } catch (_) {
        return '/uploads/$fileName';
      }
    }
    try {
      final streamedResponse = await _api.uploadMultipart('/upload', bytes, fileName);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['url'] as String?;
      }
      throw Exception('Failed to upload file: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (_useMockFallback) {
        return '/uploads/$fileName';
      }
      rethrow;
    }
  }
}

