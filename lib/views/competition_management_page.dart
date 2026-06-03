import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/competition_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/filter_widgets.dart';
import 'competition_detail_page.dart';
import 'competition_creation_page.dart';
import 'competition_judging_page.dart';
import 'competition_library_page.dart';

class CompetitionManagementPage extends StatefulWidget {
  final bool isInline;

  const CompetitionManagementPage({
    super.key,
    this.isInline = false,
  });

  @override
  State<CompetitionManagementPage> createState() => _CompetitionManagementPageState();
}

class _CompetitionManagementPageState extends State<CompetitionManagementPage> {
  String _selectedCompetitionStatus = 'upcoming';

  @override
  void initState() {
    super.initState();
    // Fetch competitions on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<CompetitionProvider>(context, listen: false)
            .fetchCompetitions(status: _selectedCompetitionStatus);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUserProfile;

    if (currentUser == null) {
      final loginPrompt = Center(
        child: Text(
          'Please log in to manage competitions.',
          style: theme.textTheme.titleMedium,
        ),
      );
      if (widget.isInline) return loginPrompt;
      return Scaffold(
        appBar: AppBar(title: const Text('Competition Management')),
        body: loginPrompt,
      );
    }

    final manageableComps = provider.competitions.where((comp) {
      if (currentUser.isAdmin) return true;
      final bool ownsAssociation = comp.associationId != null &&
          provider.associations.any(
            (assoc) =>
                assoc.id == comp.associationId &&
                assoc.ownerId == currentUser.id,
          );
      final bool canManageIndividual =
          comp.associationId == null && currentUser.isCompetitionCreator;
      return ownsAssociation || canManageIndividual;
    }).toList();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;

    final mainWidget = _buildMainContent(
      context,
      provider,
      theme,
      isDesktop,
      isTablet,
      manageableComps,
    );

    if (widget.isInline) {
      return mainWidget;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Competition Management'),
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width - 56.0,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: CompetitionFilterContent(
                    provider: provider,
                    isDesktop: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: mainWidget,
      floatingActionButton: !isDesktop
          ? FloatingActionButton.extended(
              key: const Key('create_competition_fab'),
              backgroundColor: const Color(0xFFE94E1B),
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CompetitionCreationPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Competition'),
            )
          : null,
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
    List<dynamic> manageableComps,
  ) {
    final resultsWidget = manageableComps.isEmpty
        ? _buildEmptyState(theme, provider)
        : (provider.layout == CompetitionsLayout.list
            ? _buildCompactList(theme, manageableComps)
            : _buildGridList(theme, manageableComps, isDesktop, isTablet));

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar Filter
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Text(
                    'Filters',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: CompetitionFilterContent(
                      provider: provider,
                      isDesktop: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Results Panel
          Expanded(
            child: Column(
              children: [
                _buildResultsHeader(context, provider, theme, true, manageableComps.length),
                Expanded(child: resultsWidget),
              ],
            ),
          ),
        ],
      );
    } else {
      // Mobile / Tablet layout
      return Column(
        children: [
          _buildResultsHeader(context, provider, theme, false, manageableComps.length),
          Expanded(child: resultsWidget),
        ],
      );
    }
  }

  Widget _buildResultsHeader(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    int count,
  ) {
    final statusSelector = SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'upcoming',
          label: Text('Upcoming'),
          icon: Icon(Icons.upcoming, size: 16),
        ),
        ButtonSegment<String>(
          value: 'completed',
          label: Text('Completed'),
          icon: Icon(Icons.check_circle_outline, size: 16),
        ),
      ],
      selected: {_selectedCompetitionStatus},
      onSelectionChanged: (val) {
        final newStatus = val.first;
        setState(() {
          _selectedCompetitionStatus = newStatus;
        });
        provider.fetchCompetitions(status: newStatus);
      },
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: const Color(0xFFE94E1B),
        selectedForegroundColor: Colors.white,
      ),
    );

    final createButton = ElevatedButton.icon(
      key: const Key('create_competition_button'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CompetitionCreationPage(),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE94E1B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Create', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$count Competitions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            statusSelector,
            const SizedBox(width: 12),
            createButton,
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              iconColor: theme.colorScheme.onSurfaceVariant,
              icon: Icon(
                Icons.sort,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Sort options',
              offset: const Offset(0, 40),
              onSelected: (val) {
                provider.setSortOrder(val);
              },
              itemBuilder: (BuildContext context) => [
                CheckedPopupMenuItem<String>(
                  value: 'date_asc',
                  checked: provider.sortOrder == 'date_asc',
                  child: const Text('Date: Asc'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'date_desc',
                  checked: provider.sortOrder == 'date_desc',
                  child: const Text('Date: Desc'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'name_asc',
                  checked: provider.sortOrder == 'name_asc',
                  child: const Text('Name: A-Z'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'name_desc',
                  checked: provider.sortOrder == 'name_desc',
                  child: const Text('Name: Z-A'),
                ),
              ],
            ),

          ],
        ),
      );
    } else {
      // Mobile header
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
            child: Row(
              children: [
                Expanded(child: statusSelector),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$count Competitions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Filter options',
                      onPressed: () {
                        if (!widget.isInline) {
                          Scaffold.of(context).openEndDrawer();
                        } else {
                          // If inline (inside home navigation shell), open the shell's endDrawer
                          final ScaffoldState? shellScaffold = Scaffold.maybeOf(context);
                          if (shellScaffold != null && shellScaffold.hasEndDrawer) {
                            shellScaffold.openEndDrawer();
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      iconColor: theme.colorScheme.onSurfaceVariant,
                      icon: Icon(
                        Icons.sort,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Sort options',
                      offset: const Offset(0, 40),
                      onSelected: (val) {
                        provider.setSortOrder(val);
                      },
                      itemBuilder: (BuildContext context) => [
                        CheckedPopupMenuItem<String>(
                          value: 'date_asc',
                          checked: provider.sortOrder == 'date_asc',
                          child: const Text('Date: Asc'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'date_desc',
                          checked: provider.sortOrder == 'date_desc',
                          child: const Text('Date: Desc'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'name_asc',
                          checked: provider.sortOrder == 'name_asc',
                          child: const Text('Name: A-Z'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'name_desc',
                          checked: provider.sortOrder == 'name_desc',
                          child: const Text('Name: Z-A'),
                        ),
                      ],
                    ),

                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildEmptyState(ThemeData theme, CompetitionProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No competitions found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refining your search query or reset filters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: provider.clearFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactList(ThemeData theme, List<dynamic> competitions) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: competitions.length,
      itemBuilder: (context, index) {
        final comp = competitions[index];
        final dateStr = DateFormat('MMM dd, yyyy').format(comp.startDate);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              comp.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${comp.location} • $dateStr • ${comp.status.toUpperCase()}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'View Details',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompetitionDetailPage(competition: comp),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Manage Attempts',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompetitionJudgingPage(competitionId: comp.id),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridList(
    ThemeData theme,
    List<dynamic> competitions,
    bool isDesktop,
    bool isTablet,
  ) {
    final int crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
    final double childAspectRatio = isDesktop ? 0.95 : 1.1;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: competitions.length,
      itemBuilder: (context, index) {
        final comp = competitions[index];
        final dateStr = DateFormat('MMM dd, yyyy').format(comp.startDate);
        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: comp.isModern
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        comp.sportSubtype.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: comp.isModern
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    Text(
                      comp.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: comp.status == 'upcoming' ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  comp.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        comp.location,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                const Divider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('VIEW'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CompetitionDetailPage(competition: comp),
                          ),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94E1B),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      label: const Text('MANAGE'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CompetitionJudgingPage(competitionId: comp.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
