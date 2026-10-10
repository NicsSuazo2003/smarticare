import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/features/symptom_assessment/services/scoring_service.dart';
import 'package:flutter_application_1/services/ml/staging_service.dart';

/// ONE-TIME MIGRATION SCRIPT
/// Run this once to update all legacy scans with enhanced staging data
class OneTimeScanMigration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final ScoringService _scoring = ScoringService();

  /// Main migration function - Run this once
  static Future<void> runOneTimeMigration() async {
    print('🚀 ========================================');
    print('🚀 STARTING ONE-TIME SCAN MIGRATION');
    print('🚀 Date: 2025-11-15 10:11:32 UTC');
    print('🚀 ========================================\n');

    final startTime = DateTime.now();
    int totalUsers = 0;
    int totalScans = 0;
    int scansEnhanced = 0;
    int scansSkipped = 0;
    int scansErrored = 0;

    try {
      // Step 1: Get all users
      print('📋 Step 1: Fetching all users...');
      final usersSnapshot = await _firestore.collection('users').get();
      totalUsers = usersSnapshot.docs.length;
      print('✅ Found $totalUsers users\n');

      // Step 2: Process each user
      int currentUser = 0;
      for (var userDoc in usersSnapshot.docs) {
        currentUser++;
        final userId = userDoc.id;
        final userData = userDoc.data();
        final userName =
            userData['firstName'] ?? userData['username'] ?? 'Unknown';

        print(
            '👤 [$currentUser/$totalUsers] Processing user: $userName ($userId)');

        try {
          // Get all scans for this user
          final scansSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('scans')
              .get();

          final userScanCount = scansSnapshot.docs.length;
          totalScans += userScanCount;

          if (userScanCount == 0) {
            print('   ℹ️  No scans found - skipping\n');
            continue;
          }

          print('   📊 Found $userScanCount scans');

          // Process each scan
          int userEnhanced = 0;
          int userSkipped = 0;
          int userErrored = 0;

          for (var scanDoc in scansSnapshot.docs) {
            final scanId = scanDoc.id;
            final scanData = scanDoc.data();

            try {
              // Check if already enhanced
              final hasEnhancedStaging =
                  scanData.containsKey('enhancedStaging') &&
                      scanData['enhancedStaging'] != null;
              final hasHealthScore = scanData.containsKey('healthScore') &&
                  scanData['healthScore'] != null;
              final hasRiskLevel = scanData.containsKey('riskLevel') &&
                  scanData['riskLevel'] != null;

              if (hasEnhancedStaging && hasHealthScore && hasRiskLevel) {
                userSkipped++;
                scansSkipped++;
                continue; // Already enhanced
              }

              // Extract existing data
              final prediction = scanData['prediction'] as String? ?? 'Normal';
              final confidence =
                  (scanData['confidence'] as num?)?.toDouble() ?? 0.0;
              final symptomScore =
                  (scanData['symptomScore'] as num?)?.toDouble() ?? 0.0;
              final eye = scanData['eye'] as String? ?? 'Unknown';
              final scanDate = scanData['scanDate'] as String? ?? 'Unknown';

              // Calculate enhanced fields
              final healthScore = _scoring.calculateHealthScore(
                imageScore: confidence,
                symptomScore: symptomScore,
                prediction: prediction,
              );

              final stage = StagingService.determineStage(
                prediction: prediction,
                symptomScore: symptomScore,
                confidence: confidence,
              );

              final riskLevel = _getRiskLevel(healthScore);

              // Update the scan document
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('scans')
                  .doc(scanId)
                  .update({
                'enhancedStaging': stage,
                'healthScore': healthScore.round(),
                'riskLevel': riskLevel,
                'migratedAt': FieldValue.serverTimestamp(),
                'migrationVersion': '1.0',
              });

              userEnhanced++;
              scansEnhanced++;

              print(
                  '      ✅ $eye | $scanDate | $stage | ${healthScore.round()}% | $riskLevel');
            } catch (e) {
              userErrored++;
              scansErrored++;
              print('      ❌ Error processing scan $scanId: $e');
            }
          }

          // User summary
          print('   📈 User summary:');
          print('      Enhanced: $userEnhanced');
          print('      Skipped: $userSkipped');
          print('      Errors: $userErrored\n');
        } catch (e) {
          print('   ❌ Error processing user $userId: $e\n');
          scansErrored++;
        }
      }

      // Final summary
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      print('');
      print('🎉 ========================================');
      print('🎉 MIGRATION COMPLETED SUCCESSFULLY');
      print('🎉 ========================================');
      print('📊 Final Statistics:');
      print('   Total Users: $totalUsers');
      print('   Total Scans: $totalScans');
      print('   ✅ Enhanced: $scansEnhanced');
      print('   ⏭️  Skipped: $scansSkipped');
      print('   ❌ Errors: $scansErrored');
      print(
          '   ⏱️  Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
      print('🎉 ========================================\n');

      // Create admin notification
      await _createAdminNotification(
        totalUsers: totalUsers,
        totalScans: totalScans,
        enhanced: scansEnhanced,
        skipped: scansSkipped,
        errors: scansErrored,
        duration: duration,
      );
    } catch (e) {
      print('');
      print('❌ ========================================');
      print('❌ MIGRATION FAILED');
      print('❌ ========================================');
      print('Error: $e');
      print('❌ ========================================\n');

      // Create error notification
      await _createErrorNotification(e.toString());
    }
  }

  /// Helper: Get risk level from health score
  static String _getRiskLevel(double score) {
    if (score >= 80) return 'Low';
    if (score >= 60) return 'Moderate';
    return 'High';
  }

  /// Create admin notification for successful migration
  static Future<void> _createAdminNotification({
    required int totalUsers,
    required int totalScans,
    required int enhanced,
    required int skipped,
    required int errors,
    required Duration duration,
  }) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': 'migration_complete',
        'title': 'Scan Migration Completed',
        'message':
            'Successfully migrated $enhanced scans across $totalUsers users. '
                'Skipped: $skipped, Errors: $errors. Duration: ${duration.inMinutes}m',
        'priority': errors > 0 ? 'High' : 'Medium',
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'details': {
          'totalUsers': totalUsers,
          'totalScans': totalScans,
          'enhanced': enhanced,
          'skipped': skipped,
          'errors': errors,
          'durationSeconds': duration.inSeconds,
        },
      });
    } catch (e) {
      print('⚠️ Failed to create admin notification: $e');
    }
  }

  /// Create admin notification for migration error
  static Future<void> _createErrorNotification(String error) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': 'migration_error',
        'title': 'Scan Migration Failed',
        'message': 'Migration encountered an error: $error',
        'priority': 'High',
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('⚠️ Failed to create error notification: $e');
    }
  }
}
