import 'package:flutter/material.dart';
import 'package:finalrep_app/models/association.dart';

class ShareResourceMultiDialog<T> extends StatefulWidget {
  final String title;
  final List<T> ownItems;
  final String Function(T) itemHeadline;
  final List<String> Function(T) itemSubtitles;
  final List<String> Function(T)? itemGenders;
  final String Function(T) itemSport;
  final String Function(T) Function()? itemFormat; // Optional, or string extractor
  final List<String> filterSports;
  final List<String> filterFormats;
  final List<String>? filterGenders;
  final Association currentAssociation;
  final List<Association> allAssociations;
  final Map<String, dynamic>? initialSharingConfig;

  const ShareResourceMultiDialog({
    Key? key,
    required this.title,
    required this.ownItems,
    required this.itemHeadline,
    required this.itemSubtitles,
    this.itemGenders,
    required this.itemSport,
    this.itemFormat,
    required this.filterSports,
    required this.filterFormats,
    this.filterGenders,
    required this.currentAssociation,
    required this.allAssociations,
    this.initialSharingConfig,
  }) : super(key: key);

  @override
  State<ShareResourceMultiDialog<T>> createState() => _ShareResourceMultiDialogState<T>();
}

class _ShareResourceMultiDialogState<T> extends State<ShareResourceMultiDialog<T>> {
  int _currentStep = 1; // 1 for selection, 2 for sharing configuration

  // Step 1: Selection states
  final Set<T> _selectedItems = {};
  String _searchQuery = '';
  final Set<String> _selectedSports = {};
  final Set<String> _selectedFormats = {};
  final Set<String> _selectedGenders = {};

  // Step 2: Sharing configuration states
  String _sharingMode = 'private';
  final Set<String> _targetAssociationIds = {};
  String _assocSearchQuery = '';
  final Set<String> _assocSelectedScopes = {};
  final Set<String> _assocSelectedCountries = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialSharingConfig != null) {
      _sharingMode = widget.initialSharingConfig!['mode'] as String? ?? 'private';
      final targetsList = widget.initialSharingConfig!['targets'] as List? ?? [];
      _targetAssociationIds.addAll(targetsList.map((e) => e.toString()));
    }
  }

  // Filtered own items for Step 1
  List<T> get _filteredOwnItems {
    final query = _searchQuery.trim().toLowerCase();
    return widget.ownItems.where((item) {
      final headline = widget.itemHeadline(item).toLowerCase();
      final matchesQuery = query.isEmpty || headline.contains(query);

      final sport = widget.itemSport(item);
      final matchesSport = _selectedSports.isEmpty || _selectedSports.contains(sport);

      final format = widget.itemSubtitles(item).firstWhere((s) => widget.filterFormats.contains(s), orElse: () => '');
      final matchesFormat = _selectedFormats.isEmpty || _selectedFormats.contains(format);

      bool matchesGender = true;
      if (widget.itemGenders != null && _selectedGenders.isNotEmpty) {
        final genders = widget.itemGenders!(item);
        matchesGender = genders.any((g) => _selectedGenders.contains(g));
      }

      return matchesQuery && matchesSport && matchesFormat && matchesGender;
    }).toList();
  }

  // Filtered target associations for Step 2
  List<Association> get _filteredTargetAssociations {
    final query = _assocSearchQuery.trim().toLowerCase();
    return widget.allAssociations.where((assoc) {
      if (assoc.id == widget.currentAssociation.id) return false;

      final matchesQuery = query.isEmpty ||
          assoc.name.toLowerCase().contains(query) ||
          assoc.scope.toLowerCase().contains(query);

      final matchesScope = _assocSelectedScopes.isEmpty || _assocSelectedScopes.contains(assoc.scope);

      final country = assoc.country ?? 'Global';
      final matchesCountry = _assocSelectedCountries.isEmpty || _assocSelectedCountries.contains(country);

      return matchesQuery && matchesScope && matchesCountry;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(minWidth: 700, maxWidth: 900, minHeight: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24.0),
        child: _currentStep == 1
            ? _buildStep1(theme)
            : _buildStep2(theme),
      ),
    );
  }

  // STEP 1 UI: Resource Selection
  Widget _buildStep1(ThemeData theme) {
    final items = _filteredOwnItems;
    final allSelected = items.isNotEmpty && items.every((i) => _selectedItems.contains(i));
    final anySelected = items.any((i) => _selectedItems.contains(i));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modal Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Search bar
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search items...',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        const SizedBox(height: 12),
        // Filter chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...widget.filterSports.map((sport) {
                final isSelected = _selectedSports.contains(sport);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(sport),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSports.add(sport);
                        } else {
                          _selectedSports.remove(sport);
                        }
                      });
                    },
                  ),
                );
              }),
              ...widget.filterFormats.map((fmt) {
                final isSelected = _selectedFormats.contains(fmt);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(fmt),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFormats.add(fmt);
                        } else {
                          _selectedFormats.remove(fmt);
                        }
                      });
                    },
                  ),
                );
              }),
              if (widget.filterGenders != null)
                ...widget.filterGenders!.map((g) {
                  final isSelected = _selectedGenders.contains(g);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(g),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedGenders.add(g);
                          } else {
                            _selectedGenders.remove(g);
                          }
                        });
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Selection info / Select All bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedItems.length} selected',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                const Text('Select All shown'),
                Checkbox(
                  value: allSelected ? true : (anySelected ? null : false),
                  tristate: true,
                  activeColor: const Color(0xFFE94E1B),
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedItems.addAll(items);
                      } else {
                        for (var item in items) {
                          _selectedItems.remove(item);
                        }
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const Divider(),
        // Resources list
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No items match filters.'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final isSelected = _selectedItems.contains(item);
                    final headline = widget.itemHeadline(item);
                    final subs = widget.itemSubtitles(item);

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
                        title: Text(headline, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Wrap(
                            spacing: 6,
                            children: subs.map((sub) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  sub,
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        value: isSelected,
                        onChanged: (bool? val) {
                          setState(() {
                            if (val == true) {
                              _selectedItems.add(item);
                            } else {
                              _selectedItems.remove(item);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _selectedItems.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _currentStep = 2;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E1B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('NEXT'),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 2 UI: Sharing Config
  Widget _buildStep2(ThemeData theme) {
    final targets = _filteredTargetAssociations;
    final allCountries = widget.allAssociations
        .map((e) => e.country ?? 'Global')
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modal Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Set Sharing Mode & Targets',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Dropdown
        DropdownButtonFormField<String>(
          value: _sharingMode,
          decoration: const InputDecoration(
            labelText: 'Sharing Mode',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
          items: const [
            DropdownMenuItem(value: 'private', child: Text('Private (No sharing)')),
            DropdownMenuItem(value: 'sub_recursive', child: Text('All Sub-Associations (Recursive)')),
            DropdownMenuItem(value: 'parent_recursive', child: Text('All Parent Associations (Recursive)')),
            DropdownMenuItem(value: 'specific', child: Text('Specific Selected Associations')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _sharingMode = val;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        // If specific mode is selected, show search/filters/list of target associations
        if (_sharingMode == 'specific') ...[
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search target associations...',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            onChanged: (val) {
              setState(() {
                _assocSearchQuery = val;
              });
            },
          ),
          const SizedBox(height: 8),
          // Association filter chips (scope, country)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...['global', 'continental', 'national', 'local'].map((scope) {
                  final isSelected = _assocSelectedScopes.contains(scope);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(scope.toUpperCase()),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _assocSelectedScopes.add(scope);
                          } else {
                            _assocSelectedScopes.remove(scope);
                          }
                        });
                      },
                    ),
                  );
                }),
                ...allCountries.map((country) {
                  final isSelected = _assocSelectedCountries.contains(country);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(country),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _assocSelectedCountries.add(country);
                          } else {
                            _assocSelectedCountries.remove(country);
                          }
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select Target Associations (${_targetAssociationIds.length} selected)',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: targets.isEmpty
                ? const Center(child: Text('No associations found.'))
                : ListView.builder(
                    itemCount: targets.length,
                    itemBuilder: (context, idx) {
                      final assoc = targets[idx];
                      final isSelected = _targetAssociationIds.contains(assoc.id);
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
                          title: Text(assoc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${assoc.scope.toUpperCase()} • ${assoc.country ?? "Global"}'),
                          value: isSelected,
                          onChanged: (bool? checked) {
                            setState(() {
                              if (checked == true) {
                                _targetAssociationIds.add(assoc.id);
                              } else {
                                _targetAssociationIds.remove(assoc.id);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ] else ...[
          const Spacer(),
        ],
        const SizedBox(height: 16),
        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              child: const Text('BACK'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'items': _selectedItems.toList(),
                  'sharing': {
                    'mode': _sharingMode,
                    'targets': _targetAssociationIds.toList(),
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94E1B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('SHARE'),
            ),
          ],
        ),
      ],
    );
  }
}
