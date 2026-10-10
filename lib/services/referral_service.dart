import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralCheckResult {
  final bool shouldRefer;
  final List<String> triggeredReasons;
  final String riskLevel;

  ReferralCheckResult({
    required this.shouldRefer,
    required this.triggeredReasons,
    required this.riskLevel,
  });
}

class ReferralService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if ANY referral trigger is met
  static Future<ReferralCheckResult> checkReferralTriggers({
    required String userId,
    required String email,
    required String userName,
    required String prediction,
    required double confidence,
    required String eye,
    required double symptomScore,
    required double healthScore,
    required String scanId,
  }) async {
    final triggeredReasons = <String>[];
    bool shouldRefer = false;

    try {
      print('🔵 Checking referral triggers for user: $userId');

      // ✅ MOVED UP: Check for existing pending referral FIRST
      final existingReferral = await _checkExistingPendingReferral(userId, eye);
      if (existingReferral) {
        print('⚠️ User already has a pending referral for $eye - skipping');
        return ReferralCheckResult(
          shouldRefer: false,
          triggeredReasons: ['Existing pending referral found'],
          riskLevel: _getRiskLevel(healthScore),
        );
      }

      // Trigger 1: High Confidence in Cataract Detection
      final isCataract = !prediction.toLowerCase().contains('normal') &&
          !prediction.toLowerCase().contains('no cataract');

      if (isCataract && confidence > 0.85) {
        triggeredReasons.add(
            'High confidence cataract detection (${(confidence * 100).toStringAsFixed(0)}%)');
        shouldRefer = true;
        print('✅ Trigger 1 HIT: High Confidence Cataract');
      }

      // Trigger 2:  Worsening Condition
      final previousScan = await _getPreviousScan(userId, eye);
      if (previousScan != null) {
        final previousRisk = previousScan['riskLevel'] ?? 'Unknown';
        final currentRisk = _getRiskLevel(healthScore);

        if (_isWorsening(previousRisk, currentRisk)) {
          triggeredReasons
              .add('Condition worsened:  $previousRisk → $currentRisk');
          shouldRefer = true;
          print('✅ Trigger 2 HIT: Worsening Condition');
        }
      }

      // Trigger 3: High Risk (Health Score < 60)
      if (healthScore < 60) {
        triggeredReasons
            .add('High risk score (${healthScore.toStringAsFixed(0)}%)');
        shouldRefer = true;
        print('✅ Trigger 3 HIT:  High Risk Score');
      }

      // Trigger 4: Consecutive High Risk Scans
      final consecutiveHighRisk = await _checkConsecutiveHighRisk(userId, eye);
      if (consecutiveHighRisk) {
        triggeredReasons.add('Multiple consecutive high-risk scans detected');
        shouldRefer = true;
        print('✅ Trigger 4 HIT:  Consecutive High Risk');
      }

      // Trigger 5: Advanced Stage Detection
      if (prediction.toLowerCase().contains('mature') ||
          prediction.toLowerCase().contains('advanced')) {
        triggeredReasons.add('Advanced cataract stage detected');
        shouldRefer = true;
        print('✅ Trigger 5 HIT: Advanced Stage');
      }

      // Trigger 6: Multiple Symptoms
      if (symptomScore > 0.7) {
        triggeredReasons.add(
            'Multiple symptoms reported (Score: ${(symptomScore * 100).toStringAsFixed(0)}%)');
        shouldRefer = true;
        print('✅ Trigger 6 HIT: Many Symptoms');
      }

      final riskLevel = _getRiskLevel(healthScore);
      print(
          '📊 Final Decision - Should Refer: $shouldRefer, Risk:  $riskLevel');

      return ReferralCheckResult(
        shouldRefer: shouldRefer,
        triggeredReasons: triggeredReasons,
        riskLevel: riskLevel,
      );
    } catch (e) {
      print('❌ Error checking referral triggers:  $e');
      rethrow;
    }
  }

  /// Check for existing pending referral
  static Future<bool> _checkExistingPendingReferral(
      String userId, String eye) async {
    try {
      // Check appointments collection
      final appointmentSnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .where('status', isEqualTo: 'Pending')
          .get();

      if (appointmentSnapshot.docs.isNotEmpty) {
        return true;
      }

      // Check referrals collection
      final referralSnapshot = await _firestore
          .collection('referrals')
          .where('userId', isEqualTo: userId)
          .where('eye', isEqualTo: eye)
          .where('status', isEqualTo: 'Pending')
          .get();

      return referralSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('⚠️ Error checking existing referral: $e');
      return false;
    }
  }

  /// Create referral and appointment entry
  static Future<String> createReferral({
    required String userId,
    required String email,
    required String userName,
    required String eye,
    required String stage,
    required double healthScore,
    required String scanId,
    required ReferralCheckResult checkResult,
  }) async {
    try {
      print('🎯 Creating referral for user: $userId');

      final batch = _firestore.batch();

      // 1. Create referral document
      final referralDoc = _firestore.collection('referrals').doc();
      final referralId = referralDoc.id;

      batch.set(referralDoc, {
        'referralId': referralId,
        'userId': userId,
        'email': email,
        'userName': userName,
        'eye': eye,
        'stage': stage,
        'healthScore': healthScore.round(),
        'riskLevel': checkResult.riskLevel,
        'scanId': scanId,
        'triggeredReasons': checkResult.triggeredReasons,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'clinicId': null,
        'clinicName': null,
        'appointmentDate': null,
        'appointmentTime': null,
      });

      // 2. Create corresponding appointment entry for admin panel
      final appointmentDoc = _firestore.collection('appointments').doc();
      final appointmentId = appointmentDoc.id;

      batch.set(appointmentDoc, {
        'appointmentId': appointmentId,
        'referralId': referralId,
        'patientId': userId, // ✅ Consistent with admin expectations
        'patientName': userName,
        'patientEmail': email,
        'clinicId': '',
        'clinicName': '',
        'date': '',
        'time': '',
        'status': 'Pending',
        'type': 'Cataract Referral',
        'notes': _buildReferralNotes(checkResult, stage, eye, healthScore),
        'eye': eye,
        'stage': stage,
        'healthScore': healthScore.round(),
        'riskLevel': checkResult.riskLevel,
        'scanId': scanId,
        'triggeredReasons': checkResult.triggeredReasons,
        'autoCreated': true, // ✅ Flag for admin to identify
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      print('✅ Referral created:  $referralId');
      print('✅ Appointment created: $appointmentId');

      // Send notifications
      await _sendNotifications(
        userId: userId,
        userName: userName,
        referralId: referralId,
        appointmentId: appointmentId,
        checkResult: checkResult,
        eye: eye,
        stage: stage,
      );

      // Log action
      await _logReferralAction(
        userId: userId,
        action: 'Referral auto-created',
        details: 'Triggers: ${checkResult.triggeredReasons.join(", ")}',
        scanId: scanId,
      );

      return referralId;
    } catch (e) {
      print('❌ Error creating referral: $e');
      rethrow;
    }
  }

  static String _buildReferralNotes(
    ReferralCheckResult checkResult,
    String stage,
    String eye,
    double healthScore,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('🔴 AUTO-GENERATED REFERRAL');
    buffer.writeln('');
    buffer.writeln('Eye: $eye');
    buffer.writeln('Stage: $stage');
    buffer.writeln('Health Score: ${healthScore.round()}%');
    buffer.writeln('Risk Level: ${checkResult.riskLevel}');
    buffer.writeln('');
    buffer.writeln('Triggered Reasons:');
    for (var reason in checkResult.triggeredReasons) {
      buffer.writeln('• $reason');
    }
    return buffer.toString();
  }

  static Future<Map<String, dynamic>?> _getPreviousScan(
      String userId, String eye) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('scans')
          .where('eye', isEqualTo: eye)
          .orderBy('timestamp', descending: true)
          .limit(2)
          .get();

      if (snapshot.docs.length >= 2) {
        return snapshot.docs[1].data();
      }
      return null;
    } catch (e) {
      print('⚠️ Error fetching previous scan:  $e');
      return null;
    }
  }

  static Future<bool> _checkConsecutiveHighRisk(
      String userId, String eye) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('scans')
          .where('eye', isEqualTo: eye)
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      if (snapshot.docs.length < 2) return false;

      int highRiskCount = 0;
      for (var doc in snapshot.docs.take(2)) {
        final healthScore = (doc['healthScore'] as num?)?.toDouble() ?? 100;
        if (healthScore < 60) highRiskCount++;
      }

      return highRiskCount >= 2;
    } catch (e) {
      print('⚠️ Error checking consecutive high risk: $e');
      return false;
    }
  }

  static bool _isWorsening(String previousRisk, String currentRisk) {
    const riskOrder = {'Low': 0, 'Moderate': 1, 'High': 2};
    final prevScore = riskOrder[previousRisk] ?? 0;
    final currScore = riskOrder[currentRisk] ?? 0;
    return currScore > prevScore;
  }

  static String _getRiskLevel(double healthScore) {
    if (healthScore >= 80) return 'Low';
    if (healthScore >= 60) return 'Moderate';
    return 'High';
  }

  static Future<void> _sendNotifications({
    required String userId,
    required String userName,
    required String referralId,
    required String appointmentId,
    required ReferralCheckResult checkResult,
    required String eye,
    required String stage,
  }) async {
    try {
      // User notification
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'referral_created',
        'title': 'Referral Created',
        'message': 'A referral has been created for your $eye ($stage). '
            'Our team will assign you to a clinic shortly.',
        'referralId': referralId,
        'appointmentId': appointmentId,
        'riskLevel': checkResult.riskLevel,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Admin notification
      await _firestore.collection('admin_notifications').add({
        'type': 'referral_pending_assignment',
        'title': '🔴 New Referral - Clinic Assignment Needed',
        'message': '$userName needs clinic assignment.\n'
            'Eye: $eye | Stage: $stage | Risk: ${checkResult.riskLevel}',
        'priority': checkResult.riskLevel == 'High' ? 'urgent' : 'normal',
        'referralId': referralId,
        'appointmentId': appointmentId,
        'userId': userId,
        'userName': userName,
        'eye': eye,
        'stage': stage,
        'triggers': checkResult.triggeredReasons,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'isRead': false,
      });

      print('✅ Notifications sent');
    } catch (e) {
      print('⚠️ Error sending notifications: $e');
    }
  }

  static Future<void> _logReferralAction({
    required String userId,
    required String action,
    required String details,
    required String scanId,
  }) async {
    try {
      await _firestore.collection('audit_logs').add({
        'userId': userId,
        'action': action,
        'details': details,
        'scanId': scanId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ Error logging action: $e');
    }
  }
}
