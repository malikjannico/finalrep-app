import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/profile.dart';

class UserPermissionsEditorPage extends StatefulWidget {
  final String? userId;
  final String? username;
  final bool isEmbedded;
  final VoidCallback? onBack;
  const UserPermissionsEditorPage({
    super.key,
    this.userId,
    this.username,
    this.isEmbedded = false,
    this.onBack,
  });

  @override
  State<UserPermissionsEditorPage> createState() => _UserPermissionsEditorPageState();
}

class _UserPermissionsEditorPageState extends State<UserPermissionsEditorPage> {
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
      Profile? profile;
      if (widget.userId != null) {
        profile = await authProvider.profileRepository.getProfile(
          widget.userId!,
        );
      } else if (widget.username != null) {
        profile = await authProvider.profileRepository.getProfileByUsername(
          widget.username!,
        );
      }
      if (profile != null) {
        setState(() {
          _profile = profile;
          _isCompetitionCreator = profile!.isCompetitionCreator;
          _isAssociationCreator = profile!.isAssociationCreator;
          _isAdmin = profile!.isAdmin;
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
    if (_profile == null) return;
    final userId = _profile!.id;
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
        userId,
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

  Widget _buildInfoField(ThemeData theme, String label, String value, {bool isMonospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: isMonospace ? 'monospace' : null,
            fontSize: isMonospace ? 13 : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return const Scaffold(
        body: Center(child: Text('User profile not found.')),
      );
    }

    final Widget bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isEmbedded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.onBack,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'User',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    ' / ${_profile!.fullName.isNotEmpty ? _profile!.fullName : 'No Name'}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          // User Information Section
          CollapsibleSection(
            title: 'User Information',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildInfoField(
                            theme,
                            'Name',
                            _profile!.fullName.isNotEmpty ? _profile!.fullName : 'No Name',
                          ),
                        ),
                        if (isWide) const SizedBox(width: 16),
                        if (isWide)
                          Expanded(
                            child: _buildInfoField(
                              theme,
                              'Username',
                              '@${_profile!.username}',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!isWide) ...[
                      _buildInfoField(
                        theme,
                        'Username',
                        '@${_profile!.username}',
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildInfoField(
                            theme,
                            'Email',
                            _profile!.email,
                          ),
                        ),
                        if (isWide) const SizedBox(width: 16),
                        if (isWide)
                          Expanded(
                            child: _buildInfoField(
                              theme,
                              'User ID',
                              _profile!.id,
                              isMonospace: true,
                            ),
                          ),
                      ],
                    ),
                    if (!isWide) ...[
                      const SizedBox(height: 16),
                      _buildInfoField(
                        theme,
                        'User ID',
                        _profile!.id,
                        isMonospace: true,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // User Permissions Section
          CollapsibleSection(
            title: 'User Permissions',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Competition Creator'),
                  subtitle: const Text(
                    'Allows user to create and manage their own competitions.',
                  ),
                  value: _isCompetitionCreator,
                  onChanged: (val) => _updatePermission('competition', val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Association Creator'),
                  subtitle: const Text(
                    'Allows user to create and manager their own associations.',
                  ),
                  value: _isAssociationCreator,
                  onChanged: (val) => _updatePermission('association', val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('System Administrator'),
                  subtitle: const Text(
                    'Allows user to manage system configuration, permission requests and user permissions.',
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
    );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('User Management')),
      body: bodyContent,
    );
  }
}

class CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initialExpanded;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.initialExpanded = true,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: isDark
          ? theme.colorScheme.surfaceContainerLow
          : theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHigh
                    : theme.colorScheme.surfaceContainerLowest,
                borderRadius: _isExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      )
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Visibility(
            visible: _isExpanded,
            maintainState: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
