import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/competition_group.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/association/widgets/hierarchy_helpers.dart';
import 'package:finalrep_app/views/association/widgets/dropdown_filter_chip.dart';

class _SharedRulebookItem {
  final String sport;
  final String format;
  final String url;
  final Association owningAssociation;

  _SharedRulebookItem({
    required this.sport,
    required this.format,
    required this.url,
    required this.owningAssociation,
  });
}

class ExploreSharedResourcesDialog extends StatefulWidget {
  final Association currentAssociation;
  final List<Association> allAssociations;
  final String resourceType; // 'rulebooks', 'competition_groups', or 'athlete_groups'

  const ExploreSharedResourcesDialog({
    Key? key,
    required this.currentAssociation,
    required this.allAssociations,
    required this.resourceType,
  }) : super(key: key);

  @override
  State<ExploreSharedResourcesDialog> createState() => _ExploreSharedResourcesDialogState();
}

class _ExploreSharedResourcesDialogState extends State<ExploreSharedResourcesDialog> {
  bool _loading = true;

  List<_SharedRulebookItem> _eligibleRulebooks = [];
  List<CompetitionGroup> _eligibleCompGroups = [];
  List<AthleteGroup> _eligibleAthleteGroups = [];

  Map<String, dynamic> _selectedRulebooks = {};
  List<Map<String, dynamic>> _selectedCompGroups = [];
  List<Map<String, dynamic>> _selectedAthleteGroups = [];

  // Filter states
  String _searchQuery = '';
  final Set<String> _selectedSports = {};
  final Set<String> _selectedFormats = {};
  final Set<String> _selectedGenders = {};

  @override
  void initState() {
    super.initState();

    final applied = widget.currentAssociation.appliedSharedResources;
    _selectedRulebooks = Map<String, dynamic>.from(applied['rulebooks'] as Map? ?? {});
    _selectedCompGroups = List<Map<String, dynamic>>.from(
      (applied['competition_groups'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
    );
    _selectedAthleteGroups = List<Map<String, dynamic>>.from(
      (applied['athlete_groups'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
    );

    _loadSharedResources();
  }

  Future<void> _loadSharedResources() async {
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    final neighbors = widget.allAssociations.where((assoc) {
      if (assoc.id == widget.currentAssociation.id) return false;
      return isDescendant(
        childId: widget.currentAssociation.id,
        parentId: assoc.id,
        allAssociations: widget.allAssociations,
      ) || isDescendant(
        childId: assoc.id,
        parentId: widget.currentAssociation.id,
        allAssociations: widget.allAssociations,
      );
    }).toList();

    final List<_SharedRulebookItem> rulebooks = [];
    final List<CompetitionGroup> compGroups = [];
    final List<AthleteGroup> athleteGroups = [];

    for (var neighbor in neighbors) {
      if (widget.resourceType == 'rulebooks') {
        final appliedRulebooksMap = widget.currentAssociation.appliedSharedResources['rulebooks'] as Map? ?? {};
        neighbor.rulebooks.forEach((sport, url) {
          final sharing = neighbor.rulebooksSharing[sport] as Map<String, dynamic>? ?? {'mode': 'private', 'targets': []};
          if (isResourceSharedWith(
            resourceOwnerId: neighbor.id,
            sharingConfig: sharing,
            targetAssociationId: widget.currentAssociation.id,
            allAssociations: widget.allAssociations,
          )) {
            for (var format in neighbor.supportedFormats) {
              final key = '$sport:$format';
              if (!appliedRulebooksMap.containsKey(key)) {
                rulebooks.add(_SharedRulebookItem(
                  sport: sport,
                  format: format,
                  url: url,
                  owningAssociation: neighbor,
                ));
              }
            }
          }
        });
      }

      if (widget.resourceType == 'competition_groups') {
        try {
          final groups = await compProvider.getCompetitionGroups(neighbor.id);
          final appliedCompGroupsList = widget.currentAssociation.appliedSharedResources['competition_groups'] as List? ?? [];
          for (var g in groups) {
            if (isResourceSharedWith(
              resourceOwnerId: neighbor.id,
              sharingConfig: g.sharingConfig,
              targetAssociationId: widget.currentAssociation.id,
              allAssociations: widget.allAssociations,
            )) {
              final alreadyApplied = appliedCompGroupsList.any((item) => item is Map && item['id'] == g.id);
              if (!alreadyApplied) {
                compGroups.add(g);
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading comp groups for neighbor ${neighbor.name}: $e');
        }
      }

      if (widget.resourceType == 'athlete_groups') {
        try {
          final groups = await compProvider.getAthleteGroups(neighbor.id);
          final appliedAthleteGroupsList = widget.currentAssociation.appliedSharedResources['athlete_groups'] as List? ?? [];
          for (var g in groups) {
            if (isResourceSharedWith(
              resourceOwnerId: neighbor.id,
              sharingConfig: g.sharingConfig,
              targetAssociationId: widget.currentAssociation.id,
              allAssociations: widget.allAssociations,
            )) {
              final alreadyApplied = appliedAthleteGroupsList.any((item) => item is Map && item['id'] == g.id);
              if (!alreadyApplied) {
                athleteGroups.add(g);
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading athlete groups for neighbor ${neighbor.name}: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _eligibleRulebooks = rulebooks;
        _eligibleCompGroups = compGroups;
        _eligibleAthleteGroups = athleteGroups;
        _loading = false;
      });
    }
  }

  // Helper filters
  List<_SharedRulebookItem> get _filteredRulebooks {
    final query = _searchQuery.trim().toLowerCase();
    return _eligibleRulebooks.where((item) {
      final matchesQuery = query.isEmpty ||
          item.sport.toLowerCase().contains(query) ||
          item.format.toLowerCase().contains(query) ||
          item.owningAssociation.name.toLowerCase().contains(query);
      final matchesSport = _selectedSports.isEmpty || _selectedSports.contains(item.sport);
      final matchesFormat = _selectedFormats.isEmpty || _selectedFormats.contains(item.format);
      return matchesQuery && matchesSport && matchesFormat;
    }).toList();
  }

  List<CompetitionGroup> get _filteredCompGroups {
    final query = _searchQuery.trim().toLowerCase();
    return _eligibleCompGroups.where((g) {
      final owner = widget.allAssociations.firstWhere((a) => a.id == g.associationId, orElse: () => widget.currentAssociation);
      final matchesQuery = query.isEmpty ||
          g.name.toLowerCase().contains(query) ||
          owner.name.toLowerCase().contains(query);
      final matchesSport = _selectedSports.isEmpty || _selectedSports.contains(g.sport);
      final matchesFormat = _selectedFormats.isEmpty || _selectedFormats.contains(g.format);
      return matchesQuery && matchesSport && matchesFormat;
    }).toList();
  }

  List<AthleteGroup> get _filteredAthleteGroups {
    final query = _searchQuery.trim().toLowerCase();
    return _eligibleAthleteGroups.where((g) {
      final owner = widget.allAssociations.firstWhere((a) => a.id == g.associationId, orElse: () => widget.currentAssociation);
      final matchesQuery = query.isEmpty ||
          g.name.toLowerCase().contains(query) ||
          owner.name.toLowerCase().contains(query);
      final matchesSport = _selectedSports.isEmpty || _selectedSports.contains(g.sport);
      final matchesFormat = _selectedFormats.isEmpty || _selectedFormats.contains(g.format);
      final matchesGender = _selectedGenders.isEmpty || _selectedGenders.contains(g.gender);
      return matchesQuery && matchesSport && matchesFormat && matchesGender;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context);

    final String titleText;
    int selectedCount = 0;
    if (widget.resourceType == 'rulebooks') {
      titleText = 'Explore Shared Rulebooks';
      selectedCount = _selectedRulebooks.length;
    } else if (widget.resourceType == 'competition_groups') {
      titleText = 'Explore Shared Competition Groups';
      selectedCount = _selectedCompGroups.length;
    } else {
      titleText = 'Explore Shared Athlete Groups';
      selectedCount = _selectedAthleteGroups.length;
    }

    final sportsList = compProvider.sportConfig?.sports.map((s) => s.name).toList() ?? ['Streetlifting'];
    final formatsList = compProvider.sportConfig?.formats.map((f) => f.name).toSet().toList() ?? ['Modern', 'Classic'];
    final gendersList = const ['men', 'women', 'mixed'];

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          minWidth: isMobile ? 0 : 800,
          maxWidth: isMobile ? 600 : 1000,
          minHeight: isMobile ? 300 : 500,
          maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.9 : 700,
        ),
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    titleText,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_loading) ...[
              // Search input
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search shared resources by name or owner...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              // Dropdown Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownFilterChip<String>(
                      label: 'Sport',
                      items: sportsList,
                      selectedItems: _selectedSports,
                      itemLabel: (s) => s,
                      onSelected: (sport, selected) {
                        setState(() {
                          if (selected) {
                            _selectedSports.add(sport);
                          } else {
                            _selectedSports.remove(sport);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    DropdownFilterChip<String>(
                      label: 'Format',
                      items: formatsList,
                      selectedItems: _selectedFormats,
                      itemLabel: (f) => f,
                      onSelected: (format, selected) {
                        setState(() {
                          if (selected) {
                            _selectedFormats.add(format);
                          } else {
                            _selectedFormats.remove(format);
                          }
                        });
                      },
                    ),
                    if (widget.resourceType == 'athlete_groups') ...[
                      const SizedBox(width: 8),
                      DropdownFilterChip<String>(
                        label: 'Gender',
                        items: gendersList,
                        selectedItems: _selectedGenders,
                        itemLabel: (g) => g == 'women' ? 'Women' : (g.isEmpty ? '' : g[0].toUpperCase() + g.substring(1)),
                        onSelected: (gender, selected) {
                          setState(() {
                            if (selected) {
                              _selectedGenders.add(gender);
                            } else {
                              _selectedGenders.remove(gender);
                            }
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Number Indicator and Select All Checkbox
              _buildSelectAllBar(theme),
              const Divider(),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.resourceType == 'rulebooks'
                      ? _buildRulebooksList(theme)
                      : widget.resourceType == 'competition_groups'
                          ? _buildCompGroupsList(theme)
                          : _buildAthleteGroupsList(theme),
            ),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop({
                            'rulebooks': _selectedRulebooks,
                            'competition_groups': _selectedCompGroups,
                            'athlete_groups': _selectedAthleteGroups,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('APPLY SELECTED'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('CANCEL'),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop({
                            'rulebooks': _selectedRulebooks,
                            'competition_groups': _selectedCompGroups,
                            'athlete_groups': _selectedAthleteGroups,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('APPLY SELECTED'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectAllBar(ThemeData theme) {
    bool? allSelected;
    bool? tristateValue;
    int itemsCount = 0;
    int selectedCount = 0;
    VoidCallback? onSelectAllToggled;

    if (widget.resourceType == 'rulebooks') {
      final items = _filteredRulebooks;
      itemsCount = items.length;
      final selectedItems = items.where((item) {
        final key = '${item.sport}:${item.format}';
        return _selectedRulebooks[key]?['owning_association_id'] == item.owningAssociation.id;
      }).toList();
      selectedCount = selectedItems.length;

      allSelected = itemsCount > 0 && selectedCount == itemsCount;
      final anySelected = selectedCount > 0;
      tristateValue = allSelected ? true : (anySelected ? null : false);

      onSelectAllToggled = () {
        setState(() {
          if (allSelected == true) {
            for (var item in items) {
              final key = '${item.sport}:${item.format}';
              _selectedRulebooks.remove(key);
            }
          } else {
            for (var item in items) {
              final key = '${item.sport}:${item.format}';
              _selectedRulebooks[key] = {
                'rulebook_url': item.url,
                'owning_association_id': item.owningAssociation.id,
              };
            }
          }
        });
      };
    } else if (widget.resourceType == 'competition_groups') {
      final items = _filteredCompGroups;
      itemsCount = items.length;
      final selectedItems = items.where((g) => _selectedCompGroups.any((item) => item['id'] == g.id)).toList();
      selectedCount = selectedItems.length;

      allSelected = itemsCount > 0 && selectedCount == itemsCount;
      final anySelected = selectedCount > 0;
      tristateValue = allSelected ? true : (anySelected ? null : false);

      onSelectAllToggled = () {
        setState(() {
          if (allSelected == true) {
            for (var g in items) {
              _selectedCompGroups.removeWhere((item) => item['id'] == g.id);
            }
          } else {
            for (var g in items) {
              if (!_selectedCompGroups.any((item) => item['id'] == g.id)) {
                _selectedCompGroups.add({
                  'id': g.id,
                  'owning_association_id': g.associationId,
                });
              }
            }
          }
        });
      };
    } else {
      final items = _filteredAthleteGroups;
      itemsCount = items.length;
      final selectedItems = items.where((g) => _selectedAthleteGroups.any((item) => item['id'] == g.id)).toList();
      selectedCount = selectedItems.length;

      allSelected = itemsCount > 0 && selectedCount == itemsCount;
      final anySelected = selectedCount > 0;
      tristateValue = allSelected ? true : (anySelected ? null : false);

      onSelectAllToggled = () {
        setState(() {
          if (allSelected == true) {
            for (var g in items) {
              _selectedAthleteGroups.removeWhere((item) => item['id'] == g.id);
            }
          } else {
            for (var g in items) {
              if (!_selectedAthleteGroups.any((item) => item['id'] == g.id)) {
                _selectedAthleteGroups.add({
                  'id': g.id,
                  'owning_association_id': g.associationId,
                });
              }
            }
          }
        });
      };
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$selectedCount / $itemsCount selected',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            const Text('Select All shown'),
            Checkbox(
              value: tristateValue,
              tristate: true,
              activeColor: const Color(0xFFE94E1B),
              onChanged: (_) => onSelectAllToggled?.call(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRulebooksList(ThemeData theme) {
    final items = _filteredRulebooks;
    if (items.isEmpty) {
      return const Center(child: Text('No shared rulebooks available matching filters.'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final key = '${item.sport}:${item.format}';
        final isApplied = _selectedRulebooks[key]?['owning_association_id'] == item.owningAssociation.id;

        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: CheckboxListTile(
            activeColor: const Color(0xFFE94E1B),
            title: Text('${item.sport} - ${item.format}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
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
                      'Shared by ${item.owningAssociation.name}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.secondary),
                    ),
                  ),
                  Text(
                    'Url: ${item.url}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            value: isApplied,
            onChanged: (bool? checked) {
              setState(() {
                if (checked == true) {
                  _selectedRulebooks[key] = {
                    'rulebook_url': item.url,
                    'owning_association_id': item.owningAssociation.id,
                  };
                } else {
                  _selectedRulebooks.remove(key);
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildCompGroupsList(ThemeData theme) {
    final items = _filteredCompGroups;
    if (items.isEmpty) {
      return const Center(child: Text('No shared competition groups available matching filters.'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final group = items[idx];
        final isApplied = _selectedCompGroups.any((item) => item['id'] == group.id);
        final ownerAssoc = widget.allAssociations.where((a) => a.id == group.associationId).firstOrNull;
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
          child: CheckboxListTile(
            activeColor: const Color(0xFFE94E1B),
            title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      group.format,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Shared by $ownerName',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.secondary),
                    ),
                  ),
                ],
              ),
            ),
            value: isApplied,
            onChanged: (bool? checked) {
              setState(() {
                if (checked == true) {
                  _selectedCompGroups.add({
                    'id': group.id,
                    'owning_association_id': group.associationId,
                  });
                } else {
                  _selectedCompGroups.removeWhere((item) => item['id'] == group.id);
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildAthleteGroupsList(ThemeData theme) {
    final items = _filteredAthleteGroups;
    if (items.isEmpty) {
      return const Center(child: Text('No shared athlete groups available matching filters.'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final group = items[idx];
        final isApplied = _selectedAthleteGroups.any((item) => item['id'] == group.id);
        final ownerAssoc = widget.allAssociations.where((a) => a.id == group.associationId).firstOrNull;
        final ownerName = ownerAssoc?.name ?? 'Other';
        final displayGender = group.gender == 'women' ? 'Women' : (group.gender.isEmpty ? '' : group.gender[0].toUpperCase() + group.gender.substring(1));

        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: CheckboxListTile(
            activeColor: const Color(0xFFE94E1B),
            title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      group.format,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      displayGender,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Shared by $ownerName',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.secondary),
                    ),
                  ),
                ],
              ),
            ),
            value: isApplied,
            onChanged: (bool? checked) {
              setState(() {
                if (checked == true) {
                  _selectedAthleteGroups.add({
                    'id': group.id,
                    'owning_association_id': group.associationId,
                  });
                } else {
                  _selectedAthleteGroups.removeWhere((item) => item['id'] == group.id);
                }
              });
            },
          ),
        );
      },
    );
  }
}
