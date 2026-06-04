import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/competition.dart';
import '../models/admin_config.dart';
import '../providers/competition_provider.dart';

class CompetitionCompactRow extends StatefulWidget {
  final Competition competition;
  final VoidCallback onTap;

  const CompetitionCompactRow({
    super.key,
    required this.competition,
    required this.onTap,
  });

  @override
  State<CompetitionCompactRow> createState() => _CompetitionCompactRowState();
}

class _CompetitionCompactRowState extends State<CompetitionCompactRow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildStatusBadge(BuildContext context, ThemeData theme, String status) {
    String text = status.toUpperCase();
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color textCol = theme.colorScheme.onSurfaceVariant;
    final normalized = status.toLowerCase().replaceAll('_', ' ');

    if (normalized == 'draft') {
      text = 'DRAFT';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'published') {
      text = 'PUBLISHED';
      bg = theme.colorScheme.secondaryContainer.withValues(alpha: 0.5);
      textCol = theme.colorScheme.onSecondaryContainer;
    } else if (normalized == 'registration started' || normalized == 'registration open') {
      text = 'REGISTRATION OPEN';
      bg = theme.colorScheme.primaryContainer;
      textCol = theme.colorScheme.onPrimaryContainer;
    } else if (normalized == 'registration closed' || normalized == 'registration completed') {
      text = 'REGISTRATION CLOSED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'payment started' || normalized == 'payment open') {
      text = 'PAYMENT OPEN';
      bg = theme.colorScheme.secondaryContainer;
      textCol = theme.colorScheme.onSecondaryContainer;
    } else if (normalized == 'payment completed') {
      text = 'PAYMENT COMPLETED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    } else if (normalized == 'competition started' || normalized == 'ongoing') {
      text = 'ONGOING';
      bg = theme.colorScheme.tertiaryContainer;
      textCol = theme.colorScheme.onTertiaryContainer;
    } else if (normalized == 'competition completed' || normalized == 'completed') {
      text = 'COMPLETED';
      bg = theme.colorScheme.surfaceContainerHighest;
      textCol = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textCol,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context);

    // Resolve Location
    final city = widget.competition.city;
    final country = widget.competition.country;
    final displayLocation = (city != null && city.isNotEmpty && country != null && country.isNotEmpty)
        ? '$city, $country'
        : widget.competition.location;

    // Resolve Sport and Format with abbreviations
    final sport = widget.competition.sportType;
    final formatName = widget.competition.sportSubtype;
    List<String> abbrList = [];
    if (compProvider.sportConfig != null) {
      final links = compProvider.sportConfig!.links.where((l) =>
        l.sportName.toLowerCase() == sport.toLowerCase() &&
        l.formatName.toLowerCase() == formatName.toLowerCase()
      ).toList();
      final disciplines = compProvider.sportConfig!.disciplines;
      for (final link in links) {
        final d = disciplines.firstWhere(
          (dep) => dep.name.toLowerCase() == link.disciplineName.toLowerCase(),
          orElse: () => DisciplineDefinition(name: link.disciplineName),
        );
        if (d.abbreviation != null && d.abbreviation!.isNotEmpty) {
          abbrList.add(d.abbreviation!);
        }
      }
    }
    final sportFormatText = '$sport, $formatName${abbrList.isNotEmpty ? ' (${abbrList.join(', ')})' : ''}';

    // Date range logic
    final startDate = widget.competition.startDate;
    final endDate = widget.competition.endDate;
    
    String monthDayStr;
    String yearStr = DateFormat('yyyy').format(startDate);

    if (startDate.year == endDate.year) {
      if (startDate.month == endDate.month) {
        if (startDate.day == endDate.day) {
          monthDayStr = '${DateFormat('MMM').format(startDate).toUpperCase()} ${DateFormat('dd').format(startDate)}';
        } else {
          monthDayStr = '${DateFormat('MMM').format(startDate).toUpperCase()} ${DateFormat('dd').format(startDate)} - ${DateFormat('dd').format(endDate)}';
        }
      } else {
        monthDayStr = '${DateFormat('MMM dd').format(startDate).toUpperCase()} - ${DateFormat('MMM dd').format(endDate).toUpperCase()}';
      }
    } else {
      monthDayStr = '${DateFormat('MMM dd, yy').format(startDate).toUpperCase()} - ${DateFormat('MMM dd, yy').format(endDate).toUpperCase()}';
      yearStr = '';
    }

    final chipsList = [
      _buildStatusBadge(context, theme, widget.competition.status),
      if (widget.competition.isPartOfGroup)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.competition.compGroupName!.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      // Location (raw inline details, not as chips)
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            displayLocation,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
      // Sport and format (raw inline details, not as chips)
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            sportFormatText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    ];

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            horizontalTitleGap: 12,
            onTap: widget.onTap,
            leading: Container(
              width: 105,
              padding: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      monthDayStr,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (yearStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      yearStr,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.competition.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: chipsList,
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
