import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
        appBar: AppBar(title: const Text('Appearance')),
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
                        trailing: DropdownButton<String>(
                          value: profile.colorMode,
                          underline: Container(),
                          items: const [
                            DropdownMenuItem(
                              value: 'system',
                              child: Text('System'),
                            ),
                            DropdownMenuItem(
                              value: 'light',
                              child: Text('Light'),
                            ),
                            DropdownMenuItem(
                              value: 'dark',
                              child: Text('Dark'),
                            ),
                          ],
                          onChanged: (val) async {
                            if (val == null) return;
                            setState(() {
                              _isLoading = true;
                            });
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await authProvider.updateProfile(
                                fullName: profile.fullName,
                                email: profile.email,
                                gender: profile.gender,
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
