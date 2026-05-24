import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/association.dart';
import '../models/association_member.dart';
import '../models/competition_group.dart';
import '../models/athlete_group.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import 'association_management_page.dart';

class AssociationDetailPage extends StatefulWidget {
  final String associationId;

  const AssociationDetailPage({super.key, required this.associationId});

  @override
  State<AssociationDetailPage> createState() => _AssociationDetailPageState();
}

class _AssociationDetailPageState extends State<AssociationDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Association? _association;
  List<AssociationMember> _members = [];
  List<CompetitionGroup> _compGroups = [];
  List<AthleteGroup> _athleteGroups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final compProvider = Provider.of<CompetitionProvider>(
      context,
      listen: false,
    );
    try {
      final assoc = await compProvider.getAssociationDetails(
        widget.associationId,
      );
      if (assoc != null) {
        final membersList = await compProvider.getAssociationMembers(
          widget.associationId,
        );
        final compGroupsList = await compProvider.getCompetitionGroups(
          widget.associationId,
        );
        final athleteGroupsList = await compProvider.getAthleteGroups(
          widget.associationId,
        );
        setState(() {
          _association = assoc;
          _members = membersList;
          _compGroups = compGroupsList;
          _athleteGroups = athleteGroupsList;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading association details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _canManage(String? currentUserId, bool isAdmin) {
    if (isAdmin) return true;
    if (currentUserId == null || _association == null) return false;
    if (_association!.ownerId == currentUserId) return true;

    // Check if user is editor in members list
    return _members.any(
      (member) =>
          member.userId == currentUserId &&
          (member.role == 'owner' || member.role == 'editor'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUserProfile;
    final isAdmin = authProvider.isAdmin;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Association Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_association == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Association Not Found')),
        body: const Center(
          child: Text('Could not find the requested association.'),
        ),
      );
    }

    final assoc = _association!;
    final isAuthorizedToManage = _canManage(currentUser?.id, isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Text(assoc.name),
        actions: [
          if (isAuthorizedToManage)
            TextButton.icon(
              icon: const Icon(Icons.edit, color: Colors.orange),
              label: const Text(
                'MANAGE',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AssociationManagementPage(associationId: assoc.id),
                  ),
                );
                _loadData();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Info'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'Members'),
            Tab(icon: Icon(Icons.list_alt_outlined), text: 'Comp Groups'),
            Tab(
              icon: Icon(Icons.fitness_center_outlined),
              text: 'Athlete Groups',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(assoc, theme),
          _buildMembersTab(theme),
          _buildCompGroupsTab(theme),
          _buildAthleteGroupsTab(theme),
        ],
      ),
    );
  }

  Widget _buildInfoTab(Association assoc, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  assoc.scope.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (assoc.areaName != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Territory: ${assoc.areaName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Description',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(assoc.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text(
            'Rulebooks',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (assoc.rulebooks.isEmpty)
            const Text('No rulebooks published yet.')
          else
            Column(
              children: assoc.rulebooks.entries.map((e) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                    ),
                    title: Text('${e.key} Rulebook'),
                    subtitle: Text(
                      e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // Open external URL
                    },
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          Text(
            'Social Channels',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (assoc.socialChannels.isEmpty)
            const Text('No social channels added.')
          else
            Wrap(
              spacing: 12,
              children: assoc.socialChannels.entries.map((e) {
                return ActionChip(
                  avatar: Icon(
                    e.key == 'Instagram'
                        ? Icons.camera_alt_outlined
                        : Icons.link,
                    size: 16,
                  ),
                  label: Text('${e.key}: @${e.value}'),
                  onPressed: () {},
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(ThemeData theme) {
    if (_members.isEmpty) {
      return const Center(child: Text('No members found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isOwner = member.role == 'owner';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOwner
                  ? Colors.orange.withOpacity(0.2)
                  : theme.colorScheme.primaryContainer,
              child: Icon(
                isOwner ? Icons.workspace_premium : Icons.person,
                color: isOwner ? Colors.orange : theme.colorScheme.primary,
              ),
            ),
            title: Text(
              member.userId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ), // In a real app we load profile name
            subtitle: Text(member.customTitle ?? member.role.toUpperCase()),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOwner
                    ? Colors.orange.withOpacity(0.1)
                    : theme.colorScheme.outlineVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                member.role.toUpperCase(),
                style: TextStyle(
                  color: isOwner
                      ? Colors.orange
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompGroupsTab(ThemeData theme) {
    if (_compGroups.isEmpty) {
      return const Center(child: Text('No competition groups configured.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _compGroups.length,
      itemBuilder: (context, index) {
        final group = _compGroups[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.list_alt, color: Colors.blue),
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Sport: ${group.sport} (${group.format})'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: group.isActive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                group.isActive ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(
                  color: group.isActive ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAthleteGroupsTab(ThemeData theme) {
    if (_athleteGroups.isEmpty) {
      return const Center(child: Text('No athlete groups configured.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _athleteGroups.length,
      itemBuilder: (context, index) {
        final group = _athleteGroups[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.fitness_center, color: Colors.purple),
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Sport: ${group.sport} (${group.format}) • Gender: ${group.gender} • Max weight: ${group.maxWeight ?? "Open"}',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: group.isActive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                group.isActive ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(
                  color: group.isActive ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
