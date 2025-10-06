import 'dart:math';

/// ScoringService calculates a weighted health score based on image predictions and user reported symptoms.
///
/// The final health score H is computed by combining the image score (I) from a CNN and the symptom score (S) from the questionnaire using weighted coefficients:
///
/// H = weightImage * I + weightSymptom * S
///
/// Where:
/// - I is the image score (expected to be a probability between 0 and 1)
/// - S is the symptom score (expected to be normalized between 0 and 1)
/// - weightImage and weightSymptom reflect the importance of each component (defaulting to 0.7 and 0.3, respectively)
class ScoringService {
  final double weightImage;
  final double weightSymptom;

  ScoringService({this.weightImage = 0.7, this.weightSymptom = 0.3});

  /// Calculate the overall health score.
  ///
  /// [imageScore] and [symptomScore] should be provided as values between 0 and 1.
  /// Returns a double value representing the final health score, capped at 1.0.
  double calculateHealthScore(
      {required double imageScore, required double symptomScore}) {
    if (imageScore < 0 || imageScore > 1) {
      throw ArgumentError('Image score must be between 0 and 1');
    }
    if (symptomScore < 0 || symptomScore > 1) {
      throw ArgumentError('Symptom score must be between 0 and 1');
    }

    double healthScore =
        (weightImage * imageScore) + (weightSymptom * symptomScore);
    return min(healthScore, 1.0);
  }
}
