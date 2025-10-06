// Create this file in your project if you haven't already
class LatestScanCache {
  // Static variables to hold the latest scan data
  static String leftEyePrediction = '';
  static double leftEyeConfidence = 0.0;
  static String rightEyePrediction = '';
  static double rightEyeConfidence = 0.0;

  // Method to update left eye data
  static void updateLeftEye(String prediction, double confidence) {
    leftEyePrediction = prediction;
    leftEyeConfidence = confidence;
    print('Updated LatestScanCache for left eye: $prediction, $confidence');
  }

  // Method to update right eye data
  static void updateRightEye(String prediction, double confidence) {
    rightEyePrediction = prediction;
    rightEyeConfidence = confidence;
    print('Updated LatestScanCache for right eye: $prediction, $confidence');
  }

  // Method to check if we have data
  static bool hasEyeData(bool isLeftEye) {
    return isLeftEye
        ? leftEyeConfidence > 0 && leftEyePrediction.isNotEmpty
        : rightEyeConfidence > 0 && rightEyePrediction.isNotEmpty;
  }

  // Method to clear all cache data (useful for logout)
  static void clearCache() {
    leftEyePrediction = '';
    leftEyeConfidence = 0.0;
    rightEyePrediction = '';
    rightEyeConfidence = 0.0;
    print('Cache cleared');
  }
}
