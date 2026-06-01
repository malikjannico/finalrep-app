import 'package:flutter/material.dart';
import 'package:finalrep_app/models/athlete_group.dart';

class AthleteGroupsReorderDialog extends StatefulWidget {
  final List<AthleteGroup> athleteGroups;

  const AthleteGroupsReorderDialog({
    Key? key,
    required this.athleteGroups,
  }) : super(key: key);

  @override
  State<AthleteGroupsReorderDialog> createState() => _AthleteGroupsReorderDialogState();
}

class _AthleteGroupsReorderDialogState extends State<AthleteGroupsReorderDialog> {
  late List<AthleteGroup> _tempList;

  @override
  void initState() {
    super.initState();
    _tempList = List.from(widget.athleteGroups);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Reorder Athlete Groups'),
      content: Container(
        width: 500,
        height: 400,
        child: ReorderableListView.builder(
          itemCount: _tempList.length,
          itemBuilder: (context, index) {
            final ag = _tempList[index];
            return ListTile(
              key: ValueKey(ag.id),
              leading: const Icon(Icons.drag_handle),
              title: Text(ag.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${ag.sport} • ${ag.format} • ${ag.gender == 'women' ? 'Women' : (ag.gender.isEmpty ? '' : ag.gender[0].toUpperCase() + ag.gender.substring(1))}'),
            );
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = _tempList.removeAt(oldIndex);
              _tempList.insert(newIndex, item);
            });
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_tempList),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE94E1B),
            foregroundColor: Colors.white,
          ),
          child: const Text('SAVE ORDER'),
        ),
      ],
    );
  }
}
