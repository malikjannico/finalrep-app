import 'package:flutter/material.dart';
import 'package:finalrep_app/models/association.dart';
import 'package:finalrep_app/models/admin_config.dart';

class SportConfigResult {
  final String sport;
  final List<String> formats;
  final String rulebookUrl;
  SportConfigResult({required this.sport, required this.formats, required this.rulebookUrl});
}

class SportConfigDialog extends StatefulWidget {
  final String? editSportType;
  final List<String> sports;
  final SportConfig? sportConfig;
  final Map<String, List<String>> selectedSportsFormats;
  final Map<String, TextEditingController> rulebookControllers;
  final String activeSportType;
  final Map<String, dynamic> appliedSharedResources;

  final bool hideRulebook;
  final bool limitToConfiguredFormats;
  final bool isRulebookOnly;

  const SportConfigDialog({
    Key? key,
    this.editSportType,
    required this.sports,
    required this.sportConfig,
    required this.selectedSportsFormats,
    required this.rulebookControllers,
    required this.activeSportType,
    required this.appliedSharedResources,
    this.hideRulebook = false,
    this.limitToConfiguredFormats = false,
    this.isRulebookOnly = false,
  }) : super(key: key);

  @override
  State<SportConfigDialog> createState() => _SportConfigDialogState();
}

class _SportConfigDialogState extends State<SportConfigDialog> {
  late String _localActiveSport;
  late List<String> _localActiveFormats;
  late TextEditingController _rulebookController;
  final TextEditingController _formatSearchController = TextEditingController();
  List<String> _allSportFormats = [];
  List<String> _filteredFormats = [];

  @override
  void initState() {
    super.initState();
    _localActiveSport = widget.editSportType ?? 
        (widget.sports.contains(widget.activeSportType) ? widget.activeSportType : widget.sports.first);
    _localActiveFormats = List<String>.from(widget.selectedSportsFormats[_localActiveSport] ?? []);
    _rulebookController = TextEditingController(text: widget.rulebookControllers[_localActiveSport]?.text ?? '');
    _updateFormatsList(_localActiveSport);
  }

  void _updateFormatsList(String sport) {
    var formats = widget.sportConfig?.formats
            .where((f) => f.sportName == sport)
            .map((f) => f.name)
            .toList() ??
        ['Modern', 'Classic'];

    if (widget.limitToConfiguredFormats) {
      final configured = widget.selectedSportsFormats[sport] ?? [];
      formats = formats.where((fmt) => configured.contains(fmt)).toList();
    }
    _allSportFormats = formats;

    final query = _formatSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredFormats = List<String>.from(_allSportFormats);
    } else {
      _filteredFormats = _allSportFormats
          .where((fmt) => fmt.toLowerCase().contains(query))
          .toList();
    }
  }

  @override
  void dispose() {
    _rulebookController.dispose();
    _formatSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleText = widget.isRulebookOnly
        ? (widget.editSportType == null ? 'Add Rulebook' : 'Edit Rulebook')
        : (widget.editSportType == null ? 'Add Sport and Format' : 'Edit Sport Configuration');

    return AlertDialog(
      title: Text(titleText),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.editSportType == null) ...[
              _buildCustomDropdownFieldModal<String>(
                context: context,
                labelText: 'Select Sport Type',
                value: _localActiveSport,
                prefixIcon: Icon(Icons.sports, color: theme.colorScheme.primary, size: 20),
                items: widget.sports
                    .map((s) => PopupMenuItem<String>(
                          value: s,
                          child: Text(s),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _localActiveSport = val;
                    _localActiveFormats = List<String>.from(widget.selectedSportsFormats[val] ?? []);
                    _rulebookController.text = widget.rulebookControllers[val]?.text ?? '';
                    _formatSearchController.clear();
                    _updateFormatsList(val);
                  });
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                'Sport: $_localActiveSport',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Formats *', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _formatSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Formats',
                        hintText: 'Type format name...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _updateFormatsList(_localActiveSport);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: _filteredFormats.map((fmt) {
                        final isSelected = _localActiveFormats.contains(fmt);
                        final isAppliedShared = widget.appliedSharedResources['rulebooks']?['$_localActiveSport:$fmt'] != null;
                        
                        final List<String> linked = widget.sportConfig?.links
                                .where((link) => link.sportName == _localActiveSport && link.formatName == fmt)
                                .map((link) => link.disciplineName)
                                .toList() ??
                            <String>[];
                        final List<String> discs = linked.isNotEmpty
                            ? linked
                            : (_localActiveSport == 'Streetlifting'
                                ? (fmt == 'Classic'
                                    ? ['Pull-up', 'Dip']
                                    : ['Squat', 'Pull-up', 'Dip', 'Deadlift'])
                                : <String>[]);

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
                            value: isSelected,
                            onChanged: isAppliedShared
                                ? null
                                : (bool? checked) {
                                    setState(() {
                                      if (checked == true) {
                                        if (!_localActiveFormats.contains(fmt)) {
                                          _localActiveFormats.add(fmt);
                                        }
                                      } else {
                                        _localActiveFormats.remove(fmt);
                                      }
                                    });
                                  },
                            title: Row(
                              children: [
                                Text(
                                  fmt,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (isAppliedShared) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.share,
                                          size: 10,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Shared',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontSize: 10,
                                            color: theme.colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: discs.isNotEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: discs.map((d) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          d,
                                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                        ),
                                      )).toList(),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    if (!widget.hideRulebook) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _rulebookController,
                        decoration: const InputDecoration(
                          labelText: 'Rulebook URL',
                          hintText: 'https://example.com/rules.pdf',
                          prefixIcon: Icon(Icons.link_outlined),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _localActiveFormats.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(
                    SportConfigResult(
                      sport: _localActiveSport,
                      formats: _localActiveFormats,
                      rulebookUrl: _rulebookController.text.trim(),
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE94E1B),
            foregroundColor: Colors.white,
          ),
          child: const Text('SAVE'),
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
