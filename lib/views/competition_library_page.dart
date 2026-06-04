import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/competition.dart';
import '../providers/competition_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/competition_card.dart';
import '../widgets/competition_compact_row.dart';
import '../widgets/profile_card.dart';
import '../widgets/user_compact_row.dart';
import '../widgets/filter_widgets.dart';
import 'competition_detail_page.dart';
import 'association_detail_page.dart';
import '../widgets/unified_empty_state.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'world_map_view.dart';

class CompetitionLibraryPage extends StatefulWidget {
  const CompetitionLibraryPage({super.key});

  @override
  State<CompetitionLibraryPage> createState() => _CompetitionLibraryPageState();
}

class _CompetitionLibraryPageState extends State<CompetitionLibraryPage> {
  String _selectedCompetitionStatus = 'upcoming';
  bool _userIsCompactLayout = false;
  String? _selectedProfileId;
  String? _selectedProfileUsername;
  late CompetitionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<CompetitionProvider>(context, listen: false);
    _provider.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    if (_provider.query.isNotEmpty &&
        _provider.searchScope == SearchScope.competitions &&
        _provider.selectedAssociationId == null &&
        _provider.selectedProfileUsername == null &&
        _provider.selectedProfileId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _provider.setQuery('');
      });
    }
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    if (_provider.query.isNotEmpty) {
      setState(() {
        _selectedProfileId = null;
        _selectedProfileUsername = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;

    if (isDesktop &&
        (_selectedProfileId != null || _selectedProfileUsername != null)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 16),
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to search feed'),
              onPressed: () {
                setState(() {
                  _selectedProfileId = null;
                  _selectedProfileUsername = null;
                });
              },
            ),
          ),
          Expanded(
            child: ProfilePage(
              userId: _selectedProfileId,
              username: _selectedProfileUsername,
              isInline: true,
              profileRepository: provider.profileRepository,
            ),
          ),
        ],
      );
    }

    return _buildMainContent(context, provider, theme, isDesktop, isTablet);
  }

  Widget _buildMainContent(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    final isUsers = false;
    final isAssociations = false;

    final activeWidget = isUsers
        ? _buildUsersListGrid(context, provider, theme, isDesktop, isTablet)
        : isAssociations
            ? _buildAssociationsListGrid(
                context,
                provider,
                theme,
                isDesktop,
                isTablet,
              )
            : (provider.layout == CompetitionsLayout.map
                ? const WorldMapView()
                : _buildCompetitionsListGrid(
                    context,
                    provider,
                    theme,
                    isDesktop,
                    isTablet,
                  ));

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar (always visible on desktop, hidden for users and associations search scope)
          if (!isUsers && !isAssociations)
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
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
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
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

          // Right Content Panel
          Expanded(
            child: Column(
              children: [
                isUsers
                    ? _buildUsersResultsHeader(context, provider, theme, true)
                    : isAssociations
                        ? _buildAssociationsResultsHeader(
                            context,
                            provider,
                            theme,
                            true,
                          )
                        : _buildResultsHeader(context, provider, theme, true),
                Expanded(child: activeWidget),
              ],
            ),
          ),
        ],
      );
    } else {
      // Mobile / Tablet Feed View
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 200) {
            Scaffold.of(context).openDrawer();
          } else if (velocity < -200) {
            if (!isUsers && !isAssociations) {
              Scaffold.of(context).openEndDrawer();
            }
          }
        },
        child: Column(
          children: [
            isUsers
                ? _buildUsersResultsHeader(context, provider, theme, false)
                : isAssociations
                    ? _buildAssociationsResultsHeader(
                        context,
                        provider,
                        theme,
                        false,
                      )
                    : _buildResultsHeader(context, provider, theme, false),
            Expanded(child: activeWidget),
          ],
        ),
      );
    }
  }

  Widget _buildUsersResultsHeader(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
  ) {
    final headerPadding = isDesktop
        ? const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Padding(
      padding: headerPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${provider.searchedUsers.length} Users',
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
              PopupMenuButton<bool>(
                tooltip: 'Select layout',
                offset: const Offset(0, 40),
                onSelected: (bool isCompact) {
                  setState(() {
                    _userIsCompactLayout = isCompact;
                  });
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<bool>(
                    value: false,
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Grid Layout',
                          style: TextStyle(
                            fontWeight: !_userIsCompactLayout
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<bool>(
                    value: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_list,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Compact Layout',
                          style: TextStyle(
                            fontWeight: _userIsCompactLayout
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  !_userIsCompactLayout ? Icons.grid_view : Icons.view_list,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssociationsResultsHeader(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
  ) {
    final headerPadding = isDesktop
        ? const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Padding(
      padding: headerPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${provider.searchedAssociations.length} Associations',
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
              PopupMenuButton<bool>(
                tooltip: 'Select layout',
                offset: const Offset(0, 40),
                onSelected: (bool isCompact) {
                  setState(() {
                    _userIsCompactLayout = isCompact;
                  });
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<bool>(
                    value: false,
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Grid Layout',
                          style: TextStyle(
                            fontWeight: !_userIsCompactLayout
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<bool>(
                    value: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_list,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Compact Layout',
                          style: TextStyle(
                            fontWeight: _userIsCompactLayout
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  !_userIsCompactLayout ? Icons.grid_view : Icons.view_list,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
  ) {
    final showLabels = true;
    final statusSelector = SegmentedButton<String>(
      segments: [
        ButtonSegment<String>(
          value: 'upcoming',
          label: showLabels ? const Text('Upcoming') : null,
          icon: const Icon(Icons.upcoming, size: 16),
        ),
        ButtonSegment<String>(
          value: 'completed',
          label: showLabels ? const Text('Completed') : null,
          icon: const Icon(Icons.check_circle_outline, size: 16),
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

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${provider.competitions.length} Competitions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            statusSelector,
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provider.layout != CompetitionsLayout.map) ...[
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
                  const SizedBox(width: 8),
                ],
                PopupMenuButton<CompetitionsLayout>(
                  tooltip: 'Select layout',
                  offset: const Offset(0, 40),
                  onSelected: (CompetitionsLayout layout) {
                    provider.setLayout(layout);
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<CompetitionsLayout>(
                      value: CompetitionsLayout.grid,
                      child: Row(
                        children: [
                          Icon(
                            Icons.grid_view,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Grid Layout',
                            style: TextStyle(
                              fontWeight: provider.layout == CompetitionsLayout.grid
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<CompetitionsLayout>(
                      value: CompetitionsLayout.list,
                      child: Row(
                        children: [
                          Icon(
                            Icons.view_list,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Compact Layout',
                            style: TextStyle(
                              fontWeight: provider.layout == CompetitionsLayout.list
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<CompetitionsLayout>(
                      value: CompetitionsLayout.map,
                      child: Row(
                        children: [
                          Icon(
                            Icons.map,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Map View',
                            style: TextStyle(
                              fontWeight: provider.layout == CompetitionsLayout.map
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(
                    provider.layout == CompetitionsLayout.grid
                        ? Icons.grid_view
                        : provider.layout == CompetitionsLayout.list
                            ? Icons.view_list
                            : Icons.map,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
            child: SizedBox(
              width: double.infinity,
              child: statusSelector,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${provider.competitions.length} Competitions',
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
                        Scaffold.of(context).openEndDrawer();
                      },
                    ),
                    const SizedBox(width: 8),
                    if (provider.layout != CompetitionsLayout.map) ...[
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
                      const SizedBox(width: 8),
                    ],
                    PopupMenuButton<CompetitionsLayout>(
                      tooltip: 'Select layout',
                      offset: const Offset(0, 40),
                      onSelected: (CompetitionsLayout layout) {
                        provider.setLayout(layout);
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<CompetitionsLayout>(
                          value: CompetitionsLayout.grid,
                          child: Row(
                            children: [
                              Icon(
                                Icons.grid_view,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              const Text('Grid Layout'),
                            ],
                          ),
                        ),
                        PopupMenuItem<CompetitionsLayout>(
                          value: CompetitionsLayout.list,
                          child: Row(
                            children: [
                              Icon(
                                Icons.view_list,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              const Text('Compact Layout'),
                            ],
                          ),
                        ),
                        PopupMenuItem<CompetitionsLayout>(
                          value: CompetitionsLayout.map,
                          child: Row(
                            children: [
                              Icon(
                                Icons.map,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              const Text('Map View'),
                            ],
                          ),
                        ),
                      ],
                      icon: Icon(
                        provider.layout == CompetitionsLayout.grid
                            ? Icons.grid_view
                            : provider.layout == CompetitionsLayout.list
                                ? Icons.view_list
                                : Icons.map,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

  Widget _buildCompetitionsListGrid(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Text(
          provider.errorMessage!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserProfile;
    final bool hasCompCreatorPrivilege =
        user != null && (user.isCompetitionCreator || user.isAdmin);

    Widget buildBannerWidget() {
      return Card(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        margin: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 16,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apply to organize your competition.',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  if (authProvider.isAuthenticated) {
                    try {
                      GoRouter.of(context);
                      goRouter.push('/settings');
                    } catch (_) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/settings'),
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    }
                  } else {
                    try {
                      GoRouter.of(context);
                      goRouter.push('/login');
                    } catch (_) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/login'),
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                child: Text(
                  authProvider.isAuthenticated ? 'APPLY NOW' : 'LOG IN',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.competitions.isEmpty) {
      final emptyContent = UnifiedEmptyState(
        key: const Key('competitions_empty_state'),
        title: 'No competitions found',
        message: 'Try refining your search query or reset filters.',
        onReset: provider.clearFilters,
      );

      if (!hasCompCreatorPrivilege) {
        if (isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildBannerWidget(),
              Expanded(child: emptyContent),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: emptyContent),
              buildBannerWidget(),
            ],
          );
        }
      }
      return emptyContent;
    }

    final Widget gridContent = CustomScrollView(
      slivers: [
        if (!hasCompCreatorPrivilege && isDesktop)
          SliverToBoxAdapter(child: buildBannerWidget()),
        if (provider.isCompactLayout)
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 12,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final comp = provider.competitions[index];
                return CompetitionCompactRow(
                  competition: comp,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: RouteSettings(
                          name: '/competitions/${comp.id}',
                        ),
                        builder: (_) =>
                            CompetitionDetailPage(competition: comp),
                      ),
                    );
                  },
                );
              }, childCount: provider.competitions.length),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(
              left: isDesktop ? 24 : 16,
              right: isDesktop ? 24 : 16,
              bottom: 40,
              top: 12,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 380,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final comp = provider.competitions[index];
                return CompetitionCard(
                  key: Key('comp_card_${comp.id}'),
                  competition: comp,
                );
              }, childCount: provider.competitions.length),
            ),
          ),
      ],
    );

    if (!isDesktop && !hasCompCreatorPrivilege) {
      return Column(
        children: [
          Expanded(child: gridContent),
          buildBannerWidget(),
        ],
      );
    }
    return gridContent;
  }

  Widget _buildUsersListGrid(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    if (provider.isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Text(
          provider.errorMessage!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    if (provider.searchedUsers.isEmpty) {
      return UnifiedEmptyState(
        key: const Key('users_empty_state'),
        title: 'No users found',
        message: 'Try refining your search query.',
        onReset: () => provider.searchUsers(''),
        buttonText: 'Clear Search',
        icon: Icons.person_off_outlined,
      );
    }

    return CustomScrollView(
      slivers: [
        if (_userIsCompactLayout)
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 12,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final user = provider.searchedUsers[index];
                return UserCompactRow(
                  profile: user,
                  onTap: isDesktop
                      ? () {
                          setState(() {
                            _selectedProfileId = user.id;
                            _selectedProfileUsername = user.username;
                          });
                        }
                      : null,
                );
              }, childCount: provider.searchedUsers.length),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(
              left: isDesktop ? 24 : 16,
              right: isDesktop ? 24 : 16,
              bottom: 40,
              top: 12,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 150,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final user = provider.searchedUsers[index];
                return ProfileCard(
                  profile: user,
                  onTap: isDesktop
                      ? () {
                          setState(() {
                            _selectedProfileId = user.id;
                            _selectedProfileUsername = user.username;
                          });
                        }
                      : null,
                );
              }, childCount: provider.searchedUsers.length),
            ),
          ),
      ],
    );
  }

  Widget _buildAssociationsListGrid(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    if (provider.isLoadingAssociations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Text(
          provider.errorMessage!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    if (provider.searchedAssociations.isEmpty) {
      return UnifiedEmptyState(
        key: const Key('associations_empty_state'),
        title: 'No associations found',
        message: 'Try refining your search query.',
        onReset: () => provider.searchAssociations(''),
        buttonText: 'Clear Search',
        icon: Icons.grid_off_outlined,
      );
    }

    return CustomScrollView(
      slivers: [
        if (_userIsCompactLayout)
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 12,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final assoc = provider.searchedAssociations[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        assoc.name.isNotEmpty
                            ? assoc.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      assoc.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Scope: ${assoc.scope.toUpperCase()} • ${assoc.supportedSports.join(", ")}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: RouteSettings(name: '/associations/${assoc.id}'),
                          builder: (_) =>
                              AssociationDetailPage(associationId: assoc.id),
                        ),
                      );
                    },
                  ),
                );
              }, childCount: provider.searchedAssociations.length),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(
              left: isDesktop ? 24 : 16,
              right: isDesktop ? 24 : 16,
              bottom: 40,
              top: 12,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 160,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final assoc = provider.searchedAssociations[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: RouteSettings(name: '/associations/${assoc.id}'),
                          builder: (_) =>
                              AssociationDetailPage(associationId: assoc.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Text(
                                  assoc.name.isNotEmpty
                                      ? assoc.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  assoc.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Text(
                              assoc.description.isEmpty
                                  ? 'No description provided.'
                                  : assoc.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  assoc.scope.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              Text(
                                assoc.supportedSports.join(', '),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: provider.searchedAssociations.length),
            ),
          ),
      ],
    );
  }
}

class CompetitionFilterContent extends StatefulWidget {
  final CompetitionProvider provider;
  final bool isDesktop;

  const CompetitionFilterContent({
    super.key,
    required this.provider,
    this.isDesktop = false,
  });

  @override
  State<CompetitionFilterContent> createState() =>
      _CompetitionFilterContentState();
}

class _CompetitionFilterContentState extends State<CompetitionFilterContent> {
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _associationSearchController;
  late FocusNode _startFocusNode;
  late FocusNode _endFocusNode;
  String _associationSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _associationSearchController = TextEditingController();
    _startFocusNode = FocusNode();
    _endFocusNode = FocusNode();

    _syncDateControllers(widget.provider.selectedDateRange);
    widget.provider.addListener(_onProviderChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.provider.associations.isEmpty) {
        widget.provider.fetchAssociations();
      }
    });
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    _startDateController.dispose();
    _endDateController.dispose();
    _associationSearchController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final currentRange = widget.provider.selectedDateRange;
    if (currentRange == null) {
      if (_startDateController.text.isNotEmpty ||
          _endDateController.text.isNotEmpty) {
        setState(() {
          _startDateController.clear();
          _endDateController.clear();
        });
      }
    } else {
      final startStr = DateFormat('yyyy-MM-dd').format(currentRange.start);
      final endStr = DateFormat('yyyy-MM-dd').format(currentRange.end);
      if (_startDateController.text != startStr && !_startFocusNode.hasFocus) {
        setState(() {
          _startDateController.text = startStr;
        });
      }
      if (_endDateController.text != endStr && !_endFocusNode.hasFocus) {
        setState(() {
          _endDateController.text = endStr;
        });
      }
    }
  }

  void _syncDateControllers(DateTimeRange? range) {
    if (range == null) {
      _startDateController.clear();
      _endDateController.clear();
    } else {
      _startDateController.text = DateFormat('yyyy-MM-dd').format(range.start);
      _endDateController.text = DateFormat('yyyy-MM-dd').format(range.end);
    }
  }

  void _updateDateRangeFromText() {
    final startText = _startDateController.text.trim();
    final endText = _endDateController.text.trim();

    if (startText.isEmpty && endText.isEmpty) {
      widget.provider.clearDateRange();
      return;
    }

    if (startText.length == 10 && endText.length == 10) {
      final start = DateTime.tryParse(startText);
      final end = DateTime.tryParse(endText);
      if (start != null && end != null) {
        if (start.isBefore(end) || start.isAtSameMomentAs(end)) {
          widget.provider.setDateRange(DateTimeRange(start: start, end: end));
        }
      }
    }
  }

  void _selectDateRange(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: widget.provider.selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      widget.provider.setDateRange(picked);
      _syncDateControllers(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = widget.provider;

    final config = provider.sportConfig;
    final sports = config?.sports.map((s) => s.name).toSet().toList() ?? ['Streetlifting'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActiveFilterChips(context, provider, theme, isDesktop: widget.isDesktop),
        CollapsibleFilterSection(
          title: 'Sport & Format',
          isInitiallyExpanded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...sports.map((s) {
                final sportFormats = config?.formats
                    .where((f) => f.sportName == s)
                    .map((f) => f.name)
                    .toList() ?? (s == 'Streetlifting' ? ['Modern', 'Classic'] : []);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterCheckboxRow(
                      s,
                      provider.selectedSports.contains(s),
                      provider.getSportCount(s),
                      (val) => provider.toggleSport(s),
                      theme,
                    ),
                    if (sportFormats.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, top: 4.0, bottom: 4.0),
                        child: Column(
                          children: sportFormats.map((f) {
                            return _buildFilterCheckboxRow(
                              f,
                              provider.selectedSubtypes.contains(f),
                              provider.getSubtypeCount(f),
                              (val) => provider.toggleSubtype(f),
                              theme,
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
        if (provider.associations.isNotEmpty)
          CollapsibleFilterSection(
            title: 'Association',
            isInitiallyExpanded: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: _associationSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search association...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (val) {
                      setState(() {
                        _associationSearchQuery = val;
                      });
                    },
                  ),
                ),
                ...provider.associations
                    .where((assoc) => assoc.name
                        .toLowerCase()
                        .contains(_associationSearchQuery.toLowerCase()))
                    .map((assoc) {
                  final isChecked = provider.selectedAssociationId == assoc.id;
                  final count = provider.allCompetitions.where((c) => c.associationId == assoc.id).length;
                  return _buildFilterCheckboxRow(
                    assoc.name,
                    isChecked,
                    count,
                    (val) {
                      if (isChecked) {
                        provider.selectAssociation(null);
                      } else {
                        provider.selectAssociation(assoc.id);
                      }
                    },
                    theme,
                  );
                }).toList(),
              ],
            ),
          ),
        () {
          final List<String> existingGroups = provider.allCompetitions
              .map((c) => c.compGroupName)
              .where((g) => g != null && g.isNotEmpty)
              .cast<String>()
              .toSet()
              .toList();
          existingGroups.sort();

          final hasIndividual = provider.allCompetitions.any((c) => !c.isPartOfGroup);

          final List<String> availableGroups = [];
          if (provider.associations.isNotEmpty || existingGroups.isNotEmpty) {
            availableGroups.addAll(existingGroups);
            if (hasIndividual || existingGroups.isNotEmpty) {
              availableGroups.add('Individual');
            }
          }

          if (availableGroups.isEmpty) {
            return const SizedBox.shrink();
          }

          return CollapsibleFilterSection(
            title: 'Group',
            child: Column(
              children: availableGroups.map((group) {
                return _buildFilterCheckboxRow(
                  group,
                  provider.selectedGroups.contains(group),
                  provider.getGroupCount(group),
                  (val) {
                    provider.toggleGroup(group);
                  },
                  theme,
                );
              }).toList(),
            ),
          );
        }(),
        CollapsibleFilterSection(
          title: 'Location',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.availableAreas.isNotEmpty) ...[
                Text(
                  'AREAS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ...provider.availableAreas.map((area) {
                  return _buildFilterCheckboxRow(
                    area,
                    provider.selectedAreas.contains(area),
                    provider.getAreaCount(area),
                    (val) => provider.toggleArea(area),
                    theme,
                  );
                }),
                const SizedBox(height: 8),
              ],
              if (provider.availableCountries.isNotEmpty) ...[
                Text(
                  'COUNTRIES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ...provider.availableCountries.map((country) {
                  return _buildFilterCheckboxRow(
                    country,
                    provider.selectedCountries.contains(country),
                    provider.getCountryCount(country),
                    (val) => provider.toggleCountry(country),
                    theme,
                  );
                }),
                const SizedBox(height: 8),
              ],
              if (provider.availableCities.isNotEmpty) ...[
                Text(
                  'CITIES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ...provider.availableCities.map((city) {
                  return _buildFilterCheckboxRow(
                    city,
                    provider.selectedCities.contains(city),
                    provider.getCityCount(city),
                    (val) => provider.toggleCity(city),
                    theme,
                  );
                }),
              ],
            ],
          ),
        ),
        CollapsibleFilterSection(
          title: 'Date Range',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startDateController,
                      focusNode: _startFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Start',
                        hintText: 'YYYY-MM-DD',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.datetime,
                      onChanged: (_) => _updateDateRangeFromText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _endDateController,
                      focusNode: _endFocusNode,
                      decoration: InputDecoration(
                        labelText: 'End',
                        hintText: 'YYYY-MM-DD',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.datetime,
                      onChanged: (_) => _updateDateRangeFromText(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.calendar_month, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _selectDateRange(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCheckboxRow(
    String label,
    bool isSelected,
    int count,
    ValueChanged<bool?> onChanged,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme, {
    required bool isDesktop,
  }) {
    final List<Widget> chips = [];

    if (provider.query.isNotEmpty) {
      chips.add(
        RawChip(
          label: Text('Search: "${provider.query}"'),
          onDeleted: () {
            provider.setQuery('');
          },
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    if (provider.selectedAssociationId != null) {
      final assoc = provider.associations
          .where((a) => a.id == provider.selectedAssociationId)
          .firstOrNull;
      final labelText = assoc != null ? 'Association: ${assoc.name}' : 'Association';
      chips.add(
        RawChip(
          label: Text(labelText),
          onDeleted: () {
            provider.selectAssociation(null);
          },
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    for (final sport in provider.selectedSports) {
      chips.add(
        RawChip(
          label: Text('Sport: $sport'),
          onDeleted: () => provider.toggleSport(sport),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    for (final subtype in provider.selectedSubtypes) {
      chips.add(
        RawChip(
          label: Text('Format: $subtype'),
          onDeleted: () => provider.toggleSubtype(subtype),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    for (final group in provider.selectedGroups) {
      chips.add(
        RawChip(
          label: Text('Group: $group'),
          onDeleted: () => provider.toggleGroup(group),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    for (final area in provider.selectedAreas) {
      chips.add(
        RawChip(
          label: Text('Area: $area'),
          onDeleted: () => provider.toggleArea(area),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    for (final country in provider.selectedCountries) {
      chips.add(
        RawChip(
          label: Text('Country: $country'),
          onDeleted: () => provider.toggleCountry(country),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    for (final city in provider.selectedCities) {
      chips.add(
        RawChip(
          label: Text('City: $city'),
          onDeleted: () => provider.toggleCity(city),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    if (provider.selectedDateRange != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(provider.selectedDateRange!.start);
      final endStr = DateFormat('yyyy-MM-dd').format(provider.selectedDateRange!.end);
      chips.add(
        RawChip(
          label: Text('Date: $startStr to $endStr'),
          onDeleted: () => provider.clearDateRange(),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...chips,
              TextButton(
                onPressed: provider.clearFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Reset All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
