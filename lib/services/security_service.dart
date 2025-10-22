import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecurityService {
  static const int MAX_FAILED_ATTEMPTS = 5;
  static const int LOCKOUT_MINUTES = 15;

  /// Check if account is currently locked
  static Future<bool> isAccountLocked(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('security_logs')
          .doc(email)
          .get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final lockedUntil = (data['lockedUntil'] as Timestamp?)?.toDate();

      if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
        return true;
      }

      // ✅ Unlock if time has passed
      if (lockedUntil != null && DateTime.now().isAfter(lockedUntil)) {
        await resetFailedAttempts(email);
      }

      return false;
    } catch (e) {
      print('❌ Error checking account lock: $e');
      return false;
    }
  }

  /// Record a failed login attempt
  static Future<void> recordFailedAttempt(String email) async {
    try {
      final doc =
          FirebaseFirestore.instance.collection('security_logs').doc(email);

      final docSnapshot = await doc.get();

      if (!docSnapshot.exists) {
        // First attempt
        await doc.set({
          'email': email,
          'failedAttempts': 1,
          'lastAttempt': FieldValue.serverTimestamp(),
          'lockedUntil': null,
          'isLocked': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = docSnapshot.data() as Map<String, dynamic>;
        int currentAttempts = (data['failedAttempts'] as int?) ?? 0;
        currentAttempts++;

        if (currentAttempts >= MAX_FAILED_ATTEMPTS) {
          // Lock account
          final lockUntil =
              DateTime.now().add(Duration(minutes: LOCKOUT_MINUTES));
          await doc.update({
            'failedAttempts': currentAttempts,
            'lastAttempt': FieldValue.serverTimestamp(),
            'lockedUntil': lockUntil,
            'isLocked': true,
          });

          // ✅ Log security event
          await logSecurityEvent(
            action: 'account_locked',
            email: email,
            details: 'Account locked after $currentAttempts failed attempts',
            severity: 'HIGH',
          );

          return;
        }

        await doc.update({
          'failedAttempts': currentAttempts,
          'lastAttempt': FieldValue.serverTimestamp(),
        });
      }

      // ✅ Log each failed attempt
      await logSecurityEvent(
        action: 'failed_login_attempt',
        email: email,
        details: 'Failed login attempt recorded',
        severity: 'MEDIUM',
      );
    } catch (e) {
      print('❌ Error recording failed attempt: $e');
    }
  }

  /// Reset failed attempts on successful login
  static Future<void> resetFailedAttempts(String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('security_logs')
          .doc(email)
          .update({
        'failedAttempts': 0,
        'lockedUntil': null,
        'isLocked': false,
        'lastSuccessfulLogin': FieldValue.serverTimestamp(),
      });

      await logSecurityEvent(
        action: 'login_successful',
        email: email,
        details: 'Successful login',
        severity: 'LOW',
      );
    } catch (e) {
      print('❌ Error resetting failed attempts: $e');
    }
  }

  /// Get remaining lockout time in minutes
  static Future<int> getRemainingLockoutMinutes(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('security_logs')
          .doc(email)
          .get();

      if (!doc.exists) return 0;

      final data = doc.data() as Map<String, dynamic>;
      final lockedUntil = (data['lockedUntil'] as Timestamp?)?.toDate();

      if (lockedUntil == null) return 0;

      final remaining = lockedUntil.difference(DateTime.now()).inMinutes;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      print('❌ Error getting lockout time: $e');
      return 0;
    }
  }

  /// Get remaining failed attempts
  static Future<int> getRemainingAttempts(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('security_logs')
          .doc(email)
          .get();

      if (!doc.exists) return MAX_FAILED_ATTEMPTS;

      final data = doc.data() as Map<String, dynamic>;
      int failedAttempts = (data['failedAttempts'] as int?) ?? 0;

      return MAX_FAILED_ATTEMPTS - failedAttempts;
    } catch (e) {
      print('❌ Error getting remaining attempts: $e');
      return MAX_FAILED_ATTEMPTS;
    }
  }

  /// Log security events for compliance
  static Future<void> logSecurityEvent({
    required String action,
    required String email,
    required String details,
    required String severity, // LOW, MEDIUM, HIGH, CRITICAL
    String? scanId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('security_audit_logs').add({
        'action': action,
        'email': email,
        'details': details,
        'severity': severity,
        'timestamp': FieldValue.serverTimestamp(),
        'scanId': scanId,
      });

      print('✅ Security event logged: $action');
    } catch (e) {
      print('❌ Error logging security event: $e');
    }
  }

  /// Send security alert email (queued for Cloud Function processing)
  static Future<void> sendSecurityAlert({
    required String email,
    required String subject,
    required String body,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('email_queue').add({
        'to': email,
        'subject': subject,
        'body': body,
        'type': 'security_alert',
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      print('✅ Security alert queued for $email');
    } catch (e) {
      print('❌ Error queuing security alert: $e');
    }
  }

  /// Check 2FA status for user
  static Future<bool> is2FAEnabled(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['twoFactorEnabled'] ?? false;
    } catch (e) {
      print('❌ Error checking 2FA status: $e');
      return false;
    }
  }

  /// Enable 2FA for user
  static Future<void> enable2FA(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'twoFactorEnabled': true,
        'twoFactorEnabledAt': FieldValue.serverTimestamp(),
      });

      await logSecurityEvent(
        action: 'two_factor_enabled',
        email: '', // Will be fetched from user context
        details: 'User enabled two-factor authentication',
        severity: 'LOW',
      );

      print('✅ 2FA enabled for user $userId');
    } catch (e) {
      print('❌ Error enabling 2FA: $e');
    }
  }

  /// Disable 2FA for user
  static Future<void> disable2FA(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'twoFactorEnabled': false,
      });

      await logSecurityEvent(
        action: 'two_factor_disabled',
        email: '',
        details: 'User disabled two-factor authentication',
        severity: 'LOW',
      );

      print('✅ 2FA disabled for user $userId');
    } catch (e) {
      print('❌ Error disabling 2FA: $e');
    }
  }
}
