import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/utils/streetlifting_rules_engine.dart';
import 'e2e/e2e_test_harness.dart';

void main() {
  group('Streetlifting Rules & Competition Handling Adversarial Tests', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.initialize();
    });

    tearDown(() {
      harness.dispose();
    });

    test(
      'Adversarial Test 1: VAR overrule of failed 3rd attempt causes state corruption when prior attempt succeeded',
      () {
        final provider = harness.competitionProvider;
        provider.initCompetitionHandling('comp-1');

        // 1. Muscle Up Attempt 1: Good Lift (10.0kg)
        provider.selectAttemptWeight('athlete-1', 'Muscle Up', 1, 10.0);
        provider.submitJudgingVotes(discipline: 'Muscle Up');
        expect(provider.liftPassed, isTrue);
        expect(provider.attemptNum, 2);
        expect(provider.submittedAttempts, equals([10.0]));
        expect(provider.activeDiscipline, 'Muscle Up');

        // 2. Muscle Up Attempt 2: No Lift (15.0kg)
        provider.selectAttemptWeight('athlete-1', 'Muscle Up', 2, 15.0);
        provider.toggleJudgeVote(0);
        provider.toggleJudgeVote(1);
        provider.toggleJudgeVote(2); // all 3 No
        provider.submitJudgingVotes(discipline: 'Muscle Up');
        expect(provider.liftPassed, isFalse);
        expect(provider.attemptNum, 3);
        expect(provider.submittedAttempts, equals([10.0]));
        expect(provider.activeDiscipline, 'Muscle Up');

        // 3. Muscle Up Attempt 3: No Lift (20.0kg)
        provider.selectAttemptWeight('athlete-1', 'Muscle Up', 3, 20.0);
        provider.submitJudgingVotes(discipline: 'Muscle Up');
        expect(provider.liftPassed, isFalse);

        // CRITICAL STATE CORRUPTION CHECK:
        // Because Attempt 3 failed, but we had a successful Attempt 1,
        // the provider should advance to the next discipline (Pull Up),
        // reset attempt number to 1, and clear submitted attempts.
        expect(provider.activeDiscipline, 'Pull Up');
        expect(provider.attemptNum, 1);
        expect(provider.submittedAttempts, isEmpty);

        // Now, the user requests VAR review for the failed 3rd attempt (which was 20.0kg)
        provider.requestVARReview();
        expect(provider.varRequested, isTrue);

        // Overrule to Good Lift
        provider.resolveVARReview(true);

        // After overruling, let's examine the state:
        // Since attemptNum is now 1 (not 3), and activeDiscipline is 'Pull Up',
        // the overruled weight (20.0kg) is incorrectly added to the Pull Up attempts!
        // This is a major business logic violation!
        debugPrint('ACTIVE DISCIPLINE: ${provider.activeDiscipline}');
        debugPrint('ATTEMPT NUM: ${provider.attemptNum}');
        debugPrint('SUBMITTED ATTEMPTS: ${provider.submittedAttempts}');

        // The overruled weight (20.0kg) belongs to Muscle Up, not Pull Up.
        // Therefore, the Pull Up discipline's submitted attempts list must remain empty.
        expect(
          provider.submittedAttempts,
          isEmpty,
          reason:
              'Overruled weight from prior discipline must not pollute next discipline',
        );
      },
    );

    test(
      'Adversarial Test 2: Decreasing weight attempts after failed attempts are permitted',
      () {
        final provider = harness.competitionProvider;
        provider.initCompetitionHandling('comp-1');

        // Muscle Up Attempt 1: Select 20.0kg and fail
        provider.selectAttemptWeight('athlete-1', 'Muscle Up', 1, 20.0);
        provider.toggleJudgeVote(0);
        provider.toggleJudgeVote(1);
        provider.toggleJudgeVote(2); // all No
        provider.submitJudgingVotes(discipline: 'Muscle Up');
        expect(provider.liftPassed, isFalse);

        // Muscle Up Attempt 2: Select 15.0kg (lighter than failed 20.0kg attempt)
        // The rules state weight must be ascending, so attempting a lighter weight must be blocked!
        final error = provider.selectAttemptWeight(
          'athlete-1',
          'Muscle Up',
          2,
          15.0,
        );

        // If the bug exists, error will be null (it is accepted)!
        debugPrint('ERROR FOR LIGHTER ATTEMPT: $error');
        expect(
          error,
          isNotNull,
          reason: 'Lighter attempt after failed attempt must be blocked',
        );
      },
    );
  });
}
