import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/association.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../views/association_detail_page.dart';
import '../views/association_management_page.dart';
import '../utils/image_url_resolver.dart';

class AssociationCard extends StatefulWidget {
  final Association association;
  final bool isManagement;
  final VoidCallback? onRefresh;

  const AssociationCard({
    super.key,
    required this.association,
    this.isManagement = false,
    this.onRefresh,
  });

  @override
  State<AssociationCard> createState() => _AssociationCardState();
}

class _AssociationCardState extends State<AssociationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 900;
    final showHover = _isHovered && !isMobile;

    final logoUrl = ImageUrlResolver.resolve(context, widget.association.profilePictureUrl);
    final bannerUrl = ImageUrlResolver.resolve(context, widget.association.bannerUrl);

    // Color code badge depending on scope
    Color scopeBg;
    Color scopeText;
    final territory = widget.association.scope.toLowerCase() != 'global'
        ? (widget.association.areaName ?? widget.association.country)
        : null;
    final showTerritory = territory != null && territory.isNotEmpty;
    switch (widget.association.scope.toLowerCase()) {
      case 'global':
        scopeBg = const Color(0xFFFFB300).withOpacity(0.2);
        scopeText = const Color(0xFFFF8F00);
        break;
      case 'continental':
      case 'area':
        scopeBg = Colors.blue.withOpacity(0.2);
        scopeText = Colors.blue.shade700;
        break;
      case 'national':
        scopeBg = Colors.green.withOpacity(0.2);
        scopeText = Colors.green.shade700;
        break;
      case 'local':
      default:
        scopeBg = Colors.purple.withOpacity(0.2);
        scopeText = Colors.purple.shade700;
        break;
    }

    final initials = widget.association.name.isNotEmpty
        ? widget.association.name[0].toUpperCase()
        : 'A';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: showHover
            ? Matrix4.translationValues(0.0, -4.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showHover
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: showHover ? 2 : 1,
          ),
          boxShadow: showHover
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(
                      isDark ? 0.25 : 0.15,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: widget.isManagement ? () => _navigateToManage(context) : () => _navigateToDetails(context),
            child: Stack(
              children: [
              // Banner Area
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bannerUrl.isNotEmpty)
                      Image.network(
                        bannerUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => _buildDefaultBanner(theme),
                      )
                    else
                      _buildDefaultBanner(theme),
                  ],
                ),
              ),
              // Body Content (overlapping logo)
              Positioned(
                top: 56, // 80 - 24 overlap
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Profile image, Title, Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                                child: logoUrl.isEmpty
                                    ? Text(
                                        initials,
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimaryContainer,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8), // A little distance under the profile image
                            // Title
                            Text(
                              widget.association.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            // Description
                            SizedBox(
                              height: 45,
                              child: Text(
                                widget.association.description.isEmpty
                                    ? 'No description provided.'
                                    : widget.association.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right Column: Scope & Location badges (Location under Scope)
                      Padding(
                        padding: const EdgeInsets.only(top: 40.0), // Keep 16px below banner (80 - 56 + 16 = 40)
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Scope Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: scopeBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.association.scope.toUpperCase(),
                                style: TextStyle(
                                  color: scopeText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (showTerritory) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  territory.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDefaultBanner(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context) {
    try {
      context.push('/associations/${widget.association.id}').then((_) {
        if (widget.onRefresh != null) widget.onRefresh!();
      });
    } catch (_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssociationDetailPage(associationId: widget.association.id),
        ),
      ).then((_) {
        if (widget.onRefresh != null) widget.onRefresh!();
      });
    }
  }

  void _navigateToManage(BuildContext context) {
    context.go('/management/associations/${widget.association.id}');
  }
}

class AssociationCompactRow extends StatelessWidget {
  final Association association;
  final bool isManagement;
  final VoidCallback? onRefresh;

  const AssociationCompactRow({
    super.key,
    required this.association,
    this.isManagement = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoUrl = ImageUrlResolver.resolve(context, association.profilePictureUrl);

    // Color code badge depending on scope
    Color scopeBg;
    Color scopeText;
    switch (association.scope.toLowerCase()) {
      case 'global':
        scopeBg = const Color(0xFFFFB300).withOpacity(0.2);
        scopeText = const Color(0xFFFF8F00);
        break;
      case 'continental':
      case 'area':
        scopeBg = Colors.blue.withOpacity(0.2);
        scopeText = Colors.blue.shade700;
        break;
      case 'national':
        scopeBg = Colors.green.withOpacity(0.2);
        scopeText = Colors.green.shade700;
        break;
      case 'local':
      default:
        scopeBg = Colors.purple.withOpacity(0.2);
        scopeText = Colors.purple.shade700;
        break;
    }

    final initials = association.name.isNotEmpty
        ? association.name[0].toUpperCase()
        : 'A';

    final territory = association.scope.toLowerCase() != 'global'
        ? (association.areaName ?? association.country)
        : null;
    final showTerritory = territory != null && territory.isNotEmpty;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isManagement ? () => _navigateToManage(context) : () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                child: logoUrl.isEmpty
                    ? Text(
                        initials,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      association.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isDesktop) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Territory Badge (size matching UserCompactRow chips, if not global)
                          if (showTerritory) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                territory.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Scope Badge (size matching UserCompactRow chips)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scopeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              association.scope.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scopeText,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 16),
                // Territory Badge
                if (showTerritory) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      territory.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Scope Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scopeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    association.scope.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scopeText,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context) {
    try {
      context.push('/associations/${association.id}').then((_) {
        if (onRefresh != null) onRefresh!();
      });
    } catch (_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssociationDetailPage(associationId: association.id),
        ),
      ).then((_) {
        if (onRefresh != null) onRefresh!();
      });
    }
  }

  void _navigateToManage(BuildContext context) {
    context.go('/management/associations/${association.id}');
  }
}
