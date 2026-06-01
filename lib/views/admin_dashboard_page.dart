import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../utils/image_url_resolver.dart';
import '../models/permission_application.dart';
import '../models/admin_config.dart';
import '../models/profile.dart';
import 'user_permissions_editor_page.dart';
import 'sports_config_page.dart';
import 'formats_config_page.dart';
import 'disciplines_config_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final bool isInline;
  final int initialTabIndex;
  final ValueChanged<int>? onTabIndexChanged;
  final String? selectedUsername;
  final String? selectedConfigSubpage;
  const AdminDashboardPage({
    super.key,
    this.isInline = false,
    this.initialTabIndex = 0,
    this.onTabIndexChanged,
    this.selectedUsername,
    this.selectedConfigSubpage,
  });

  @override
  State<AdminDashboardPage> createState() => AdminDashboardPageState();
}

class AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  int _lastNotifiedIndex = 0;

  void closeConfigSubpage() {
    setState(() {
      _currentConfigSubpage = null;
    });
  }

  void closeUserManagementSubpage() {
    setState(() {
      _selectedUserIdForManagement = null;
    });
  }
  late TabController _tabController;
  List<PermissionApplication> _applications = [];
  SportConfig? _sportConfig;
  bool _isLoadingData = false;

  // Cache user profiles and list all users for management
  final Map<String, Profile> _profileCache = {};
  final Set<String> _loadingProfiles = {};
  List<Profile> _allUsers = [];
  final TextEditingController _userSearchController = TextEditingController();

  // Controllers for sports editing
  final TextEditingController _sportNameController = TextEditingController();
  final TextEditingController _sportDescController = TextEditingController();

  final TextEditingController _formatNameController = TextEditingController();
  final TextEditingController _formatDescController = TextEditingController();
  String _selectedSportForFormat = 'Streetlifting';

  // Inline subpage navigation for desktop view
  String? _currentConfigSubpage;
  String? _selectedUserIdForManagement;

  @override
  void initState() {
    super.initState();
    _lastNotifiedIndex = widget.initialTabIndex;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      final index = _tabController.index;
      if (index != _lastNotifiedIndex) {
        _lastNotifiedIndex = index;
        if (widget.onTabIndexChanged != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onTabIndexChanged!(index);
            }
          });
        }
        setState(() {
          if (index == 1) {
            _currentConfigSubpage = null;
          } else if (index == 2) {
            _selectedUserIdForManagement = null;
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex && _tabController.index != widget.initialTabIndex) {
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
          setState(() {
            _loadingProfiles.add(uid);
          });
          final profile = await authProvider.profileRepository.getProfile(uid);
          if (profile != null) {
            setState(() {
              _profileCache[uid] = profile;
            });
          }
          setState(() {
            _loadingProfiles.remove(uid);
          });
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
      if (mounted) {
        Provider.of<CompetitionProvider>(context, listen: false).loadSportsConfig();
      }
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

  Future<void> _confirmRemoveSport(String sportName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sport?'),
        content: Text('Are you sure you want to delete the sport "$sportName"? This will also delete all associated formats and mappings.'),
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
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _removeSport(sportName);
    }
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

  Future<void> _confirmRemoveFormat(String sportName, String formatName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Format?'),
        content: Text('Are you sure you want to delete the format "$formatName" from "$sportName"?'),
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
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _removeFormat(sportName, formatName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

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
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPermissionRequestsTab(theme),
              _buildConfigurationTab(theme),
              _buildUsersTab(theme),
            ],
          );

    if (widget.isInline) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          onTap: (index) {
            setState(() {
              if (index == 1) {
                _currentConfigSubpage = null;
              } else if (index == 2) {
                _selectedUserIdForManagement = null;
              }
            });
          },
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
                              : (_loadingProfiles.contains(app.userId)
                                    ? 'Loading user details...'
                                    : 'Unknown User (${app.userId})');
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
                        : (_loadingProfiles.contains(app.userId)
                              ? 'Loading user details...'
                              : 'Unknown User (${app.userId})');
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

  Widget _buildConfigurationTab(ThemeData theme) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final activeSubpage = widget.selectedConfigSubpage ?? _currentConfigSubpage;

    if (isDesktop && activeSubpage != null) {
      if (activeSubpage == 'sports') {
        return SportsConfigPage(
          isEmbedded: true,
          onBack: () {
            try {
              context.go('/admin/configuration');
            } catch (_) {
              setState(() {
                _currentConfigSubpage = null;
              });
              _loadData();
            }
          },
        );
      } else if (activeSubpage == 'formats') {
        return FormatsConfigPage(
          isEmbedded: true,
          onBack: () {
            try {
              context.go('/admin/configuration');
            } catch (_) {
              setState(() {
                _currentConfigSubpage = null;
              });
              _loadData();
            }
          },
        );
      } else if (activeSubpage == 'disciplines') {
        return DisciplinesConfigPage(
          isEmbedded: true,
          onBack: () {
            try {
              context.go('/admin/configuration');
            } catch (_) {
              setState(() {
                _currentConfigSubpage = null;
              });
              _loadData();
            }
          },
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.sports),
                title: const Text('Sports'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  try {
                    context.push('/admin/configuration/sports');
                  } catch (_) {
                    if (isDesktop) {
                      setState(() {
                        _currentConfigSubpage = 'sports';
                      });
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SportsConfigPage(),
                        ),
                      ).then((_) => _loadData());
                    }
                  }
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.format_list_bulleted),
                title: const Text('Formats'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  try {
                    context.push('/admin/configuration/formats');
                  } catch (_) {
                    if (isDesktop) {
                      setState(() {
                        _currentConfigSubpage = 'formats';
                      });
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FormatsConfigPage(),
                        ),
                      ).then((_) => _loadData());
                    }
                  }
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.fitness_center),
                title: const Text('Disciplines'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  try {
                    context.push('/admin/configuration/disciplines');
                  } catch (_) {
                    if (isDesktop) {
                      setState(() {
                        _currentConfigSubpage = 'disciplines';
                      });
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DisciplinesConfigPage(),
                        ),
                      ).then((_) => _loadData());
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportsConfigTab(ThemeData theme) {
    if (_sportConfig == null) {
      return const Center(child: Text('No sport config available.'));
    }
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    final sportsList = _sportConfig!.sports.map((s) => s.name).toList();
    if (sportsList.isNotEmpty && !sportsList.contains(_selectedSportForFormat)) {
      _selectedSportForFormat = sportsList.first;
    }

    final sportsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Supported Sports',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (!isDesktop)
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('SAVE CONFIG'),
                onPressed: _saveConfig,
              ),
          ],
        ),
        const SizedBox(height: 12),
        ..._sportConfig!.sports.map((sport) {
          return Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                sport.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: sport.description != null && sport.description!.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(sport.description!),
                    )
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmRemoveSport(sport.name),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        _buildAddSportForm(theme, !isDesktop),
      ],
    );

    final formatsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Format Definitions & Mappings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        ..._sportConfig!.formats.map((format) {
          final sportLinks = _sportConfig!.links
              .where(
                (l) =>
                    l.sportName == format.sportName &&
                    l.formatName == format.name,
              )
              .map((l) => l.disciplineName)
              .join(', ');
          return Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                '${format.sportName} — ${format.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (format.description != null && format.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(format.description!),
                    ),
                  if (sportLinks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Wrap(
                        spacing: 6,
                        children: sportLinks.split(', ').map((d) {
                          return Chip(
                            label: Text(d, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmRemoveFormat(format.sportName, format.name),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        _buildAddFormatForm(theme, !isDesktop),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner card
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Global sport configs determine which disciplines, formats, and weight classes are supported inside the platform. Modifying these configurations affects competition wizard creation guidelines.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('SAVE CONFIGURATION'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed: _saveConfig,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sportsColumn),
                const SizedBox(width: 32),
                Expanded(child: formatsColumn),
              ],
            )
          else ...[
            sportsColumn,
            const SizedBox(height: 32),
            formatsColumn,
          ],
        ],
      ),
    );
  }

  Widget _buildAddSportForm(ThemeData theme, bool isMobile) {
    final inputs = [
      Expanded(
        flex: isMobile ? 0 : 2,
        child: TextField(
          controller: _sportNameController,
          decoration: const InputDecoration(
            labelText: 'Sport Name',
            hintText: 'e.g. Streetlifting',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 12),
      Expanded(
        flex: isMobile ? 0 : 3,
        child: TextField(
          controller: _sportDescController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Short summary',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 12),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE94E1B),
          foregroundColor: Colors.white,
          minimumSize: isMobile ? const Size.fromHeight(48) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onPressed: _addSport,
        icon: const Icon(Icons.add),
        label: const Text('ADD SPORT'),
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Sport',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: inputs,
              )
            else
              Row(
                children: inputs,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFormatForm(ThemeData theme, bool isMobile) {
    final inputs = [
      Expanded(
        flex: isMobile ? 0 : 2,
        child: DropdownButtonFormField<String>(
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
      ),
      if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 12),
      Expanded(
        flex: isMobile ? 0 : 2,
        child: TextField(
          controller: _formatNameController,
          decoration: const InputDecoration(
            labelText: 'Format Name',
            hintText: 'e.g. Modern, Classic',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 12),
      Expanded(
        flex: isMobile ? 0 : 3,
        child: TextField(
          controller: _formatDescController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Exercises involved',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 12),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE94E1B),
          foregroundColor: Colors.white,
          minimumSize: isMobile ? const Size.fromHeight(48) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onPressed: _addFormat,
        icon: const Icon(Icons.add),
        label: const Text('ADD FORMAT'),
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Format Definition',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: inputs,
              )
            else
              Row(
                children: inputs,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(ThemeData theme) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    if (isDesktop && (widget.selectedUsername != null || _selectedUserIdForManagement != null)) {
      return UserPermissionsEditorPage(
        userId: _selectedUserIdForManagement,
        username: widget.selectedUsername,
        isEmbedded: true,
        onBack: () {
          try {
            context.go('/admin/users');
          } catch (_) {
            setState(() {
              _selectedUserIdForManagement = null;
            });
            _loadData();
          }
        },
      );
    }

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
                : (isDesktop
                    ? SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Table(
                          border: TableBorder(
                            bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
                            horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3), width: 1),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(2.0), // Name
                            1: FlexColumnWidth(1.5), // Username
                            2: FlexColumnWidth(2.5), // Email
                            3: FlexColumnWidth(2.0), // ID
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.colorScheme.onSurface,
                                    width: 2.0,
                                  ),
                                ),
                              ),
                              children: const [
                                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)))),
                                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Username', style: TextStyle(fontWeight: FontWeight.bold)))),
                                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)))),
                                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold)))),
                              ],
                            ),
                            ..._allUsers.map((user) {
                              final void Function() onTapRow = () {
                                try {
                                  context.push('/admin/users/${user.username}');
                                } catch (_) {
                                  setState(() {
                                    _selectedUserIdForManagement = user.id;
                                  });
                                }
                              };
                              return TableRow(
                                children: [
                                  TableCell(
                                    child: InkWell(
                                      onTap: onTapRow,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        child: Text(user.fullName.isNotEmpty ? user.fullName : 'No Name'),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    child: InkWell(
                                      onTap: onTapRow,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        child: Text('@${user.username}'),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    child: InkWell(
                                      onTap: onTapRow,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        child: Text(user.email),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    child: InkWell(
                                      onTap: onTapRow,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        child: Text(
                                          user.id,
                                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _allUsers.length,
                        itemBuilder: (context, index) {
                          final user = _allUsers[index];
                          final initials = user.fullName.isNotEmpty
                              ? user.fullName
                                    .trim()
                                    .split(' ')
                                    .map((e) => e.isEmpty ? '' : e[0])
                                    .take(2)
                                    .join()
                                    .toUpperCase()
                              : user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?';
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                backgroundImage: ImageUrlResolver.resolve(context, user.profilePictureUrl).isNotEmpty
                                    ? NetworkImage(ImageUrlResolver.resolve(context, user.profilePictureUrl))
                                    : null,
                                child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                                    ? Text(
                                        initials,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                user.fullName.isNotEmpty ? user.fullName : 'No Name',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text('@${user.username}', style: theme.textTheme.bodySmall),
                                  const SizedBox(height: 2),
                                  Text(user.email, style: theme.textTheme.bodySmall),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () {
                                try {
                                  context.push('/admin/users/${user.username}');
                                } catch (_) {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) => UserPermissionsEditorPage(userId: user.id),
                                        ),
                                      )
                                      .then((_) => _loadData());
                                }
                              },
                            ),
                          );
                        },
                      )),
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
