import 'package:flutter/material.dart';

class HoverableBreadcrumb extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const HoverableBreadcrumb({super.key, required this.label, required this.onTap});

  @override
  State<HoverableBreadcrumb> createState() => _HoverableBreadcrumbState();
}

class _HoverableBreadcrumbState extends State<HoverableBreadcrumb> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _isHovered ? theme.colorScheme.primary.withOpacity(0.8) : theme.colorScheme.primary,
            decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
