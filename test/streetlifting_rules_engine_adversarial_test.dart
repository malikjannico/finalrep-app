import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/utils/streetlifting_rules_engine.dart';

void main() {
  group('StreetliftingRulesEngine Adversarial Unit Tests', () {
    group('validateIncrement', () {
      test('Negative weights return validation errors', () {
        expect(
          StreetliftingRulesEngine.validateIncrement(-2.5, 'Squat'),
          isNotNull,
        );
        expect(
          StreetliftingRulesEngine.validateIncrement(-1.25, 'Dip'),
          isNotNull,
        );
      });

      test('Zero weight returns validation errors', () {
        expect(
          StreetliftingRulesEngine.validateIncrement(0.0, 'Squat'),
          isNotNull,
        );
        expect(
          StreetliftingRulesEngine.validateIncrement(0.0, 'Dip'),
          isNotNull,
        );
      });

      test(
        'Calling validateIncrement on NaN/Infinity returns error string instead of crashing',
        () {
          expect(
            StreetliftingRulesEngine.validateIncrement(double.nan, 'Squat'),
            isNotNull,
          );
          expect(
            StreetliftingRulesEngine.validateIncrement(
              double.infinity,
              'Squat',
            ),
            isNotNull,
          );
        },
      );

      test('Unexpected discipline names fallback to 1.25kg increment', () {
        // discipline = "Bench Press" defaults minIncrement to 1.25
        expect(
          StreetliftingRulesEngine.validateIncrement(1.25, 'Bench Press'),
          isNull,
        );
        expect(
          StreetliftingRulesEngine.validateIncrement(2.0, 'Bench Press'),
          isNotNull,
        );
      });
    });

    group('calculateAllPlates', () {
      test('Negative weights result in zero plates', () {
        final plates = StreetliftingRulesEngine.calculateAllPlates(-25.0);
        expect(plates['25'], 0);
      });

      test(
        'Extremely large weights are calculated without crashing but might overflow integer limit in 32-bit systems',
        () {
          final plates = StreetliftingRulesEngine.calculateAllPlates(1e9);
          expect(plates['25'], 40000000);
        },
      );

      test('NaN/Infinity weight returns zero plates without crashing', () {
        final nanPlates = StreetliftingRulesEngine.calculateAllPlates(
          double.nan,
        );
        expect(nanPlates['25'], 0);
        final infPlates = StreetliftingRulesEngine.calculateAllPlates(
          double.infinity,
        );
        expect(infPlates['25'], 0);
      });
    });

    group('evaluateJudging', () {
      test('Empty votes list returns false without crashing', () {
        expect(
          StreetliftingRulesEngine.evaluateJudging(
            discipline: 'Dip',
            votes: [],
            failureReason: 'Invalid Depth',
          ),
          isFalse,
        );
      });

      test('Votes list of size 2 returns correct majority rule', () {
        // [true, true] -> goodCount is 2, length = 2. Unanimous is true.
        expect(
          StreetliftingRulesEngine.evaluateJudging(
            discipline: 'Dip',
            votes: [true, true],
            failureReason: 'Invalid Depth',
          ),
          isTrue,
        );

        // [true, false] -> goodCount = 1, length = 2. Majority of 2 is (2/2).ceil() = 1.
        expect(
          StreetliftingRulesEngine.evaluateJudging(
            discipline: 'Dip',
            votes: [true, false],
            failureReason: 'Invalid Depth',
          ),
          isTrue,
        );
      });

      test('Five-judge panel with unanimous good votes (5:0) returns true', () {
        expect(
          StreetliftingRulesEngine.evaluateJudging(
            discipline: 'Dip',
            votes: [true, true, true, true, true],
            failureReason: null,
          ),
          isTrue,
        );
      });

      test('Null failureReason under majority decision returns false', () {
        // 2:1 split (2 good votes) but failureReason is null.
        // In this case it returns false because the check requires a specific failureReason to accept majority.
        expect(
          StreetliftingRulesEngine.evaluateJudging(
            discipline: 'Dip',
            votes: [true, true, false],
            failureReason: null,
          ),
          isFalse,
        );
      });
    });
  });
}
