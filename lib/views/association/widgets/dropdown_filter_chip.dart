import 'package:flutter/material.dart';

class DropdownFilterChip<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final Set<T> selectedItems;
  final String Function(T) itemLabel;
  final Function(T, bool) onSelected;

  const DropdownFilterChip({
    Key? key,
    required this.label,
    required this.items,
    required this.selectedItems,
    required this.itemLabel,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = selectedItems.isNotEmpty;
    final menuKey = GlobalKey<PopupMenuButtonState<T>>();

    final labelText = hasSelection
        ? '$label: ${selectedItems.map(itemLabel).join(", ")}'
        : label;

    return Theme(
      data: theme.copyWith(
        cardColor: theme.colorScheme.surface,
      ),
      child: PopupMenuButton<T>(
        key: menuKey,
        tooltip: label,
        offset: const Offset(0, 40),
        onSelected: (item) {
          final isSelected = selectedItems.contains(item);
          onSelected(item, !isSelected);
        },
        itemBuilder: (BuildContext context) {
          return items.map((item) {
            final isSelected = selectedItems.contains(item);
            return PopupMenuItem<T>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isSelected ? const Color(0xFFE94E1B) : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    itemLabel(item),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }).toList();
        },
        child: FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: hasSelection ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          selected: hasSelection,
          onSelected: (_) {
            menuKey.currentState?.showButtonMenu();
          },
        ),
      ),
    );
  }
}
