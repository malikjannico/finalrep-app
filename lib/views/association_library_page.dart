import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router.dart';
import 'package:provider/provider.dart';
import '../models/association.dart';
import '../providers/auth_provider.dart';
import '../providers/competition_provider.dart';
import '../widgets/filter_widgets.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'association_detail_page.dart';
import '../utils/image_url_resolver.dart';
import '../widgets/association_card.dart';
import '../widgets/unified_empty_state.dart';

class AssociationLibraryPage extends StatefulWidget {
  final bool isInline;

  const AssociationLibraryPage({
    super.key,
    this.isInline = false,
  });

  @override
  State<AssociationLibraryPage> createState() => _AssociationLibraryPageState();
}

class _AssociationLibraryPageState extends State<AssociationLibraryPage> {
  final Set<String> _selectedAssocScopes = {};
  final Set<String> _selectedAssocCountries = {};
  final Set<String> _selectedAssocAreas = {};
  final Set<String> _selectedAssocSports = {};
  final Set<String> _selectedAssocFormats = {};
  String _assocSortOrder = 'name_asc';
  bool _assocIsCompactLayout = false;
  bool _isLoading = false;
  late CompetitionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<CompetitionProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    if (_provider.query.isNotEmpty &&
        _provider.searchScope == SearchScope.associations &&
        _provider.selectedAssociationId == null &&
        _provider.selectedProfileUsername == null &&
        _provider.selectedProfileId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _provider.setQuery('');
      });
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);
    await compProvider.fetchAssociations();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context);

    if (_isLoading) {
      if (widget.isInline) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Associations Library')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allAssocs = compProvider.searchedAssociations;
    final filteredAssocs = allAssocs.where((assoc) {
      if (_selectedAssocScopes.isNotEmpty && !_selectedAssocScopes.contains(assoc.scope)) {
        return false;
      }
      if (_selectedAssocCountries.isNotEmpty || _selectedAssocAreas.isNotEmpty) {
        bool matchLocation = false;
        if (_selectedAssocCountries.contains('Global') && assoc.scope == 'global') {
          matchLocation = true;
        }
        if (assoc.country != null && _selectedAssocCountries.contains(assoc.country)) {
          matchLocation = true;
        }
        if (assoc.areaName != null && _selectedAssocAreas.contains(assoc.areaName)) {
          matchLocation = true;
        }
        if (!matchLocation) {
          return false;
        }
      }
      if (_selectedAssocSports.isNotEmpty && !_selectedAssocSports.any((s) => assoc.supportedSports.contains(s))) {
        return false;
      }
      if (_selectedAssocFormats.isNotEmpty && !_selectedAssocFormats.any((f) => assoc.supportedFormats.contains(f))) {
        return false;
      }
      return true;
    }).toList();

    if (_assocSortOrder == 'name_asc') {
      filteredAssocs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_assocSortOrder == 'name_desc') {
      filteredAssocs.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final emptyState = UnifiedEmptyState(
      title: 'No associations found',
      message: 'Try adjusting your search or filters.',
      onReset: () {
        setState(() {
          _selectedAssocScopes.clear();
          _selectedAssocCountries.clear();
          _selectedAssocAreas.clear();
          _selectedAssocSports.clear();
          _selectedAssocFormats.clear();
        });
        compProvider.searchAssociations('');
      },
    );

    final warningBanner = _buildAssocWarningBanner(context, theme, isDesktop);

    final mainContent = _buildAssocMainContent(
      context,
      filteredAssocs,
      theme,
      compProvider,
      isDesktop,
      emptyState,
      warningBanner,
    );

    final publicBody = isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
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
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildAssocFilterContent(context, compProvider, theme),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: mainContent,
              ),
            ],
          )
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 200) {
                Scaffold.of(context).openDrawer();
              } else if (velocity < -200) {
                _showMobileFilters(context);
              }
            },
            child: Column(
              children: [
                Expanded(child: mainContent),
                warningBanner,
              ],
            ),
          );

    return Scaffold(
      drawerEnableOpenDragGesture: false,
      endDrawerEnableOpenDragGesture: false,
      appBar: widget.isInline
          ? null
          : AppBar(
              title: const Text('Associations Library'),
            ),
      body: publicBody,
    );
  }

  Widget _buildAssocWarningBanner(BuildContext context, ThemeData theme, bool isDesktop) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserProfile;
    final bool hasAssocCreatorPrivilege =
        user != null && (user.isAssociationCreator || user.isAdmin);

    if (hasAssocCreatorPrivilege) return const SizedBox.shrink();

    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.2),
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
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
                    'Apply to register your association.',
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

  Widget _buildAssocMainContent(
    BuildContext context,
    List<Association> filteredAssocs,
    ThemeData theme,
    CompetitionProvider compProvider,
    bool isDesktop,
    Widget emptyState,
    Widget warningBanner,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: isDesktop
              ? const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${filteredAssocs.length} Associations',
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
                  if (!isDesktop) ...[
                    IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Filter options',
                      onPressed: () {
                        _showMobileFilters(context);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
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
                      setState(() {
                        _assocSortOrder = val;
                      });
                    },
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem(
                        value: 'name_asc',
                        checked: _assocSortOrder == 'name_asc',
                        child: const Text('Name: A-Z'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'name_desc',
                        checked: _assocSortOrder == 'name_desc',
                        child: const Text('Name: Z-A'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<bool>(
                    tooltip: 'Select layout ',
                    offset: const Offset(0, 40),
                    onSelected: (val) {
                      setState(() {
                        _assocIsCompactLayout = val;
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: true,
                        child: Row(
                          children: [
                            Icon(Icons.view_list, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            const Text('Compact View'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: false,
                        child: Row(
                          children: [
                            Icon(Icons.grid_view, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            const Text('Grid View'),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(
                      _assocIsCompactLayout ? Icons.view_list : Icons.grid_view,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isDesktop) warningBanner,
        Expanded(
          child: filteredAssocs.isEmpty
              ? emptyState
              : _assocIsCompactLayout
                  ? _buildCompactListView(filteredAssocs, theme)
                  : _buildGridListView(filteredAssocs, theme, isDesktop),
        ),
      ],
    );
  }

  Widget _buildCompactListView(List<Association> associations, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: associations.length,
      itemBuilder: (context, index) {
        final assoc = associations[index];
        return AssociationCompactRow(
          association: assoc,
          onRefresh: _loadData,
        );
      },
    );
  }

  Widget _buildGridListView(List<Association> associations, ThemeData theme, bool isDesktop) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width >= 600 ? 2 : 1),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 250, // Adjusted for premium content height
      ),
      itemCount: associations.length,
      itemBuilder: (context, index) {
        final assoc = associations[index];
        return AssociationCard(
          association: assoc,
          onRefresh: _loadData,
        );
      },
    );
  }

  void _showMobileFilters(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context, listen: false);

    final drawerContent = Material(
      color: theme.colorScheme.surface,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
            Navigator.of(context).pop();
          }
        },
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
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildAssocFilterContent(context, compProvider, theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 56.0,
            child: drawerContent,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    );
  }

  Widget _buildActiveFilterChips(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
  ) {
    final List<Widget> chips = [];

    if (provider.query.isNotEmpty && provider.searchScope == SearchScope.associations) {
      chips.add(
        RawChip(
          label: Text('Search: "${provider.query}"'),
          onDeleted: () {
            provider.setSearchScopeAndQuery(SearchScope.associations, '');
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

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  Widget _buildAssocFilterContent(BuildContext context, CompetitionProvider provider, ThemeData theme) {
    final allAssocs = provider.searchedAssociations;
    final scopes = ['global', 'area', 'national', 'local'];
    final scopeLabels = {
      'global': 'Global',
      'area': 'Area',
      'national': 'National',
      'local': 'Local',
    };

    final areas = allAssocs
        .map((e) => e.areaName)
        .where((a) => a != null && a.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    areas.sort();

    final countries = allAssocs
        .map((e) => e.country)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    countries.sort();

    final config = provider.sportConfig;
    final sports = config?.sports.map((s) => s.name).toSet().toList() ?? ['Streetlifting'];

    int getScopeCount(String scope) => allAssocs.where((assoc) => assoc.scope == scope).length;
    int getAreaCount(String area) => allAssocs.where((assoc) => assoc.areaName == area).length;
    int getCountryCount(String country) => allAssocs.where((assoc) => assoc.country == country).length;
    int getSportCount(String sport) => allAssocs.where((assoc) => assoc.supportedSports.contains(sport)).length;
    int getFormatCount(String format) => allAssocs.where((assoc) => assoc.supportedFormats.contains(format)).length;
    int getGlobalCount() => allAssocs.where((assoc) => assoc.scope == 'global').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActiveFilterChips(context, provider, theme),
        CollapsibleFilterSection(
          title: 'Sport & Format',
          isInitiallyExpanded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...sports.map((s) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterCheckboxRow(
                      label: s,
                      value: _selectedAssocSports.contains(s),
                      count: getSportCount(s),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedAssocSports.add(s);
                          } else {
                            _selectedAssocSports.remove(s);
                          }
                        });
                      },
                    ),
                    (() {
                      final sportFormats = config?.formats
                          .where((f) => f.sportName == s)
                          .map((f) => f.name)
                          .toList() ?? (s == 'Streetlifting' ? ['Modern', 'Classic'] : []);
                      if (sportFormats.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 20.0, top: 4.0, bottom: 4.0),
                        child: Column(
                          children: sportFormats.map((f) {
                            return FilterCheckboxRow(
                              label: f,
                              value: _selectedAssocFormats.contains(f),
                              count: getFormatCount(f),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedAssocFormats.add(f);
                                  } else {
                                    _selectedAssocFormats.remove(f);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      );
                    })(),
                  ],
                );
              }),
            ],
          ),
        ),
        CollapsibleFilterSection(
          title: 'Scope',
          isInitiallyExpanded: false,
          child: Column(
            children: scopes.map((s) {
              return FilterCheckboxRow(
                label: scopeLabels[s] ?? s,
                value: _selectedAssocScopes.contains(s),
                count: getScopeCount(s),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedAssocScopes.add(s);
                    } else {
                      _selectedAssocScopes.remove(s);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        CollapsibleFilterSection(
          title: 'Location',
          isInitiallyExpanded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterCheckboxRow(
                label: 'Global',
                value: _selectedAssocCountries.contains('Global'),
                count: getGlobalCount(),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedAssocCountries.add('Global');
                    } else {
                      _selectedAssocCountries.remove('Global');
                    }
                  });
                },
              ),
              if (areas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'AREAS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                ...areas.map((a) {
                  return FilterCheckboxRow(
                    label: a,
                    value: _selectedAssocAreas.contains(a),
                    count: getAreaCount(a),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedAssocAreas.add(a);
                        } else {
                          _selectedAssocAreas.remove(a);
                        }
                      });
                    },
                  );
                }),
              ],
              if (countries.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'COUNTRIES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                ...countries.map((c) {
                  return FilterCheckboxRow(
                    label: c,
                    value: _selectedAssocCountries.contains(c),
                    count: getCountryCount(c),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedAssocCountries.add(c);
                        } else {
                          _selectedAssocCountries.remove(c);
                        }
                      });
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
