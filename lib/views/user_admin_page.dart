import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/profile.dart';

class UserAdminPage extends StatefulWidget {
  final String userId;
  const UserAdminPage({super.key, required this.userId});

  @override
  State<UserAdminPage> createState() => _UserAdminPageState();
}

class _UserAdminPageState extends State<UserAdminPage> {
  Profile? _profile;
  bool _isLoading = false;
  bool _isCompetitionCreator = false;
  bool _isAssociationCreator = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final profile = await authProvider.profileRepository.getProfile(
        widget.userId,
      );
      if (profile != null) {
        setState(() {
          _profile = profile;
          _isCompetitionCreator = profile.isCompetitionCreator;
          _isAssociationCreator = profile.isAssociationCreator;
          _isAdmin = profile.isAdmin;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading user profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePermission(String type, bool newValue) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Keep local backup to revert on failure
    final oldComp = _isCompetitionCreator;
    final oldAssoc = _isAssociationCreator;
    final oldAdmin = _isAdmin;

    setState(() {
      if (type == 'competition') {
        _isCompetitionCreator = newValue;
      } else if (type == 'association') {
        _isAssociationCreator = newValue;
      } else if (type == 'admin') {
        _isAdmin = newValue;
      }
    });

    try {
      final updated = await authProvider.profileRepository.updatePermissions(
        widget.userId,
        isCompetitionCreator: _isCompetitionCreator,
        isAssociationCreator: _isAssociationCreator,
        isAdmin: _isAdmin,
      );

      if (updated != null) {
        setState(() {
          _profile = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update permissions on repository.');
      }
    } catch (e) {
      // Revert UI switches on error
      setState(() {
        _isCompetitionCreator = oldComp;
        _isAssociationCreator = oldAssoc;
        _isAdmin = oldAdmin;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update permissions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? const Center(child: Text('User profile not found.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile!.fullName.isNotEmpty
                                ? _profile!.fullName
                                : 'No Name',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Username: @${_profile!.username}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Email: ${_profile!.email}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User ID: ${_profile!.id}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Privileges Administration',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Competition Creator'),
                          subtitle: const Text(
                            'Allows user to create and manage their own meets.',
                          ),
                          value: _isCompetitionCreator,
                          onChanged: (val) =>
                              _updatePermission('competition', val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Association Creator'),
                          subtitle: const Text(
                            'Allows user to register associations and create club leagues.',
                          ),
                          value: _isAssociationCreator,
                          onChanged: (val) =>
                              _updatePermission('association', val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('System Administrator'),
                          subtitle: const Text(
                            'Grants full administrative access to system configurations, dashboards, and role reviews.',
                          ),
                          value: _isAdmin,
                          activeColor: Colors.redAccent,
                          onChanged: (val) => _updatePermission('admin', val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
