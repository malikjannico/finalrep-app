import 'package:flutter/material.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/utils/image_url_resolver.dart';

class AddSubAssociationDialog extends StatefulWidget {
  final Association currentAssociation;
  final List<Association> allAssociations;

  const AddSubAssociationDialog({
    Key? key,
    required this.currentAssociation,
    required this.allAssociations,
  }) : super(key: key);

  @override
  State<AddSubAssociationDialog> createState() => _AddSubAssociationDialogState();
}

class _AddSubAssociationDialogState extends State<AddSubAssociationDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  List<Association> _searchResults = [];
  Set<String> _excludedIds = {};

  @override
  void initState() {
    super.initState();
    _computeExcludedIds();
    _performSearch('');
  }

  void _computeExcludedIds() {
    final ancestors = <String>{};
    String? currentParentId = widget.currentAssociation.parentAssociationId;
    while (currentParentId != null && !ancestors.contains(currentParentId)) {
      ancestors.add(currentParentId);
      final parent = widget.allAssociations.where((a) => a.id == currentParentId).firstOrNull;
      currentParentId = parent?.parentAssociationId;
    }

    _excludedIds = {
      widget.currentAssociation.id,
      ...ancestors,
      ...widget.allAssociations
          .where((a) => a.parentAssociationId == widget.currentAssociation.id)
          .map((a) => a.id),
    };
  }

  void _performSearch(String query) {
    final term = query.trim().toLowerCase();
    setState(() {
      _searchResults = widget.allAssociations.where((assoc) {
        if (_excludedIds.contains(assoc.id)) return false;
        if (term.isEmpty) return true;
        return assoc.name.toLowerCase().contains(term) ||
               assoc.scope.toLowerCase().contains(term) ||
               (assoc.description.toLowerCase().contains(term));
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final allSelected = _searchResults.isNotEmpty && _searchResults.every((a) => _selectedIds.contains(a.id));
    final anySelected = _searchResults.any((a) => _selectedIds.contains(a.id));

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
                    'Add Sub-Associations',
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
            TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name, description or scope...',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedIds.length} selected',
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
                            for (var assoc in _searchResults) {
                              _selectedIds.add(assoc.id);
                            }
                          } else {
                            for (var assoc in _searchResults) {
                              _selectedIds.remove(assoc.id);
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
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(child: Text('No available associations found.'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, idx) {
                        final assoc = _searchResults[idx];
                        final isSelected = _selectedIds.contains(assoc.id);
                        final logoUrl = ImageUrlResolver.resolve(context, assoc.profilePictureUrl);
                        final initials = assoc.name.isNotEmpty ? assoc.name[0].toUpperCase() : 'A';

                        final territory = assoc.scope.toLowerCase() != 'global'
                            ? (assoc.areaName ?? assoc.country)
                            : null;
                        final showTerritory = territory != null && territory.isNotEmpty;

                        final scopeLabel = assoc.scope.isEmpty ? '' : assoc.scope[0].toUpperCase() + assoc.scope.substring(1).toLowerCase();
                        final territoryLabel = territory != null && territory.isNotEmpty ? territory[0].toUpperCase() + territory.substring(1).toLowerCase() : '';

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
                            secondary: CircleAvatar(
                              radius: 16,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                              child: logoUrl.isEmpty
                                  ? Text(
                                      initials,
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimaryContainer,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(assoc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (showTerritory)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        territoryLabel,
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
                                      scopeLabel,
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            value: isSelected,
                            onChanged: (bool? val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.add(assoc.id);
                                } else {
                                  _selectedIds.remove(assoc.id);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(_selectedIds.toList()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('ADD'),
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
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(_selectedIds.toList()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('ADD'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
