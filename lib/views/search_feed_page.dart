import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  String _drawerType = 'navigation'; // 'navigation' or 'filters'

  @override
  void initState() {
    super.initState();
    // Sync initial date range from provider if it exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<CompetitionProvider>(context, listen: false);
        _syncDateControllers(provider.selectedDateRange);
      }
    });
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
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

  void _selectDateRange(BuildContext context, CompetitionProvider provider) async {
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

    // Keep date controllers in sync when date range is cleared/changed externally
    final currentRange = provider.selectedDateRange;
    if (currentRange == null) {
      if (_startDateController.text.isNotEmpty || _endDateController.text.isNotEmpty) {
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.surface,
      drawer: _buildDrawer(context, provider, theme),
      bottomNavigationBar: !isDesktop
          ? BottomNavigationBar(
              currentIndex: provider.activeTab,
              onTap: provider.setActiveTab,
              selectedItemColor: const Color(0xFFE94E1B),
              unselectedItemColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore),
                  label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: 'Map',
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Responsive Top Header
            _buildTopHeader(context, provider, theme, isDesktop, isTablet),
            
            // Sub-navigation bar for desktop view
            if (isDesktop) _buildDesktopSubNavBar(provider, theme),

            // Main View Content
            Expanded(
              child: provider.activeTab == 1
                  ? const WorldMapView()
                  : _buildCompetitionsFeed(context, provider, theme, isDesktop, isTablet),
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
                setState(() {
                  _drawerType = 'navigation';
                });
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
            SizedBox(
              width: 400,
              child: const DesktopSearchBar(),
            ),
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
        children: [
          _buildSubNavButton(
            label: 'Competitions Feed',
            isActive: provider.activeTab == 0,
            onPressed: () => provider.setActiveTab(0),
            theme: theme,
          ),
          const SizedBox(width: 16),
          _buildSubNavButton(
            label: 'World Map',
            isActive: provider.activeTab == 1,
            onPressed: () => provider.setActiveTab(1),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFE94E1B) : theme.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            color: isActive ? const Color(0xFFE94E1B) : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, CompetitionProvider provider, ThemeData theme) {
    if (_drawerType == 'filters') {
      return Drawer(
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
                  child: _buildFilterContent(context, provider, theme, isDesktop: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          provider.clearFilters();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Reset All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Navigation drawer
      return Drawer(
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
                leading: Icon(Icons.explore, color: provider.activeTab == 0 ? const Color(0xFFE94E1B) : null),
                title: Text(
                  'Feed',
                  style: TextStyle(
                    fontWeight: provider.activeTab == 0 ? FontWeight.bold : FontWeight.normal,
                    color: provider.activeTab == 0 ? const Color(0xFFE94E1B) : null,
                  ),
                ),
                onTap: () {
                  provider.setActiveTab(0);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.map, color: provider.activeTab == 1 ? const Color(0xFFE94E1B) : null),
                title: Text(
                  'World Map',
                  style: TextStyle(
                    fontWeight: provider.activeTab == 1 ? FontWeight.bold : FontWeight.normal,
                    color: provider.activeTab == 1 ? const Color(0xFFE94E1B) : null,
                  ),
                ),
                onTap: () {
                  provider.setActiveTab(1);
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
                    const Text('Theme Mode'),
                    IconButton(
                      icon: Icon(
                        theme.brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
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
      );
    }
  }

  Widget _buildFilterContent(BuildContext context, CompetitionProvider provider, ThemeData theme, {bool isDesktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                provider.selectedSubtype == 'Modern',
                provider.getSubtypeCount('Modern'),
                (val) {
                  provider.setSelectedSubtype(val == true ? 'Modern' : 'All');
                },
                theme,
              ),
              _buildFilterCheckboxRow(
                'Classic',
                provider.selectedSubtype == 'Classic',
                provider.getSubtypeCount('Classic'),
                (val) {
                  provider.setSelectedSubtype(val == true ? 'Classic' : 'All');
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
                provider.selectedGroup == 'FinalRep Qualifier',
                provider.getGroupCount('FinalRep Qualifier'),
                (val) {
                  provider.setSelectedGroup(val == true ? 'FinalRep Qualifier' : 'All');
                },
                theme,
              ),
              _buildFilterCheckboxRow(
                'FinalRep Underground',
                provider.selectedGroup == 'FinalRep Underground',
                provider.getGroupCount('FinalRep Underground'),
                (val) {
                  provider.setSelectedGroup(val == true ? 'FinalRep Underground' : 'All');
                },
                theme,
              ),
              _buildFilterCheckboxRow(
                'FinalRep Final',
                provider.selectedGroup == 'FinalRep Final',
                provider.getGroupCount('FinalRep Final'),
                (val) {
                  provider.setSelectedGroup(val == true ? 'FinalRep Final' : 'All');
                },
                theme,
              ),
              _buildFilterCheckboxRow(
                'Individual',
                provider.selectedGroup == 'Individual',
                provider.getGroupCount('Individual'),
                (val) {
                  provider.setSelectedGroup(val == true ? 'Individual' : 'All');
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitionsFeed(
    BuildContext context,
    CompetitionProvider provider,
    ThemeData theme,
    bool isDesktop,
    bool isTablet,
  ) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar (always visible on desktop)
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
            child: SingleChildScrollView(
              child: _buildFilterContent(context, provider, theme, isDesktop: true),
            ),
          ),

          // Right Content Panel
          Expanded(
            child: Column(
              children: [
                _buildResultsHeader(context, provider, theme, true),
                _buildActiveFilterChips(context, provider, theme),
                Expanded(
                  child: _buildCompetitionsListGrid(context, provider, theme, isDesktop, isTablet),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Mobile / Tablet Feed View
      return Column(
        children: [
          _buildResultsHeader(context, provider, theme, false),
          _buildActiveFilterChips(context, provider, theme),
          Expanded(
            child: _buildCompetitionsListGrid(context, provider, theme, isDesktop, isTablet),
          ),
        ],
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
              isDesktop
                  ? '${provider.competitions.length} Upcoming Competitions'
                  : '${provider.competitions.length} events',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          
          // Right side: Filter Icon (Mobile only), Sort, Layout Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDesktop) ...[
                // Filter Drawer toggle on mobile
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filters',
                  onPressed: () {
                    setState(() {
                      _drawerType = 'filters';
                    });
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                const SizedBox(width: 8),
              ],

              // Sorting Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF1E1715)
                      : const Color(0xFFF3EDEB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: provider.sortOrder,
                    icon: const Icon(Icons.arrow_drop_down, size: 16),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'date_asc',
                        child: Text('Date: Asc'),
                      ),
                      DropdownMenuItem(
                        value: 'date_desc',
                        child: Text('Date: Desc'),
                      ),
                      DropdownMenuItem(
                        value: 'name_asc',
                        child: Text('Name: A-Z'),
                      ),
                      DropdownMenuItem(
                        value: 'name_desc',
                        child: Text('Name: Z-A'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        provider.setSortOrder(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Layout Toggle (Card vs Compact)
              IconButton(
                icon: Icon(
                  provider.isCompactLayout ? Icons.grid_view : Icons.view_list,
                  size: 20,
                ),
                tooltip: provider.isCompactLayout ? 'Card Layout' : 'Compact Layout',
                onPressed: () => provider.setIsCompactLayout(!provider.isCompactLayout),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips(BuildContext context, CompetitionProvider provider, ThemeData theme) {
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
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    // Format (Subtype)
    if (provider.selectedSubtype != 'All') {
      chips.add(
        RawChip(
          label: Text('Format: ${provider.selectedSubtype}'),
          onDeleted: () => provider.setSelectedSubtype('All'),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          labelStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    // Group
    if (provider.selectedGroup != 'All') {
      chips.add(
        RawChip(
          label: Text('Group: ${provider.selectedGroup}'),
          onDeleted: () => provider.setSelectedGroup('All'),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
      final startStr = DateFormat('yyyy-MM-dd').format(provider.selectedDateRange!.start);
      final endStr = DateFormat('yyyy-MM-dd').format(provider.selectedDateRange!.end);
      chips.add(
        RawChip(
          label: Text('Date: $startStr to $endStr'),
          onDeleted: () => provider.clearDateRange(),
          deleteIconColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Wrap(
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
      return const Center(
        child: CircularProgressIndicator(),
      );
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
              Icon(Icons.search_off_outlined,
                  size: 64, color: theme.colorScheme.outline),
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
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final comp = provider.competitions[index];
                  return CompetitionCompactRow(
                    competition: comp,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CompetitionDetailPage(competition: comp),
                        ),
                      );
                    },
                  );
                },
                childCount: provider.competitions.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40, top: 12),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 380,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final comp = provider.competitions[index];
                  return CompetitionCard(competition: comp);
                },
                childCount: provider.competitions.length,
              ),
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
    this.isInitiallyExpanded = true,
  });

  @override
  State<CollapsibleFilterSection> createState() => _CollapsibleFilterSectionState();
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
        Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
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
                      (c.city != null && c.city!.toLowerCase().contains(query)) ||
                      (c.country != null && c.country!.toLowerCase().contains(query));
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
                              builder: (_) => CompetitionDetailPage(competition: comp),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          hintText: 'Search meets globally...',
          prefixIcon: Icon(Icons.search, size: 20, color: theme.colorScheme.primary),
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
          provider.setActiveTab(0); // Show feed view
          _hideOverlay();
          _focusNode.unfocus();
        },
      ),
    );
  }
}
