import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  final int itemCount;
  final String itemCountLabel;
  final String currentSortOrder;
  final Map<String, String> sortOptions;
  final ValueChanged<String> onSortChanged;
  final bool isCompactLayout;
  final ValueChanged<bool> onLayoutChanged;
  final Widget? trailing;

  const DashboardHeader({
    Key? key,
    required this.itemCount,
    required this.itemCountLabel,
    required this.currentSortOrder,
    required this.sortOptions,
    required this.onSortChanged,
    required this.isCompactLayout,
    required this.onLayoutChanged,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$itemCount $itemCountLabel',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                iconColor: theme.colorScheme.onSurfaceVariant,
                icon: Icon(
                  Icons.sort,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Sort options',
                offset: const Offset(0, 40),
                onSelected: onSortChanged,
                itemBuilder: (context) => sortOptions.entries.map((entry) {
                  return CheckedPopupMenuItem(
                    value: entry.key,
                    checked: currentSortOrder == entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Select layout',
                offset: const Offset(0, 40),
                onSelected: onLayoutChanged,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: true,
                    child: Row(
                      children: [
                        Icon(Icons.view_list, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        const Text('Compact View'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: false,
                    child: Row(
                      children: [
                        Icon(Icons.grid_view, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        const Text('Grid View'),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  isCompactLayout ? Icons.view_list : Icons.grid_view,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
