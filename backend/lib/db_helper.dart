import 'dart:convert';
import 'dart:math';
import 'package:postgres/postgres.dart';
import 'db_connection.dart';

class DbHelper {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String? id) {
    if (id == null) return false;
    return _uuidRegex.hasMatch(id);
  }

  /// Clean a row map from Postgres by converting DateTime to ISO-8601 strings.
  static Map<String, dynamic> cleanRowMap(Map<String, dynamic> map) {
    final clean = <String, dynamic>{};
    for (final entry in map.entries) {
      var val = entry.value;
      if (val is DateTime) {
        val = val.toUtc().toIso8601String();
      }
      clean[entry.key] = val;
    }
    return clean;
  }

  // === Competitions CRUD ===

  static Future<List<Map<String, dynamic>>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status,
  }) async {
    final conn = await DbConnection.connection;
    var sql = 'SELECT * FROM public.competitions WHERE 1=1';
    final params = <String, dynamic>{};

    if (status != null && status.isNotEmpty) {
      sql += ' AND status = @status';
      params['status'] = status;
    }

    if (sportSubtype != null && sportSubtype.isNotEmpty && sportSubtype != 'All') {
      sql += ' AND sport_subtype = @sportSubtype';
      params['sportSubtype'] = sportSubtype;
    }

    if (compGroupName != null && compGroupName.isNotEmpty && compGroupName != 'All') {
      if (compGroupName == 'Individual') {
        sql += ' AND comp_group_name IS NULL';
      } else {
        sql += ' AND comp_group_name = @compGroupName';
        params['compGroupName'] = compGroupName;
      }
    }

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (title ILIKE @query OR location ILIKE @query)';
      params['query'] = '%${query.trim()}%';
    }

    sql += ' ORDER BY start_date ASC';

    final result = await conn.execute(Sql.named(sql), parameters: params);
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>?> getCompetitionById(String id) async {
    if (!isValidUuid(id)) return null;
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.competitions WHERE id = @id LIMIT 1'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> createCompetition(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = <String>[];
    final valuePlaceholders = <String>[];
    final params = <String, dynamic>{};

    for (final entry in json.entries) {
      columns.add(entry.key);
      valuePlaceholders.add('@${entry.key}');
      
      var val = entry.value;
      if (val is String && (entry.key.endsWith('_date') || entry.key.endsWith('_start') || entry.key.endsWith('_end') || entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.competitions (${columns.join(', ')}) VALUES (${valuePlaceholders.join(', ')}) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> updateCompetition(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final id = json['id'] as String;
    final updates = json.keys.where((k) => k != 'id').map((k) => '$k = @$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key.endsWith('_date') || entry.key.endsWith('_start') || entry.key.endsWith('_end') || entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'UPDATE public.competitions SET $updates WHERE id = @id RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  // === Profiles CRUD ===

  static Future<Map<String, dynamic>?> getProfileById(String id) async {
    if (!isValidUuid(id)) return null;
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.profiles WHERE id = @id LIMIT 1'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>?> getProfileByUsername(String username) async {
    final conn = await DbConnection.connection;
    final clean = username.trim().toLowerCase();
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.profiles WHERE LOWER(username) = @username LIMIT 1'),
      parameters: {'username': clean},
    );
    if (result.isEmpty) return null;
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>?> getProfileByEmail(String email) async {
    final conn = await DbConnection.connection;
    final clean = email.trim().toLowerCase();
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.profiles WHERE LOWER(email) = @email LIMIT 1'),
      parameters: {'email': clean},
    );
    if (result.isEmpty) return null;
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> createOrUpdateProfile(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final id = json['id'] as String;
    
    // Check if profile exists
    final check = await conn.execute(
      Sql.named('SELECT 1 FROM public.profiles WHERE id = @id LIMIT 1'),
      parameters: {'id': id},
    );

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    if (check.isEmpty) {
      // INSERT
      final columns = json.keys.join(', ');
      final placeholders = json.keys.map((k) => '@$k').join(', ');
      final sql = 'INSERT INTO public.profiles ($columns) VALUES ($placeholders) RETURNING *';
      final result = await conn.execute(Sql.named(sql), parameters: params);
      return cleanRowMap(result.first.toColumnMap());
    } else {
      // UPDATE
      final updates = json.keys.where((k) => k != 'id').map((k) => '$k = @$k').join(', ');
      final sql = 'UPDATE public.profiles SET $updates WHERE id = @id RETURNING *';
      final result = await conn.execute(Sql.named(sql), parameters: params);
      return cleanRowMap(result.first.toColumnMap());
    }
  }

  static Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final conn = await DbConnection.connection;
    final clean = '%${query.trim().toLowerCase()}%';
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.profiles WHERE username ILIKE @query OR full_name ILIKE @query ORDER BY username ASC'),
      parameters: {'query': clean},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  // === Associations CRUD ===

  static Future<List<Map<String, dynamic>>> getAssociations() async {
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.associations ORDER BY name ASC'),
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>> createAssociation(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');
    
    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.associations ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<List<Map<String, dynamic>>> getAssociationMembers(String associationId) async {
    if (associationId.isEmpty) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.association_members WHERE association_id = @id'),
      parameters: {'id': associationId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>> addAssociationMember(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.association_members ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>?> getAssociationById(String id) async {
    if (id.isEmpty) return null;
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.associations WHERE id = @id LIMIT 1'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> updateAssociation(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final id = json['id'] as String;
    final updates = json.keys.where((k) => k != 'id').map((k) => '$k = @$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'UPDATE public.associations SET $updates WHERE id = @id RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<bool> removeAssociationMember(String associationId, String userId, {String? role}) async {
    if (associationId.isEmpty || !isValidUuid(userId)) return false;
    final conn = await DbConnection.connection;
    final sql = role != null 
        ? 'DELETE FROM public.association_members WHERE association_id = @associationId AND user_id = @userId AND role = @role'
        : 'DELETE FROM public.association_members WHERE association_id = @associationId AND user_id = @userId';
    final params = {
      'associationId': associationId,
      'userId': userId,
      if (role != null) 'role': role,
    };
    final result = await conn.execute(
      Sql.named(sql),
      parameters: params,
    );
    return result.affectedRows > 0;
  }

  static Future<Map<String, dynamic>?> transferAssociationOwnership(String associationId, String newOwnerId, {String? customTitle}) async {
    if (associationId.isEmpty || !isValidUuid(newOwnerId)) return null;
    final conn = await DbConnection.connection;
    
    // 1. Get current owner_id
    final assocResult = await conn.execute(
      Sql.named('SELECT owner_id FROM public.associations WHERE id = @id LIMIT 1'),
      parameters: {'id': associationId},
    );
    if (assocResult.isEmpty) return null;
    final oldOwnerId = assocResult.first.toColumnMap()['owner_id'] as String;

    // 2. Update owner_id on associations table
    final updateAssocResult = await conn.execute(
      Sql.named('UPDATE public.associations SET owner_id = @newOwnerId WHERE id = @associationId RETURNING *'),
      parameters: {'associationId': associationId, 'newOwnerId': newOwnerId},
    );
    if (updateAssocResult.isEmpty) return null;

    // 3. Delete only 'owner' role membership row for the old owner
    await conn.execute(
      Sql.named("DELETE FROM public.association_members WHERE association_id = @associationId AND user_id = @userId AND role = 'owner'"),
      parameters: {'associationId': associationId, 'userId': oldOwnerId},
    );

    // 4. Ensure new owner has a membership row with role 'owner'
    final checkNewOwnerOwnerRole = await conn.execute(
      Sql.named("SELECT 1 FROM public.association_members WHERE association_id = @associationId AND user_id = @userId AND role = 'owner' LIMIT 1"),
      parameters: {'associationId': associationId, 'userId': newOwnerId},
    );
    
    if (checkNewOwnerOwnerRole.isEmpty) {
      final memberId = 'member-$associationId-$newOwnerId-owner';
      await conn.execute(
        Sql.named("INSERT INTO public.association_members (id, association_id, user_id, role, custom_title) VALUES (@id, @associationId, @userId, 'owner', @customTitle)"),
        parameters: {
          'id': memberId,
          'associationId': associationId,
          'userId': newOwnerId,
          'customTitle': customTitle,
        },
      );
    } else {
      await conn.execute(
        Sql.named("UPDATE public.association_members SET custom_title = @customTitle WHERE association_id = @associationId AND user_id = @userId AND role = 'owner'"),
        parameters: {
          'associationId': associationId,
          'userId': newOwnerId,
          'customTitle': customTitle,
        },
      );
    }

    return cleanRowMap(updateAssocResult.first.toColumnMap());
  }

  static Future<bool> deleteAssociation(String id) async {
    if (id.isEmpty) return false;
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('DELETE FROM public.associations WHERE id = @id'),
      parameters: {'id': id},
    );
    return result.affectedRows > 0;
  }

  // === Competition Groups CRUD ===

  static Future<List<Map<String, dynamic>>> getCompetitionGroups(String associationId) async {
    if (associationId.isEmpty) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.competition_groups WHERE association_id = @id'),
      parameters: {'id': associationId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>> createCompetitionGroup(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.competition_groups ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> updateCompetitionGroup(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final id = json['id'] as String;
    final updates = json.keys.where((k) => k != 'id').map((k) => '$k = @$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'UPDATE public.competition_groups SET $updates WHERE id = @id RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  // === Athlete Groups CRUD ===

  static Future<List<Map<String, dynamic>>> getAthleteGroups(String associationId) async {
    if (associationId.isEmpty) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.athlete_groups WHERE association_id = @id'),
      parameters: {'id': associationId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>> createAthleteGroup(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.athlete_groups ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> updateAthleteGroup(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final id = json['id'] as String;
    final updates = json.keys.where((k) => k != 'id').map((k) => '$k = @$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'UPDATE public.athlete_groups SET $updates WHERE id = @id RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  // === Competitions Sub-Collections (Attempts, Flights, Schedule) ===

  static Future<List<Map<String, dynamic>>> getAttempts(String competitionId) async {
    if (!isValidUuid(competitionId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.attempts WHERE competition_id = @id ORDER BY flight_id ASC, round_number ASC'),
      parameters: {'id': competitionId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>> createAttempt(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.attempts ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> updateAttempt(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final id = json['id'] as String;
    final updates = json.keys.where((k) => k != 'id').map((k) => '$k = @$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'UPDATE public.attempts SET $updates WHERE id = @id RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<List<Map<String, dynamic>>> getFlights(String competitionId) async {
    if (!isValidUuid(competitionId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.flights WHERE competition_id = @id ORDER BY name ASC'),
      parameters: {'id': competitionId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>> createFlight(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.flights ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> updateFlight(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final id = json['id'] as String;
    final updates = json.keys.where((k) => k != 'id').map((k) => '$k = @$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'UPDATE public.flights SET $updates WHERE id = @id RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<List<Map<String, dynamic>>> getScheduleItems(String competitionId) async {
    if (!isValidUuid(competitionId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.schedule_items WHERE competition_id = @id ORDER BY start_time ASC'),
      parameters: {'id': competitionId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>> createScheduleItem(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'start_time' || entry.key == 'end_time' || entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.schedule_items ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> updateScheduleItem(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final id = json['id'] as String;
    final updates = json.keys.where((k) => k != 'id').map((k) => '$k = @$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'start_time' || entry.key == 'end_time' || entry.key == 'created_at' || entry.key == 'updated_at')) {
        val = DateTime.parse(val);
      } else if (val is Map || val is List) {
        val = jsonEncode(val);
      }
      params[entry.key] = val;
    }

    final sql = 'UPDATE public.schedule_items SET $updates WHERE id = @id RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  // === Registrations & Results ===

  static Future<List<Map<String, dynamic>>> getCompetitionAthletes(String competitionId) async {
    if (!isValidUuid(competitionId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT p.* FROM public.profiles p JOIN public.athlete_registrations r ON p.id = r.profile_id WHERE r.competition_id = @id AND r.status = \'registered\''),
      parameters: {'id': competitionId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<bool> registerAthlete(String competitionId, String userId, {String status = 'registered'}) async {
    if (!isValidUuid(competitionId) || !isValidUuid(userId)) return false;
    final conn = await DbConnection.connection;
    final id = 'reg-$competitionId-$userId-${DateTime.now().millisecondsSinceEpoch}';
    final result = await conn.execute(
      Sql.named('INSERT INTO public.athlete_registrations (id, competition_id, profile_id, status, created_at) VALUES (@id, @competitionId, @userId, @status, @now)'),
      parameters: {
        'id': id,
        'competitionId': competitionId,
        'userId': userId,
        'status': status,
        'now': DateTime.now().toUtc()
      },
    );
    return result.affectedRows > 0;
  }

  static Future<List<String>> getRegisteredAthleteIds(String competitionId) async {
    if (!isValidUuid(competitionId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT profile_id FROM public.athlete_registrations WHERE competition_id = @id AND status = \'registered\''),
      parameters: {'id': competitionId},
    );
    return result.map((row) => row.first as String).toList();
  }

  static Future<List<Map<String, dynamic>>> getUserUpcomingMeets(String userId) async {
    if (!isValidUuid(userId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT c.* FROM public.competitions c JOIN public.athlete_registrations r ON c.id = r.competition_id WHERE r.profile_id = @id AND c.status = \'upcoming\''),
      parameters: {'id': userId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<List<Map<String, dynamic>>> getUserCompletedMeets(String userId) async {
    if (!isValidUuid(userId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT c.* FROM public.competitions c JOIN public.athlete_registrations r ON c.id = r.competition_id WHERE r.profile_id = @id AND c.status = \'completed\''),
      parameters: {'id': userId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<List<Map<String, dynamic>>> getUserHighestRankings(String userId) async {
    if (!isValidUuid(userId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.highest_rankings WHERE profile_id = @id'),
      parameters: {'id': userId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<List<Map<String, dynamic>>> getUserPersonalRecords(String userId) async {
    if (!isValidUuid(userId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.personal_records WHERE profile_id = @id'),
      parameters: {'id': userId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  // === Notifications CRUD ===

  static Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    if (!isValidUuid(userId)) return [];
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.notifications WHERE user_id = @id ORDER BY created_at DESC'),
      parameters: {'id': userId},
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>> createNotification(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at')) {
        val = DateTime.parse(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.notifications ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>> markNotificationRead(String id) async {
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('UPDATE public.notifications SET is_read = true WHERE id = @id RETURNING *'),
      parameters: {'id': id},
    );
    return cleanRowMap(result.first.toColumnMap());
  }

  // === Admin CRUD ===

  static Future<Map<String, dynamic>> applyForPermissions(Map<String, dynamic> json) async {
    final conn = await DbConnection.connection;
    final columns = json.keys.join(', ');
    final placeholders = json.keys.map((k) => '@$k').join(', ');

    final params = <String, dynamic>{};
    for (final entry in json.entries) {
      var val = entry.value;
      if (val is String && (entry.key == 'created_at')) {
        val = DateTime.parse(val);
      }
      params[entry.key] = val;
    }

    final sql = 'INSERT INTO public.permission_applications ($columns) VALUES ($placeholders) RETURNING *';
    final result = await conn.execute(Sql.named(sql), parameters: params);
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<List<Map<String, dynamic>>> getPermissionApplications() async {
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.permission_applications ORDER BY created_at DESC'),
    );
    return result.map((row) => cleanRowMap(row.toColumnMap())).toList();
  }

  static Future<Map<String, dynamic>?> approvePermissionApplication(String id) async {
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('UPDATE public.permission_applications SET status = \'approved\' WHERE id = @id RETURNING *'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>?> rejectPermissionApplication(String id) async {
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('UPDATE public.permission_applications SET status = \'rejected\' WHERE id = @id RETURNING *'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<Map<String, dynamic>?> loadSportsConfig() async {
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM public.sport_configs WHERE id = \'global_config\' LIMIT 1'),
    );
    if (result.isEmpty) return null;
    return cleanRowMap(result.first.toColumnMap());
  }

  static Future<bool> saveSportsConfig(Map<String, dynamic> config) async {
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('INSERT INTO public.sport_configs (id, config, updated_at) VALUES (\'global_config\', @config, @now) ON CONFLICT (id) DO UPDATE SET config = EXCLUDED.config, updated_at = EXCLUDED.updated_at'),
      parameters: {
        'config': jsonEncode(config),
        'now': DateTime.now().toUtc(),
      },
    );
    return result.affectedRows > 0;
  }

  // === Meet Results & Rankings ===

  static Future<List<Map<String, dynamic>>> getMeetResults() async {
    final conn = await DbConnection.connection;
    final result = await conn.execute(
      Sql.named('''
        SELECT mr.id AS mr_id, mr.profile_id AS mr_profile_id, mr.competition_id AS mr_competition_id,
               mr.competition_class AS mr_competition_class, mr.total_score AS mr_total_score,
               mr.rank AS mr_rank, mr.best_lifts AS mr_best_lifts, mr.created_at AS mr_created_at,
               p.id AS p_id, p.username AS p_username, p.full_name AS p_full_name, p.email AS p_email,
               p.sex AS p_sex, p.country AS p_country, p.profile_picture_url AS p_profile_picture_url,
               p.description AS p_description, p.color_mode AS p_color_mode,
               p.created_at AS p_created_at, p.updated_at AS p_updated_at, p.social_links AS p_social_links
        FROM public.competition_results mr
        LEFT JOIN public.profiles p ON mr.profile_id = p.id
      '''),
    );

    final list = <Map<String, dynamic>>[];
    for (final row in result) {
      final colMap = row.toColumnMap();

      final cleanMr = <String, dynamic>{
        'id': colMap['mr_id'],
        'profile_id': colMap['mr_profile_id'],
        'competition_id': colMap['mr_competition_id'],
        'competition_class': colMap['mr_competition_class'],
        'total_score': colMap['mr_total_score'] is num ? (colMap['mr_total_score'] as num).toDouble() : colMap['mr_total_score'],
        'rank': colMap['mr_rank'],
        'best_lifts': colMap['mr_best_lifts'],
        'created_at': colMap['mr_created_at'] != null ? (colMap['mr_created_at'] as DateTime).toUtc().toIso8601String() : null,
      };

      cleanMr['profile'] = {
        'id': colMap['p_id'],
        'username': colMap['p_username'],
        'full_name': colMap['p_full_name'],
        'email': colMap['p_email'],
        'sex': colMap['p_sex'],
        'country': colMap['p_country'],
        'profile_picture_url': colMap['p_profile_picture_url'],
        'description': colMap['p_description'],
        'color_mode': colMap['p_color_mode'],
        'created_at': colMap['p_created_at'] != null ? (colMap['p_created_at'] as DateTime).toUtc().toIso8601String() : null,
        'updated_at': colMap['p_updated_at'] != null ? (colMap['p_updated_at'] as DateTime).toUtc().toIso8601String() : null,
        'social_links': colMap['p_social_links'],
      };

      list.add(cleanMr);
    }
    return list;
  }

  static Future<bool> runRandomDraw(String competitionId) async {
    if (!isValidUuid(competitionId)) return false;
    final conn = await DbConnection.connection;
    
    // 1. Get competition details
    final comp = await getCompetitionById(competitionId);
    if (comp == null) return false;
    
    final regMode = comp['registration_mode'] as String? ?? 'fcfs';
    if (regMode != 'random') return false;
    
    // 2. Fetch all current registrations with profile sex
    final result = await conn.execute(
      Sql.named('SELECT r.id as registration_id, r.profile_id, p.sex FROM public.athlete_registrations r JOIN public.profiles p ON r.profile_id = p.id WHERE r.competition_id = @id'),
      parameters: {'id': competitionId},
    );
    
    final registrations = result.map((row) => row.toColumnMap()).toList();
    if (registrations.isEmpty) return true;
    
    final maxAthletes = comp['max_athletes'] as int?;
    final enableWaitlist = comp['enable_waitlist'] as bool? ?? false;
    
    // Decode max_athletes_per_group
    List<dynamic> groupLimits = [];
    if (comp['max_athletes_per_group'] != null) {
      if (comp['max_athletes_per_group'] is String) {
        groupLimits = jsonDecode(comp['max_athletes_per_group'] as String) as List<dynamic>;
      } else {
        groupLimits = comp['max_athletes_per_group'] as List<dynamic>;
      }
    }
    
    // Track assigned registrations (registration_id -> status)
    final assignedStatus = <String, String>{};
    final random = Random();
    
    if (groupLimits.isNotEmpty) {
      for (final group in groupLimits) {
        final groupGender = (group['gender'] as String? ?? 'open').toLowerCase();
        final groupLimit = group['limit'] as int?;
        
        final candidates = registrations.where((reg) {
          final regId = reg['registration_id'] as String;
          if (assignedStatus[regId] == 'registered') return false;
          
          final userSex = (reg['sex'] as String? ?? '').toLowerCase();
          
          if (groupGender == 'open' || groupGender == 'mixed') return true;
          if ((groupGender == 'men' || groupGender == 'male') && (userSex == 'male' || userSex == 'other')) return true;
          if ((groupGender == 'women' || groupGender == 'female' || groupGender == 'woman') && (userSex == 'female' || userSex == 'other')) return true;
          
          return false;
        }).toList();
        
        candidates.shuffle(random);
        
        if (groupLimit != null) {
          final limit = groupLimit < candidates.length ? groupLimit : candidates.length;
          for (int i = 0; i < limit; i++) {
            final regId = candidates[i]['registration_id'] as String;
            assignedStatus[regId] = 'registered';
          }
          
          for (int i = limit; i < candidates.length; i++) {
            final regId = candidates[i]['registration_id'] as String;
            if (assignedStatus[regId] != 'registered') {
              if (enableWaitlist) {
                assignedStatus[regId] = 'waitlisted';
              } else {
                assignedStatus[regId] = 'pending';
              }
            }
          }
        } else {
          for (final cand in candidates) {
            final regId = cand['registration_id'] as String;
            assignedStatus[regId] = 'registered';
          }
        }
      }
    } else {
      final candidates = List<Map<String, dynamic>>.from(registrations);
      candidates.shuffle(random);
      
      if (maxAthletes != null) {
        final limit = maxAthletes < candidates.length ? maxAthletes : candidates.length;
        for (int i = 0; i < limit; i++) {
          final regId = candidates[i]['registration_id'] as String;
          assignedStatus[regId] = 'registered';
        }
        for (int i = limit; i < candidates.length; i++) {
          final regId = candidates[i]['registration_id'] as String;
          if (enableWaitlist) {
            assignedStatus[regId] = 'waitlisted';
          } else {
            assignedStatus[regId] = 'pending';
          }
        }
      } else {
        for (final cand in candidates) {
          final regId = cand['registration_id'] as String;
          assignedStatus[regId] = 'registered';
        }
      }
    }
    
    for (final reg in registrations) {
      final regId = reg['registration_id'] as String;
      if (!assignedStatus.containsKey(regId)) {
        if (enableWaitlist) {
          assignedStatus[regId] = 'waitlisted';
        } else {
          assignedStatus[regId] = 'pending';
        }
      }
    }
    
    bool allSuccess = true;
    for (final entry in assignedStatus.entries) {
      final regId = entry.key;
      final status = entry.value;
      final updateResult = await conn.execute(
        Sql.named('UPDATE public.athlete_registrations SET status = @status WHERE id = @id'),
        parameters: {'id': regId, 'status': status},
      );
      if (updateResult.affectedRows == 0) {
        allSuccess = false;
      }
    }
    
    return allSuccess;
  }
}

