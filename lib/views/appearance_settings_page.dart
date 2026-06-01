import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../router.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final profile = authProvider.currentUserProfile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Appearance'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                try {
                  GoRouter.of(context);
                  goRouter.go('/settings');
                } catch (_) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ),
        body: const Center(
          child: Text('Please log in to view appearance settings.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Appearance',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              try {
                GoRouter.of(context);
                goRouter.go('/settings');
              } catch (_) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Customize how the application looks on your device.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('Default Color Mode'),
                        subtitle: Text(
                          'Current: ${profile.colorMode[0].toUpperCase()}${profile.colorMode.substring(1)}',
                        ),
                        trailing: PopupMenuButton<String>(
                          initialValue: profile.colorMode,
                          tooltip: 'Select Color Mode',
                          offset: const Offset(0, 32),
                          onSelected: (val) async {
                            if (val == profile.colorMode) return;
                            setState(() {
                              _isLoading = true;
                            });
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await authProvider.updateProfile(
                                fullName: profile.fullName,
                                email: profile.email,
                                sex: profile.sex,
                                country: profile.country,
                                description: profile.description,
                                colorMode: val,
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to update color mode: $e',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem(
                              value: 'system',
                              child: Row(
                                children: [
                                  Icon(Icons.settings_brightness, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('System'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'light',
                              child: Row(
                                children: [
                                  Icon(Icons.light_mode, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Light'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'dark',
                              child: Row(
                                children: [
                                  Icon(Icons.dark_mode, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Dark'),
                                ],
                              ),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  profile.colorMode == 'system'
                                      ? Icons.settings_brightness
                                      : profile.colorMode == 'light'
                                          ? Icons.light_mode
                                          : Icons.dark_mode,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  profile.colorMode == 'system'
                                      ? 'System'
                                      : profile.colorMode == 'light'
                                          ? 'Light'
                                          : 'Dark',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time_outlined),
                        title: const Text('Time Format'),
                        subtitle: Text(
                          'Current: ${authProvider.timeFormat == '12h' ? '12-hour (AM/PM)' : '24-hour'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          initialValue: authProvider.timeFormat,
                          tooltip: 'Select Time Format',
                          offset: const Offset(0, 32),
                          onSelected: (val) {
                            authProvider.setTimeFormat(val);
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem(
                              value: '12h',
                              child: Row(
                                children: [
                                  Icon(Icons.schedule, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('12-hour (AM/PM)'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: '24h',
                              child: Row(
                                children: [
                                  Icon(Icons.schedule, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('24-hour'),
                                ],
                              ),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  authProvider.timeFormat == '12h' ? '12-hour' : '24-hour',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
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
}
