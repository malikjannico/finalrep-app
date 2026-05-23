import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/providers/auth_provider.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';

// ==========================================
// 1. SUPABASE CLIENT MOCKS (HTTP & AUTH)
// ==========================================

class MockSupabaseClient implements SupabaseClient {
  @override
  final MockGoTrueClient auth;

  MockSupabaseClient({required this.auth});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserResponse implements UserResponse {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoTrueClient implements GoTrueClient {
  final StreamController<AuthState> _authStateController;
  MockGoTrueClient(this._authStateController);

  final List<Map<String, dynamic>> signUpCalls = [];
  final List<Map<String, dynamic>> signInCalls = [];
  int signOutCallCount = 0;

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #signUp) {
      final namedArgs = invocation.namedArguments;
      signUpCalls.add({
        'email': namedArgs[#email],
        'password': namedArgs[#password],
        'data': namedArgs[#data],
      });
      return Future.value(AuthResponse(session: null, user: null));
    }
    if (name == #signInWithPassword) {
      final namedArgs = invocation.namedArguments;
      signInCalls.add({
        'email': namedArgs[#email],
        'password': namedArgs[#password],
      });
      return Future.value(AuthResponse(session: null, user: null));
    }
    if (name == #signOut) {
      signOutCallCount++;
      return Future.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

// ==========================================
// 2. MOCK REPOSITORIES
// ==========================================

class MockProfileRepository implements ProfileRepository {
  final Map<String, Profile> profiles = {};
  final List<Profile> searchResults = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Profile?> getProfile(String id) async => profiles[id];

  @override
  Future<Profile?> getProfileByUsername(String username) async {
    for (final p in profiles.values) {
      if (p.username.toLowerCase() == username.toLowerCase()) return p;
    }
    return null;
  }

  @override
  Future<Profile?> getProfileByEmail(String email) async {
    for (final p in profiles.values) {
      if (p.email.toLowerCase() == email.toLowerCase()) return p;
    }
    return null;
  }

  @override
  Future<List<Profile>> searchProfiles(String query) async => searchResults;
}

class MockCompetitionRepository implements CompetitionRepository {
  final List<Competition> mockCompetitions = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
  }) async {
    return mockCompetitions.where((comp) {
      if (query != null && query.isNotEmpty) {
        if (!comp.title.toLowerCase().contains(query.toLowerCase())) return false;
      }
      if (sportSubtype != null && sportSubtype != 'All' && comp.sportSubtype != sportSubtype) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Competition?> getCompetitionById(String id) async {
    try {
      return mockCompetitions.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ==========================================
// 3. MOCK PAGES & VIEWS (For compilation and E2E Flow)
// ==========================================

class MockAssociationWizardPage extends StatefulWidget {
  const MockAssociationWizardPage({super.key});
  @override
  State<MockAssociationWizardPage> createState() => _MockAssociationWizardPageState();
}

class _MockAssociationWizardPageState extends State<MockAssociationWizardPage> {
  int _currentStep = 0;
  final _nameController = TextEditingController();
  String _scope = 'Global';
  final List<String> _sports = [];
  final _rulebookController = TextEditingController();
  final _channelsController = TextEditingController();
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
                    TextField(key: const Key('assoc_name'), controller: _nameController, decoration: const InputDecoration(labelText: 'Association Name')),
                  ] else if (_currentStep == 1) ...[
                    DropdownButton<String>(
                      key: const Key('assoc_scope'),
                      value: _scope,
                      items: ['Global', 'National', 'Local'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _scope = val ?? 'Global'),
                    ),
                  ] else if (_currentStep == 2) ...[
                    CheckboxListTile(
                      key: const Key('assoc_sport_streetlifting'),
                      title: const Text('Streetlifting'),
                      value: _sports.contains('Streetlifting'),
                      onChanged: (val) => setState(() => val! ? _sports.add('Streetlifting') : _sports.remove('Streetlifting')),
                    ),
                    TextField(key: const Key('assoc_rulebook'), controller: _rulebookController, decoration: const InputDecoration(labelText: 'Rulebook Link')),
                  ] else if (_currentStep == 3) ...[
                    TextField(key: const Key('assoc_details'), controller: _detailsController, decoration: const InputDecoration(labelText: 'Details/Reason')),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0) ElevatedButton(key: const Key('assoc_back'), onPressed: () => setState(() => _currentStep--), child: const Text('Back')),
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
                  )
                ],
              ),
            ),
    );
  }
}

class MockCompetitionWizardPage extends StatefulWidget {
  const MockCompetitionWizardPage({super.key});
  @override
  State<MockCompetitionWizardPage> createState() => _MockCompetitionWizardPageState();
}

class _MockCompetitionWizardPageState extends State<MockCompetitionWizardPage> {
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
                    TextField(key: const Key('comp_name_field'), controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
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
                      onChanged: (val) => setState(() => _waitlistRequired = val),
                    ),
                  ] else if (_step == 2) ...[
                    CheckboxListTile(
                      key: const Key('comp_disclaimer'),
                      title: const Text('Accept Terms'),
                      value: _disclaimerAccepted,
                      onChanged: (val) => setState(() => _disclaimerAccepted = val ?? false),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_step > 0) ElevatedButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
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

class MockCompetitionHandlingPage extends StatefulWidget {
  final Competition competition;
  const MockCompetitionHandlingPage({super.key, required this.competition});

  @override
  State<MockCompetitionHandlingPage> createState() => _MockCompetitionHandlingPageState();
}

class _MockCompetitionHandlingPageState extends State<MockCompetitionHandlingPage> {
  final List<String> _disciplines = ['Muscle Up', 'Pull Up', 'Dip', 'Squat'];
  String _activeDiscipline = 'Muscle Up';
  int _attemptNum = 1;
  double _attemptWeight = 0.0;
  final List<double> _submittedAttempts = [];
  bool _disqualified = false;
  
  // Platform Judging
  final List<bool> _judgeVotes = [true, true, true]; // true = Good Lift, false = No Lift
  String? _failureReason;
  bool _judgingComplete = false;
  bool _liftPassed = false;
  
  // VAR
  bool _varRequested = false;
  bool _varOverruled = false;
  int _varCredits = 1;

  void _submitAttempt(double weight) {
    // Increment rules
    double minIncrement = _activeDiscipline == 'Squat' ? 2.5 : 1.25;
    if (_submittedAttempts.isNotEmpty && weight < _submittedAttempts.last) {
      // Must be ascending weight order
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attempt weight must be ascending!'), backgroundColor: Colors.red),
      );
      return;
    }
    if (((weight * 100).round() % (minIncrement * 100).round()) != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weight must be multiple of ${minIncrement}kg!'), backgroundColor: Colors.red),
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
    } else if (_activeDiscipline == 'Squat' && (_failureReason == 'Bent Knees' || _failureReason == 'Invalid Depth')) {
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
      _varOverruled = overrule;
      if (overrule) {
        _varCredits++; // Restore VAR credit
        _liftPassed = true;
        _submittedAttempts.add(_attemptWeight);
      }
      _varRequested = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.competition.title)),
      body: _disqualified
          ? const Center(key: Key('dq_status'), child: Text('ATHLETE DISQUALIFIED (0/3 lifts valid)'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Discipline: $_activeDiscipline', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Attempt: #$_attemptNum'),
                  const SizedBox(height: 16),
                  
                  // Pre-calculated weight configurations
                  Text('Standard Plates: ${(_attemptWeight / 25).floor()}x25kg, ${((_attemptWeight % 25) / 20).floor()}x20kg'),
                  
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('attempt_weight_input'),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) => _submitAttempt(double.parse(val)),
                    decoration: const InputDecoration(labelText: 'Attempt Weight (kg)'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Judging Options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        key: const Key('judge_1_toggle'),
                        onPressed: () => setState(() => _judgeVotes[0] = !_judgeVotes[0]),
                        child: Text('J1: ${_judgeVotes[0] ? "Good" : "No"}'),
                      ),
                      ElevatedButton(
                        key: const Key('judge_2_toggle'),
                        onPressed: () => setState(() => _judgeVotes[1] = !_judgeVotes[1]),
                        child: Text('J2: ${_judgeVotes[1] ? "Good" : "No"}'),
                      ),
                      ElevatedButton(
                        key: const Key('judge_3_toggle'),
                        onPressed: () => setState(() => _judgeVotes[2] = !_judgeVotes[2]),
                        child: Text('J3: ${_judgeVotes[2] ? "Good" : "No"}'),
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    key: const Key('failure_reason_dropdown'),
                    value: _failureReason,
                    hint: const Text('Select Failure Reason'),
                    items: ['Chicken Wing', 'Invalid Depth', 'Bent Knees', 'Kipping']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) => setState(() => _failureReason = val),
                  ),
                  ElevatedButton(
                    key: const Key('judge_submit'),
                    onPressed: _judgeLift,
                    child: const Text('SUBMIT JUDGING'),
                  ),
                  
                  if (_judgingComplete) ...[
                    const SizedBox(height: 16),
                    Text(
                      _liftPassed ? 'LIFT PASSED' : 'LIFT FAILED',
                      key: const Key('lift_status'),
                      style: TextStyle(color: _liftPassed ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
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
                        ElevatedButton(key: const Key('var_confirm_fail'), onPressed: () => _overruleVAR(false), child: const Text('Confirm No Lift')),
                        ElevatedButton(key: const Key('var_overrule_pass'), onPressed: () => _overruleVAR(true), child: const Text('Overrule to Good Lift')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class MockRankingsPage extends StatelessWidget {
  const MockRankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rankings')),
      body: ListView(
        key: const Key('rankings_list'),
        children: const [
          ListTile(
            title: Text('1. John Doe - 420.0kg'),
            subtitle: Text('MU: 20kg | PU: 50kg | Dip: 80kg | Squat: 180kg'),
          ),
          ListTile(
            title: Text('2. Jane Smith - 390.0kg'),
            subtitle: Text('MU: 15kg | PU: 45kg | Dip: 75kg | Squat: 165kg'),
          ),
        ],
      ),
    );
  }
}

class MockNotificationsPage extends StatelessWidget {
  const MockNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        key: const Key('notifications_list'),
        children: const [
          ListTile(
            title: Text('Registration Approved'),
            subtitle: Text('Your application to Hamburg Meet was accepted.'),
          ),
          ListTile(
            title: Text('Payment Reminder'),
            subtitle: Text('Please pay the fee of 25.00 EUR by 2026-06-01.'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. TEST HARNESS SETUP UTILITY
// ==========================================

class E2ETestHarness {
  final mockClient = MockSupabaseClient(auth: MockGoTrueClient(StreamController<AuthState>.broadcast()));
  final mockProfileRepository = MockProfileRepository();
  final mockCompetitionRepository = MockCompetitionRepository();

  late final AuthProvider authProvider;
  late final CompetitionProvider competitionProvider;

  E2ETestHarness() {
    authProvider = AuthProvider(mockClient, mockProfileRepository);
    competitionProvider = CompetitionProvider(mockCompetitionRepository, mockProfileRepository);
  }

  Widget buildTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CompetitionProvider>.value(value: competitionProvider),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == '/create-association') {
            return MaterialPageRoute(builder: (_) => const MockAssociationWizardPage());
          }
          if (settings.name == '/create-competition') {
            return MaterialPageRoute(builder: (_) => const MockCompetitionWizardPage());
          }
          if (settings.name == '/rankings') {
            return MaterialPageRoute(builder: (_) => const MockRankingsPage());
          }
          if (settings.name == '/notifications') {
            return MaterialPageRoute(builder: (_) => const MockNotificationsPage());
          }
          if (settings.name?.startsWith('/competition-handling/') ?? false) {
            final id = settings.name!.replaceFirst('/competition-handling/', '');
            return MaterialPageRoute(
              builder: (_) => FutureBuilder<Competition?>(
                future: mockCompetitionRepository.getCompetitionById(id),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return MockCompetitionHandlingPage(competition: snapshot.data!);
                  }
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                },
              ),
            );
          }
          return null;
        },
        home: child,
      ),
    );
  }

  void setupFakeData() {
    // Populate fake profile
    final adminProfile = Profile(
      id: 'admin-123',
      username: 'adminuser',
      fullName: 'System Administrator',
      email: 'admin@finalrep.com',
      colorMode: 'dark',
    );
    mockProfileRepository.profiles['admin-123'] = adminProfile;

    // Populate fake competition
    final comp = Competition(
      id: 'hamburg-1',
      title: 'Hamburg Meet 2026',
      location: 'Hamburg, Germany',
      sportSubtype: 'Modern',
      startDate: DateTime(2026, 6, 10),
      endDate: DateTime(2026, 6, 12),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    mockCompetitionRepository.mockCompetitions.add(comp);
  }
}
