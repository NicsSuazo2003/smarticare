class LatestScanCache {
  static String leftEyePrediction = '';
  static double leftEyeHealthScore = 0.0; // ✅ Changed from confidence
  static String rightEyePrediction = '';
  static double rightEyeHealthScore = 0.0; // ✅ Changed from confidence

  static void updateLeftEye(String prediction, double healthScore) {
    leftEyePrediction = prediction;
    leftEyeHealthScore = healthScore; // ✅ Now stores 0-100 score
    print('✅ Cache updated - Left eye: $prediction, Health: $healthScore%');
  }

  static void updateRightEye(String prediction, double healthScore) {
    rightEyePrediction = prediction;
    rightEyeHealthScore = healthScore; // ✅ Now stores 0-100 score
    print('✅ Cache updated - Right eye: $prediction, Health: $healthScore%');
  }

  static bool hasEyeData(bool isLeftEye) {
    return isLeftEye
        ? leftEyeHealthScore > 0 && leftEyePrediction.isNotEmpty
        : rightEyeHealthScore > 0 && rightEyePrediction.isNotEmpty;
  }

  static void clearCache() {
    leftEyePrediction = '';
    leftEyeHealthScore = 0.0;
    rightEyePrediction = '';
    rightEyeHealthScore = 0.0;
    print('🗑️ Cache cleared');
  }
}
