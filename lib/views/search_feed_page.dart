import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/competition_provider.dart';
import '../widgets/competition_card.dart';

class SearchFeedPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const SearchFeedPage({
    Key? key,
    required this.onToggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<SearchFeedPage> createState() => _SearchFeedPageState();
}

class _SearchFeedPageState extends State<SearchFeedPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CompetitionProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;

    // Keep search text box in sync when filters are cleared
    if (provider.query.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    final hasActiveFilters = provider.query.isNotEmpty ||
        provider.selectedSubtype != 'All' ||
        provider.selectedGroup != 'All' ||
        provider.selectedAreas.isNotEmpty ||
        provider.selectedCountries.isNotEmpty ||
        provider.selectedCities.isNotEmpty ||
        provider.selectedDateRange != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Logo colored with #E94E1B
                  SvgPicture.asset(
                    'assets/finalrep_logo.svg',
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFE94E1B),
                      BlendMode.srcIn,
                    ),
                  ),
                  
                  if (isDesktop || isTablet) ...[
                    const SizedBox(width: 32),
                    // Navigation bar
                    TextButton(
                      onPressed: () {},
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Competitions',
                            style: TextStyle(
                              color: Color(0xFFE94E1B),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 2,
                            width: 36,
                            color: const Color(0xFFE94E1B),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAboutDialog(context, theme),
                      child: Text(
                        'Rules',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                  
                  const Spacer(),
                  
                  // Search Bar in the Header
                  SizedBox(
                    width: isDesktop ? 300 : (isTablet ? 200 : 150),
                    child: TextField(
                      controller: _searchController,
                      onChanged: provider.setQuery,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search, size: 18, color: theme.colorScheme.primary),
                        suffixIcon: provider.query.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  provider.setQuery('');
                                },
                                child: const Icon(Icons.clear, size: 16),
                              )
                            : null,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Theme Toggle Button
                  IconButton(
                    icon: Icon(
                      widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: widget.onToggleTheme,
                    tooltip: 'Toggle Theme',
                  ),
                ],
              ),
            ),

            // Main Feed Area
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Page Title & Header Count
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Competitions',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '${provider.competitions.length} events',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Horizontal Filter Bar
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          // Calendar filter chip
                          FilterChip(
                            avatar: Icon(
                              Icons.calendar_month,
                              size: 16,
                              color: provider.selectedDateRange != null
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.primary,
                            ),
                            label: Text(provider.selectedDateRange == null
                                ? 'Date Range'
                                : '${DateFormat('MMM dd').format(provider.selectedDateRange!.start)} - ${DateFormat('MMM dd').format(provider.selectedDateRange!.end)}'),
                            selected: provider.selectedDateRange != null,
                            onSelected: (_) => _selectDateRange(context, provider),
                            onDeleted: provider.selectedDateRange != null
                                ? () => provider.clearDateRange()
                                : null,
                            selectedColor: theme.colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              color: provider.selectedDateRange != null
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              fontWeight: provider.selectedDateRange != null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Area filter chip
                          FilterChip(
                            label: Text(provider.selectedAreas.isEmpty
                                ? 'Area'
                                : 'Area (${provider.selectedAreas.length})'),
                            selected: provider.selectedAreas.isNotEmpty,
                            onSelected: (_) {
                              _showMultiSelectFilter(
                                context: context,
                                title: 'Area',
                                allOptions: provider.availableAreas,
                                selectedOptions: provider.selectedAreas,
                                onToggle: provider.toggleArea,
                                onClear: () {
                                  provider.selectedAreas.clear();
                                  provider.clearFilters(); // refresh everything
                                },
                              );
                            },
                            selectedColor: theme.colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              color: provider.selectedAreas.isNotEmpty
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              fontWeight: provider.selectedAreas.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Country filter chip
                          FilterChip(
                            label: Text(provider.selectedCountries.isEmpty
                                ? 'Country'
                                : 'Country (${provider.selectedCountries.length})'),
                            selected: provider.selectedCountries.isNotEmpty,
                            onSelected: (_) {
                              _showMultiSelectFilter(
                                context: context,
                                title: 'Country',
                                allOptions: provider.availableCountries,
                                selectedOptions: provider.selectedCountries,
                                onToggle: provider.toggleCountry,
                                onClear: () => provider.selectedCountries.clear(),
                              );
                            },
                            selectedColor: theme.colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              color: provider.selectedCountries.isNotEmpty
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              fontWeight: provider.selectedCountries.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // City filter chip
                          FilterChip(
                            label: Text(provider.selectedCities.isEmpty
                                ? 'City'
                                : 'City (${provider.selectedCities.length})'),
                            selected: provider.selectedCities.isNotEmpty,
                            onSelected: (_) {
                              _showMultiSelectFilter(
                                context: context,
                                title: 'City',
                                allOptions: provider.availableCities,
                                selectedOptions: provider.selectedCities,
                                onToggle: provider.toggleCity,
                                onClear: () => provider.selectedCities.clear(),
                              );
                            },
                            selectedColor: theme.colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              color: provider.selectedCities.isNotEmpty
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              fontWeight: provider.selectedCities.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Format (Subtype) Dropdown Chip
                          PopupMenuButton<String>(
                            tooltip: 'Select Subtype',
                            onSelected: provider.setSelectedSubtype,
                            itemBuilder: (context) => ['All', 'Modern', 'Classic']
                                .map((s) => PopupMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ))
                                .toList(),
                            child: RawChip(
                              label: Text(provider.selectedSubtype == 'All'
                                  ? 'Format'
                                  : 'Format: ${provider.selectedSubtype}'),
                              avatar: Icon(
                                Icons.fitness_center,
                                size: 16,
                                color: provider.selectedSubtype != 'All'
                                    ? theme.colorScheme.onTertiaryContainer
                                    : theme.colorScheme.primary,
                              ),
                              selected: provider.selectedSubtype != 'All',
                              selectedColor: theme.colorScheme.tertiaryContainer,
                              labelStyle: TextStyle(
                                color: provider.selectedSubtype != 'All'
                                    ? theme.colorScheme.onTertiaryContainer
                                    : theme.colorScheme.onSurface,
                                fontWeight: provider.selectedSubtype != 'All' ? FontWeight.bold : FontWeight.normal,
                              ),
                              showCheckmark: false,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Group Dropdown Chip
                          PopupMenuButton<String>(
                            tooltip: 'Select Competition Group',
                            onSelected: provider.setSelectedGroup,
                            itemBuilder: (context) => [
                              'All',
                              'FinalRep Underground',
                              'FinalRep Qualifier',
                              'FinalRep Final',
                              'Individual'
                            ]
                                .map((g) => PopupMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ))
                                .toList(),
                            child: RawChip(
                              label: Text(provider.selectedGroup == 'All'
                                  ? 'Group'
                                  : 'Group: ${provider.selectedGroup}'),
                              avatar: Icon(
                                Icons.stars_outlined,
                                size: 16,
                                color: provider.selectedGroup != 'All'
                                    ? theme.colorScheme.onTertiaryContainer
                                    : theme.colorScheme.primary,
                              ),
                              selected: provider.selectedGroup != 'All',
                              selectedColor: theme.colorScheme.tertiaryContainer,
                              labelStyle: TextStyle(
                                color: provider.selectedGroup != 'All'
                                    ? theme.colorScheme.onTertiaryContainer
                                    : theme.colorScheme.onSurface,
                                fontWeight: provider.selectedGroup != 'All' ? FontWeight.bold : FontWeight.normal,
                              ),
                              showCheckmark: false,
                            ),
                          ),

                          if (hasActiveFilters) ...[
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: provider.clearFilters,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset', style: TextStyle(fontSize: 13)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                foregroundColor: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Results Grid/List
                  if (provider.isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (provider.errorMessage != null)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          provider.errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    )
                  else if (provider.competitions.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
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
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          mainAxisExtent: 380, // Extended extent to accommodate the image
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
              ),
            ),
          ],
        ),
      ),
    );
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
    }
  }

  void _showMultiSelectFilter({
    required BuildContext context,
    required String title,
    required Set<String> allOptions,
    required Set<String> selectedOptions,
    required Function(String) onToggle,
    required VoidCallback onClear,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter by $title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (selectedOptions.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            onClear();
                            setModalState(() {});
                          },
                          child: const Text('Clear All'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (allOptions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No options available based on current filters.',
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: allOptions.map((option) {
                          final isChecked = selectedOptions.contains(option);
                          return CheckboxListTile(
                            title: Text(option),
                            value: isChecked,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (bool? val) {
                              onToggle(option);
                              setModalState(() {});
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              SvgPicture.asset('assets/finalrep_icon.svg', height: 28, colorFilter: const ColorFilter.mode(Color(0xFFE94E1B), BlendMode.srcIn)),
              const SizedBox(width: 12),
              const Text('Streetlifting Rules'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Format: One-Rep-Max (1RM)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Athletes perform 3 attempts per discipline with maximum weight. Highest valid attempt weights are summed to compute the final total.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Streetlifting Modern (4 disciplines):',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Text('• Muscle Up\n• Pull Up\n• Dip\n• Squat'),
                const SizedBox(height: 12),
                Text(
                  'Streetlifting Classic (2 disciplines):',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Text('• Pull Up\n• Dip'),
                const SizedBox(height: 16),
                Text(
                  'Official Weight Classes:',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Men: -66 kg, -73 kg, -80 kg, -87 kg, -101 kg, +101 kg\n'
                  'Women: -52 kg, -57 kg, -63 kg, -70 kg, +70 kg',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }
}
