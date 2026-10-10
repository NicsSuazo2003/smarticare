class StagingService {
  /// Determine cataract stage from:
  /// - prediction: model output ("Normal", "Immature", "Mature")
  /// - symptomScore: 0.0–1.0 from the assessment
  /// - confidence: 0.0–1.0 model confidence
  ///
  /// Returns one of: "Normal", "Immature", "Mature".
  static String determineStage({
    required String prediction,
    required double symptomScore,
    required double confidence,
    double? healthScore,
  }) {
    final pred = prediction.toLowerCase();

    final bool isNormal = pred.contains('normal');
    final bool isImmature = pred.contains('immature');
    final bool isMature = pred.contains('mature');

    // 1) Model says Normal
    //
    // If symptoms are moderate or high (symptomScore ≥ 0.4),
    // treat as early Immature even if image looks normal.
    if (isNormal) {
      if (symptomScore >= 0.4) {
        return 'Immature';
      }
      return 'Normal';
    }

    // 2) Model says Immature cataract
    //
    // With low symptoms → keep Immature.
    // With stronger symptoms (≥ 0.6) → escalate to Mature.
    if (isImmature) {
      if (symptomScore >= 0.6) {
        return 'Mature';
      }
      return 'Immature';
    }

    // 3) Model says Mature cataract
    //
    // Symptoms just help confirm severity, but stage remains Mature.
    if (isMature) {
      return 'Mature';
    }

    // Fallback: if label is unexpected, treat as Normal
    return 'Normal';
  }
}
