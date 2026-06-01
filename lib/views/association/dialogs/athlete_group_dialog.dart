import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/models/admin_config.dart';
import 'package:finalrep_app/providers/competition_provider.dart';

class AthleteGroupDialog extends StatefulWidget {
  final AthleteGroup? group;
  final Association association;
  final SportConfig? sportConfig;

  const AthleteGroupDialog({
    Key? key,
    this.group,
    required this.association,
    this.sportConfig,
  }) : super(key: key);

  @override
  State<AthleteGroupDialog> createState() => _AthleteGroupDialogState();
}

class _AthleteGroupDialogState extends State<AthleteGroupDialog> {
  late TextEditingController _nameController;
  late String _sport;
  late String _format;
  late String _gender;
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
    
    final rawGender = (widget.group?.gender ?? 'men').toLowerCase();
    if (rawGender == 'male' || rawGender == 'men') {
      _gender = 'men';
    } else if (rawGender == 'female' || rawGender == 'woman' || rawGender == 'women') {
      _gender = 'women';
    } else {
      _gender = 'open';
    }
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
      title: Text(widget.group == null ? 'Add Athlete Class' : 'Edit Athlete Class'),
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
                  hintText: 'e.g. -80kg Male',
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
              const SizedBox(height: 16),
              _buildCustomDropdownFieldModal<String>(
                context: context,
                labelText: 'Gender',
                value: _gender,
                displayValue: (val) => val == 'women' ? 'Women' : val[0].toUpperCase() + val.substring(1),
                items: const [
                  PopupMenuItem(value: 'men', child: Text('Men')),
                  PopupMenuItem(value: 'women', child: Text('Women')),
                  PopupMenuItem(value: 'open', child: Text('Open')),
                ],
                onChanged: (val) {
                  setState(() {
                    _gender = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        if (widget.group == null)
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.trim().isEmpty) return;
              final name = _nameController.text.trim();
              final newGroup = AthleteGroup(
                id: 'ag-${DateTime.now().millisecondsSinceEpoch}',
                associationId: widget.association.id,
                name: name,
                sport: _sport,
                format: _format,
                gender: _gender,
                isActive: _isActive,
              );
              final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
              final created = await compProvider.createAthleteGroup(newGroup);
              if (mounted) {
                if (created != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Athlete class "$name" created successfully.')),
                  );
                  setState(() {
                    _nameController.clear();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to create athlete class.')),
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
            Navigator.of(context).pop(AthleteGroup(
              id: widget.group?.id ?? 'ag-${DateTime.now().millisecondsSinceEpoch}',
              associationId: widget.association.id,
              name: _nameController.text.trim(),
              sport: _sport,
              format: _format,
              gender: _gender,
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
