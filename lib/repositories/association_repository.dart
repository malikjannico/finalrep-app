import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/association.dart';
import '../models/association_member.dart';
import '../models/competition_group.dart';
import '../models/athlete_group.dart';

class AssociationRepository {
  final SupabaseClient? _client;

  // Static mock cache to persist state across operations as fallback
  static final List<Association> _mockAssociations = [
    Association(
      id: 'assoc-1',
      name: 'Global Streetlifting Federation (GSF)',
      scope: 'global',
      description: 'The main global governing body for streetlifting.',
      rulebooks: {'Streetlifting': 'https://example.com/gsf-rules.pdf'},
      socialChannels: {'Instagram': 'gsf_lifting'},
      status: 'approved',
      ownerId: 'user-1',
      supportedSports: ['Streetlifting'],
      supportedFormats: ['Classic', 'Modern'],
    ),
    Association(
      id: 'assoc-2',
      name: 'European Streetlifting Association (ESA)',
      scope: 'area',
      areaName: 'Europe',
      description: 'Continental governing body for Europe.',
      rulebooks: {'Streetlifting': 'https://example.com/esa-rules.pdf'},
      socialChannels: {'Instagram': 'esa_lifting'},
      status: 'approved',
      ownerId: 'user-2',
      parentAssociationId: 'assoc-1',
      supportedSports: ['Streetlifting'],
      supportedFormats: ['Classic', 'Modern'],
    ),
  ];

  static final List<AssociationMember> _mockMembers = [
    AssociationMember(id: 'member-1', associationId: 'assoc-1', userId: 'user-1', role: 'owner', customTitle: 'Federation President'),
    AssociationMember(id: 'member-2', associationId: 'assoc-2', userId: 'user-2', role: 'owner', customTitle: 'ESA Chief'),
    AssociationMember(id: 'member-3', associationId: 'assoc-1', userId: 'user-2', role: 'editor', customTitle: 'Technical Advisor'),
  ];

  static final List<CompetitionGroup> _mockCompGroups = [
    CompetitionGroup(id: 'group-1', associationId: 'assoc-1', name: 'FinalRep Qualifier', sport: 'Streetlifting', format: 'Modern', isActive: true, isAthleteGroupsRequired: true),
    CompetitionGroup(id: 'group-3', associationId: 'assoc-1', name: 'FinalRep Final', sport: 'Streetlifting', format: 'Modern', isActive: true, isAthleteGroupsRequired: true),
    CompetitionGroup(id: 'group-4', associationId: 'assoc-1', name: 'FinalRep Underground', sport: 'Streetlifting', format: 'Modern', isActive: true, isAthleteGroupsRequired: false),
  ];

  static final List<AthleteGroup> _mockAthleteGroups = [
    AthleteGroup(id: 'ag-1', associationId: 'assoc-1', competitionGroupId: 'group-1', name: '-80kg Male', sport: 'Streetlifting', format: 'Modern', gender: 'Male', maxWeight: 80.0, isActive: true),
    AthleteGroup(id: 'ag-2', associationId: 'assoc-1', competitionGroupId: 'group-1', name: '+80kg Male', sport: 'Streetlifting', format: 'Modern', gender: 'Male', maxWeight: null, isActive: true),
  ];

  AssociationRepository(this._client);

  SupabaseClient? get client => _client;

  void _logError(String op, Object e, String table) {
    if (e is PostgrestException && e.code == 'PGRST205') {
      debugPrint('[Info] Supabase table "$table" not found. Using local mock fallback for "$op".');
    } else {
      debugPrint('Supabase $op error (using mock fallback): $e');
    }
  }

  /// Create a new association.
  Future<Association?> createAssociation(Association association) async {
    try {
      final response = await _client!.from('associations').insert(association.toJson()).select().single();
      final created = Association.fromJson(response);
      _syncAssociationToMock(created);
      return created;
    } catch (e) {
      _logError('createAssociation', e, 'associations');
      _mockAssociations.add(association);
      // Auto-assign owner as member
      final newMember = AssociationMember(
        id: 'member-${DateTime.now().millisecondsSinceEpoch}',
        associationId: association.id,
        userId: association.ownerId,
        role: 'owner',
      );
      _mockMembers.add(newMember);
      return association;
    }
  }

  /// Update association details.
  Future<Association?> updateAssociation(Association association) async {
    try {
      final response = await _client!
          .from('associations')
          .update(association.toJson())
          .eq('id', association.id)
          .select()
          .single();
      final updated = Association.fromJson(response);
      _syncAssociationToMock(updated);
      return updated;
    } catch (e) {
      _logError('updateAssociation', e, 'associations');
      final idx = _mockAssociations.indexWhere((element) => element.id == association.id);
      if (idx != -1) {
        _mockAssociations[idx] = association;
        return association;
      }
      return null;
    }
  }

  /// Fetch single association details.
  Future<Association?> getAssociationDetails(String id) async {
    try {
      final response = await _client!.from('associations').select().eq('id', id).maybeSingle();
      if (response == null) return null;
      final assoc = Association.fromJson(response);
      _syncAssociationToMock(assoc);
      return assoc;
    } catch (e) {
      _logError('getAssociationDetails', e, 'associations');
      return _mockAssociations.firstWhere((element) => element.id == id, orElse: () => null as Association);
    }
  }

  /// Fetch all associations.
  Future<List<Association>> getAssociations() async {
    try {
      final response = await _client!.from('associations').select();
      final list = (response as List).map((e) => Association.fromJson(e as Map<String, dynamic>)).toList();
      _mockAssociations.clear();
      _mockAssociations.addAll(list);
      return list;
    } catch (e) {
      _logError('getAssociations', e, 'associations');
      return List.from(_mockAssociations);
    }
  }

  /// Load member list for an association.
  Future<List<AssociationMember>> getAssociationMembers(String associationId) async {
    try {
      final response = await _client!.from('association_members').select().eq('association_id', associationId);
      final list = (response as List).map((e) => AssociationMember.fromJson(e as Map<String, dynamic>)).toList();
      _mockMembers.removeWhere((element) => element.associationId == associationId);
      _mockMembers.addAll(list);
      return list;
    } catch (e) {
      _logError('getAssociationMembers', e, 'association_members');
      return _mockMembers.where((element) => element.associationId == associationId).toList();
    }
  }

  /// Add member to association.
  Future<AssociationMember?> addAssociationMember(
    String associationId,
    String userId,
    String role, {
    String? customTitle,
  }) async {
    final member = AssociationMember(
      id: 'member-${DateTime.now().millisecondsSinceEpoch}',
      associationId: associationId,
      userId: userId,
      role: role,
      customTitle: customTitle,
    );

    try {
      final response = await _client!.from('association_members').insert(member.toJson()).select().single();
      final created = AssociationMember.fromJson(response);
      _syncMemberToMock(created);
      return created;
    } catch (e) {
      _logError('addAssociationMember', e, 'association_members');
      _mockMembers.add(member);
      return member;
    }
  }

  /// Remove member from association.
  Future<bool> removeAssociationMember(String associationId, String userId) async {
    try {
      await _client!.from('association_members').delete().eq('association_id', associationId).eq('user_id', userId);
      _mockMembers.removeWhere((element) => element.associationId == associationId && element.userId == userId);
      return true;
    } catch (e) {
      _logError('removeAssociationMember', e, 'association_members');
      _mockMembers.removeWhere((element) => element.associationId == associationId && element.userId == userId);
      return true;
    }
  }

  /// Transfer ownership of association.
  Future<Association?> transferAssociationOwnership(String associationId, String newOwnerId) async {
    try {
      final response = await _client!
          .from('associations')
          .update({'owner_id': newOwnerId})
          .eq('id', associationId)
          .select()
          .single();
      final updated = Association.fromJson(response);
      _syncAssociationToMock(updated);

      // Also update membership roles in database
      // Demote current owner to editor if necessary or change roles
      return updated;
    } catch (e) {
      _logError('transferAssociationOwnership', e, 'associations');
      final idx = _mockAssociations.indexWhere((element) => element.id == associationId);
      if (idx != -1) {
        final current = _mockAssociations[idx];
        final updated = current.copyWith(ownerId: newOwnerId);
        _mockAssociations[idx] = updated;

        // Update members role: find the member entry for newOwnerId, promote to owner.
        // Also demote the old owner to editor.
        final oldOwnerId = current.ownerId;
        for (var i = 0; i < _mockMembers.length; i++) {
          if (_mockMembers[i].associationId == associationId) {
            if (_mockMembers[i].userId == newOwnerId) {
              _mockMembers[i] = _mockMembers[i].copyWith(role: 'owner');
            } else if (_mockMembers[i].userId == oldOwnerId) {
              _mockMembers[i] = _mockMembers[i].copyWith(role: 'editor');
            }
          }
        }
        return updated;
      }
      return null;
    }
  }

  /// Load competition groups for an association.
  Future<List<CompetitionGroup>> getCompetitionGroups(String associationId) async {
    try {
      final response = await _client!.from('competition_groups').select().eq('association_id', associationId);
      final list = (response as List).map((e) => CompetitionGroup.fromJson(e as Map<String, dynamic>)).toList();
      _mockCompGroups.removeWhere((element) => element.associationId == associationId);
      _mockCompGroups.addAll(list);
      return list;
    } catch (e) {
      _logError('getCompetitionGroups', e, 'competition_groups');
      return _mockCompGroups.where((element) => element.associationId == associationId).toList();
    }
  }

  /// Create a competition group.
  Future<CompetitionGroup?> createCompetitionGroup(CompetitionGroup group) async {
    try {
      final response = await _client!.from('competition_groups').insert(group.toJson()).select().single();
      final created = CompetitionGroup.fromJson(response);
      _syncCompGroupToMock(created);
      return created;
    } catch (e) {
      _logError('createCompetitionGroup', e, 'competition_groups');
      _mockCompGroups.add(group);
      return group;
    }
  }

  /// Update a competition group.
  Future<CompetitionGroup?> updateCompetitionGroup(CompetitionGroup group) async {
    try {
      final response = await _client!
          .from('competition_groups')
          .update(group.toJson())
          .eq('id', group.id)
          .select()
          .single();
      final updated = CompetitionGroup.fromJson(response);
      _syncCompGroupToMock(updated);
      return updated;
    } catch (e) {
      _logError('updateCompetitionGroup', e, 'competition_groups');
      final idx = _mockCompGroups.indexWhere((element) => element.id == group.id);
      if (idx != -1) {
        _mockCompGroups[idx] = group;
        return group;
      }
      return null;
    }
  }

  /// Load athlete groups for an association.
  Future<List<AthleteGroup>> getAthleteGroups(String associationId) async {
    try {
      final response = await _client!.from('athlete_groups').select().eq('association_id', associationId);
      final list = (response as List).map((e) => AthleteGroup.fromJson(e as Map<String, dynamic>)).toList();
      _mockAthleteGroups.removeWhere((element) => element.associationId == associationId);
      _mockAthleteGroups.addAll(list);
      return list;
    } catch (e) {
      _logError('getAthleteGroups', e, 'athlete_groups');
      return _mockAthleteGroups.where((element) => element.associationId == associationId).toList();
    }
  }

  /// Create an athlete group.
  Future<AthleteGroup?> createAthleteGroup(AthleteGroup group) async {
    try {
      final response = await _client!.from('athlete_groups').insert(group.toJson()).select().single();
      final created = AthleteGroup.fromJson(response);
      _syncAthleteGroupToMock(created);
      return created;
    } catch (e) {
      _logError('createAthleteGroup', e, 'athlete_groups');
      _mockAthleteGroups.add(group);
      return group;
    }
  }

  /// Update an athlete group.
  Future<AthleteGroup?> updateAthleteGroup(AthleteGroup group) async {
    try {
      final response = await _client!
          .from('athlete_groups')
          .update(group.toJson())
          .eq('id', group.id)
          .select()
          .single();
      final updated = AthleteGroup.fromJson(response);
      _syncAthleteGroupToMock(updated);
      return updated;
    } catch (e) {
      _logError('updateAthleteGroup', e, 'athlete_groups');
      final idx = _mockAthleteGroups.indexWhere((element) => element.id == group.id);
      if (idx != -1) {
        _mockAthleteGroups[idx] = group;
        return group;
      }
      return null;
    }
  }

  void _syncAssociationToMock(Association assoc) {
    final idx = _mockAssociations.indexWhere((element) => element.id == assoc.id);
    if (idx != -1) {
      _mockAssociations[idx] = assoc;
    } else {
      _mockAssociations.add(assoc);
    }
  }

  void _syncMemberToMock(AssociationMember member) {
    final idx = _mockMembers.indexWhere((element) => element.id == member.id);
    if (idx != -1) {
      _mockMembers[idx] = member;
    } else {
      _mockMembers.add(member);
    }
  }

  void _syncCompGroupToMock(CompetitionGroup group) {
    final idx = _mockCompGroups.indexWhere((element) => element.id == group.id);
    if (idx != -1) {
      _mockCompGroups[idx] = group;
    } else {
      _mockCompGroups.add(group);
    }
  }

  void _syncAthleteGroupToMock(AthleteGroup group) {
    final idx = _mockAthleteGroups.indexWhere((element) => element.id == group.id);
    if (idx != -1) {
      _mockAthleteGroups[idx] = group;
    } else {
      _mockAthleteGroups.add(group);
    }
  }
}
