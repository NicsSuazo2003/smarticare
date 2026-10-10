class StagingService {
  /// Determine cataract stage from:
  /// - prediction: model output ("Normal" or "Cataract")
  /// - symptomScore: 0.0–1.0 from the assessment
  /// - confidence: 0.0–1.0 model confidence
  /// - healthScore: optional 0–100 if you want to adjust thresholds in the future
  static String determineStage({
    required String prediction,
    required double symptomScore,
    required double confidence,
    double? healthScore,
  }) {
    final pred = prediction.toLowerCase();
    final isNormal = pred.contains('normal') || pred.contains('no cataract');

    // If model says Normal:
    // - If symptoms are moderate/high, treat as early Immature (camera-invisible)
    if (isNormal) {
      return symptomScore >= 0.4 ? 'Immature' : 'Normal';
    }

    // If model says Cataract:
    // Stage primarily by symptoms
    if (symptomScore < 0.3) return 'Immature';
    if (symptomScore < 0.7) return 'Mature';
    return 'Mature';
  }
}
