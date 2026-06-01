import 'package:flutter/material.dart';

class UnifiedEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onReset;
  final String buttonText;
  final IconData icon;

  const UnifiedEmptyState({
    Key? key,
    required this.title,
    required this.message,
    this.onReset,
    this.buttonText = 'Reset All Filters',
    this.icon = Icons.search_off_outlined,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onReset != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: Text(buttonText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
