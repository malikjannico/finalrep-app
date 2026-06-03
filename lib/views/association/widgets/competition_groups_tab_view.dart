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
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Filter configuration lists
    final sportsList = compProvider.sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'];
    final formatsList = compProvider.sportConfig?.formats.map((f) => f.name).toSet().toList() ?? ['Modern', 'Classic'];

    final totalCount = state.compGroups.length + state.appliedCompGroups.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card/row for count and buttons
        Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$totalCount Competition Groups',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (state.hasManagePermission)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (MediaQuery.of(context).size.width >= 900) ...[
                            ElevatedButton.icon(
                              onPressed: state.showAddCompGroupModal,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Group'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE94E1B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          PopupMenuButton<String>(
                            tooltip: 'Competition Groups Options',
                            icon: const Icon(Icons.more_vert),
                            position: PopupMenuPosition.under,
                            onSelected: (value) {
                              if (value == 'apply') {
                                state.exploreSharedResources(resourceType: 'competition_groups');
                              } else if (value == 'share') {
                                state.shareCompetitionGroupsMulti();
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'apply',
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.explore_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 12),
                                    const Text('Apply Shared'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'share',
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.share, size: 20, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 12),
                                    const Text('Share Groups'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Search & Filter controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search competition groups by name...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                ),
                onChanged: (val) {
                  state.setState(() {
                    state.cgSearchQuery = val;
                  });
                },
              ),
              if (totalCount > 0) ...[
                const SizedBox(height: 12),
                // Dropdown Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterDropdownChip(
                        label: 'Sport',
                        options: sportsList,
                        selectedValues: state.cgSelectedSports,
                        onToggled: (sport) {
                          state.setState(() {
                            if (state.cgSelectedSports.contains(sport)) {
                              state.cgSelectedSports.remove(sport);
                            } else {
                              state.cgSelectedSports.add(sport);
                            }
                          });
                        },
                        onClear: () {
                          state.setState(() {
                            state.cgSelectedSports.clear();
                          });
                        },
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterDropdownChip(
                        label: 'Format',
                        options: formatsList,
                        selectedValues: state.cgSelectedFormats,
                        onToggled: (format) {
                          state.setState(() {
                            if (state.cgSelectedFormats.contains(format)) {
                              state.cgSelectedFormats.remove(format);
                            } else {
                              state.cgSelectedFormats.add(format);
                            }
                          });
                        },
                        onClear: () {
                          state.setState(() {
                            state.cgSelectedFormats.clear();
                          });
                        },
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Groups checklist
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
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 24.0, vertical: 8.0),
              itemCount: flatItems.length,
              itemBuilder: (context, idx) {
                final item = flatItems[idx];
                if (item is FlatHeaderItem) {
                  final isExpanded = !state.userCollapsedKeys.contains(item.key);
                  final paddingLeft = item.level * (isMobile ? 8.0 : 16.0);

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

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                group.format,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (isApplied)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Shared by $ownerName',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
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
                          : (state.hasManagePermission
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                                )
                              : null),
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

  Widget _buildFilterDropdownChip({
    required String label,
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onToggled,
    required VoidCallback onClear,
    required ThemeData theme,
  }) {
    final String chipLabel;
    if (selectedValues.isEmpty) {
      chipLabel = label;
    } else if (selectedValues.length == 1) {
      chipLabel = '$label: ${selectedValues.first}';
    } else {
      chipLabel = '$label (${selectedValues.length})';
    }

    return PopupMenuButton<String>(
      onSelected: onToggled,
      position: PopupMenuPosition.under,
      itemBuilder: (context) {
        return options.map((opt) {
          final isChecked = selectedValues.contains(opt);
          final capitalizedOpt = opt.isNotEmpty ? opt[0].toUpperCase() + opt.substring(1) : opt;
          return PopupMenuItem<String>(
            value: opt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(capitalizedOpt),
                if (isChecked) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                ],
              ],
            ),
          );
        }).toList();
      },
      child: InputChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(chipLabel),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
        selected: selectedValues.isNotEmpty,
        onDeleted: selectedValues.isNotEmpty ? onClear : null,
        showCheckmark: false,
      ),
    );
  }
}
