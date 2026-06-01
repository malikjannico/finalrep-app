import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/association/widgets/flat_list_item.dart';

class CompetitionGroupsTabView extends StatelessWidget {
  final AssociationManagementPageState state;

  const CompetitionGroupsTabView({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context);
    final flatItems = state.buildCompGroupsFlatList(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.compGroups.length + state.appliedCompGroups.length} Competition Groups',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (state.hasManagePermission)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => state.exploreSharedResources(resourceType: 'competition_groups'),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Explore Shared'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE94E1B),
                        side: const BorderSide(color: Color(0xFFE94E1B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: state.showAddCompGroupModal,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Comp Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94E1B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (state.compGroups.isEmpty && state.appliedCompGroups.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No competition groups configured.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              itemCount: flatItems.length,
              itemBuilder: (context, idx) {
                final item = flatItems[idx];
                if (item is FlatHeaderItem) {
                  final isExpanded = !state.userCollapsedKeys.contains(item.key);
                  final paddingLeft = item.level * 16.0;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    margin: EdgeInsets.only(left: paddingLeft, bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        state.setState(() {
                          if (state.userCollapsedKeys.contains(item.key)) {
                            state.userCollapsedKeys.remove(item.key);
                          } else {
                            state.userCollapsedKeys.add(item.key);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            if (item.countText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  item.countText!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSecondaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                } else if (item is FlatCompGroupCardItem) {
                  final group = item.compGroup;
                  final isApplied = group.associationId != state.widget.associationId;
                  final ownerAssoc = compProvider.associations.cast<Association?>().firstWhere(
                    (a) => a?.id == group.associationId,
                    orElse: () => null,
                  );
                  final ownerName = ownerAssoc?.name ?? 'Other';

                  return Padding(
                    padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isApplied ? 'Shared by $ownerName' : (group.isActive ? 'Active' : 'Inactive'),
                          style: TextStyle(
                            color: isApplied ? theme.colorScheme.primary : (group.isActive ? Colors.green : Colors.red),
                            fontSize: 12,
                          ),
                        ),
                        trailing: isApplied
                            ? (state.hasManagePermission
                                ? IconButton(
                                    icon: const Icon(Icons.link_off, color: Colors.orange),
                                    tooltip: 'Remove Applied Group',
                                    onPressed: () => state.removeAppliedCompetitionGroup(group),
                                  )
                                : null)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (state.hasManagePermission)
                                    IconButton(
                                      icon: const Icon(Icons.share, size: 20),
                                      tooltip: 'Share Group',
                                      onPressed: () => state.configureCompGroupSharing(group),
                                    ),
                                  Switch(
                                    value: group.isActive,
                                    onChanged: state.hasManagePermission ? (_) => state.toggleCompGroup(group) : null,
                                  ),
                                  if (state.hasManagePermission) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Update Group',
                                      color: theme.colorScheme.primary,
                                      onPressed: () => state.showUpdateCompGroupModal(group),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                      tooltip: 'Remove Group',
                                      onPressed: () => state.showRemoveCompGroupConfirmation(group),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
      ],
    );
  }
}
