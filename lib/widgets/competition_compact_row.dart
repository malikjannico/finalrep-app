import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/competition.dart';

class CompetitionCompactRow extends StatelessWidget {
  final Competition competition;
  final VoidCallback onTap;

  const CompetitionCompactRow({
    super.key,
    required this.competition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 80,
          padding: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMM dd').format(competition.startDate).toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),
              Text(
                DateFormat('yyyy').format(competition.startDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          competition.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Format chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  competition.sportSubtype.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
                ),
              ),
              // Location chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  competition.location,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
                ),
              ),
              // Disciplines chips
              ...competition.disciplines.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _abbreviateDiscipline(d),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        onTap: onTap,
      ),
    );
  }

  String _abbreviateDiscipline(String discipline) {
    switch (discipline.toLowerCase()) {
      case 'muscle up':
        return 'MU';
      case 'pull up':
        return 'PU';
      case 'dip':
        return 'DP';
      case 'squat':
        return 'SQ';
      default:
        return discipline;
    }
  }
}
