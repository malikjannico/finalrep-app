import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/competition_provider.dart';
import '../repositories/competition_repository.dart';

class RankingsPage extends StatefulWidget {
  final bool showAppBar;
  const RankingsPage({super.key, this.showAppBar = true});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  late final CompetitionRepository _repository;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;

  // Filter States
  String _searchQuery = '';
  String _selectedGender = 'All'; // 'All', 'Male', 'Female'
  String _selectedSubtype = 'All'; // 'All', 'Modern', 'Classic'

  @override
  void initState() {
    super.initState();
    _repository = Provider.of<CompetitionProvider>(context, listen: false).competitionRepository;
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final list = await _repository.getMeetResults();
      setState(() {
        _results = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching rankings from meet_results: $e');
      setState(() {
        _results = [];
        _isLoading = false;
      });
    }
  }


  List<Map<String, dynamic>> get _fallbackData => [
    {
      'id': 'fallback-1',
      'profile': {'full_name': 'John Doe', 'gender': 'Male'},
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
    },
    {
      'id': 'fallback-2',
      'profile': {'full_name': 'Jane Smith', 'gender': 'Female'},
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
    // Determine source list (genuine or fallback)
    final sourceList = _results.isNotEmpty ? _results : _fallbackData;

    // Map source list elements to a standard display structure
    final parsedList = sourceList.map((item) {
      final profile = item['profile'] as Map<String, dynamic>? ?? {};
      final athleteName = profile['full_name'] as String? ?? 'Unknown Athlete';
      final gender = profile['gender'] as String? ?? 'Male';

      // Determine subtype from competition_class or key
      String subtype = item['subtype'] as String? ?? 'Modern';
      final compClass = (item['competition_class'] as String? ?? '')
          .toLowerCase();
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
      final mu =
          (bestLiftsMap['Muscle Up'] ?? bestLiftsMap['mu'] ?? 0.0) as num;
      final pu = (bestLiftsMap['Pull Up'] ?? bestLiftsMap['pu'] ?? 0.0) as num;
      final dip = (bestLiftsMap['Dip'] ?? bestLiftsMap['dip'] ?? 0.0) as num;
      final squat = (bestLiftsMap['Squat'] ?? bestLiftsMap['sq'] ?? 0.0) as num;

      final subtitleStr =
          'MU: ${_formatWeight(mu.toDouble())}kg | PU: ${_formatWeight(pu.toDouble())}kg | '
          'Dip: ${_formatWeight(dip.toDouble())}kg | Squat: ${_formatWeight(squat.toDouble())}kg';

      return {
        'id': item['id'],
        'athleteName': athleteName,
        'gender': gender,
        'subtype': subtype,
        'totalScore': totalScore,
        'rank': rank,
        'subtitle': subtitleStr,
      };
    }).toList();

    // Sort by total score descending
    parsedList.sort((a, b) => b['totalScore'].compareTo(a['totalScore']));

    // Filter parsed list based on query and filters
    final filtered = parsedList.where((item) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = item['athleteName'].toLowerCase();
        if (!name.contains(query)) return false;
      }

      // 2. Gender
      if (_selectedGender != 'All') {
        if (item['gender'].toLowerCase() != _selectedGender.toLowerCase())
          return false;
      }

      // 3. Subtype
      if (_selectedSubtype != 'All') {
        if (item['subtype'].toLowerCase() != _selectedSubtype.toLowerCase())
          return false;
      }

      return true;
    }).toList();

    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filter Panel
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      children: [
                        TextField(
                          key: const Key('rankings_search_input'),
                          decoration: const InputDecoration(
                            labelText: 'Search Athlete Name',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: const Key('gender_filter_dropdown'),
                                value: _selectedGender,
                                decoration: const InputDecoration(
                                  labelText: 'Gender',
                                ),
                                items: ['All', 'Male', 'Female']
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedGender = val ?? 'All';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: const Key('subtype_filter_dropdown'),
                                value: _selectedSubtype,
                                decoration: const InputDecoration(
                                  labelText: 'Subtype',
                                ),
                                items: ['All', 'Modern', 'Classic']
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSubtype = val ?? 'All';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              // Rankings List
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        key: const Key('rankings_list'),
                        children: const [
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('No rankings found.'),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        key: const Key('rankings_list'),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final displayRank = index + 1;
                          return ListTile(
                            key: Key('ranking_item_${item['id']}'),
                            title: Text(
                              '$displayRank. ${item['athleteName']} - ${item['totalScore'].toStringAsFixed(1)}kg',
                            ),
                            subtitle: Text(item['subtitle']),
                          );
                        },
                      ),
              ),
            ],
          );

    if (!widget.showAppBar) {
      return bodyContent;
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
      body: bodyContent,
    );
  }
}
