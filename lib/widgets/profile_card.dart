import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../views/profile_page.dart';

class ProfileCard extends StatefulWidget {
  final Profile profile;

  const ProfileCard({super.key, required this.profile});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobileLayout = size.width < 900;
    final showHover = _isHovered && !isMobileLayout;

    final cardRadius = theme.cardTheme.shape is RoundedRectangleBorder
        ? ((theme.cardTheme.shape as RoundedRectangleBorder).borderRadius
              as BorderRadius)
        : BorderRadius.circular(16);

    final initials = widget.profile.fullName.isNotEmpty
        ? widget.profile.fullName
            .trim()
            .split(' ')
            .map((e) => e.isEmpty ? '' : e[0])
            .take(2)
            .join()
            .toUpperCase()
        : widget.profile.username.isNotEmpty
            ? widget.profile.username[0].toUpperCase()
            : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              settings: RouteSettings(name: '/users/${widget.profile.username}'),
              builder: (_) => ProfilePage(userId: widget.profile.id),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: showHover
              ? Matrix4.translationValues(0.0, -4.0, 0.0)
              : Matrix4.identity(),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: cardRadius,
            border: Border.all(
              color: showHover
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: showHover ? 2 : 1,
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Section
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: widget.profile.profilePictureUrl != null
                    ? NetworkImage(widget.profile.profilePictureUrl!)
                    : null,
                child: widget.profile.profilePictureUrl == null
                    ? Text(
                        initials,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Info Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Username
                    Text(
                      widget.profile.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${widget.profile.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Bio Snippet
                    if (widget.profile.description != null &&
                        widget.profile.description!.isNotEmpty) ...[
                      Text(
                        widget.profile.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Gender & Country Badges
                    Row(
                      children: [
                        if (widget.profile.gender != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.profile.gender!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        if (widget.profile.gender != null &&
                            widget.profile.country != null)
                          const SizedBox(width: 8),
                        if (widget.profile.country != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  widget.profile.country!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // View Profile Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
