import 'package:flutter/material.dart';
import 'package:finalrep_app/models/athlete_group.dart';

class ShareAthleteGroupsSelectionDialog extends StatefulWidget {
  final String genderTitle;
  final List<AthleteGroup> ownGroups;

  const ShareAthleteGroupsSelectionDialog({
    Key? key,
    required this.genderTitle,
    required this.ownGroups,
  }) : super(key: key);

  @override
  State<ShareAthleteGroupsSelectionDialog> createState() => _ShareAthleteGroupsSelectionDialogState();
}

class _ShareAthleteGroupsSelectionDialogState extends State<ShareAthleteGroupsSelectionDialog> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.ownGroups.map((g) => g.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected = widget.ownGroups.every((g) => _selectedIds.contains(g.id));
    final anySelected = widget.ownGroups.any((g) => _selectedIds.contains(g.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 600, maxHeight: 600),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share ${widget.genderTitle} Athlete Groups',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
              value: allSelected ? true : (anySelected ? null : false),
              tristate: true,
              onChanged: (bool? val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.addAll(widget.ownGroups.map((g) => g.id));
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.ownGroups.length,
                itemBuilder: (context, idx) {
                  final group = widget.ownGroups[idx];
                  final isSelected = _selectedIds.contains(group.id);
                  return CheckboxListTile(
                    title: Text(group.name),
                    subtitle: Text('${group.sport} • ${group.format}'),
                    value: isSelected,
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(group.id);
                        } else {
                          _selectedIds.remove(group.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
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
                      : () {
                          final selectedGroups = widget.ownGroups.where((g) => _selectedIds.contains(g.id)).toList();
                          Navigator.of(context).pop(selectedGroups);
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
        ),
      ),
    );
  }
}
