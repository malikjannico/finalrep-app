import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/competition_group.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/association/widgets/hierarchy_helpers.dart';

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

  @override
  void dispose() {
    super.dispose();
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
        neighbor.rulebooks.forEach((sport, url) {
          final sharing = neighbor.rulebooksSharing[sport] as Map<String, dynamic>? ?? {'mode': 'private', 'targets': []};
          if (isResourceSharedWith(
            resourceOwnerId: neighbor.id,
            sharingConfig: sharing,
            targetAssociationId: widget.currentAssociation.id,
            allAssociations: widget.allAssociations,
          )) {
            for (var format in neighbor.supportedFormats) {
              rulebooks.add(_SharedRulebookItem(
                sport: sport,
                format: format,
                url: url,
                owningAssociation: neighbor,
              ));
            }
          }
        });
      }

      if (widget.resourceType == 'competition_groups') {
        try {
          final groups = await compProvider.getCompetitionGroups(neighbor.id);
          for (var g in groups) {
            if (isResourceSharedWith(
              resourceOwnerId: neighbor.id,
              sharingConfig: g.sharingConfig,
              targetAssociationId: widget.currentAssociation.id,
              allAssociations: widget.allAssociations,
            )) {
              compGroups.add(g);
            }
          }
        } catch (e) {
          debugPrint('Error loading comp groups for neighbor ${neighbor.name}: $e');
        }
      }

      if (widget.resourceType == 'athlete_groups') {
        try {
          final groups = await compProvider.getAthleteGroups(neighbor.id);
          for (var g in groups) {
            if (isResourceSharedWith(
              resourceOwnerId: neighbor.id,
              sharingConfig: g.sharingConfig,
              targetAssociationId: widget.currentAssociation.id,
              allAssociations: widget.allAssociations,
            )) {
              athleteGroups.add(g);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String titleText;
    if (widget.resourceType == 'rulebooks') {
      titleText = 'Explore Shared Rulebooks';
    } else if (widget.resourceType == 'competition_groups') {
      titleText = 'Explore Shared Competition Groups';
    } else {
      titleText = 'Explore Shared Athlete Groups';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(minWidth: 800, maxWidth: 1000, minHeight: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titleText,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.resourceType == 'rulebooks'
                      ? _buildRulebooksTab(theme)
                      : widget.resourceType == 'competition_groups'
                          ? _buildCompGroupsTab(theme)
                          : _buildAthleteGroupsTab(theme),
            ),
            const SizedBox(height: 16),
            Row(
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

  Widget _buildRulebooksTab(ThemeData theme) {
    if (_eligibleRulebooks.isEmpty) {
      return const Center(child: Text('No shared rulebooks available.'));
    }
    return ListView.builder(
      itemCount: _eligibleRulebooks.length,
      itemBuilder: (context, idx) {
        final item = _eligibleRulebooks[idx];
        final key = '${item.sport}:${item.format}';
        final isApplied = _selectedRulebooks[key]?['owning_association_id'] == item.owningAssociation.id;

        return CheckboxListTile(
          title: Text('${item.sport} (${item.format})'),
          subtitle: Text('Shared by: ${item.owningAssociation.name}\nURL: ${item.url}'),
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
        );
      },
    );
  }

  Widget _buildCompGroupsTab(ThemeData theme) {
    if (_eligibleCompGroups.isEmpty) {
      return const Center(child: Text('No shared competition groups available.'));
    }
    return ListView.builder(
      itemCount: _eligibleCompGroups.length,
      itemBuilder: (context, idx) {
        final group = _eligibleCompGroups[idx];
        final isApplied = _selectedCompGroups.any((item) => item['id'] == group.id);
        final ownerAssoc = widget.allAssociations.where((a) => a.id == group.associationId).firstOrNull;
        final ownerName = ownerAssoc?.name ?? 'Other';

        return CheckboxListTile(
          title: Text(group.name),
          subtitle: Text('${group.sport} • ${group.format} (Shared by: $ownerName)'),
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
        );
      },
    );
  }

  Widget _buildAthleteGroupsTab(ThemeData theme) {
    if (_eligibleAthleteGroups.isEmpty) {
      return const Center(child: Text('No shared athlete groups available.'));
    }

    final allSelected = _eligibleAthleteGroups.every((g) =>
        _selectedAthleteGroups.any((item) => item['id'] == g.id));
    final anySelected = _eligibleAthleteGroups.any((g) =>
        _selectedAthleteGroups.any((item) => item['id'] == g.id));

    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Select All Shared Classes', style: TextStyle(fontWeight: FontWeight.bold)),
          value: allSelected,
          tristate: anySelected && !allSelected,
          onChanged: (bool? checked) {
            setState(() {
              if (checked == true) {
                for (var group in _eligibleAthleteGroups) {
                  if (!_selectedAthleteGroups.any((item) => item['id'] == group.id)) {
                    _selectedAthleteGroups.add({
                      'id': group.id,
                      'owning_association_id': group.associationId,
                    });
                  }
                }
              } else {
                for (var group in _eligibleAthleteGroups) {
                  _selectedAthleteGroups.removeWhere((item) => item['id'] == group.id);
                }
              }
            });
          },
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _eligibleAthleteGroups.length,
            itemBuilder: (context, idx) {
              final group = _eligibleAthleteGroups[idx];
              final isApplied = _selectedAthleteGroups.any((item) => item['id'] == group.id);
              final ownerAssoc = widget.allAssociations.where((a) => a.id == group.associationId).firstOrNull;
              final ownerName = ownerAssoc?.name ?? 'Other';

              return CheckboxListTile(
                title: Text(group.name),
                subtitle: Text('${group.sport} • ${group.format} • ${group.gender.toUpperCase()} (Shared by: $ownerName)'),
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
              );
            },
          ),
        ),
      ],
    );
  }
}
