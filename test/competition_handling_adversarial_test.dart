import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/repositories/association_repository.dart';
import 'package:finalrep_app/repositories/notification_repository.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/association.dart';

class LocalMockSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LocalMockCompetitionRepository implements CompetitionRepository {
  final Map<String, Competition> competitions = {};

  @override
  SupabaseClient get client => LocalMockSupabaseClient();

  @override
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status = 'upcoming',
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Competition?> getCompetitionById(String id) async => competitions[id];
}

class LocalMockProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LocalMockAssociationRepository implements AssociationRepository {
  @override
  Future<List<Association>> getAssociations() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Competition Handling Adversarial State Tests', () {
    late CompetitionProvider provider;
    late LocalMockCompetitionRepository compRepo;
    late LocalMockProfileRepository profileRepo;
    late LocalMockAssociationRepository assocRepo;
    late NotificationRepository notifRepo;

    setUp(() {
      compRepo = LocalMockCompetitionRepository();
      profileRepo = LocalMockProfileRepository();
      assocRepo = LocalMockAssociationRepository();
      notifRepo = NotificationRepository(null);

      provider = CompetitionProvider(
        compRepo,
        profileRepo,
        associationRepository: assocRepo,
        notificationRepository: notifRepo,
      );
    });

    test(
      'Double submission of judging votes is prevented and does not corrupt state',
      () {
        provider.initCompetitionHandling('comp-1');
        expect(provider.activeDiscipline, 'Muscle Up');
        expect(provider.attemptNum, 1);
        expect(provider.submittedAttempts, isEmpty);

        // Select valid weight for attempt 1
        final err = provider.selectAttemptWeight(
          'athlete-1',
          'Muscle Up',
          1,
          10.0,
        );
        expect(err, isNull);
        expect(provider.attemptWeight, 10.0);
        expect(provider.judgingComplete, isFalse);

        // 1. First submission (valid)
        provider.submitJudgingVotes(discipline: 'Muscle Up');
        expect(provider.judgingComplete, isTrue);
        expect(provider.liftPassed, isTrue);
        expect(provider.submittedAttempts, equals([10.0]));
        expect(provider.attemptNum, 2);

        // 2. Second submission without selecting a new weight is prevented
        provider.submitJudgingVotes(discipline: 'Muscle Up');
        expect(
          provider.submittedAttempts,
          equals([10.0]),
        ); // No duplicates added!
        expect(provider.attemptNum, 2); // Attempt number remains 2!
      },
    );

    test('Selecting negative attempt weight is rejected by validation', () {
      provider.initCompetitionHandling('comp-1');

      final err = provider.selectAttemptWeight(
        'athlete-1',
        'Muscle Up',
        1,
        -1.25,
      );
      expect(err, isNotNull); // Negative weight rejected!
    });

    test('Negative bodyweight throws ArgumentError', () {
      provider.initCompetitionHandling('comp-1');

      // Record negative bodyweight (-75.0kg) and zero weight -> must throw ArgumentError
      expect(
        () => provider.recordWeighIn('athlete-1', -75.0, '12', 'Medium'),
        throwsArgumentError,
      );
      expect(
        () => provider.recordWeighIn('athlete-1', 0.0, '12', 'Medium'),
        throwsArgumentError,
      );
    });

    test('VAR overrules correct disqualification status on 3rd attempt fail', () {
      provider.initCompetitionHandling('comp-1');

      // Fail first attempt
      provider.selectAttemptWeight('athlete-1', 'Muscle Up', 1, 10.0);
      provider.toggleJudgeVote(0); // vote: [false, true, true]
      provider.setFailureReason(
        'Double Motion',
      ); // needs unanimous, so will fail
      provider.submitJudgingVotes(discipline: 'Muscle Up');
      expect(provider.liftPassed, isFalse);
      expect(provider.attemptNum, 2);
      expect(provider.submittedAttempts, isEmpty);

      // Fail second attempt
      provider.selectAttemptWeight('athlete-1', 'Muscle Up', 2, 11.25);
      provider.submitJudgingVotes(
        discipline: 'Muscle Up',
      ); // votes still have a false, fails
      expect(provider.liftPassed, isFalse);
      expect(provider.attemptNum, 3);
      expect(provider.submittedAttempts, isEmpty);

      // Fail third attempt
      provider.selectAttemptWeight('athlete-1', 'Muscle Up', 3, 12.5);
      provider.submitJudgingVotes(discipline: 'Muscle Up');
      expect(provider.liftPassed, isFalse);
      expect(provider.disqualified, isTrue); // Disqualified because 3 fails
      expect(provider.attemptNum, 3); // Remains 3

      // Request VAR
      provider.requestVARReview();
      expect(provider.varRequested, isTrue);
      expect(provider.varCredits, 0);

      // Resolve VAR with overrule
      provider.resolveVARReview(true);
      expect(provider.varRequested, isFalse);
      expect(provider.liftPassed, isTrue);
      expect(provider.disqualified, isFalse); // Restored!

      // Since it was the 3rd attempt, and it was overruled to pass:
      // It should have advanced to the next discipline, so current active discipline is Pull Up
      // And attemptNum is 1, and submittedAttempts for the new discipline is empty.
      expect(provider.activeDiscipline, 'Pull Up');
      expect(provider.attemptNum, 1);
      expect(provider.submittedAttempts, isEmpty);
    });
  });
}
