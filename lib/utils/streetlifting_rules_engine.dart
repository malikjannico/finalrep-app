class StreetliftingRulesEngine {
  /// Validates the weight increment based on the discipline.
  /// Muscle Up, Pull Up, Dip must be multiples of 1.25kg.
  /// Squat must be multiple of 2.5kg.
  static String? validateIncrement(double weight, String discipline) {
    if (weight.isNaN || weight.isInfinite || weight <= 0) {
      return 'Weight must be positive and valid!';
    }
    final minIncrement = (discipline == 'Squat') ? 2.5 : 1.25;
    final weightCents = (weight * 100).round();
    final incCents = (minIncrement * 100).round();
    if (weightCents % incCents != 0) {
      return 'Weight must be multiple of ${minIncrement}kg!';
    }
    return null;
  }

  /// Validates if the new attempt weight is ascending (greater than or equal to the previous attempt weight).
  static bool isAscending(double newWeight, double? previousWeight) {
    if (previousWeight == null) return true;
    return newWeight >= previousWeight;
  }

  static Map<String, int> calculateAllPlates(double weight) {
    if (weight.isNaN || weight.isInfinite || weight <= 0) {
      return {
        '25': 0,
        '20': 0,
        '15': 0,
        '10': 0,
        '5': 0,
        '2.5': 0,
        '1.25': 0,
      };
    }
    int weightCents = (weight * 100).round();
    
    int count25 = weightCents ~/ 2500;
    weightCents %= 2500;
    
    int count20 = weightCents ~/ 2000;
    weightCents %= 2000;

    int count15 = weightCents ~/ 1500;
    weightCents %= 1500;

    int count10 = weightCents ~/ 1000;
    weightCents %= 1000;

    int count5 = weightCents ~/ 500;
    weightCents %= 500;

    int count2_5 = weightCents ~/ 250;
    weightCents %= 250;

    int count1_25 = weightCents ~/ 125;
    weightCents %= 125;

    return {
      '25': count25,
      '20': count20,
      '15': count15,
      '10': count10,
      '5': count5,
      '2.5': count2_5,
      '1.25': count1_25,
    };
  }

  /// Plate calculation using greedy logic.
  /// Returns a formatted string like "Standard Plates: Xx25kg, Yx20kg"
  static String calculatePlatesString(double weight) {
    final plates = calculateAllPlates(weight);
    return 'Standard Plates: ${plates['25']}x25kg, ${plates['20']}x20kg';
  }

  /// Returns a formatted string for other plates: 15kg, 10kg, 5kg, 2.5kg, 1.25kg.
  static String calculateOtherPlatesString(double weight) {
    final plates = calculateAllPlates(weight);
    return 'Other Plates: ${plates['15']}x15kg, ${plates['10']}x10kg, ${plates['5']}x5kg, ${plates['2.5']}x2.5kg, ${plates['1.25']}x1.25kg';
  }

  /// Evaluates judging votes.
  /// Majority (2:1) allowed for Dips Depth (Invalid Depth) and Squat knees/depth (Bent Knees, Invalid Depth).
  /// Unanimous (3:0) required for all other errors.
  static bool evaluateJudging({
    required String discipline,
    required List<bool> votes,
    String? failureReason,
  }) {
    if (votes.isEmpty) return false;
    int goodCount = votes.where((v) => v).length;
    if (goodCount == votes.length) return true;

    // Under majority rule
    final isMajorityAllowed = (discipline == 'Dip' && failureReason == 'Invalid Depth') ||
        (discipline == 'Squat' && (failureReason == 'Bent Knees' || failureReason == 'Invalid Depth'));

    if (isMajorityAllowed) {
      return goodCount >= (votes.length / 2).ceil();
    }
    return false;
  }
}
