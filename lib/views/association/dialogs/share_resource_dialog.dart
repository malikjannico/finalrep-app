import 'package:flutter/material.dart';
import 'package:finalrep_app/models/association.dart';

class ShareResourceDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic> initialConfig;
  final Association currentAssociation;
  final List<Association> allAssociations;

  const ShareResourceDialog({
    Key? key,
    required this.title,
    required this.initialConfig,
    required this.currentAssociation,
    required this.allAssociations,
  }) : super(key: key);

  @override
  State<ShareResourceDialog> createState() => _ShareResourceDialogState();
}

class _ShareResourceDialogState extends State<ShareResourceDialog> {
  late String _mode;
  late List<String> _targets;
  final TextEditingController _searchController = TextEditingController();
  List<Association> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialConfig['mode'] as String? ?? 'private';
    _targets = List<String>.from(widget.initialConfig['targets'] as List? ?? []);
    _performSearch('');
  }

  void _performSearch(String query) {
    final term = query.trim().toLowerCase();
    setState(() {
      _searchResults = widget.allAssociations.where((assoc) {
        if (assoc.id == widget.currentAssociation.id) return false;
        if (term.isEmpty) return true;
        return assoc.name.toLowerCase().contains(term) ||
               assoc.scope.toLowerCase().contains(term);
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          minWidth: isMobile ? 0 : 700,
          maxWidth: isMobile ? 600 : 900,
          minHeight: isMobile ? 300 : 500,
          maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.9 : 700,
        ),
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _mode,
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
                            _mode = val;
                          });
                        }
                      },
                    ),
                    if (_mode == 'specific') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: _performSearch,
                        decoration: const InputDecoration(
                          labelText: 'Search Associations to Share with',
                          hintText: 'Search by name or scope...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select Associations to Share with (${_targets.length} selected)',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _searchResults.isEmpty
                            ? const Center(child: Text('No associations found.'))
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, idx) {
                                  final assoc = _searchResults[idx];
                                  final isSelected = _targets.contains(assoc.id);
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
                                      onChanged: (bool? checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _targets.add(assoc.id);
                                          } else {
                                            _targets.remove(assoc.id);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop({
                            'mode': _mode,
                            'targets': _targets,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('SAVE'),
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
                            'mode': _mode,
                            'targets': _targets,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94E1B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('SAVE'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
