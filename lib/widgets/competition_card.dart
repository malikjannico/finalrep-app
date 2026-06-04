import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/competition.dart';
import '../models/admin_config.dart';
import '../providers/competition_provider.dart';
import '../views/competition_detail_page.dart';

class CompetitionCard extends StatefulWidget {
  final Competition competition;
  final bool isManagement;
  final VoidCallback? onTap;

  const CompetitionCard({
    super.key,
    required this.competition,
    this.isManagement = false,
    this.onTap,
  });

  @override
  State<CompetitionCard> createState() => _CompetitionCardState();
}

class _CompetitionCardState extends State<CompetitionCard> {
  bool _isHovered = false;


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
        borderRadius: BorderRadius.circular(12),
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
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobileLayout = size.width < 900;
    final showHover = _isHovered && !isMobileLayout;

    // Formatting date and time
    final format = DateFormat('MMM dd, yyyy, HH:mm');
    final startStr = format.format(widget.competition.startDate);
    final endStr = format.format(widget.competition.endDate);
    final dateRangeStr = '$startStr - $endStr';

    final cardRadius = theme.cardTheme.shape is RoundedRectangleBorder
        ? ((theme.cardTheme.shape as RoundedRectangleBorder).borderRadius
              as BorderRadius)
        : BorderRadius.circular(16);

    final compProvider = Provider.of<CompetitionProvider>(context);

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

    final city = widget.competition.city;
    final country = widget.competition.country;
    final displayLocation = (city != null && city.isNotEmpty && country != null && country.isNotEmpty)
        ? '$city, $country'
        : widget.competition.location;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap ?? () {
          if (widget.isManagement) {
            context.go('/management/competitions/${widget.competition.id}');
          } else {
            try {
              context.push('/competitions/${widget.competition.id}');
            } catch (_) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CompetitionDetailPage(competitionId: widget.competition.id),
                ),
              );
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: showHover
              ? Matrix4.translationValues(0.0, -4.0, 0.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: cardRadius,
            border: Border.all(
              color: showHover ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: 1,
            ),
            boxShadow: showHover
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.25 : 0.15,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Image Section without Shadow and Floating Badges
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(cardRadius.topLeft.x - 1),
                ),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Title Image or Fallback Gradient
                      Positioned.fill(child: _buildTitleImage(context, theme)),
                    ],
                  ),
                ),
              ),

              // Text and details section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStatusBadge(context, theme, widget.competition.status),
                          if (widget.competition.isPartOfGroup) ...[
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
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        widget.competition.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Sport & Format with disciplines
                      Row(
                        children: [
                          Icon(
                            Icons.fitness_center_outlined,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$sport, $formatName${abbrList.isNotEmpty ? ' (${abbrList.join(', ')})' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Details: Location (city, country only)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              displayLocation,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Details: Date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              dateRangeStr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 11.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleImage(BuildContext context, ThemeData theme) {
    final path = widget.competition.titleImageUrl;
    if (path == null || path.trim().isEmpty) {
      return _buildDefaultGradient(theme);
    }

    if (path.startsWith('http') || path.startsWith('https')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildDefaultGradient(theme),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    } else if (path.startsWith('/')) {
      final apiBaseUrl = Provider.of<CompetitionProvider>(context, listen: false).competitionRepository.baseUrl;
      return Image.network(
        '$apiBaseUrl$path',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildDefaultGradient(theme),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildDefaultGradient(theme),
      );
    }
  }

  Widget _buildDefaultGradient(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fitness_center_outlined,
          size: 40,
          color: theme.colorScheme.onPrimary.withValues(alpha: 0.4),
        ),
      ),
    );
  }


}
