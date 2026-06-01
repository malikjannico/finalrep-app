import 'package:finalrep_app/models/association.dart';

bool isResourceSharedWith({
  required String resourceOwnerId,
  required Map<String, dynamic> sharingConfig,
  required String targetAssociationId,
  required List<Association> allAssociations,
}) {
  if (resourceOwnerId == targetAssociationId) return false;

  final mode = sharingConfig['mode'] as String? ?? 'private';
  final targets = List<String>.from(sharingConfig['targets'] as List? ?? []);

  if (mode == 'private') {
    return false;
  }

  if (mode == 'specific') {
    return targets.contains(targetAssociationId);
  }

  if (mode == 'sub_recursive') {
    return isDescendant(
      childId: targetAssociationId,
      parentId: resourceOwnerId,
      allAssociations: allAssociations,
    );
  }

  if (mode == 'parent_recursive') {
    return isAncestor(
      ancestorId: targetAssociationId,
      descendantId: resourceOwnerId,
      allAssociations: allAssociations,
    );
  }

  return false;
}

bool isDescendant({
  required String childId,
  required String parentId,
  required List<Association> allAssociations,
}) {
  final visited = <String>{};
  String? currentId = childId;
  while (currentId != null) {
    if (currentId == parentId) return true;
    if (visited.contains(currentId)) break;
    visited.add(currentId);
    final assoc = allAssociations.where((a) => a.id == currentId).firstOrNull;
    currentId = assoc?.parentAssociationId;
  }
  return false;
}

bool isAncestor({
  required String ancestorId,
  required String descendantId,
  required List<Association> allAssociations,
}) {
  return isDescendant(
    childId: descendantId,
    parentId: ancestorId,
    allAssociations: allAssociations,
  );
}

List<Association> getParentChain(String associationId, List<Association> allAssociations) {
  final chain = <Association>[];
  final visited = <String>{};
  String? currentId = associationId;

  final current = allAssociations.where((a) => a.id == currentId).firstOrNull;
  String? nextParentId = current?.parentAssociationId;

  while (nextParentId != null && !visited.contains(nextParentId)) {
    visited.add(nextParentId);
    final parent = allAssociations.where((a) => a.id == nextParentId).firstOrNull;
    if (parent != null) {
      chain.add(parent);
      nextParentId = parent.parentAssociationId;
    } else {
      break;
    }
  }
  return chain;
}
