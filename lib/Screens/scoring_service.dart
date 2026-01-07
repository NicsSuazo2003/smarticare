import 'dart:math';

class ScoringService {
  final double weightImage;
  final double weightSymptom;

  ScoringService({this.weightImage = 0.7, this.weightSymptom = 0.3});

  /// Calculate the overall health score (0-100 scale).
  /// For Normal: high confidence = high health score
  /// For Cataract: high confidence = low health score (inverted)
  double calculateHealthScore({
    required double imageScore,
    required double symptomScore,
    String? prediction,
  }) {
    if (imageScore < 0 || imageScore > 1) {
      throw ArgumentError('Image score must be between 0 and 1');
    }
    if (symptomScore < 0 || symptomScore > 1) {
      throw ArgumentError('Symptom score must be between 0 and 1');
    }

    // Determine if prediction is cataract
    double adjustedImageScore = imageScore;
    if (prediction != null) {
      final predLower = prediction.toLowerCase();
      final isCataract =
          !predLower.contains('normal') && !predLower.contains('no cataract');

      if (isCataract) {
        // For cataract: high confidence = low health
        adjustedImageScore = 1.0 - imageScore;
      }
      // For normal: keep as is (high confidence = high health)
    } 

    // High symptoms = low health (invert)
    double adjustedSymptomScore = 1.0 - symptomScore;

    double healthScore = (weightImage * adjustedImageScore) +
        (weightSymptom * adjustedSymptomScore);

    // Return as percentage (0-100)
    return min(healthScore * 100, 100.0);
  }
}
