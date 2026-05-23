import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'appearance_settings_page.dart';
import 'change_password_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final profile = authProvider.currentUserProfile;

    if (!authProvider.isAuthenticated || profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: Text('Please log in to view settings.')),
      );
    }

    // Monogram / Initials fallback
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

    final hasDescription = profile.description != null && profile.description!.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. PROFILE DETAILS HEADER (rendered directly on background)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: profile.profilePictureUrl != null
                          ? NetworkImage(profile.profilePictureUrl!)
                          : null,
                      child: profile.profilePictureUrl == null
                          ? Text(
                              initials,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@${profile.username}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (profile.gender != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    profile.gender!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (profile.gender != null && profile.country != null)
                                const SizedBox(width: 8),
                              if (profile.country != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        profile.country!,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onTertiaryContainer,
                                          fontWeight: FontWeight.bold,
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
                  ],
                ),
                const SizedBox(height: 16),
                // Description / Bio
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    hasDescription ? profile.description! : 'No description provided.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: hasDescription
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant.withAlpha(128),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),

                // 2. SETTINGS NAVIGATION BUTTONS (rendered directly on background)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Appearance'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppearanceSettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_outlined),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Creator Privileges'),
                  subtitle: Text(
                    'Comp creator: ${profile.isCompetitionCreator ? "Yes" : "No"} • Assoc creator: ${profile.isAssociationCreator ? "Yes" : "No"}'
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    _showApplyPrivilegesDialog(context, authProvider);
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.redAccent),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Log Out?'),
                        content: const Text('Are you sure you want to log out of your session?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('CANCEL'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('LOG OUT'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      if (!context.mounted) return;
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await authProvider.logout();
                      navigator.popUntil((route) => route.isFirst);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Logged out successfully.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showApplyPrivilegesDialog(BuildContext context, AuthProvider authProvider) {
    String selectedType = 'create_competition';
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Apply for Creator Privileges'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Privilege Type'),
                      items: const [
                        DropdownMenuItem(value: 'create_competition', child: Text('Competition Creator')),
                        DropdownMenuItem(value: 'create_association', child: Text('Association Creator')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Explain why you need these privileges...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a reason.')),
                            );
                            return;
                          }
                          setState(() {
                            isSubmitting = true;
                          });
                          try {
                            final success = await authProvider.applyForPermissions(
                              selectedType,
                              reason,
                            );
                            if (success != null) {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Application submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setState(() {
                              isSubmitting = false;
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('SUBMIT'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
