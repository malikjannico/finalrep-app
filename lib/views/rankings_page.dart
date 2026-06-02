import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/competition_provider.dart';
import '../repositories/competition_repository.dart';
import '../widgets/filter_widgets.dart';
import '../models/competition.dart';
import 'profile_page.dart';
import 'competition_detail_page.dart';
import '../widgets/unified_empty_state.dart';

class RankingsPage extends StatefulWidget {
  final bool showAppBar;
  const RankingsPage({super.key, this.showAppBar = true});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

enum RankingsLayout { table, list, grid }

class _RankingsPageState extends State<RankingsPage> {
  late final CompetitionRepository _repository;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;

  // Key for local Scaffold
  final GlobalKey<ScaffoldState> _rankingsScaffoldKey = GlobalKey<ScaffoldState>();

  // Filter States
  final Set<String> _selectedSports = {};
  final Set<String> _selectedFormats = {};
  final Set<String> _selectedGenders = {};
  final Set<String> _selectedCountries = {};
  RankingsLayout _rankingsLayout = RankingsLayout.list;
  final Map<String, GlobalKey> _athleteKeys = {};

  void _clearFilters() {
    setState(() {
      _selectedSports.clear();
      _selectedFormats.clear();
      _selectedGenders.clear();
      _selectedCountries.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _repository = Provider.of<CompetitionProvider>(context, listen: false).competitionRepository;
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final list = await _repository.getMeetResults();
      if (!mounted) return;
      setState(() {
        _results = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching rankings from competition_results: $e');
      if (!mounted) return;
      setState(() {
        _results = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _fallbackData => [
    {
      'id': 'fallback-1',
      'profile': {'id': 'fallback-profile-1', 'username': 'johndoe', 'full_name': 'John Doe', 'sex': 'male'},
      'competition_class': 'Male -83kg (Modern)',
      'total_score': 420.0,
      'rank': 1,
      'best_lifts': {
        'Muscle Up': 20.0,
        'Pull Up': 50.0,
        'Dip': 80.0,
        'Squat': 180.0,
      },
      'subtype': 'Modern',
      'competition': {'id': 'fallback-comp-1', 'name': 'Alpha Championship', 'sport': 'Streetlifting'},
    },
    {
      'id': 'fallback-2',
      'profile': {'id': 'fallback-profile-2', 'username': 'janesmith', 'full_name': 'Jane Smith', 'sex': 'female'},
      'competition_class': 'Female -63kg (Classic)',
      'total_score': 390.0,
      'rank': 2,
      'best_lifts': {
        'Muscle Up': 15.0,
        'Pull Up': 45.0,
        'Dip': 75.0,
        'Squat': 165.0,
      },
      'subtype': 'Classic',
      'competition': {'id': 'fallback-comp-2', 'name': 'Beta Championship', 'sport': 'Streetlifting'},
    },
  ];

  String _formatWeight(double weight) {
    if (weight == weight.toInt()) {
      return '${weight.toInt()}';
    }
    return weight.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compProvider = Provider.of<CompetitionProvider>(context);

    // Hide fallback data when 0 competitions exist in the system
    final bool hasNoDataInSystem = compProvider.allCompetitions.isEmpty;
    final sourceList = _results.isNotEmpty
        ? _results
        : (hasNoDataInSystem ? <Map<String, dynamic>>[] : _fallbackData);

    final parsedList = sourceList.map((item) {
      final profile = item['profile'] as Map? ?? {};
      final athleteName = profile['full_name'] as String? ?? 'Unknown Athlete';
      final sexVal = (profile['sex'] ?? profile['gender'] as String? ?? 'male').toString().toLowerCase();
      final gender = sexVal == 'female' ? 'Female' : (sexVal == 'male' ? 'Male' : (sexVal.isEmpty ? 'Male' : sexVal[0].toUpperCase() + sexVal.substring(1)));
      final athleteId = profile['id'] as String? ?? item['profile_id'] as String? ?? '';
      final username = profile['username'] as String? ?? '';
      final country = profile['country'] as String? ?? '';

      final competition = item['competition'] as Map? ?? {};
      final competitionName = competition['name'] as String? ?? 'German Nationals';
      final competitionId = competition['id'] as String? ?? item['competition_id'] as String? ?? '';
      final sport = item['sport'] as String? ?? competition['sport'] as String? ?? 'Streetlifting';

      String subtype = item['subtype'] as String? ?? 'Modern';
      final compClass = (item['competition_class'] as String? ?? '').toLowerCase();
      if (compClass.contains('classic')) {
        subtype = 'Classic';
      } else if (compClass.contains('modern')) {
        subtype = 'Modern';
      }

      final totalScore = (item['total_score'] as num?)?.toDouble() ?? 0.0;
      final rank = item['rank'] as int? ?? 0;

      final bestLiftsMap = Map<String, dynamic>.from(
        item['best_lifts'] as Map? ?? {},
      );
      final mu = (bestLiftsMap['Muscle Up'] ?? bestLiftsMap['mu'] ?? 0.0) as num;
      final pu = (bestLiftsMap['Pull Up'] ?? bestLiftsMap['pu'] ?? 0.0) as num;
      final dip = (bestLiftsMap['Dip'] ?? bestLiftsMap['dip'] ?? 0.0) as num;
      final squat = (bestLiftsMap['Squat'] ?? bestLiftsMap['sq'] ?? 0.0) as num;

      final subtitleStr =
          'MU: ${_formatWeight(mu.toDouble())}kg | PU: ${_formatWeight(pu.toDouble())}kg | '
          'Dip: ${_formatWeight(dip.toDouble())}kg | Squat: ${_formatWeight(squat.toDouble())}kg';

      return {
        'id': item['id'] as String,
        'athleteName': athleteName,
        'athleteId': athleteId,
        'username': username,
        'competitionName': competitionName,
        'competitionId': competitionId,
        'sport': sport,
        'gender': gender,
        'subtype': subtype,
        'totalScore': totalScore,
        'rank': rank,
        'subtitle': subtitleStr,
        'mu': mu.toDouble(),
        'pu': pu.toDouble(),
        'dip': dip.toDouble(),
        'squat': squat.toDouble(),
        'country': country,
      };
    }).toList();

    parsedList.sort((a, b) => (b['totalScore'] as double).compareTo(a['totalScore'] as double));

    final filtered = parsedList.where((item) {
      if (_selectedSports.isNotEmpty && !_selectedSports.contains(item['sport'])) {
        return false;
      }
      if (_selectedFormats.isNotEmpty && !_selectedFormats.contains(item['subtype'])) {
        return false;
      }
      if (_selectedGenders.isNotEmpty && !_selectedGenders.contains(item['gender'])) {
        return false;
      }
      if (_selectedCountries.isNotEmpty && !_selectedCountries.contains(item['country'])) {
        return false;
      }
      return true;
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : isDesktop
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
                            child: _buildRankingsFilterContent(context, theme, parsedList),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildRankingsMainContent(
                      context,
                      filtered,
                      theme,
                      parsedList,
                      isDesktop: true,
                    ),
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
                    _showMobileFilters(context, parsedList);
                  }
                },
                child: _buildRankingsMainContent(
                  context,
                  filtered,
                  theme,
                  parsedList,
                  isDesktop: false,
                ),
              );

    final scaffold = Scaffold(
      key: _rankingsScaffoldKey,
      drawerEnableOpenDragGesture: false,
      endDrawerEnableOpenDragGesture: false,
      body: bodyContent,
    );

    if (!widget.showAppBar) {
      return scaffold;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Rankings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRankings,
          ),
        ],
      ),
      body: scaffold,
    );
  }

  void _showMobileFilters(BuildContext context, List<Map<String, dynamic>> parsedList) {
    final theme = Theme.of(context);

    final drawerContent = Drawer(
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
                  child: _buildRankingsFilterContent(context, theme, parsedList),
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

  Widget _buildRankingsFilterContent(BuildContext context, ThemeData theme, List<Map<String, dynamic>> parsedList) {
    final provider = Provider.of<CompetitionProvider>(context);
    final config = provider.sportConfig;
    final sports = config?.sports.map((s) => s.name).toSet().toList() ?? ['Streetlifting'];
    final genders = ['Male', 'Female'];

    final availableCountries = parsedList
        .map((item) => item['country'] as String)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    availableCountries.sort();

    int getSportCount(String sport) => parsedList.where((item) => item['sport'] == sport).length;
    int getFormatCount(String format) => parsedList.where((item) => item['subtype'] == format).length;
    int getGenderCount(String gender) => parsedList.where((item) => item['gender'] == gender).length;
    int getCountryCount(String country) => parsedList.where((item) => item['country'] == country).length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                return parsedList.where((athlete) {
                  final name = athlete['athleteName'] as String;
                  final username = athlete['username'] as String;
                  final query = textEditingValue.text.toLowerCase();
                  return name.toLowerCase().contains(query) || username.toLowerCase().contains(query);
                });
              },
              displayStringForOption: (Map<String, dynamic> option) {
                final name = option['athleteName'] as String;
                final username = option['username'] as String;
                return username.isNotEmpty ? '$name (@$username)' : name;
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextField(
                  key: const Key('rankings_search_input'),
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Search Athlete Name',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (val) {
                    onFieldSubmitted();
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: Container(
                      width: 268,
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          final name = option['athleteName'] as String;
                          final username = option['username'] as String;
                          return ListTile(
                            title: Text(name),
                            subtitle: username.isNotEmpty ? Text('@$username') : null,
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              onSelected: (Map<String, dynamic> selection) {
                final athleteId = selection['id'] as String;
                final key = _athleteKeys[athleteId];
                if (key != null && key.currentContext != null) {
                  Scrollable.ensureVisible(
                    key.currentContext!,
                    duration: const Duration(milliseconds: 500),
                    alignment: 0.5,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
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
                        value: _selectedSports.contains(s),
                        count: getSportCount(s),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedSports.add(s);
                            } else {
                              _selectedSports.remove(s);
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
                                value: _selectedFormats.contains(f),
                                count: getFormatCount(f),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedFormats.add(f);
                                    } else {
                                      _selectedFormats.remove(f);
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
            title: 'Gender',
            isInitiallyExpanded: false,
            child: Column(
              children: genders.map((g) {
                return FilterCheckboxRow(
                  label: g,
                  value: _selectedGenders.contains(g),
                  count: getGenderCount(g),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedGenders.add(g);
                      } else {
                        _selectedGenders.remove(g);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          if (availableCountries.isNotEmpty)
            CollapsibleFilterSection(
              title: 'Nationality',
              isInitiallyExpanded: false,
              child: Column(
                children: availableCountries.map((c) {
                  return FilterCheckboxRow(
                    label: c,
                    value: _selectedCountries.contains(c),
                    count: getCountryCount(c),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedCountries.add(c);
                        } else {
                          _selectedCountries.remove(c);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRankingsMainContent(
    BuildContext context,
    List<Map<String, dynamic>> filtered,
    ThemeData theme,
    List<Map<String, dynamic>> parsedList, {
    required bool isDesktop,
  }) {
    final headerPadding = isDesktop
        ? const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: headerPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${filtered.length} Athletes',
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
                        _showMobileFilters(context, parsedList);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
              PopupMenuButton<RankingsLayout>(
                tooltip: 'Select layout ',
                offset: const Offset(0, 40),
                onSelected: (RankingsLayout layout) {
                  setState(() {
                    _rankingsLayout = layout;
                  });
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<RankingsLayout>(
                    value: RankingsLayout.table,
                    child: Row(
                      children: [
                        Icon(
                          Icons.table_chart,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Table View',
                          style: TextStyle(
                            fontWeight: _rankingsLayout == RankingsLayout.table
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<RankingsLayout>(
                    value: RankingsLayout.list,
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_list,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Compact View',
                          style: TextStyle(
                            fontWeight: _rankingsLayout == RankingsLayout.list
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<RankingsLayout>(
                    value: RankingsLayout.grid,
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Grid View',
                          style: TextStyle(
                            fontWeight: _rankingsLayout == RankingsLayout.grid
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  _rankingsLayout == RankingsLayout.table
                      ? Icons.table_chart
                      : _rankingsLayout == RankingsLayout.list
                          ? Icons.view_list
                          : Icons.grid_view,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
        Expanded(
          child: filtered.isEmpty
              ? UnifiedEmptyState(
                  title: 'No rankings found',
                  message: 'Try refining your search query or reset filters.',
                  onReset: _clearFilters,
                )
              : _buildRankingsDisplay(filtered, theme, isDesktop),
        ),
      ],
    );
  }

  Widget _buildRankingsDisplay(
    List<Map<String, dynamic>> filtered,
    ThemeData theme,
    bool isDesktop,
  ) {
    switch (_rankingsLayout) {
      case RankingsLayout.table:
        return _buildTableView(filtered, theme);
      case RankingsLayout.grid:
        return _buildGridView(filtered, theme, isDesktop);
      case RankingsLayout.list:
      default:
        return _buildListView(filtered, theme);
    }
  }

  Widget _buildTableView(List<Map<String, dynamic>> filtered, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Table(
          border: TableBorder(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
            horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3), width: 1),
          ),
          columnWidths: const {
            0: FlexColumnWidth(0.6), // Rank
            1: FlexColumnWidth(1.5), // Athlete
            2: FlexColumnWidth(0.8), // Gender
            3: FlexColumnWidth(0.9), // Format
            4: FlexColumnWidth(0.7), // MU
            5: FlexColumnWidth(0.7), // PU
            6: FlexColumnWidth(0.7), // Dip
            7: FlexColumnWidth(0.7), // Squat
            8: FlexColumnWidth(1.0), // Total
            9: FlexColumnWidth(1.8), // Competition
          },
          children: [
            // Bold Table Header Row with bold bottom line
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.onSurface,
                    width: 2.0, // Bold bottom line
                  ),
                ),
              ),
              children: const [
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Athlete', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Gender', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Format', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('MU', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('PU', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Dip', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Squat', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Competition', style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
            // Rows
            ...List.generate(filtered.length, (index) {
              final item = filtered[index];
              final displayRank = index + 1;
              final athleteId = item['athleteId'] as String;
              final compId = item['competitionId'] as String;

              final key = _athleteKeys.putIfAbsent(item['id'] as String, () => GlobalKey());

              return TableRow(
                children: [
                  TableCell(
                    child: Padding(
                      key: key,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('$displayRank'),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: InkWell(
                        onTap: () {
                          if (athleteId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfilePage(userId: athleteId),
                              ),
                            );
                          }
                        },
                        child: Text(
                          item['athleteName'] as String,
                          style: TextStyle(
                            color: athleteId.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: athleteId.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                            decoration: athleteId.isNotEmpty ? TextDecoration.underline : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(item['gender'] as String),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(item['subtype'] as String),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('${_formatWeight(item['mu'] as double)}kg'),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('${_formatWeight(item['pu'] as double)}kg'),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('${_formatWeight(item['dip'] as double)}kg'),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('${_formatWeight(item['squat'] as double)}kg'),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '${(item['totalScore'] as double).toStringAsFixed(1)}kg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: InkWell(
                        onTap: () {
                          if (compId.isNotEmpty) {
                            final comp = _getOrCreateCompetition(context, compId, item['competitionName'] as String);
                            if (comp != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CompetitionDetailPage(competition: comp),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          item['competitionName'] as String,
                          style: TextStyle(
                            color: compId.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: compId.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                            decoration: compId.isNotEmpty ? TextDecoration.underline : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> filtered, ThemeData theme) {
    return ListView.builder(
      key: const Key('rankings_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final displayRank = index + 1;
        final athleteId = item['athleteId'] as String;
        final key = _athleteKeys.putIfAbsent(item['id'] as String, () => GlobalKey());

        return ListTile(
          key: key,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '$displayRank',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: InkWell(
            onTap: () {
              if (athleteId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userId: athleteId),
                  ),
                );
              }
            },
            child: Text(
              '${item['athleteName']} - ${(item['totalScore'] as double).toStringAsFixed(1)}kg',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: athleteId.isNotEmpty ? TextDecoration.underline : null,
                color: athleteId.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
          ),
          subtitle: Text('${item['subtype']} • ${item['subtitle']} • Comp: ${item['competitionName']}'),
        );
      },
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> filtered, ThemeData theme, bool isDesktop) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = isDesktop ? 3 : (width >= 600 ? 2 : 1);

    return GridView.builder(
      key: const Key('rankings_list'),
      padding: const EdgeInsets.all(16.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 200,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final displayRank = index + 1;
        final athleteId = item['athleteId'] as String;
        final compId = item['competitionId'] as String;
        final key = _athleteKeys.putIfAbsent(item['id'] as String, () => GlobalKey());

        return Card(
          key: key,
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$displayRank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${(item['totalScore'] as double).toStringAsFixed(1)}kg',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    if (athleteId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(userId: athleteId),
                        ),
                      );
                    }
                  },
                  child: Text(
                    item['athleteName'] as String,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: athleteId.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      decoration: athleteId.isNotEmpty ? TextDecoration.underline : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${item['gender']} • ${item['subtype']}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    if (compId.isNotEmpty) {
                      final comp = _getOrCreateCompetition(context, compId, item['competitionName'] as String);
                      if (comp != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CompetitionDetailPage(competition: comp),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Comp: ${item['competitionName']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: compId.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      decoration: compId.isNotEmpty ? TextDecoration.underline : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 8),
                Text(
                  item['subtitle'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Competition? _getOrCreateCompetition(BuildContext context, String compId, String compName) {
    final provider = Provider.of<CompetitionProvider>(context, listen: false);
    final existing = provider.allCompetitions.where((c) => c.id == compId);
    if (existing.isNotEmpty) {
      return existing.first;
    }
    return Competition(
      id: compId,
      title: compName,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 1)),
      location: 'Unknown Location',
      sportType: 'Streetlifting',
      sportSubtype: 'Modern',
      status: 'completed',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      registrationStart: DateTime.now(),
      registrationEnd: DateTime.now(),
      requiresFees: false,
      registrationMode: 'first_come',
      enableWaitlist: false,
      volunteerNeeds: false,
    );
  }
}
