import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/permission_application.dart';
import '../models/admin_config.dart';
import '../models/profile.dart';
import 'user_admin_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final bool isInline;
  final int initialTabIndex;
  const AdminDashboardPage({
    super.key,
    this.isInline = false,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PermissionApplication> _applications = [];
  SportConfig? _sportConfig;
  bool _isLoadingData = false;

  // Cache user profiles and list all users for management
  final Map<String, Profile> _profileCache = {};
  List<Profile> _allUsers = [];
  final TextEditingController _userSearchController = TextEditingController();

  // Controllers for sports editing
  final TextEditingController _sportNameController = TextEditingController();
  final TextEditingController _sportDescController = TextEditingController();

  final TextEditingController _formatNameController = TextEditingController();
  final TextEditingController _formatDescController = TextEditingController();
  String _selectedSportForFormat = 'Streetlifting';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sportNameController.dispose();
    _sportDescController.dispose();
    _formatNameController.dispose();
    _formatDescController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final apps = await authProvider.getPermissionApplications();
      final config = await authProvider.loadSportsConfig();
      final users = await authProvider.profileRepository.searchProfiles('');
      setState(() {
        _applications = apps;
        _sportConfig = config;
        _allUsers = users;
      });

      // Eagerly load profiles for all unique user IDs
      final userIds = apps.map((app) => app.userId).toSet();
      for (final uid in userIds) {
        if (!_profileCache.containsKey(uid)) {
          final profile = await authProvider.profileRepository.getProfile(uid);
          if (profile != null) {
            setState(() {
              _profileCache[uid] = profile;
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading admin data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _handleApprove(String id) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await authProvider.approvePermissionApplication(id);
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application approved successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve application: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleReject(String id) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await authProvider.rejectPermissionApplication(id);
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject application: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveConfig() async {
    if (_sportConfig == null) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.saveSportsConfig(_sportConfig!);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sport Configuration saved successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save sport configuration.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addSport() {
    final name = _sportNameController.text.trim();
    final desc = _sportDescController.text.trim();
    if (name.isEmpty) return;

    if (_sportConfig!.sports.any(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sport already exists.')));
      return;
    }

    setState(() {
      final updatedSports = List<SportDefinition>.from(_sportConfig!.sports)
        ..add(SportDefinition(name: name, description: desc));
      _sportConfig = SportConfig(
        sports: updatedSports,
        formats: _sportConfig!.formats,
        disciplines: _sportConfig!.disciplines,
        links: _sportConfig!.links,
      );
    });

    _sportNameController.clear();
    _sportDescController.clear();
  }

  void _removeSport(String sportName) {
    setState(() {
      final updatedSports = List<SportDefinition>.from(_sportConfig!.sports)
        ..removeWhere((s) => s.name == sportName);
      final updatedFormats = List<FormatDefinition>.from(_sportConfig!.formats)
        ..removeWhere((f) => f.sportName == sportName);
      final updatedLinks = List<FormatDisciplineLink>.from(_sportConfig!.links)
        ..removeWhere((l) => l.sportName == sportName);

      _sportConfig = SportConfig(
        sports: updatedSports,
        formats: updatedFormats,
        disciplines: _sportConfig!.disciplines,
        links: updatedLinks,
      );
    });
  }

  void _addFormat() {
    final name = _formatNameController.text.trim();
    final desc = _formatDescController.text.trim();
    if (name.isEmpty) return;

    if (_sportConfig!.formats.any(
      (f) =>
          f.sportName == _selectedSportForFormat &&
          f.name.toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format already exists for this sport.')),
      );
      return;
    }

    setState(() {
      final updatedFormats = List<FormatDefinition>.from(_sportConfig!.formats)
        ..add(
          FormatDefinition(
            sportName: _selectedSportForFormat,
            name: name,
            description: desc,
          ),
        );
      _sportConfig = SportConfig(
        sports: _sportConfig!.sports,
        formats: updatedFormats,
        disciplines: _sportConfig!.disciplines,
        links: _sportConfig!.links,
      );
    });

    _formatNameController.clear();
    _formatDescController.clear();
  }

  void _removeFormat(String sportName, String formatName) {
    setState(() {
      final updatedFormats = List<FormatDefinition>.from(_sportConfig!.formats)
        ..removeWhere((f) => f.sportName == sportName && f.name == formatName);
      final updatedLinks = List<FormatDisciplineLink>.from(_sportConfig!.links)
        ..removeWhere(
          (l) => l.sportName == sportName && l.formatName == formatName,
        );

      _sportConfig = SportConfig(
        sports: _sportConfig!.sports,
        formats: updatedFormats,
        disciplines: _sportConfig!.disciplines,
        links: updatedLinks,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    if (!widget.isInline && !authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text(
            'Only System Administrators can access the Admin Dashboard.',
          ),
        ),
      );
    }

    final bodyContent = _isLoadingData
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildPermissionRequestsTab(theme),
              _buildSportsConfigTab(theme),
              _buildUsersTab(theme),
            ],
          );

    if (widget.isInline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(icon: Icon(Icons.security), text: 'Permission Requests'),
              Tab(icon: Icon(Icons.settings), text: 'Configuration'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
            ],
          ),
          Expanded(child: bodyContent),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.security), text: 'Permission Requests'),
            Tab(icon: Icon(Icons.settings), text: 'Configuration'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildPermissionRequestsTab(ThemeData theme) {
    final pendingApps = _applications
        .where((app) => app.status == 'pending')
        .toList();
    final processedApps = _applications
        .where((app) => app.status != 'pending')
        .toList();

    if (_applications.isEmpty) {
      return const Center(child: Text('No permission applications found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Applications (${pendingApps.length})',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (pendingApps.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No pending applications at this time.'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingApps.length,
              itemBuilder: (context, index) {
                final app = pendingApps[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              app.type == 'create_competition'
                                  ? 'Competition Creator Role'
                                  : 'Association Creator Role',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                app.status.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        (() {
                          final profile = _profileCache[app.userId];
                          final nameStr = profile != null
                              ? '${profile.fullName} (@${profile.username})'
                              : app.userId;
                          return Text(
                            'User: $nameStr',
                            style: theme.textTheme.bodySmall,
                          );
                        })(),
                        const SizedBox(height: 8),
                        Text(
                          'Reason:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(app.reason, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => _handleReject(app.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('REJECT'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => _handleApprove(app.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('APPROVE'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          Text(
            'Processed Applications History',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (processedApps.isEmpty)
            const Text('No processed applications in history.')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: processedApps.length,
              itemBuilder: (context, index) {
                final app = processedApps[index];
                final isApproved = app.status == 'approved';
                return ListTile(
                  title: Text(
                    app.type == 'create_competition'
                        ? 'Competition Creator'
                        : 'Association Creator',
                  ),
                  subtitle: (() {
                    final profile = _profileCache[app.userId];
                    final nameStr = profile != null
                        ? '${profile.fullName} (@${profile.username})'
                        : app.userId;
                    return Text('User: $nameStr\nReason: ${app.reason}');
                  })(),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      app.status.toUpperCase(),
                      style: TextStyle(
                        color: isApproved ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSportsConfigTab(ThemeData theme) {
    if (_sportConfig == null) {
      return const Center(child: Text('No sport config available.'));
    }
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileLayout = screenWidth < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: theme.colorScheme.primaryContainer.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Global sport configs determine which disciplines, formats, and weight classes are supported inside the platform. Modifying these configurations affects competition wizard creation guidelines.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Supported Sports', style: theme.textTheme.titleLarge),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('SAVE CONFIG'),
                onPressed: _saveConfig,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sportConfig!.sports.length,
            itemBuilder: (context, index) {
              final sport = _sportConfig!.sports[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    sport.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(sport.description ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeSport(sport.name),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Add sport fields
          isMobileLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _sportNameController,
                      decoration: const InputDecoration(
                        labelText: 'Sport Name',
                        hintText: 'e.g. Streetlifting',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sportDescController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Short summary',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _addSport,
                      child: const Text('ADD'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sportNameController,
                        decoration: const InputDecoration(
                          labelText: 'Sport Name',
                          hintText: 'e.g. Streetlifting',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _sportDescController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Short summary',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addSport,
                      child: const Text('ADD'),
                    ),
                  ],
                ),
          const SizedBox(height: 24),
          Text(
            'Format Definitions & Mappings',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sportConfig!.formats.length,
            itemBuilder: (context, index) {
              final format = _sportConfig!.formats[index];
              final sportLinks = _sportConfig!.links
                  .where(
                    (l) =>
                        l.sportName == format.sportName &&
                        l.formatName == format.name,
                  )
                  .map((l) => l.disciplineName)
                  .join(', ');
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    '${format.sportName} — ${format.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${format.description}\nDisciplines: $sportLinks',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () =>
                        _removeFormat(format.sportName, format.name),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Add format fields
          isMobileLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedSportForFormat,
                      decoration: const InputDecoration(
                        labelText: 'Sport',
                        border: OutlineInputBorder(),
                      ),
                      items: _sportConfig!.sports.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.name,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSportForFormat = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _formatNameController,
                      decoration: const InputDecoration(
                        labelText: 'Format Name',
                        hintText: 'e.g. Modern, Classic',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _formatDescController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Exercises involved',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _addFormat,
                      child: const Text('ADD'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    DropdownButton<String>(
                      value: _selectedSportForFormat,
                      items: _sportConfig!.sports.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.name,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSportForFormat = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _formatNameController,
                        decoration: const InputDecoration(
                          labelText: 'Format Name',
                          hintText: 'e.g. Modern, Classic',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _formatDescController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Exercises involved',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addFormat,
                      child: const Text('ADD'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              labelText: 'Search Users',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _userSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _userSearchController.clear();
                        _onUserSearchChanged('');
                      },
                    )
                  : null,
            ),
            onChanged: _onUserSearchChanged,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _allUsers.isEmpty
                ? const Center(child: Text('No users found.'))
                : ListView.builder(
                    itemCount: _allUsers.length,
                    itemBuilder: (context, index) {
                      final user = _allUsers[index];
                      final List<Widget> roles = [];
                      if (user.isAdmin) {
                        roles.add(
                          const Chip(
                            label: Text('Admin'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      if (user.isCompetitionCreator) {
                        roles.add(const Chip(label: Text('Creator')));
                      }
                      if (user.isAssociationCreator) {
                        roles.add(const Chip(label: Text('Assoc Creator')));
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName
                                : 'No Name',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('@${user.username} • ${user.email}'),
                              if (roles.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: roles,
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UserAdminPage(userId: user.id),
                                  ),
                                )
                                .then(
                                  (_) => _loadData(),
                                ); // Reload when returning
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _onUserSearchChanged(String query) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final users = await authProvider.profileRepository.searchProfiles(query);
    setState(() {
      _allUsers = users;
    });
  }
}
