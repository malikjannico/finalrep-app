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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(minWidth: 800, minHeight: 400, maxWidth: 1200),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Sub-Associations',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: _performSearch,
                decoration: InputDecoration(
                  labelText: 'Search existing associations',
                  hintText: 'Search by name or scope...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _performSearch(_searchController.text),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Available Associations (${_searchResults.length})',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _searchResults.isEmpty
                    ? const Center(child: Text('No available associations found.'))
                    : SingleChildScrollView(
                        child: Column(
                          children: _searchResults.map((assoc) {
                            final isSelected = _selectedIds.contains(assoc.id);
                            final logoUrl = ImageUrlResolver.resolve(context, assoc.profilePictureUrl);
                            final initials = assoc.name.isNotEmpty ? assoc.name[0].toUpperCase() : 'A';

                            return CheckboxListTile(
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
                              title: Text(assoc.name),
                              subtitle: Text(
                                assoc.scope.toUpperCase() + (assoc.country != null ? ' - ${assoc.country}' : ''),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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
                            );
                          }).toList(),
                        ),
                      ),
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
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_selectedIds.toList()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94E1B),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('ADD'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
