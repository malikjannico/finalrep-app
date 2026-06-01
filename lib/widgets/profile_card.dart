import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../views/profile_page.dart';
import '../providers/competition_provider.dart';
import '../utils/mock_safety.dart';
import '../utils/image_url_resolver.dart';

class ProfileCard extends StatefulWidget {
  final Profile profile;
  final VoidCallback? onTap;

  const ProfileCard({super.key, required this.profile, this.onTap});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _isHovered = false;

  String _getBannerUrl() {
    final userId = widget.profile.id;
    try {
      final competitionProvider = Provider.of<CompetitionProvider>(
        context,
        listen: false,
      );
      String apiBaseUrl = 'http://localhost:8080';
      try {
        apiBaseUrl = competitionProvider.competitionRepository.baseUrl;
      } catch (_) {}
      if (MockSafety.isMockAllowed) {
        return '$apiBaseUrl/uploads/profiles-$userId-banner.jpg';
      }
      final bucket = 'finalrep-app-media-${MockSafety.env}';
      return 'https://storage.googleapis.com/$bucket/avatars/profiles-$userId-banner.jpg';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedProfilePicUrl = ImageUrlResolver.resolve(context, widget.profile.profilePictureUrl);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 900;
    final showHover = _isHovered && !isMobile;

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

    final bannerUrl = _getBannerUrl();

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
          borderRadius: cardRadius,
          border: Border.all(
            color: showHover
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
        child: ClipRRect(
          borderRadius: cardRadius.subtract(BorderRadius.circular(1)),
          child: InkWell(
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
                // Body Content (overlapping avatar)
                Positioned(
                  top: 56, // 80 - 24 overlap
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                backgroundImage: resolvedProfilePicUrl != null &&
                                        resolvedProfilePicUrl.isNotEmpty
                                    ? NetworkImage(resolvedProfilePicUrl)
                                    : null,
                                child: widget.profile.profilePictureUrl == null ||
                                        widget.profile.profilePictureUrl!.isEmpty
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
                            const Spacer(),
                            // Country badge next to gender badge
                            if (widget.profile.country != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 10,
                                      color: theme.colorScheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.profile.country!,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onTertiaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.profile.sex != null) const SizedBox(width: 8),
                            ],
                            // Sex Badge
                            if (widget.profile.sex != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
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
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Full Name
                        Text(
                          widget.profile.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Username
                        Text(
                          '@${widget.profile.username}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Bio Snippet
                        SizedBox(
                          height: 30,
                          child: Text(
                            widget.profile.description == null ||
                                    widget.profile.description!.isEmpty
                                ? 'No biography provided.'
                                : widget.profile.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          ],
        ),
      ),
    );
  }
}
