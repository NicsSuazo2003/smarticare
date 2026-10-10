import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecurityService {
  static const int MAX_FAILED_ATTEMPTS = 5;
  static const int LOCKOUT_MINUTES = 5;
  // Add this method to the SecurityService class

  /// Rate limit password reset requests
  /// Limits: 3 attempts per email per hour
  static Future<bool> canRequestPasswordReset(String email) async {
    try {
      final now = DateTime.now();
      final doc = await FirebaseFirestore.instance
          .collection('password_reset_limits')
          .doc(email.toLowerCase())
          .get();

      if (!doc.exists) {
        // First request, allow it
        await FirebaseFirestore.instance
            .collection('password_reset_limits')
            .doc(email.toLowerCase())
            .set({
          'email': email.toLowerCase(),
          'attempts': 1,
          'windowStart': Timestamp.fromDate(now),
          'lastAttempt': Timestamp.fromDate(now),
        });
        return true;
      }

      final data = doc.data()!;
      final attempts = (data['attempts'] as int?) ?? 0;
      final windowStart = (data['windowStart'] as Timestamp?)?.toDate() ?? now;
      final lastAttempt = (data['lastAttempt'] as Timestamp?)?.toDate() ?? now;

      // Check if window has expired (1 hour)
      if (now.difference(windowStart).inHours >= 1) {
        // Reset window
        await doc.reference.update({
          'attempts': 1,
          'windowStart': Timestamp.fromDate(now),
          'lastAttempt': Timestamp.fromDate(now),
        });
        return true;
      }

      // Check if too many attempts within window
      if (attempts >= 3) {
        // Log suspicious activity
        await logSecurityEvent(
          action: 'password_reset_rate_limit_exceeded',
          email: email,
          details: 'User exceeded password reset rate limit',
          severity: 'MEDIUM',
        );
        return false;
      }

      // Check minimum time between requests (5 minutes)
      if (now.difference(lastAttempt).inMinutes < 5) {
        return false;
      }

      // Increment attempts
      await doc.reference.update({
        'attempts': attempts + 1,
        'lastAttempt': Timestamp.fromDate(now),
      });

      return true;
    } catch (e) {
      print('❌ Error checking password reset rate limit: $e');
      return false; // Fail secure - deny request on error
    }
  }

  /// Get remaining cooldown time for password reset
  static Future<Duration?> getPasswordResetCooldown(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('password_reset_limits')
          .doc(email.toLowerCase())
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final attempts = (data['attempts'] as int?) ?? 0;
      final windowStart = (data['windowStart'] as Timestamp?)?.toDate();
      final lastAttempt = (data['lastAttempt'] as Timestamp?)?.toDate();

      if (windowStart == null) return null;

      final now = DateTime.now();

      // If max attempts reached, return time until window expires
      if (attempts >= 3) {
        final windowEnd = windowStart.add(const Duration(hours: 1));
        if (now.isBefore(windowEnd)) {
          return windowEnd.difference(now);
        }
      }

      // Check minimum time between requests
      if (lastAttempt != null) {
        final nextAllowedTime = lastAttempt.add(const Duration(minutes: 5));
        if (now.isBefore(nextAllowedTime)) {
          return nextAllowedTime.difference(now);
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting password reset cooldown: $e');
      return null;
    }
  }

  /// Clean up expired password reset rate limits (call periodically)
  static Future<void> cleanupPasswordResetLimits() async {
    try {
      final oneHourAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 1)),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('password_reset_limits')
          .where('windowStart', isLessThan: oneHourAgo)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print(
          '✅ Cleaned up ${snapshot.docs.length} expired password reset limits');
    } catch (e) {
      print('❌ Error cleaning up password reset limits: $e');
    }
  }

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

  /// Detect and alert on suspicious activities
  static Future<void> checkSuspiciousActivity({
    required String email,
    required String action,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final now = DateTime.now();

      // Get recent activity for this user
      final recentActivity = await FirebaseFirestore.instance
          .collection('security_audit_logs')
          .where('email', isEqualTo: email)
          .where('timestamp',
              isGreaterThan:
                  Timestamp.fromDate(now.subtract(Duration(hours: 1))))
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final activities = recentActivity.docs;

      // Check for multiple failed attempts in short time
      final failedAttempts = activities
          .where((doc) => doc['action'] == 'failed_login_attempt')
          .length;

      if (failedAttempts >= 3) {
        await sendSecurityAlert(
          email: email,
          subject: 'Suspicious Activity Detected - SmartiCare',
          body:
              'Multiple failed login attempts detected for your account. If this was not you, please secure your account immediately.',
        );
      }

      // Log the current activity
      await logSecurityEvent(
        action: action,
        email: email,
        details: 'User activity: $action from IP: $ipAddress',
        severity: failedAttempts >= 2 ? 'MEDIUM' : 'LOW',
      );
    } catch (e) {
      print('❌ Error checking suspicious activity: $e');
    }
  }

  /// Check for new device/login location
  static Future<void> checkNewDeviceLogin({
    required String email,
    required String userId,
    String? deviceInfo,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final knownDevices = userData['knownDevices'] ?? [];

        if (!knownDevices.contains(deviceInfo)) {
          // New device detected
          await sendSecurityAlert(
            email: email,
            subject: 'New Login Device - SmartiCare',
            body:
                'A new device has been used to access your SmartiCare account. Device: $deviceInfo\n\nIf this was not you, please change your password immediately.',
          );

          // Add to known devices
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'knownDevices': FieldValue.arrayUnion([deviceInfo]),
          });

          await logSecurityEvent(
            action: 'new_device_login',
            email: email,
            details: 'Login from new device: $deviceInfo',
            severity: 'MEDIUM',
          );
        }
      }
    } catch (e) {
      print('❌ Error checking new device: $e');
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
            'lockedAt': FieldValue.serverTimestamp(),
          });

          // ✅ Log security event
          await logSecurityEvent(
            action: 'account_locked',
            email: email,
            details: 'Account locked after $currentAttempts failed attempts',
            severity: 'HIGH',
          );

          // ✅ Send alert email
          await sendSecurityAlert(
            email: email,
            subject: 'Security Alert: Your Account Was Locked',
            body: '''
Your SmartiCare account has been temporarily locked due to multiple failed login attempts.

Details:
- Failed Attempts: $currentAttempts
- Locked Until: ${lockUntil.toString()}
- Lockout Duration: $LOCKOUT_MINUTES minutes

If this wasn't you, please contact support immediately at support@smarticare.ph

Your SmartiCare Security Team
            ''',
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
        details: 'Successful login - failed attempts reset',
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

  /// Get number of failed attempts
  static Future<int> getFailedAttempts(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('security_logs')
          .doc(email)
          .get();

      if (!doc.exists) return 0;

      final data = doc.data() as Map<String, dynamic>;
      return (data['failedAttempts'] as int?) ?? 0;
    } catch (e) {
      print('❌ Error getting failed attempts: $e');
      return 0;
    }
  }

  /// Log security events for compliance
  static Future<void> logSecurityEvent({
    required String action,
    required String email,
    required String details,
    required String severity,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('security_audit_logs').add({
        'action': action,
        'email': email,
        'details': details,
        'severity': severity,
        'timestamp': FieldValue.serverTimestamp(),
        'userType': 'patient', // Distinguish from admin logs
      });

      print('✅ Security event logged: $action');
    } catch (e) {
      print('❌ Error logging security event: $e');
    }
  }

  /// Send security alert email
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

  /// Enable 2FA for user
  static Future<void> enable2FA(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'twoFactorEnabled': true,
        'twoFactorEnabledAt': FieldValue.serverTimestamp(),
      });

      await logSecurityEvent(
        action: 'two_factor_enabled',
        email: '',
        details: 'User enabled two-factor authentication',
        severity: 'LOW',
      );

      print('✅ 2FA enabled for user: $userId');
    } catch (e) {
      print('❌ Error enabling 2FA: $e');
    }
  }

  /// Get login activity for user
  static Future<List<Map<String, dynamic>>> getLoginActivity(
    String email, {
    int limit = 10,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('security_audit_logs')
          .where('email', isEqualTo: email)
          .where('action', isEqualTo: 'login_successful')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('❌ Error fetching login activity: $e');
      return [];
    }
  }
}
