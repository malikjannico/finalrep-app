import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/competition_provider.dart';
import '../utils/streetlifting_rules_engine.dart';

class CompetitionHandlingPage extends StatefulWidget {
  final String? competitionId;
  const CompetitionHandlingPage({super.key, this.competitionId});

  @override
  State<CompetitionHandlingPage> createState() =>
      _CompetitionHandlingPageState();
}

class _CompetitionHandlingPageState extends State<CompetitionHandlingPage> {
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompetitionProvider>().initCompetitionHandling(
        widget.competitionId ?? '',
      );
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _submitAttempt(String value) {
    if (value.isEmpty) return;
    final parsed = double.tryParse(value);
    if (parsed == null) return;

    final provider = context.read<CompetitionProvider>();
    final error = provider.selectAttemptWeight(
      'athlete_id', // default/mock athleteId
      provider.activeDiscipline ?? 'Muscle Up',
      provider.attemptNum,
      parsed,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompetitionProvider>();
    final isDisqualified = provider.disqualified;

    final activeDiscipline = provider.activeDiscipline ?? 'Muscle Up';
    final attemptNum = provider.attemptNum;
    final attemptWeight = provider.attemptWeight;
    final platesStr = StreetliftingRulesEngine.calculatePlatesString(
      attemptWeight,
    );
    final otherPlatesStr = StreetliftingRulesEngine.calculateOtherPlatesString(
      attemptWeight,
    );
    final judgeVotes = provider.judgeVotes;
    final failureReason = provider.failureReason;
    final judgingComplete = provider.judgingComplete;
    final liftPassed = provider.liftPassed;
    final varRequested = provider.varRequested;
    final varCredits = provider.varCredits;

    return Scaffold(
      appBar: AppBar(
        title: Text('Competition Handling: ${widget.competitionId}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDisqualified) ...[
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
              'Discipline: $activeDiscipline',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text('Attempt: #$attemptNum'),
            const SizedBox(height: 16),

            Text(platesStr),
            Text(otherPlatesStr),

            const SizedBox(height: 8),
            TextField(
              key: const Key('attempt_weight_input'),
              controller: _weightController,
              enabled: !isDisqualified,
              keyboardType: TextInputType.number,
              onSubmitted: isDisqualified ? null : _submitAttempt,
              decoration: const InputDecoration(
                labelText: 'Attempt Weight (kg)',
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  key: const Key('judge_1_toggle'),
                  onPressed: isDisqualified
                      ? null
                      : () => provider.toggleJudgeVote(0),
                  child: Text('J1: ${judgeVotes[0] ? "Good" : "No"}'),
                ),
                ElevatedButton(
                  key: const Key('judge_2_toggle'),
                  onPressed: isDisqualified
                      ? null
                      : () => provider.toggleJudgeVote(1),
                  child: Text('J2: ${judgeVotes[1] ? "Good" : "No"}'),
                ),
                ElevatedButton(
                  key: const Key('judge_3_toggle'),
                  onPressed: isDisqualified
                      ? null
                      : () => provider.toggleJudgeVote(2),
                  child: Text('J3: ${judgeVotes[2] ? "Good" : "No"}'),
                ),
              ],
            ),
            DropdownButton<String>(
              key: const Key('failure_reason_dropdown'),
              value: failureReason,
              hint: const Text('Select Failure Reason'),
              items: [
                'Chicken Wing',
                'Invalid Depth',
                'Bent Knees',
                'Kipping',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: isDisqualified
                  ? null
                  : (val) => provider.setFailureReason(val),
            ),
            ElevatedButton(
              key: const Key('judge_submit'),
              onPressed: isDisqualified
                  ? null
                  : () {
                      provider.submitJudgingVotes(discipline: activeDiscipline);
                    },
              child: const Text('SUBMIT JUDGING'),
            ),

            if (judgingComplete) ...[
              const SizedBox(height: 16),
              Text(
                liftPassed ? 'LIFT PASSED' : 'LIFT FAILED',
                key: const Key('lift_status'),
                style: TextStyle(
                  color: liftPassed ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!liftPassed && varCredits > 0) ...[
                ElevatedButton(
                  key: const Key('var_request_btn'),
                  onPressed: () => provider.requestVARReview(),
                  child: Text('Request VAR (Credits: $varCredits)'),
                ),
              ],
            ],

            if (varRequested) ...[
              const SizedBox(height: 16),
              const Text('VAR Video Review in Progress...'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    key: const Key('var_confirm_fail'),
                    onPressed: () => provider.resolveVARReview(false),
                    child: const Text('Confirm No Lift'),
                  ),
                  ElevatedButton(
                    key: const Key('var_overrule_pass'),
                    onPressed: () => provider.resolveVARReview(true),
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
