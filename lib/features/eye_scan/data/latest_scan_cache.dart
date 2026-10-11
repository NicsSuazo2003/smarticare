import 'package:hive/hive.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

class LatestScanCache {
  static const String _boxName = 'latestScansCache';

  static late Box<Map> _cacheBox;

  // Initialize the cache box (call this once at app startup)
  static Future<void> initialize() async {
    try {
      _cacheBox = await Hive.openBox<Map>(_boxName);
      Logger.d('✅ LatestScanCache initialized with Hive');
    } catch (e) {
      Logger.d('❌ Error initializing LatestScanCache: $e');
      rethrow;
    }
  }

  // Get left eye prediction
  static String get leftEyePrediction {
    try {
      final data = _cacheBox.get('leftEye');
      return (data?['prediction'] as String?) ?? '';
    } catch (e) {
      Logger.d('⚠️ Error reading leftEyePrediction:  $e');
      return '';
    }
  }

  // Get left eye health score
  static double get leftEyeHealthScore {
    try {
      final data = _cacheBox.get('leftEye');
      return (data?['healthScore'] as double?) ?? 0.0;
    } catch (e) {
      Logger.d('⚠️ Error reading leftEyeHealthScore: $e');
      return 0.0;
    }
  }

  // Get right eye prediction
  static String get rightEyePrediction {
    try {
      final data = _cacheBox.get('rightEye');
      return (data?['prediction'] as String?) ?? '';
    } catch (e) {
      Logger.d('⚠️ Error reading rightEyePrediction: $e');
      return '';
    }
  }

  // Get right eye health score
  static double get rightEyeHealthScore {
    try {
      final data = _cacheBox.get('rightEye');
      return (data?['healthScore'] as double?) ?? 0.0;
    } catch (e) {
      Logger.d('⚠️ Error reading rightEyeHealthScore:  $e');
      return 0.0;
    }
  }

  // Update left eye (persisted to Hive)
  static Future<void> updateLeftEye(
      String prediction, double healthScore) async {
    try {
      await _cacheBox.put('leftEye', {
        'prediction': prediction,
        'healthScore': healthScore,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      Logger.d(
          '✅ Cache updated - Left eye: $prediction, Health: ${healthScore.toStringAsFixed(1)}%');
    } catch (e) {
      Logger.d('❌ Error updating leftEye cache: $e');
    }
  }

  // Update right eye (persisted to Hive)
  static Future<void> updateRightEye(
      String prediction, double healthScore) async {
    try {
      await _cacheBox.put('rightEye', {
        'prediction': prediction,
        'healthScore': healthScore,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      Logger.d(
          '✅ Cache updated - Right eye: $prediction, Health:  ${healthScore.toStringAsFixed(1)}%');
    } catch (e) {
      Logger.d('❌ Error updating rightEye cache: $e');
    }
  }

  // Check if eye has data
  static bool hasEyeData(bool isLeftEye) {
    try {
      final key = isLeftEye ? 'leftEye' : 'rightEye';
      final data = _cacheBox.get(key);
      final prediction = (data?['prediction'] as String?) ?? '';
      return prediction.isNotEmpty;
    } catch (e) {
      Logger.d('⚠️ Error checking hasEyeData: $e');
      return false;
    }
  }

  // Get cache status for debugging
  static Map<String, dynamic> getCacheStatus() {
    try {
      final leftData = _cacheBox.get('leftEye');
      final rightData = _cacheBox.get('rightEye');

      return {
        'leftEye': {
          'hasPrediction': leftData != null &&
              (leftData['prediction'] as String?)?.isNotEmpty == true,
          'prediction': (leftData?['prediction'] as String?) ?? 'None',
          'healthScore': (leftData?['healthScore'] as double?) ?? 0.0,
          'updatedAt': (leftData?['updatedAt'] as String?) ?? 'Never',
        },
        'rightEye': {
          'hasPrediction': rightData != null &&
              (rightData['prediction'] as String?)?.isNotEmpty == true,
          'prediction': (rightData?['prediction'] as String?) ?? 'None',
          'healthScore': (rightData?['healthScore'] as double?) ?? 0.0,
          'updatedAt': (rightData?['updatedAt'] as String?) ?? 'Never',
        },
      };
    } catch (e) {
      Logger.d('⚠️ Error getting cache status: $e');
      return {};
    }
  }

  // Clear cache
  static Future<void> clearCache() async {
    try {
      await _cacheBox.delete('leftEye');
      await _cacheBox.delete('rightEye');
      Logger.d('🗑️ Cache cleared');
    } catch (e) {
      Logger.d('❌ Error clearing cache: $e');
    }
  }

  // ✅ NEW: Print cache for debugging
  static void debugPrintCache() {
    final status = getCacheStatus();
    Logger.d('\n📦 CACHE STATUS:');
    Logger.d('Left Eye: ${status['leftEye']}');
    Logger.d('Right Eye: ${status['rightEye']}\n');
  }
}
