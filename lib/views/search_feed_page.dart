import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/competition.dart';
import '../providers/competition_provider.dart';
import '../widgets/competition_card.dart';
import '../widgets/competition_compact_row.dart';
import 'competition_detail_page.dart';
import 'mobile_search_page.dart';
import 'world_map_view.dart';

class SearchFeedPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const SearchFeedPage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<SearchFeedPage> createState() => _SearchFeedPageState();
}

class _SearchFeedPageState extends State<SearchFeedPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  late CompetitionProvider _provider;
  bool _hasCheckedSharedLink = false;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<CompetitionProvider>(context, listen: false);
    _provider.addListener(_onProviderChanged);
    _syncDateControllers(_provider.selectedDateRange);

    // Check deep link routing after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkSharedLink(_provider);
      }
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    _startDateController.dispose();
    _endDateController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;

    // Safely update the text controllers out of the build phase
    final currentRange = _provider.selectedDateRange;
    if (currentRange == null) {
      if (_startDateController.text.isNotEmpty ||
          _endDateController.text.isNotEmpty) {
        _startDateController.clear();
        _endDateController.clear();
      }
    } else {
      final startStr = DateFormat('yyyy-MM-dd').format(currentRange.start);
      final endStr = DateFormat('yyyy-MM-dd').format(currentRange.end);
      if (_startDateController.text != startStr && !_startFocusNode.hasFocus) {
        _startDateController.text = startStr;
      }
      if (_endDateController.text != endStr && !_endFocusNode.hasFocus) {
        _endDateController.text = endStr;
      }
    }

    // Attempt to route to shared link once data has loaded
    _checkSharedLink(_provider);
  }

  String? _getSharedCompetitionId() {
    if (!kIsWeb) return null;
    final uri = Uri.base;

    // 1. Check path segments: /competitions/uuid
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'competitions') {
      return uri.pathSegments[1];
    }

    // 2. Check fragment (hash routing): /#/competitions/uuid
    if (uri.fragment.isNotEmpty) {
      try {
        final cleanFragment = uri.fragment.startsWith('/')
            ? uri.fragment
            : '/${uri.fragment}';
        final fragmentUri = Uri.parse(cleanFragment);
        if (fragmentUri.pathSegments.length >= 2 &&
            fragmentUri.pathSegments[0] == 'competitions') {
          return fragmentUri.pathSegments[1];
        }
      } catch (_) {}
    }

    // 3. Fallback to query parameter: ?competitionId=uuid
    if (uri.queryParameters.containsKey('competitionId')) {
      return uri.queryParameters['competitionId'];
    }

    return null;
  }

  void _checkSharedLink(CompetitionProvider provider) {
    if (_hasCheckedSharedLink) return;
    if (provider.isLoading) return;

    final sharedId = _getSharedCompetitionId();
    if (sharedId != null && provider.allCompetitions.isNotEmpty) {
      _hasCheckedSharedLink = true; // Only try once

      Competition? foundComp;
      for (final c in provider.allCompetitions) {
        if (c.id == sharedId) {
          foundComp = c;
          break;
        }
      }

      if (foundComp != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CompetitionDetailPage(competition: foundComp!),
              ),
            );
          }
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

  void _updateDateRangeFromText(CompetitionProvider provider) {
    final startText = _startDateController.text.trim();
    final endText = _endDateController.text.trim();

    if (startText.isEmpty && endText.isEmpty) {
      provider.clearDateRange();
      return;
    }

    if (startText.length == 10 && endText.length == 10) {
      final start = DateTime.tryParse(startText);
      final end = DateTime.tryParse(endText);
      if (start != null && end != null) {
        if (start.isBefore(end) || start.isAtSameMomentAs(end)) {
          provider.setDateRange(DateTimeRange(start: start, end: end));
        }
      }
    }
  }

  void _selectDateRange(
    BuildContext context,
    CompetitionProvider provider,
  ) async {
    final theme = Theme.of(context);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: provider.selectedDateRange,
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
      provider.setDateRange(picked);
      _syncDateControllers(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.surface,
      drawer: _buildNavigationDrawer(context, provider, theme),
      endDrawer: _buildFiltersDrawer(context, provider, theme),
      body: SafeArea(
        child: Column(
          children: [
            // Responsive Top Header
            _buildTopHeader(context, provider, theme, isDesktop, isTablet),

            // Sub-navigation bar for desktop view
            if (isDesktop) _buildDesktopSubNavBar(provider, theme),

            // Main View Content
            Expanded(
              child: _buildMainContent(
                context,
                provider,
                theme,
                isDesktop,
                isTablet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            // Hamburger menu on mobile left
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            const Spacer(),
          ],

          // Brand Icon
          SvgPicture.asset(
            'assets/finalrep_icon.svg',
            height: 28,
            colorFilter: const ColorFilter.mode(
              Color(0xFFE94E1B),
              BlendMode.srcIn,
            ),
          ),

          if (!isDesktop) const Spacer(),

          // Centered Search bar in desktop
          if (isDesktop) ...[
            const Spacer(),
            SizedBox(width: 400, child: const DesktopSearchBar()),
            const Spacer(),
          ],

          if (!isDesktop) ...[
            // Mobile search icon on right
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MobileSearchPage()),
                );
              },
            ),
          ] else ...[
            // Theme toggle on desktop right
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: widget.onToggleTheme,
              tooltip: 'Toggle Theme',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopSubNavBar(CompetitionProvider provider, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSubNavButton(
            label: 'Competitions',
            isActive: true,
            onPressed: () {},
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavButton({
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive
              ? const Color(0xFFE94E1B)
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
  ) {
    return Drawer(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -200) {
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SvgPicture.asset(
                  'assets/finalrep_icon.svg',
                  height: 32,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFE94E1B),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.explore, color: Color(0xFFE94E1B)),
                title: const Text(
                  'Competitions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE94E1B),
                  ),
                ),
                onTap: () {
                  provider.setLayout(CompetitionsLayout.grid);
                  Navigator.of(context).pop();
                },
              ),
              const Spacer(),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Color Mode'),
                    IconButton(
                      icon: Icon(
                        theme.brightness == Brightness.dark
                            ? Icons.light_mode
                            : Icons.dark_mode,
                      ),
                      onPressed: () {
                        widget.onToggleTheme();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersDrawer(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
  ) {
    return Drawer(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 200) {
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildFilterContent(
                    context,
                    provider,
                    theme,
                    isDesktop: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterContent(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme, {
    bool isDesktop = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActiveFilterChips(context, provider, theme, isDesktop: isDesktop),
        // Sport Section
        CollapsibleFilterSection(
          title: 'Sport',
          child: Column(
            children: [
              _buildFilterCheckboxRow(
                'Streetlifting',
                provider.selectedSports.contains('Streetlifting'),
                provider.getSportCount('Streetlifting'),
                (val) => provider.toggleSport('Streetlifting'),
                theme,
              ),
            ],
          ),
        ),

        // Format Section
        CollapsibleFilterSection(
          title: 'Format',
          child: Column(
            children: [
              _buildFilterCheckboxRow(
                'Modern',
                provider.selectedSubtypes.contains('Modern'),
                provider.getSubtypeCount('Modern'),
                (val) {
                  provider.toggleSubtype('Modern');
                },
                theme,
              ),
              _buildFilterCheckboxRow(
                'Classic',
                provider.selectedSubtypes.contains('Classic'),
                provider.getSubtypeCount('Classic'),
                (val) {
                  provider.toggleSubtype('Classic');
                },
                theme,
              ),
            ],
          ),
        ),

        // Group Section
        CollapsibleFilterSection(
          title: 'Group',
          child: Column(
            children: [
              _buildFilterCheckboxRow(
                'FinalRep Qualifier',
                provider.selectedGroups.contains('FinalRep Qualifier'),
                provider.getGroupCount('FinalRep Qualifier'),
                (val) {
                  provider.toggleGroup('FinalRep Qualifier');
                },
                theme,
              ),
              _buildFilterCheckboxRow(
                'FinalRep Underground',
                provider.selectedGroups.contains('FinalRep Underground'),
                provider.getGroupCount('FinalRep Underground'),
                (val) {
                  provider.toggleGroup('FinalRep Underground');
                },
                theme,
              ),
              _buildFilterCheckboxRow(
                'FinalRep Final',
                provider.selectedGroups.contains('FinalRep Final'),
                provider.getGroupCount('FinalRep Final'),
                (val) {
                  provider.toggleGroup('FinalRep Final');
                },
                theme,
              ),
              _buildFilterCheckboxRow(
                'Individual',
                provider.selectedGroups.contains('Individual'),
                provider.getGroupCount('Individual'),
                (val) {
                  provider.toggleGroup('Individual');
                },
                theme,
              ),
            ],
          ),
        ),

        // Location Section
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

        // Date Range Section
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
                      onChanged: (_) => _updateDateRangeFromText(provider),
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
                      onChanged: (_) => _updateDateRangeFromText(provider),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.calendar_month, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _selectDateRange(context, provider),
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
    bool value,
    int count,
    ValueChanged<bool?> onChanged,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (val) => onChanged(val),
                activeColor: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: value ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '($count)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    final activeWidget = provider.layout == CompetitionsLayout.map
        ? const WorldMapView()
        : _buildCompetitionsListGrid(
            context,
            provider,
            theme,
            isDesktop,
            isTablet,
          );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar (always visible on desktop)
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
                    child: _buildFilterContent(
                      context,
                      provider,
                      theme,
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
                _buildResultsHeader(context, provider, theme, true),
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
            _scaffoldKey.currentState?.openDrawer();
          } else if (velocity < -200) {
            _scaffoldKey.currentState?.openEndDrawer();
          }
        },
        child: Column(
          children: [
            _buildResultsHeader(context, provider, theme, false),
            Expanded(child: activeWidget),
          ],
        ),
      );
    }
  }

  Widget _buildResultsHeader(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title and Count
          Expanded(
            child: Text(
              '${provider.competitions.length} Competitions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          // Right side: Filter Icon (Mobile only), Sort, Layout Options
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDesktop) ...[
                // Filter Drawer toggle on mobile
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Filters',
                  onPressed: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                ),
                const SizedBox(width: 8),
              ],

              if (provider.layout != CompetitionsLayout.map) ...[
                // Sorting Button (Popup Menu)
                PopupMenuButton<String>(
                  iconColor: theme.colorScheme.onSurfaceVariant,
                  icon: Icon(
                    Icons.sort,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Sort options',
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

              // Layout Selector Dropdown
              PopupMenuButton<CompetitionsLayout>(
                tooltip: 'Select layout',
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
                            fontWeight:
                                provider.layout == CompetitionsLayout.grid
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
                            fontWeight:
                                provider.layout == CompetitionsLayout.list
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
                          'Map Layout',
                          style: TextStyle(
                            fontWeight:
                                provider.layout == CompetitionsLayout.map
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    provider.layout == CompetitionsLayout.grid
                        ? Icons.grid_view
                        : provider.layout == CompetitionsLayout.list
                        ? Icons.view_list
                        : Icons.map,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
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

    // Query
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

    // Sport (if not empty and is default, but let's show all active selected sports)
    // Toggling off the default might clear all, but let's allow it
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

    // Format (Subtypes)
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

    // Groups
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

    // Areas
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

    // Countries
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

    // Cities
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

    // Date Range
    if (provider.selectedDateRange != null) {
      final startStr = DateFormat(
        'yyyy-MM-dd',
      ).format(provider.selectedDateRange!.start);
      final endStr = DateFormat(
        'yyyy-MM-dd',
      ).format(provider.selectedDateRange!.end);
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

    if (provider.competitions.isEmpty) {
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

    return CustomScrollView(
      slivers: [
        if (provider.isCompactLayout)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final comp = provider.competitions[index];
                return CompetitionCompactRow(
                  competition: comp,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
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
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
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
                return CompetitionCard(competition: comp);
              }, childCount: provider.competitions.length),
            ),
          ),
      ],
    );
  }
}

class CollapsibleFilterSection extends StatefulWidget {
  final String title;
  final Widget child;
  final bool isInitiallyExpanded;

  const CollapsibleFilterSection({
    super.key,
    required this.title,
    required this.child,
    this.isInitiallyExpanded = false,
  });

  @override
  State<CollapsibleFilterSection> createState() =>
      _CollapsibleFilterSectionState();
}

class _CollapsibleFilterSectionState extends State<CollapsibleFilterSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: widget.child,
          ),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}

class DesktopSearchBar extends StatefulWidget {
  const DesktopSearchBar({super.key});

  @override
  State<DesktopSearchBar> createState() => _DesktopSearchBarState();
}

class _DesktopSearchBarState extends State<DesktopSearchBar> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _controller = TextEditingController();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _controller.text.isNotEmpty) {
      _showOverlay();
    } else {
      // Delay slightly to let a tap on the suggestion list tiles process first
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    if (_controller.text.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 6.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Consumer<CompetitionProvider>(
              builder: (context, provider, child) {
                final query = _controller.text.trim().toLowerCase();
                final suggestions = provider.allCompetitions.where((c) {
                  return c.title.toLowerCase().contains(query) ||
                      c.location.toLowerCase().contains(query) ||
                      (c.city != null &&
                          c.city!.toLowerCase().contains(query)) ||
                      (c.country != null &&
                          c.country!.toLowerCase().contains(query));
                }).toList();

                if (suggestions.isEmpty) {
                  return Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.all(16),
                    child: const Text('No competitions found'),
                  );
                }

                return Container(
                  color: Theme.of(context).colorScheme.surface,
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final comp = suggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          comp.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(comp.location),
                        onTap: () {
                          _hideOverlay();
                          _focusNode.unfocus();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CompetitionDetailPage(competition: comp),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);

    // Keep text field in sync when provider query is cleared
    if (provider.query.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          hintText: 'Search competitions globally...',
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _controller.clear();
                    provider.setQuery('');
                    _hideOverlay();
                  },
                  child: const Icon(Icons.clear, size: 18),
                )
              : null,
          filled: true,
          fillColor: theme.brightness == Brightness.dark
              ? const Color(0xFF1E1715)
              : const Color(0xFFF3EDEB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (val) {
          provider.setQuery(val);
          provider.setLayout(CompetitionsLayout.grid); // Show grid view
          _hideOverlay();
          _focusNode.unfocus();
        },
      ),
    );
  }
}
