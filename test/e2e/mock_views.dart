import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/utils/streetlifting_rules_engine.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';
import 'package:finalrep_app/models/system_notification.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Permissions Applications'),
            subtitle: Text('Review user creation requests'),
          ),
          ListTile(
            key: const Key('pending_app_1'),
            title: const Text('user_123 - Competition Creation'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  key: const Key('approve_btn_1'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application Approved')),
                    );
                  },
                  child: const Text('Approve'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateAssociationPage extends StatefulWidget {
  const CreateAssociationPage({super.key});
  @override
  State<CreateAssociationPage> createState() => _CreateAssociationPageState();
}

class _CreateAssociationPageState extends State<CreateAssociationPage> {
  int _currentStep = 0;
  final _nameController = TextEditingController();
  String _scope = 'Global';
  final List<String> _sports = [];
  final _rulebookController = TextEditingController();
  final _detailsController = TextEditingController();
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Association')),
      body: _submitted
          ? const Center(child: Text('Association Created Successfully!'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Step $_currentStep of 4'),
                  if (_currentStep == 0) ...[
                    TextField(
                      key: const Key('assoc_name'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Association Name',
                      ),
                    ),
                  ] else if (_currentStep == 1) ...[
                    DropdownButton<String>(
                      key: const Key('assoc_scope'),
                      value: _scope,
                      items: ['Global', 'National', 'Local']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _scope = val ?? 'Global'),
                    ),
                  ] else if (_currentStep == 2) ...[
                    CheckboxListTile(
                      key: const Key('assoc_sport_streetlifting'),
                      title: const Text('Streetlifting'),
                      value: _sports.contains('Streetlifting'),
                      onChanged: (val) => setState(
                        () => val!
                            ? _sports.add('Streetlifting')
                            : _sports.remove('Streetlifting'),
                      ),
                    ),
                    TextField(
                      key: const Key('assoc_rulebook'),
                      controller: _rulebookController,
                      decoration: const InputDecoration(
                        labelText: 'Rulebook Link',
                      ),
                    ),
                  ] else if (_currentStep == 3) ...[
                    TextField(
                      key: const Key('assoc_details'),
                      controller: _detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Details/Reason',
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        ElevatedButton(
                          key: const Key('assoc_back'),
                          onPressed: () => setState(() => _currentStep--),
                          child: const Text('Back'),
                        ),
                      ElevatedButton(
                        key: const Key('assoc_next'),
                        onPressed: () {
                          if (_currentStep < 3) {
                            setState(() => _currentStep++);
                          } else {
                            setState(() => _submitted = true);
                          }
                        },
                        child: Text(_currentStep == 3 ? 'Submit' : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class CreateCompetitionPage extends StatefulWidget {
  const CreateCompetitionPage({super.key});
  @override
  State<CreateCompetitionPage> createState() => _CreateCompetitionPageState();
}

class _CreateCompetitionPageState extends State<CreateCompetitionPage> {
  int _step = 0;
  final _nameController = TextEditingController();
  bool _feesRequired = false;
  bool _waitlistRequired = false;
  bool _disclaimerAccepted = false;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Competition')),
      body: _submitted
          ? const Center(child: Text('Competition Created!'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Step $_step'),
                  if (_step == 0) ...[
                    TextField(
                      key: const Key('comp_name_field'),
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  ] else if (_step == 1) ...[
                    SwitchListTile(
                      key: const Key('comp_fees_toggle'),
                      title: const Text('Requires Fees'),
                      value: _feesRequired,
                      onChanged: (val) => setState(() => _feesRequired = val),
                    ),
                    SwitchListTile(
                      key: const Key('comp_waitlist_toggle'),
                      title: const Text('Enable Waitlist'),
                      value: _waitlistRequired,
                      onChanged: (val) =>
                          setState(() => _waitlistRequired = val),
                    ),
                  ] else if (_step == 2) ...[
                    CheckboxListTile(
                      key: const Key('comp_disclaimer'),
                      title: const Text('Accept Terms'),
                      value: _disclaimerAccepted,
                      onChanged: (val) =>
                          setState(() => _disclaimerAccepted = val ?? false),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_step > 0)
                        ElevatedButton(
                          onPressed: () => setState(() => _step--),
                          child: const Text('Back'),
                        ),
                      ElevatedButton(
                        key: const Key('comp_next_btn'),
                        onPressed: () {
                          if (_step < 2) {
                            setState(() => _step++);
                          } else {
                            if (_disclaimerAccepted) {
                              setState(() => _submitted = true);
                            }
                          }
                        },
                        child: Text(_step == 2 ? 'Submit' : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class CompetitionHandlingPage extends StatefulWidget {
  final String? competitionId;
  const CompetitionHandlingPage({super.key, this.competitionId});

  @override
  State<CompetitionHandlingPage> createState() =>
      _CompetitionHandlingPageState();
}

class _CompetitionHandlingPageState extends State<CompetitionHandlingPage> {
  final List<String> _disciplines = ['Muscle Up', 'Pull Up', 'Dip', 'Squat'];
  String _activeDiscipline = 'Muscle Up';
  int _attemptNum = 1;
  double _attemptWeight = 0.0;
  final List<double> _submittedAttempts = [];
  bool _disqualified = false;

  // Platform Judging
  final List<bool> _judgeVotes = [
    true,
    true,
    true,
  ]; // true = Good Lift, false = No Lift
  String? _failureReason;
  bool _judgingComplete = false;
  bool _liftPassed = false;

  // VAR
  bool _varRequested = false;
  int _varCredits = 1;

  void _submitAttempt(double weight) {
    // Increment rules
    double minIncrement = _activeDiscipline == 'Squat' ? 2.5 : 1.25;
    if (_submittedAttempts.isNotEmpty && weight < _submittedAttempts.last) {
      // Must be ascending weight order
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempt weight must be ascending!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (((weight * 100).round() % (minIncrement * 100).round()) != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weight must be multiple of ${minIncrement}kg!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _attemptWeight = weight;
      _judgingComplete = false;
    });
  }

  void _judgeLift() {
    int goodCount = _judgeVotes.where((v) => v).length;
    // Majority rule vs. Unanimous rule
    bool passed = false;
    if (_activeDiscipline == 'Dip' && _failureReason == 'Invalid Depth') {
      passed = goodCount >= 2; // Majority (2:1)
    } else if (_activeDiscipline == 'Squat' &&
        (_failureReason == 'Bent Knees' || _failureReason == 'Invalid Depth')) {
      passed = goodCount >= 2; // Majority (2:1)
    } else {
      passed = goodCount == 3; // Unanimous (3:0)
    }

    setState(() {
      _liftPassed = passed;
      _judgingComplete = true;
      if (passed) {
        _submittedAttempts.add(_attemptWeight);
      }

      // Regardless of pass/fail, progress attempts
      if (_attemptNum < 3) {
        _attemptNum++;
      } else {
        if (_submittedAttempts.isEmpty) {
          _disqualified = true;
        } else {
          // Next discipline
          int idx = _disciplines.indexOf(_activeDiscipline);
          if (idx < 3) {
            _activeDiscipline = _disciplines[idx + 1];
            _attemptNum = 1;
            _submittedAttempts.clear();
          }
        }
      }
    });
  }

  void _requestVAR() {
    if (_varCredits > 0) {
      setState(() {
        _varRequested = true;
        _varCredits--;
      });
    }
  }

  void _overruleVAR(bool overrule) {
    setState(() {
      if (overrule) {
        _varCredits++; // Restore VAR credit
        _liftPassed = true;
        _disqualified = false;
        if (!_submittedAttempts.contains(_attemptWeight)) {
          _submittedAttempts.add(_attemptWeight);
        }
        if (_attemptNum == 3) {
          int idx = _disciplines.indexOf(_activeDiscipline);
          if (idx < 3) {
            _activeDiscipline = _disciplines[idx + 1];
            _attemptNum = 1;
            _submittedAttempts.clear();
          }
        }
      }
      _varRequested = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Competition Handling: ${widget.competitionId}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_disqualified) ...[
              Container(
                key: const Key('dq_status'),
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: const Center(
                  child: Text(
                    'ATHLETE DISQUALIFIED (0/3 lifts valid)',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Discipline: $_activeDiscipline',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text('Attempt: #$_attemptNum'),
            const SizedBox(height: 16),

            // Pre-calculated weight configurations
            Text(
              'Standard Plates: ${(_attemptWeight / 25).floor()}x25kg, ${((_attemptWeight % 25) / 20).floor()}x20kg',
            ),
            Text(
              StreetliftingRulesEngine.calculateOtherPlatesString(
                _attemptWeight,
              ),
            ),

            const SizedBox(height: 8),
            TextField(
              key: const Key('attempt_weight_input'),
              enabled: !_disqualified,
              keyboardType: TextInputType.number,
              onSubmitted: _disqualified
                  ? null
                  : (val) => _submitAttempt(double.parse(val)),
              decoration: const InputDecoration(
                labelText: 'Attempt Weight (kg)',
              ),
            ),
            const SizedBox(height: 16),

            // Judging Options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  key: const Key('judge_1_toggle'),
                  onPressed: _disqualified
                      ? null
                      : () => setState(() => _judgeVotes[0] = !_judgeVotes[0]),
                  child: Text('J1: ${_judgeVotes[0] ? "Good" : "No"}'),
                ),
                ElevatedButton(
                  key: const Key('judge_2_toggle'),
                  onPressed: _disqualified
                      ? null
                      : () => setState(() => _judgeVotes[1] = !_judgeVotes[1]),
                  child: Text('J2: ${_judgeVotes[1] ? "Good" : "No"}'),
                ),
                ElevatedButton(
                  key: const Key('judge_3_toggle'),
                  onPressed: _disqualified
                      ? null
                      : () => setState(() => _judgeVotes[2] = !_judgeVotes[2]),
                  child: Text('J3: ${_judgeVotes[2] ? "Good" : "No"}'),
                ),
              ],
            ),
            DropdownButton<String>(
              key: const Key('failure_reason_dropdown'),
              value: _failureReason,
              hint: const Text('Select Failure Reason'),
              items: [
                'Chicken Wing',
                'Invalid Depth',
                'Bent Knees',
                'Kipping',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: _disqualified
                  ? null
                  : (val) => setState(() => _failureReason = val),
            ),
            ElevatedButton(
              key: const Key('judge_submit'),
              onPressed: _disqualified ? null : _judgeLift,
              child: const Text('SUBMIT JUDGING'),
            ),

            if (_judgingComplete) ...[
              const SizedBox(height: 16),
              Text(
                _liftPassed ? 'LIFT PASSED' : 'LIFT FAILED',
                key: const Key('lift_status'),
                style: TextStyle(
                  color: _liftPassed ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_liftPassed && _varCredits > 0) ...[
                ElevatedButton(
                  key: const Key('var_request_btn'),
                  onPressed: _requestVAR,
                  child: Text('Request VAR (Credits: $_varCredits)'),
                ),
              ],
            ],

            if (_varRequested) ...[
              const SizedBox(height: 16),
              const Text('VAR Video Review in Progress...'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    key: const Key('var_confirm_fail'),
                    onPressed: () => _overruleVAR(false),
                    child: const Text('Confirm No Lift'),
                  ),
                  ElevatedButton(
                    key: const Key('var_overrule_pass'),
                    onPressed: () => _overruleVAR(true),
                    child: const Text('Overrule to Good Lift'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;

  // Filter States
  String _searchQuery = '';
  String _selectedGender = 'All'; // 'All', 'Male', 'Female'
  String _selectedSubtype = 'All'; // 'All', 'Modern', 'Classic'

  @override
  void initState() {
    super.initState();
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _client
          .from('meet_results')
          .select('*, profile:profiles(*)');

      final list =
          (response as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
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
      body: _isLoading
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
            ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationRepository _repository;
  List<SystemNotification> _notifications = [];
  bool _isLoading = true;

  // Category filters toggles (what to show)
  final Set<String> _selectedCategories = {};

  // Settings switches (what alerts are enabled)
  final Map<String, bool> _enabledAlerts = {
    'registration': true,
    'permissions': true,
    'payments': true,
    'schedule': true,
    'flights': true,
  };

  @override
  void initState() {
    super.initState();
    _repository = NotificationRepository(Supabase.instance.client);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUserProfile?.id ?? '';

    List<SystemNotification> list = [];
    if (userId.isNotEmpty) {
      list = await _repository.getNotifications(userId);
    }

    if (list.isEmpty) {
      // Fallback notifications seeding
      list = [
        SystemNotification(
          id: 'fallback-1',
          userId: userId,
          title: 'Registration Approved',
          message: 'Your application to Hamburg Meet was accepted.',
          category: 'registration',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isRead: false,
        ),
        SystemNotification(
          id: 'fallback-2',
          userId: userId,
          title: 'Payment Reminder',
          message: 'Please pay the fee of 25.00 EUR by 2026-06-01.',
          category: 'payments',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ];
    }

    setState(() {
      _notifications = list;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(SystemNotification notification) async {
    if (notification.isRead) return;
    await _repository.markAsRead(notification.id);
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        _notifications[index] = notification.copyWith(isRead: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter notifications based on alert settings (if alert is disabled, we do not show those notifications)
    final allowedNotifications = _notifications.where((n) {
      return _enabledAlerts[n.category] ?? true;
    }).toList();

    // 2. Filter notifications based on selected category chips (if any are selected)
    final filteredNotifications = allowedNotifications.where((n) {
      if (_selectedCategories.isEmpty) return true;
      return _selectedCategories.contains(n.category);
    }).toList();

    final categories = [
      'registration',
      'permissions',
      'payments',
      'schedule',
      'flights',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Alert Settings Section (Collapsible)
                ExpansionTile(
                  key: const Key('alert_settings_tile'),
                  title: const Text('Alert Settings'),
                  leading: const Icon(Icons.settings),
                  children: categories.map((category) {
                    return SwitchListTile(
                      key: Key('switch_$category'),
                      title: Text(
                        category[0].toUpperCase() + category.substring(1),
                      ),
                      value: _enabledAlerts[category] ?? true,
                      onChanged: (val) {
                        setState(() {
                          _enabledAlerts[category] = val;
                        });
                      },
                    );
                  }).toList(),
                ),

                // Category Filter Chips Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) {
                        final isSelected = _selectedCategories.contains(
                          category,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            key: Key('chip_$category'),
                            label: Text(
                              category[0].toUpperCase() + category.substring(1),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const Divider(),

                // Notifications List Section
                Expanded(
                  child: filteredNotifications.isEmpty
                      ? ListView(
                          key: const Key('notifications_list'),
                          children: const [
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('No notifications found.'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          key: const Key('notifications_list'),
                          itemCount: filteredNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = filteredNotifications[index];
                            return ListTile(
                              key: Key('notification_item_${notification.id}'),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification.message),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Category: ${notification.category} • ${notification.createdAt.toString().split('.')[0]}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              leading: Icon(
                                notification.isRead
                                    ? Icons.mark_email_read
                                    : Icons.mark_email_unread,
                                color: notification.isRead
                                    ? Colors.grey
                                    : Colors.blue,
                              ),
                              onTap: () => _markAsRead(notification),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
