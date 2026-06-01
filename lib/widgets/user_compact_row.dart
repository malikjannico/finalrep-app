import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../views/profile_page.dart';
import '../providers/competition_provider.dart';

class UserCompactRow extends StatefulWidget {
  final Profile profile;
  final VoidCallback? onTap;

  const UserCompactRow({super.key, required this.profile, this.onTap});

  @override
  State<UserCompactRow> createState() => _UserCompactRowState();
}

class _UserCompactRowState extends State<UserCompactRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobileLayout = size.width < 900;
    final showHover = _isHovered && !isMobileLayout;

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
        onTap: widget.onTap ??
            () {
              try {
                context.push('/users/${widget.profile.username}');
              } catch (_) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(username: widget.profile.username),
                  ),
                );
              }
            },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: showHover
                ? theme.colorScheme.primaryContainer.withValues(
                    alpha: isDark ? 0.15 : 0.4,
                  )
                : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showHover
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Small Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage:
                    widget.profile.profilePictureUrl != null &&
                        widget.profile.profilePictureUrl!.isNotEmpty
                    ? NetworkImage(widget.profile.profilePictureUrl!)
                    : null,
                child:
                    widget.profile.profilePictureUrl == null ||
                        widget.profile.profilePictureUrl!.isEmpty
                    ? Text(
                        initials,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.profile.fullName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${widget.profile.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Country flag/badge if present
              if (widget.profile.country != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 10,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 4),
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
                if (widget.profile.sex != null) const SizedBox(width: 8) else const SizedBox(width: 12),
              ],

              // Sex badge if present
              if (widget.profile.sex != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.profile.sex == 'prefer not to say'
                        ? 'Prefer not to say'
                        : (widget.profile.sex!.isEmpty
                            ? ''
                            : widget.profile.sex![0].toUpperCase() +
                                widget.profile.sex!.substring(1)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Chevron
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
