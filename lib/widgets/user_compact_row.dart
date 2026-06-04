import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../views/profile_page.dart';

class UserCompactRow extends StatelessWidget {
  final Profile profile;
  final VoidCallback? onTap;

  const UserCompactRow({
    super.key,
    required this.profile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final initials = profile.fullName.isNotEmpty
        ? profile.fullName
              .trim()
              .split(' ')
              .map((e) => e.isEmpty ? '' : e[0])
              .take(2)
              .join()
              .toUpperCase()
        : profile.username.isNotEmpty
            ? profile.username[0].toUpperCase()
            : '?';

    final hasCountry = profile.country != null && profile.country!.isNotEmpty;
    final hasSex = profile.sex != null && profile.sex!.isNotEmpty;

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
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: profile.profilePictureUrl != null && profile.profilePictureUrl!.isNotEmpty
              ? NetworkImage(profile.profilePictureUrl!)
              : null,
          child: profile.profilePictureUrl == null || profile.profilePictureUrl!.isEmpty
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        title: Text(
          profile.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (profile.username.isNotEmpty)
                Text(
                  '@${profile.username}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (hasCountry)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 10,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        profile.country!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasSex)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    profile.sex == 'prefer not to say'
                        ? 'Prefer not to say'
                        : profile.sex![0].toUpperCase() + profile.sex!.substring(1),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        onTap: onTap ??
            () {
              try {
                context.push('/users/${profile.username}');
              } catch (_) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(username: profile.username),
                  ),
                );
              }
            },
      ),
    );
  }
}
