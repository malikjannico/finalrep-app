import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/association/widgets/flat_list_item.dart';
import 'package:finalrep_app/views/association/widgets/dropdown_filter_chip.dart';

class RulebooksTabView extends StatelessWidget {
  final AssociationManagementPageState state;

  const RulebooksTabView({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context);
    final sportConfig = compProvider.sportConfig;
    final flatItems = state.buildRulebooksFlatList(theme);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final sportsList = sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'];
    final formatsList = sportConfig?.formats.map((f) => f.name).toSet().toList() ?? ['Modern', 'Classic'];

    int totalRulebooks = 0;
    for (var item in flatItems) {
      if (item is FlatRulebookItem) {
        totalRulebooks++;
      }
    }

    final ownRulebooksCount = state.association?.rulebooks.values.where((url) => url.isNotEmpty).length ?? 0;
    final appliedRulebooks = state.association?.appliedSharedResources['rulebooks'] as Map? ?? {};
    final totalUnfilteredRulebooks = ownRulebooksCount + appliedRulebooks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card/row for count and buttons
        Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalRulebooks Rulebooks',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (state.hasManagePermission)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (MediaQuery.of(context).size.width >= 900) ...[
                        ElevatedButton.icon(
                          onPressed: () => state.showRulebookConfigModal(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Rulebook'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE94E1B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      PopupMenuButton<String>(
                        tooltip: 'Rulebooks Options',
                        icon: const Icon(Icons.more_vert),
                        position: PopupMenuPosition.under,
                        onSelected: (value) {
                          if (value == 'apply') {
                            state.exploreSharedResources(resourceType: 'rulebooks');
                          } else if (value == 'share') {
                            state.shareRulebooksMulti();
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
                                const Text('Share Rulebooks'),
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
        ),

        // Search & Filter controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search rulebooks by sport or url...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                ),
                onChanged: (val) {
                  state.setState(() {
                    state.rbSearchQuery = val;
                  });
                },
              ),
              if (totalUnfilteredRulebooks > 0) ...[
                const SizedBox(height: 12),
                // Dropdown Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownFilterChip<String>(
                        label: 'Sport',
                        items: sportsList,
                        selectedItems: state.rbSelectedSports,
                        itemLabel: (s) => s,
                        onSelected: (sport, selected) {
                          state.setState(() {
                            if (selected) {
                              state.rbSelectedSports.add(sport);
                            } else {
                              state.rbSelectedSports.remove(sport);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      DropdownFilterChip<String>(
                        label: 'Format',
                        items: formatsList,
                        selectedItems: state.rbSelectedFormats,
                        itemLabel: (f) => f,
                        onSelected: (format, selected) {
                          state.setState(() {
                            if (selected) {
                              state.rbSelectedFormats.add(format);
                            } else {
                              state.rbSelectedFormats.remove(format);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Rulebooks list
        if (flatItems.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No rulebooks configured.',
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
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 8.0),
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
                } else if (item is FlatRulebookItem) {
                  final isApplied = item.isAppliedShared;
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
                      title: Text(
                        item.rulebookUrl,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (item.format != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.format!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              )
                            else
                              ...((state.selectedSportsFormats[item.sport] ?? []).map((fmt) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    fmt,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              })),
                            if (isApplied)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Shared by ${item.owningAssociationName ?? "Other"}',
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
                                  tooltip: 'Remove Applied Rulebook',
                                  onPressed: () => state.removeAppliedRulebook(item.sport, item.format!),
                                )
                              : null)
                          : (state.hasManagePermission
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Update Rulebook',
                                      color: theme.colorScheme.primary,
                                      onPressed: () => state.showRulebookConfigModal(editSportType: item.sport),
                                    ),
                                    if (!item.hasAppliedShared)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                        tooltip: 'Remove Rulebook',
                                        onPressed: () => state.deleteRulebook(item.sport),
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
}
