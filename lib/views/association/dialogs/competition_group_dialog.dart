import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/competition_group.dart';
import 'package:finalrep_app/models/admin_config.dart';
import 'package:finalrep_app/providers/competition_provider.dart';

class CompetitionGroupDialog extends StatefulWidget {
  final CompetitionGroup? group;
  final Association association;
  final SportConfig? sportConfig;

  const CompetitionGroupDialog({
    Key? key,
    this.group,
    required this.association,
    this.sportConfig,
  }) : super(key: key);

  @override
  State<CompetitionGroupDialog> createState() => _CompetitionGroupDialogState();
}

class _CompetitionGroupDialogState extends State<CompetitionGroupDialog> {
  late TextEditingController _nameController;
  late String _sport;
  late String _format;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _sport = widget.group?.sport ?? 
        (widget.association.supportedSports.isNotEmpty 
            ? widget.association.supportedSports.first 
            : 'Streetlifting');
    
    final validFormats = widget.sportConfig?.formats
            .where((f) => f.sportName == _sport)
            .map((f) => f.name)
            .toList() ?? ['Modern', 'Classic'];
    final available = widget.association.supportedFormats
            .where((f) => validFormats.contains(f))
            .toList();
    if (available.isEmpty) available.addAll(['Modern', 'Classic']);
    
    _format = widget.group?.format ?? available.first;
    _isActive = widget.group?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validFormats = widget.sportConfig?.formats
            .where((f) => f.sportName == _sport)
            .map((f) => f.name)
            .toList() ?? ['Modern', 'Classic'];
    final availableFormats = widget.association.supportedFormats
            .where((f) => validFormats.contains(f))
            .toList();
    if (availableFormats.isEmpty) availableFormats.addAll(['Modern', 'Classic']);

    return AlertDialog(
      title: Text(widget.group == null ? 'Add Competition Group' : 'Edit Competition Group'),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g. FinalRep Qualifier',
                ),
              ),
              const SizedBox(height: 16),
              _buildCustomDropdownFieldModal<String>(
                context: context,
                labelText: 'Sport Type',
                value: _sport,
                items: widget.association.supportedSports
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _sport = val;
                    final nextValid = widget.sportConfig?.formats
                            .where((f) => f.sportName == val)
                            .map((f) => f.name)
                            .toList() ?? ['Modern', 'Classic'];
                    final nextAvailable = widget.association.supportedFormats
                            .where((f) => nextValid.contains(f))
                            .toList();
                    if (nextAvailable.isEmpty) nextAvailable.addAll(['Modern', 'Classic']);
                    if (!nextAvailable.contains(_format)) {
                      _format = nextAvailable.first;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildCustomDropdownFieldModal<String>(
                context: context,
                labelText: 'Format',
                value: _format,
                items: availableFormats
                    .map((f) => PopupMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _format = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: MediaQuery.of(context).size.width < 600
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (_nameController.text.trim().isEmpty) return;
                        Navigator.of(context).pop(CompetitionGroup(
                          id: widget.group?.id ?? 'cg-${DateTime.now().millisecondsSinceEpoch}',
                          associationId: widget.association.id,
                          name: _nameController.text.trim(),
                          sport: _sport,
                          format: _format,
                          isActive: _isActive,
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94E1B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(widget.group == null ? 'CREATE' : 'SAVE'),
                    ),
                    if (widget.group == null) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (_nameController.text.trim().isEmpty) return;
                          final name = _nameController.text.trim();
                          final newGroup = CompetitionGroup(
                            id: 'cg-${DateTime.now().millisecondsSinceEpoch}',
                            associationId: widget.association.id,
                            name: name,
                            sport: _sport,
                            format: _format,
                            isActive: _isActive,
                          );
                          final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                          final created = await compProvider.createCompetitionGroup(newGroup);
                          if (mounted) {
                            if (created != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Competition group "$name" created successfully.')),
                              );
                              setState(() {
                                _nameController.clear();
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to create competition group.')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('SAVE + CREATE'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ],
                ),
              )
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
              if (widget.group == null)
                ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) return;
                    final name = _nameController.text.trim();
                    final newGroup = CompetitionGroup(
                      id: 'cg-${DateTime.now().millisecondsSinceEpoch}',
                      associationId: widget.association.id,
                      name: name,
                      sport: _sport,
                      format: _format,
                      isActive: _isActive,
                    );
                    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
                    final created = await compProvider.createCompetitionGroup(newGroup);
                    if (mounted) {
                      if (created != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Competition group "$name" created successfully.')),
                        );
                        setState(() {
                          _nameController.clear();
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to create competition group.')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                  child: const Text('SAVE + CREATE'),
                ),
              ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isEmpty) return;
                  Navigator.of(context).pop(CompetitionGroup(
                    id: widget.group?.id ?? 'cg-${DateTime.now().millisecondsSinceEpoch}',
                    associationId: widget.association.id,
                    name: _nameController.text.trim(),
                    sport: _sport,
                    format: _format,
                    isActive: _isActive,
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE94E1B),
                  foregroundColor: Colors.white,
                ),
                child: Text(widget.group == null ? 'CREATE' : 'SAVE'),
              ),
            ],
    );
  }

  Widget _buildCustomDropdownFieldModal<T>({
    required BuildContext context,
    required String labelText,
    required T value,
    required List<PopupMenuEntry<T>> items,
    required Function(T) onChanged,
    Widget? prefixIcon,
    String Function(T)? displayValue,
  }) {
    final theme = Theme.of(context);
    final displayStr = displayValue != null ? displayValue(value) : value.toString();
    return Theme(
      data: theme.copyWith(
        cardColor: theme.colorScheme.surface,
      ),
      child: PopupMenuButton<T>(
        tooltip: labelText,
        offset: const Offset(0, 48),
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => items,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            prefixIcon: prefixIcon,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
