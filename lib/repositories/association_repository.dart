import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/association.dart';
import '../models/association_member.dart';
import '../models/competition_group.dart';
import '../models/athlete_group.dart';
import '../utils/mock_safety.dart';
import '../utils/api_client.dart';

class AssociationRepository {
  final ApiClient _api;

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
    AssociationMember(
      id: 'member-1',
      associationId: 'assoc-1',
      userId: 'user-1',
      role: 'owner',
      customTitle: 'Federation President',
    ),
    AssociationMember(
      id: 'member-2',
      associationId: 'assoc-2',
      userId: 'user-2',
      role: 'owner',
      customTitle: 'ESA Chief',
    ),
    AssociationMember(
      id: 'member-3',
      associationId: 'assoc-1',
      userId: 'user-2',
      role: 'editor',
      customTitle: 'Technical Advisor',
    ),
  ];

  static final List<CompetitionGroup> _mockCompGroups = [
    CompetitionGroup(
      id: 'group-1',
      associationId: 'assoc-1',
      name: 'FinalRep Qualifier',
      sport: 'Streetlifting',
      format: 'Modern',
      isActive: true,
      isAthleteGroupsRequired: true,
    ),
    CompetitionGroup(
      id: 'group-3',
      associationId: 'assoc-1',
      name: 'FinalRep Final',
      sport: 'Streetlifting',
      format: 'Modern',
      isActive: true,
      isAthleteGroupsRequired: true,
    ),
    CompetitionGroup(
      id: 'group-4',
      associationId: 'assoc-1',
      name: 'FinalRep Underground',
      sport: 'Streetlifting',
      format: 'Modern',
      isActive: true,
      isAthleteGroupsRequired: false,
    ),
  ];

  static final List<AthleteGroup> _mockAthleteGroups = [
    AthleteGroup(
      id: 'ag-1',
      associationId: 'assoc-1',
      name: '-80kg Male',
      sport: 'Streetlifting',
      format: 'Modern',
      gender: 'men',
      isActive: true,
      sortOrder: 0,
    ),
    AthleteGroup(
      id: 'ag-2',
      associationId: 'assoc-1',
      name: '+80kg Male',
      sport: 'Streetlifting',
      format: 'Modern',
      gender: 'men',
      isActive: true,
      sortOrder: 1,
    ),
  ];

  AssociationRepository({ApiClient? api})
      : _api = api ?? ApiClient();

  bool get _useMockFallback => MockSafety.isMockAllowed;
  bool get _isTesting => MockSafety.isTesting;

  /// Create a new association.
  Future<Association?> createAssociation(Association association) async {
    final ownerMember = AssociationMember(
      id: 'member-owner-${association.id}-${association.ownerId}',
      associationId: association.id,
      userId: association.ownerId,
      role: 'owner',
    );
    if (!_mockMembers.any((m) => m.associationId == association.id && m.userId == association.ownerId)) {
      _mockMembers.add(ownerMember);
    }

    if (_useMockFallback) {
      _syncAssociationToMock(association);
      return association;
    }
    try {
      final response = await _api.post('/associations', body: association.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = Association.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncAssociationToMock(created);
        return created;
      }
      throw Exception('Failed to create association: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockAssociations.add(association);
      return association;
    }
  }

  /// Update an existing association.
  Future<Association?> updateAssociation(Association association) async {
    if (_useMockFallback) {
      final idx = _mockAssociations.indexWhere((element) => element.id == association.id);
      if (idx != -1) {
        _mockAssociations[idx] = association;
        return association;
      }
      return null;
    }
    try {
      final response = await _api.put('/associations/${association.id}', body: association.toJson());
      if (response.statusCode == 200) {
        final updated = Association.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncAssociationToMock(updated);
        return updated;
      }
      throw Exception('Failed to update association: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      final idx = _mockAssociations.indexWhere(
        (element) => element.id == association.id,
      );
      if (idx != -1) {
        _mockAssociations[idx] = association;
        return association;
      }
      return null;
    }
  }

  /// Fetch single association details.
  Future<Association?> getAssociationDetails(String id) async {
    if (_useMockFallback) {
      final idx = _mockAssociations.indexWhere((element) => element.id == id);
      if (idx != -1) {
        return _mockAssociations[idx];
      }
      return null;
    }
    try {
      final response = await _api.get('/associations/$id');
      if (response.statusCode == 200) {
        final assoc = Association.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncAssociationToMock(assoc);
        return assoc;
      }
      if (response.statusCode == 404) return null;
      throw Exception('Failed to get association details: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      final idx = _mockAssociations.indexWhere((element) => element.id == id);
      if (idx != -1) {
        return _mockAssociations[idx];
      }
      return null;
    }
  }

  /// Fetch all approved associations.
  Future<List<Association>> getAssociations() async {
    if (_useMockFallback) {
      return List.from(_mockAssociations);
    }
    try {
      final response = await _api.get('/associations');
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List)
            .map((e) => Association.fromJson(e as Map<String, dynamic>))
            .toList();
        _mockAssociations.clear();
        _mockAssociations.addAll(list);
        return list;
      }
      throw Exception('Failed to get associations: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      return List.from(_mockAssociations);
    }
  }

  /// Fetch members of an association.
  Future<List<AssociationMember>> getAssociationMembers(
    String associationId,
  ) async {
    if (_useMockFallback) {
      return _mockMembers.where((element) => element.associationId == associationId).toList();
    }
    try {
      final response = await _api.get('/associations/$associationId/members');
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List)
            .map((e) => AssociationMember.fromJson(e as Map<String, dynamic>))
            .toList();
        _mockMembers.removeWhere(
          (element) => element.associationId == associationId,
        );
        _mockMembers.addAll(list);
        return list;
      }
      throw Exception('Failed to get association members: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      return _mockMembers
          .where((element) => element.associationId == associationId)
          .toList();
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

    if (_useMockFallback) {
      _mockMembers.removeWhere((m) => m.associationId == associationId && m.userId == userId);
      _mockMembers.add(member);
      return member;
    }
    try {
      final response = await _api.post('/associations/$associationId/members', body: member.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = AssociationMember.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncMemberToMock(created);
        return created;
      }
      throw Exception('Failed to add association member: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockMembers.removeWhere((m) => m.associationId == associationId && m.userId == userId);
      _mockMembers.add(member);
      return member;
    }
  }

  /// Remove member from association.
  Future<bool> removeAssociationMember(
    String associationId,
    String userId, {
    String? role,
  }) async {
    if (_useMockFallback) {
      _mockMembers.removeWhere(
        (element) =>
            element.associationId == associationId &&
            element.userId == userId &&
            (role == null || element.role == role),
      );
      return true;
    }
    try {
      final roleQuery = role != null ? '&role=$role' : '';
      final response = await _api.delete('/associations/$associationId/members?userId=$userId$roleQuery');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        _mockMembers.removeWhere(
          (element) =>
              element.associationId == associationId &&
              element.userId == userId &&
              (role == null || element.role == role),
        );
        return body['success'] == true;
      }
      throw Exception('Failed to remove association member: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockMembers.removeWhere(
        (element) =>
            element.associationId == associationId &&
            element.userId == userId &&
            (role == null || element.role == role),
      );
      return true;
    }
  }

  /// Transfer ownership of association.
  Future<Association?> transferAssociationOwnership(
    String associationId,
    String newOwnerId, {
    String? customTitle,
  }) async {
    if (_useMockFallback) {
      final idx = _mockAssociations.indexWhere((element) => element.id == associationId);
      if (idx != -1) {
        final current = _mockAssociations[idx];
        final updated = current.copyWith(ownerId: newOwnerId);
        _mockAssociations[idx] = updated;
        final oldOwnerId = current.ownerId;
        
        _mockMembers.removeWhere((element) =>
            element.associationId == associationId &&
            element.userId == oldOwnerId &&
            element.role == 'owner');

        final oIdx = _mockMembers.indexWhere((element) =>
            element.associationId == associationId &&
            element.userId == newOwnerId &&
            element.role == 'owner');
        if (oIdx != -1) {
          _mockMembers[oIdx] = _mockMembers[oIdx].copyWith(customTitle: customTitle);
        } else {
          _mockMembers.add(AssociationMember(
            id: 'member-$associationId-$newOwnerId-owner',
            associationId: associationId,
            userId: newOwnerId,
            role: 'owner',
            customTitle: customTitle,
          ));
        }
        return updated;
      }
      return null;
    }
    try {
      final customTitleQuery = customTitle != null ? '&customTitle=${Uri.encodeComponent(customTitle)}' : '';
      final response = await _api.put('/associations/$associationId/transfer-ownership?newOwnerId=$newOwnerId$customTitleQuery');
      if (response.statusCode == 200) {
        final updated = Association.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncAssociationToMock(updated);
        
        final assocIdx = _mockAssociations.indexWhere((element) => element.id == associationId);
        if (assocIdx != -1) {
          final oldOwnerId = _mockAssociations[assocIdx].ownerId;
          _mockMembers.removeWhere((element) =>
              element.associationId == associationId &&
              element.userId == oldOwnerId &&
              element.role == 'owner');
        }
        final oIdx = _mockMembers.indexWhere((element) =>
            element.associationId == associationId &&
            element.userId == newOwnerId &&
            element.role == 'owner');
        if (oIdx != -1) {
          _mockMembers[oIdx] = _mockMembers[oIdx].copyWith(customTitle: customTitle);
        } else {
          _mockMembers.add(AssociationMember(
            id: 'member-$associationId-$newOwnerId-owner',
            associationId: associationId,
            userId: newOwnerId,
            role: 'owner',
            customTitle: customTitle,
          ));
        }
        return updated;
      }
      throw Exception('Failed to transfer association ownership: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      final idx = _mockAssociations.indexWhere(
        (element) => element.id == associationId,
      );
      if (idx != -1) {
        final current = _mockAssociations[idx];
        final updated = current.copyWith(ownerId: newOwnerId);
        _mockAssociations[idx] = updated;
        final oldOwnerId = current.ownerId;
        
        _mockMembers.removeWhere((element) =>
            element.associationId == associationId &&
            element.userId == oldOwnerId &&
            element.role == 'owner');

        final oIdx = _mockMembers.indexWhere((element) =>
            element.associationId == associationId &&
            element.userId == newOwnerId &&
            element.role == 'owner');
        if (oIdx != -1) {
          _mockMembers[oIdx] = _mockMembers[oIdx].copyWith(customTitle: customTitle);
        } else {
          _mockMembers.add(AssociationMember(
            id: 'member-$associationId-$newOwnerId-owner',
            associationId: associationId,
            userId: newOwnerId,
            role: 'owner',
            customTitle: customTitle,
          ));
        }
        return updated;
      }
      return null;
    }
  }

  /// Delete an association.
  Future<bool> deleteAssociation(String id) async {
    if (_useMockFallback) {
      _mockAssociations.removeWhere((element) => element.id == id);
      _mockMembers.removeWhere((element) => element.associationId == id);
      _mockCompGroups.removeWhere((element) => element.associationId == id);
      _mockAthleteGroups.removeWhere((element) => element.associationId == id);
      return true;
    }
    try {
      final response = await _api.delete('/associations/$id');
      if (response.statusCode == 200) {
        _mockAssociations.removeWhere((element) => element.id == id);
        _mockMembers.removeWhere((element) => element.associationId == id);
        _mockCompGroups.removeWhere((element) => element.associationId == id);
        _mockAthleteGroups.removeWhere((element) => element.associationId == id);
        return true;
      }
      throw Exception('Failed to delete association: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockAssociations.removeWhere((element) => element.id == id);
      _mockMembers.removeWhere((element) => element.associationId == id);
      _mockCompGroups.removeWhere((element) => element.associationId == id);
      _mockAthleteGroups.removeWhere((element) => element.associationId == id);
      return true;
    }
  }

  /// Load competition groups for an association.
  Future<List<CompetitionGroup>> getCompetitionGroups(
    String associationId,
  ) async {
    if (_useMockFallback) {
      return _mockCompGroups.where((element) => element.associationId == associationId).toList();
    }
    try {
      final response = await _api.get('/competition-groups?associationId=$associationId');
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List)
            .map((e) => CompetitionGroup.fromJson(e as Map<String, dynamic>))
            .toList();
        _mockCompGroups.removeWhere(
          (element) => element.associationId == associationId,
        );
        _mockCompGroups.addAll(list);
        return list;
      }
      throw Exception('Failed to get competition groups: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      return _mockCompGroups
          .where((element) => element.associationId == associationId)
          .toList();
    }
  }

  /// Create a competition group.
  Future<CompetitionGroup?> createCompetitionGroup(
    CompetitionGroup group,
  ) async {
    if (_useMockFallback) {
      _mockCompGroups.add(group);
      return group;
    }
    try {
      final response = await _api.post('/competition-groups', body: group.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = CompetitionGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncCompGroupToMock(created);
        return created;
      }
      throw Exception('Failed to create competition group: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockCompGroups.add(group);
      return group;
    }
  }

  /// Update a competition group.
  Future<CompetitionGroup?> updateCompetitionGroup(
    CompetitionGroup group,
  ) async {
    if (_useMockFallback) {
      final idx = _mockCompGroups.indexWhere((element) => element.id == group.id);
      if (idx != -1) {
        _mockCompGroups[idx] = group;
        return group;
      }
      return null;
    }
    try {
      final response = await _api.put('/competition-groups', body: group.toJson());
      if (response.statusCode == 200) {
        final updated = CompetitionGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncCompGroupToMock(updated);
        return updated;
      }
      throw Exception('Failed to update competition group: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      final idx = _mockCompGroups.indexWhere(
        (element) => element.id == group.id,
      );
      if (idx != -1) {
        _mockCompGroups[idx] = group;
        return group;
      }
      return null;
    }
  }

  /// Load athlete groups for an association.
  Future<List<AthleteGroup>> getAthleteGroups(String associationId) async {
    if (_useMockFallback) {
      return _mockAthleteGroups.where((element) => element.associationId == associationId).toList();
    }
    try {
      final response = await _api.get('/athlete-groups?associationId=$associationId');
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List)
            .map((e) => AthleteGroup.fromJson(e as Map<String, dynamic>))
            .toList();
        _mockAthleteGroups.removeWhere(
          (element) => element.associationId == associationId,
        );
        _mockAthleteGroups.addAll(list);
        return list;
      }
      throw Exception('Failed to get athlete groups: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      return _mockAthleteGroups
          .where((element) => element.associationId == associationId)
          .toList();
    }
  }

  /// Create an athlete group.
  Future<AthleteGroup?> createAthleteGroup(AthleteGroup group) async {
    if (_useMockFallback) {
      _mockAthleteGroups.add(group);
      return group;
    }
    try {
      final response = await _api.post('/athlete-groups', body: group.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = AthleteGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncAthleteGroupToMock(created);
        return created;
      }
      throw Exception('Failed to create athlete group: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockAthleteGroups.add(group);
      return group;
    }
  }

  /// Update an athlete group.
  Future<AthleteGroup?> updateAthleteGroup(AthleteGroup group) async {
    if (_useMockFallback) {
      final idx = _mockAthleteGroups.indexWhere((element) => element.id == group.id);
      if (idx != -1) {
        _mockAthleteGroups[idx] = group;
        return group;
      }
      return null;
    }
    try {
      final response = await _api.put('/athlete-groups', body: group.toJson());
      if (response.statusCode == 200) {
        final updated = AthleteGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        _syncAthleteGroupToMock(updated);
        return updated;
      }
      throw Exception('Failed to update athlete group: ${response.statusCode} ${response.body}');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      final idx = _mockAthleteGroups.indexWhere(
        (element) => element.id == group.id,
      );
      if (idx != -1) {
        _mockAthleteGroups[idx] = group;
        return group;
      }
    }
    return null;
  }

  /// Delete a competition group.
  Future<bool> deleteCompetitionGroup(String id) async {
    if (_useMockFallback) {
      _mockCompGroups.removeWhere((element) => element.id == id);
      return true;
    }
    try {
      final response = await _api.delete('/competition-groups/$id');
      if (response.statusCode == 200) {
        _mockCompGroups.removeWhere((element) => element.id == id);
        return true;
      }
      throw Exception('Failed to delete competition group');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockCompGroups.removeWhere((element) => element.id == id);
      return true;
    }
  }

  /// Delete an athlete group.
  Future<bool> deleteAthleteGroup(String id) async {
    if (_useMockFallback) {
      _mockAthleteGroups.removeWhere((element) => element.id == id);
      return true;
    }
    try {
      final response = await _api.delete('/athlete-groups/$id');
      if (response.statusCode == 200) {
        _mockAthleteGroups.removeWhere((element) => element.id == id);
        return true;
      }
      throw Exception('Failed to delete athlete group');
    } catch (e) {
      if (!_useMockFallback) {
        rethrow;
      }
      _mockAthleteGroups.removeWhere((element) => element.id == id);
      return true;
    }
  }

  void _syncAssociationToMock(Association assoc) {
    final idx = _mockAssociations.indexWhere(
      (element) => element.id == assoc.id,
    );
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
    final idx = _mockAthleteGroups.indexWhere(
      (element) => element.id == group.id,
    );
    if (idx != -1) {
      _mockAthleteGroups[idx] = group;
    } else {
      _mockAthleteGroups.add(group);
    }
  }
}
