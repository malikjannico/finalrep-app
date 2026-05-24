import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/association.dart';
import '../models/association_member.dart';
import '../models/competition_group.dart';
import '../models/athlete_group.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import 'association_creation_page.dart';

class AssociationManagementPage extends StatefulWidget {
  final String?
  associationId; // If null, acts as Management Dashboard for all owned/edited associations
  final bool isInline;

  const AssociationManagementPage({
    super.key,
    this.associationId,
    this.isInline = false,
  });

  @override
  State<AssociationManagementPage> createState() =>
      _AssociationManagementPageState();
}

class _AssociationManagementPageState extends State<AssociationManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Association? _association;
  List<AssociationMember> _members = [];
  List<CompetitionGroup> _compGroups = [];
  List<AthleteGroup> _athleteGroups = [];
  bool _isLoading = false;

  // Form keys and Controllers for Editing Metadata
  final _metadataFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String _scope = 'local';
  late TextEditingController _areaNameController;

  // Add Member Controllers
  final TextEditingController _memberUserIdController = TextEditingController();
  final TextEditingController _memberCustomTitleController =
      TextEditingController();
  String _memberRole = 'editor';

  // Create Comp Group Controllers
  final TextEditingController _compGroupNameController =
      TextEditingController();
  String _compGroupSport = 'Streetlifting';
  String _compGroupFormat = 'Modern';

  // Create Athlete Group Controllers
  final TextEditingController _athleteGroupNameController =
      TextEditingController();
  String _athleteGroupSport = 'Streetlifting';
  String _athleteGroupFormat = 'Modern';
  String _athleteGroupGender = 'Male';
  final TextEditingController _athleteGroupMaxWeightController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _areaNameController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _areaNameController.dispose();
    _memberUserIdController.dispose();
    _memberCustomTitleController.dispose();
    _compGroupNameController.dispose();
    _athleteGroupNameController.dispose();
    _athleteGroupMaxWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (widget.associationId == null) {
      // Load all associations first to show dashboard
      await compProvider.fetchAssociations();
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final assoc = await compProvider.getAssociationDetails(
        widget.associationId!,
      );
      if (assoc != null) {
        final membersList = await compProvider.getAssociationMembers(
          widget.associationId!,
        );
        final compGroupsList = await compProvider.getCompetitionGroups(
          widget.associationId!,
        );
        final athleteGroupsList = await compProvider.getAthleteGroups(
          widget.associationId!,
        );

        setState(() {
          _association = assoc;
          _members = membersList;
          _compGroups = compGroupsList;
          _athleteGroups = athleteGroupsList;

          _nameController.text = assoc.name;
          _descController.text = assoc.description;
          _scope = assoc.scope;
          _areaNameController.text = assoc.areaName ?? '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMetadata() async {
    if (_association == null) return;
    if (!_metadataFormKey.currentState!.validate()) return;

    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final updated = _association!.copyWith(
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      scope: _scope,
      areaName: _scope == 'global' ? null : _areaNameController.text.trim(),
    );

    final res = await compProvider.updateAssociation(updated);
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metadata updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  Future<void> _addMember() async {
    if (_association == null) return;
    final userId = _memberUserIdController.text.trim();
    final customTitle = _memberCustomTitleController.text.trim();
    if (userId.isEmpty) return;

    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final member = await compProvider.addAssociationMember(
      _association!.id,
      userId,
      _memberRole,
      customTitle: customTitle.isEmpty ? null : customTitle,
    );

    if (member != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member added successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      _memberUserIdController.clear();
      _memberCustomTitleController.clear();
      _loadData();
    }
  }

  Future<void> _removeMember(String userId) async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final success = await compProvider.removeAssociationMember(
      _association!.id,
      userId,
    );
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member removed.')));
      _loadData();
    }
  }

  Future<void> _transferOwnership(String newOwnerId) async {
    if (_association == null) return;
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final res = await compProvider.transferAssociationOwnership(
      _association!.id,
      newOwnerId,
    );
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ownership transferred successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  Future<void> _createCompGroup() async {
    if (_association == null) return;
    final name = _compGroupNameController.text.trim();
    if (name.isEmpty) return;

    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final group = CompetitionGroup(
      id: 'cg-${DateTime.now().millisecondsSinceEpoch}',
      associationId: _association!.id,
      name: name,
      sport: _compGroupSport,
      format: _compGroupFormat,
      isActive: true,
      isAthleteGroupsRequired: true,
    );

    final res = await compProvider.createCompetitionGroup(group);
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Competition Group created.'),
          backgroundColor: Colors.green,
        ),
      );
      _compGroupNameController.clear();
      _loadData();
    }
  }

  Future<void> _toggleCompGroup(CompetitionGroup group) async {
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final updated = group.copyWith(isActive: !group.isActive);
    final res = await compProvider.updateCompetitionGroup(updated);
    if (res != null) {
      _loadData();
    }
  }

  Future<void> _createAthleteGroup() async {
    if (_association == null) return;
    final name = _athleteGroupNameController.text.trim();
    if (name.isEmpty) return;

    final maxWeightStr = _athleteGroupMaxWeightController.text.trim();
    final maxWeight = maxWeightStr.isNotEmpty
        ? double.tryParse(maxWeightStr)
        : null;

    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final group = AthleteGroup(
      id: 'ag-${DateTime.now().millisecondsSinceEpoch}',
      associationId: _association!.id,
      name: name,
      sport: _athleteGroupSport,
      format: _athleteGroupFormat,
      gender: _athleteGroupGender,
      maxWeight: maxWeight,
      isActive: true,
    );

    final res = await compProvider.createAthleteGroup(group);
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Athlete Group created.'),
          backgroundColor: Colors.green,
        ),
      );
      _athleteGroupNameController.clear();
      _athleteGroupMaxWeightController.clear();
      _loadData();
    }
  }

  Future<void> _toggleAthleteGroup(AthleteGroup group) async {
    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    final updated = group.copyWith(isActive: !group.isActive);
    final res = await compProvider.updateAthleteGroup(updated);
    if (res != null) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final compProvider = Provider.of<CompetitionProvider>(context);

    if (_isLoading) {
      if (widget.isInline) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Association')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Dashboard View (if no associationId provided)
    if (widget.associationId == null) {
      final managedAssociations = compProvider.associations.where((assoc) {
        if (authProvider.isAdmin) return true;
        return assoc.ownerId == authProvider.currentUserProfile?.id;
      }).toList();

      final dashboardBody = managedAssociations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('You do not manage any associations yet.'),
                  const SizedBox(height: 12),
                  if (authProvider.isAssociationCreator || authProvider.isAdmin)
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AssociationCreationPage(),
                          ),
                        );
                        _loadData();
                      },
                      child: const Text('Create Association'),
                    )
                  else
                    const Text(
                      'Apply for Association Creator privileges in settings.',
                    ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: managedAssociations.length,
              itemBuilder: (context, index) {
                final assoc = managedAssociations[index];
                return Card(
                  child: ListTile(
                    title: Text(
                      assoc.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${assoc.scope.toUpperCase()} • ${assoc.description}',
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssociationManagementPage(
                            associationId: assoc.id,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );

      if (widget.isInline) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Association Dashboard',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (authProvider.isAssociationCreator || authProvider.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.orange),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AssociationCreationPage(),
                          ),
                        );
                        _loadData();
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: dashboardBody),
          ],
        );
      } else {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Association Dashboard'),
            actions: [
              if (authProvider.isAssociationCreator || authProvider.isAdmin)
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.orange),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AssociationCreationPage(),
                      ),
                    );
                    _loadData();
                  },
                ),
            ],
          ),
          body: dashboardBody,
        );
      }
    }

    if (_association == null) {
      if (widget.isInline) {
        return const Center(child: Text('Error loading association details.'));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Management')),
        body: const Center(child: Text('Error loading association details.')),
      );
    }

    final assoc = _association!;

    if (widget.isInline) {
      return Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.settings), text: 'Metadata'),
              Tab(icon: Icon(Icons.people), text: 'Members'),
              Tab(icon: Icon(Icons.list_alt), text: 'Comp Groups'),
              Tab(icon: Icon(Icons.fitness_center), text: 'Athlete Groups'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMetadataTab(theme),
                _buildMembersTab(theme),
                _buildCompGroupsTab(theme),
                _buildAthleteGroupsTab(theme),
              ],
            ),
          ),
        ],
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text('Manage: ${assoc.name}'),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.settings), text: 'Metadata'),
              Tab(icon: Icon(Icons.people), text: 'Members'),
              Tab(icon: Icon(Icons.list_alt), text: 'Comp Groups'),
              Tab(icon: Icon(Icons.fitness_center), text: 'Athlete Groups'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMetadataTab(theme),
            _buildMembersTab(theme),
            _buildCompGroupsTab(theme),
            _buildAthleteGroupsTab(theme),
          ],
        ),
      );
    }
  }

  Widget _buildMetadataTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _metadataFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Association Details',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Association Name'),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Enter name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _scope,
              decoration: const InputDecoration(labelText: 'Scope'),
              items: const [
                DropdownMenuItem(value: 'global', child: Text('Global')),
                DropdownMenuItem(value: 'area', child: Text('Area')),
                DropdownMenuItem(value: 'local', child: Text('Local')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _scope = val;
                  });
                }
              },
            ),
            if (_scope != 'global') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaNameController,
                decoration: const InputDecoration(labelText: 'Area Name'),
                validator: (val) =>
                    _scope != 'global' && (val == null || val.isEmpty)
                    ? 'Enter area name'
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Enter description'
                  : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveMetadata,
              child: const Text('SAVE METADATA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Association Member', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _memberUserIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    hintText: 'user-uuid-here',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _memberCustomTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Title (optional)',
                    hintText: 'e.g. Chief Admin',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DropdownButton<String>(
                value: _memberRole,
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'editor', child: Text('Editor')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _memberRole = val;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _addMember,
                child: const Text('ADD MEMBER'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Current Members (${_members.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            itemBuilder: (context, idx) {
              final member = _members[idx];
              final isSelf = member.userId == _association!.ownerId;
              return Card(
                child: ListTile(
                  title: Text(member.userId),
                  subtitle: Text(
                    '${member.role.toUpperCase()} ${member.customTitle != null ? "• ${member.customTitle}" : ""}',
                  ),
                  trailing: isSelf
                      ? const Text(
                          'OWNER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.swap_horiz,
                                color: Colors.orange,
                              ),
                              tooltip: 'Transfer Ownership',
                              onPressed: () =>
                                  _transferOwnership(member.userId),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeMember(member.userId),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompGroupsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Competition Group', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _compGroupNameController,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              hintText: 'e.g. FinalRep Qualifier',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DropdownButton<String>(
                value: _compGroupSport,
                items: const [
                  DropdownMenuItem(
                    value: 'Streetlifting',
                    child: Text('Streetlifting'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _compGroupSport = val;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _compGroupFormat,
                items: const [
                  DropdownMenuItem(value: 'Modern', child: Text('Modern')),
                  DropdownMenuItem(value: 'Classic', child: Text('Classic')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _compGroupFormat = val;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _createCompGroup,
                child: const Text('CREATE'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Configured Groups (${_compGroups.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _compGroups.length,
            itemBuilder: (context, idx) {
              final group = _compGroups[idx];
              return Card(
                child: ListTile(
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${group.sport} (${group.format})'),
                  trailing: Switch(
                    value: group.isActive,
                    onChanged: (_) => _toggleCompGroup(group),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteGroupsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Athlete Weight/Format Class',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _athleteGroupNameController,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              hintText: 'e.g. -80kg Male',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DropdownButton<String>(
                value: _athleteGroupSport,
                items: const [
                  DropdownMenuItem(
                    value: 'Streetlifting',
                    child: Text('Streetlifting'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _athleteGroupSport = val;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _athleteGroupFormat,
                items: const [
                  DropdownMenuItem(value: 'Modern', child: Text('Modern')),
                  DropdownMenuItem(value: 'Classic', child: Text('Classic')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _athleteGroupFormat = val;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _athleteGroupGender,
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Open', child: Text('Open')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _athleteGroupGender = val;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _athleteGroupMaxWeightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Weight Limit (kg, optional)',
                    hintText: 'e.g. 80.0',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _createAthleteGroup,
                child: const Text('CREATE'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Athlete Classes / Weight Divisions (${_athleteGroups.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _athleteGroups.length,
            itemBuilder: (context, idx) {
              final group = _athleteGroups[idx];
              return Card(
                child: ListTile(
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${group.sport} (${group.format}) • ${group.gender} • Limit: ${group.maxWeight ?? "Open"}',
                  ),
                  trailing: Switch(
                    value: group.isActive,
                    onChanged: (_) => _toggleAthleteGroup(group),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
