import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/association/widgets/flat_list_item.dart';

class AthleteGroupsTabView extends StatelessWidget {
  final AssociationManagementPageState state;

  const AthleteGroupsTabView({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context);
    final flatItems = state.buildAthleteGroupsFlatList(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.athleteGroups.length + state.appliedAthleteGroups.length} Athlete Groups',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (state.hasManagePermission)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: state.isReorderingAthleteGroups
                      ? [
                          TextButton(
                            onPressed: () {
                              state.setState(() {
                                state.isReorderingAthleteGroups = false;
                                state.tempAthleteGroups.clear();
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: state.saveReorderedAthleteGroups,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Order'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ]
                      : [
                          if (state.athleteGroups.isNotEmpty) ...[
                            OutlinedButton.icon(
                              onPressed: () {
                                state.setState(() {
                                  state.isReorderingAthleteGroups = true;
                                  state.tempAthleteGroups = List.from(state.athleteGroups);
                                });
                              },
                              icon: const Icon(Icons.reorder),
                              label: const Text('Reorder'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                side: BorderSide(color: theme.colorScheme.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          OutlinedButton.icon(
                            onPressed: () => state.exploreSharedResources(resourceType: 'athlete_groups'),
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
                            onPressed: state.showAddAthleteGroupModal,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Athlete Group'),
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
        if (state.athleteGroups.isEmpty && state.appliedAthleteGroups.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No athlete classes configured.',
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

                  final ownGroups = item.athleteGroups?.where((ag) => ag.associationId == state.widget.associationId).toList() ?? [];
                  final appliedGroups = item.athleteGroups?.where((ag) => ag.associationId != state.widget.associationId).toList() ?? [];
                  final showSelectionActions = state.hasManagePermission && item.level == 2 && ownGroups.isNotEmpty;
                  final showUnlinkAction = state.hasManagePermission && item.level == 2 && appliedGroups.isNotEmpty;

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
                            if (showSelectionActions) ...[
                              IconButton(
                                icon: const Icon(Icons.share, size: 20),
                                tooltip: 'Share Athlete Groups',
                                onPressed: () => state.shareAthleteGroupsForGender(item.title, ownGroups),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (showUnlinkAction) ...[
                              IconButton(
                                icon: const Icon(Icons.link_off, color: Colors.orange, size: 20),
                                tooltip: 'Remove All Applied Classes',
                                onPressed: () => state.removeAllAppliedAthleteGroupsForGender(appliedGroups),
                              ),
                              const SizedBox(width: 8),
                            ],
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
                } else if (item is FlatAthleteGroupCardItem) {
                  final ag = item.athleteGroup;
                  final isApplied = ag.associationId != state.widget.associationId;
                  final ownerAssoc = compProvider.associations.cast<Association?>().firstWhere(
                    (a) => a?.id == ag.associationId,
                    orElse: () => null,
                  );
                  final ownerName = ownerAssoc?.name ?? 'Other';

                  return Padding(
                    padding: const EdgeInsets.only(left: 48.0, bottom: 6.0),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 6.0),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(ag.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isApplied ? 'Shared by $ownerName' : (ag.isActive ? 'Active' : 'Inactive'),
                          style: TextStyle(
                            color: isApplied ? theme.colorScheme.primary : (ag.isActive ? theme.colorScheme.onSurfaceVariant : Colors.red),
                            fontSize: 12,
                          ),
                        ),
                        trailing: isApplied
                            ? (state.hasManagePermission
                                ? IconButton(
                                    icon: const Icon(Icons.link_off, color: Colors.orange),
                                    tooltip: 'Remove Applied Class',
                                    onPressed: () => state.removeAppliedAthleteGroup(ag),
                                  )
                                : null)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (state.hasManagePermission)
                                    IconButton(
                                      icon: const Icon(Icons.share, size: 20),
                                      tooltip: 'Share Class',
                                      onPressed: () => state.configureAthleteGroupSharing(ag),
                                    ),
                                  Switch(
                                    value: ag.isActive,
                                    onChanged: state.hasManagePermission ? (_) => state.toggleAthleteGroup(ag) : null,
                                  ),
                                  if (state.hasManagePermission) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Update Class',
                                      color: theme.colorScheme.primary,
                                      onPressed: () => state.showUpdateAthleteGroupModal(ag),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                      tooltip: 'Remove Class',
                                      onPressed: () => state.showRemoveAthleteGroupConfirmation(ag),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  );
                } else if (item is FlatReorderableGroupItem) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 48.0, bottom: 6.0),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: item.athleteGroups.length,
                      proxyDecorator: (Widget child, int index, Animation<double> animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (BuildContext context, Widget? child) {
                            return Material(
                              elevation: 6.0,
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: child,
                            );
                          },
                          child: child,
                        );
                      },
                      onReorder: (oldIndex, newIndex) {
                        state.setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final draggedGroup = item.athleteGroups.removeAt(oldIndex);
                          item.athleteGroups.insert(newIndex, draggedGroup);

                          // Update the global list tempAthleteGroups to match new order
                          final orderedIds = item.athleteGroups.map((g) => g.id).toList();
                          final newTempList = <AthleteGroup>[];
                          int subIdx = 0;
                          for (var g in state.tempAthleteGroups) {
                            if (orderedIds.contains(g.id)) {
                              newTempList.add(item.athleteGroups[subIdx++]);
                            } else {
                              newTempList.add(g);
                            }
                          }
                          state.tempAthleteGroups = newTempList;
                        });
                      },
                      itemBuilder: (context, index) {
                        final ag = item.athleteGroups[index];
                        return Card(
                          key: ValueKey(ag.id),
                          margin: const EdgeInsets.only(bottom: 6.0),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                            title: Text(ag.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              ag.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: ag.isActive ? theme.colorScheme.onSurfaceVariant : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
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
