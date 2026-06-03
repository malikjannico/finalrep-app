import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/association_management_page.dart';
import 'package:finalrep_app/views/association/widgets/flat_list_item.dart';
import 'package:finalrep_app/views/association/widgets/dropdown_filter_chip.dart';

class SportsAndFormatsTabView extends StatelessWidget {
  final AssociationManagementPageState state;

  const SportsAndFormatsTabView({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context);
    final sportConfig = compProvider.sportConfig;
    final flatItems = state.buildSportsAndFormatsFlatList(theme, sportConfig);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final sportsList = sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'];
    final formatsList = sportConfig?.formats.map((f) => f.name).toSet().toList() ?? ['Modern', 'Classic'];

    // Calculate total count
    int totalSports = 0;
    int totalFormats = 0;
    final Set<String> uniqueSports = {};
    for (var item in flatItems) {
      if (item is FlatSportFormatItem) {
        uniqueSports.add(item.sport);
        totalFormats++;
      }
    }
    totalSports = uniqueSports.length;

    final totalOwnedFormats = state.selectedSportsFormats.values.fold<int>(0, (sum, list) => sum + list.length);
    final appliedRulebooks = state.association?.appliedSharedResources['rulebooks'] as Map? ?? {};
    final totalUnfilteredCount = totalOwnedFormats + appliedRulebooks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header showing counts and Add button
        Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalSports Sports, $totalFormats Formats',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (state.hasManagePermission && isDesktop)
                ElevatedButton.icon(
                  onPressed: () => state.showSportConfigurationModal(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Sport & Format'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94E1B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  hintText: 'Search sports and formats...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                ),
                onChanged: (val) {
                  state.setState(() {
                    state.sfSearchQuery = val;
                  });
                },
              ),
              if (totalUnfilteredCount > 0) ...[
                const SizedBox(height: 12),
                // Dropdown Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownFilterChip<String>(
                        label: 'Sport',
                        items: sportsList,
                        selectedItems: state.sfSelectedSports,
                        itemLabel: (s) => s,
                        onSelected: (sport, selected) {
                          state.setState(() {
                            if (selected) {
                              state.sfSelectedSports.add(sport);
                            } else {
                              state.sfSelectedSports.remove(sport);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      DropdownFilterChip<String>(
                        label: 'Format',
                        items: formatsList,
                        selectedItems: state.sfSelectedFormats,
                        itemLabel: (f) => f,
                        onSelected: (format, selected) {
                          state.setState(() {
                            if (selected) {
                              state.sfSelectedFormats.add(format);
                            } else {
                              state.sfSelectedFormats.remove(format);
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

        // Main List
        if (flatItems.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No active sports or formats found.',
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
                } else if (item is FlatSportFormatItem) {
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
                      title: Text(item.format, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          if (item.disciplines.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: item.disciplines.map((d) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  d,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              )).toList(),
                            ),
                          if (item.isAppliedShared) ...[
                            const SizedBox(height: 6),
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
                        ],
                      ),
                      trailing: item.isAppliedShared
                          ? null
                          : (state.hasManagePermission
                              ? IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit Sport Formats',
                                  color: theme.colorScheme.primary,
                                  onPressed: () => state.showSportConfigurationModal(editSportType: item.sport),
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
