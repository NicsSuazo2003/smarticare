import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

class OTPService {
  static const int OTP_LENGTH = 6;
  static const int OTP_VALIDITY_MINUTES = 10;

  /// Generate a random 6-digit OTP
  static String generateOTP() {
    final random = Random.secure();
    return List.generate(OTP_LENGTH, (_) => random.nextInt(10)).join();
  }

  /// Store OTP in Firestore with expiration
  static Future<void> storeOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final expiresAt =
          DateTime.now().add(Duration(minutes: OTP_VALIDITY_MINUTES));

      await FirebaseFirestore.instance.collection('otp_codes').doc(email).set({
        'otp': otp,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'verified': false,
        'attempts': 0,
      });

      Logger.d('✅ OTP stored for $email');
    } catch (e) {
      Logger.d('❌ Error storing OTP: $e');
      rethrow;
    }
  }

  /// Verify OTP
  static Future<bool> verifyOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('otp_codes')
          .doc(email)
          .get();

      if (!doc.exists) {
        Logger.d('❌ No OTP found for $email');
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final storedOTP = data['otp'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final attempts = (data['attempts'] as int?) ?? 0;
      final verified = data['verified'] as bool;

      // Check if already verified
      if (verified) {
        Logger.d('⚠️ OTP already used');
        return false;
      }

      // Check if expired
      if (DateTime.now().isAfter(expiresAt)) {
        Logger.d('⚠️ OTP expired');
        await doc.reference.delete();
        return false;
      }

      // Check attempts limit (max 3 attempts)
      if (attempts >= 3) {
        Logger.d('⚠️ Too many OTP attempts');
        await doc.reference.delete();
        return false;
      }

      // Verify OTP
      if (storedOTP == otp) {
        // Mark as verified and delete
        await doc.reference.update({
          'verified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        // Delete after 1 minute to prevent reuse
        Future.delayed(Duration(minutes: 1), () async {
          await doc.reference.delete();
        });

        Logger.d('✅ OTP verified successfully');
        return true;
      } else {
        // Increment attempts
        await doc.reference.update({
          'attempts': attempts + 1,
        });
        Logger.d('❌ Invalid OTP');
        return false;
      }
    } catch (e) {
      Logger.d('❌ Error verifying OTP: $e');
      return false;
    }
  }

  /// Send OTP via email
  static Future<bool> sendOTPEmail({
    required String email,
    required String otp,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('email_queue').add({
        'to': email,
        'subject': 'Your SmartiCare Login Code',
        'body': '''
Hello,

Your verification code is: $otp

This code will expire in $OTP_VALIDITY_MINUTES minutes.

If you didn't request this code, please ignore this email or contact support.

Best regards,
SmartiCare Security Team
        ''',
        'type': 'otp',
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
        'otp': otp, // For debugging/testing only - remove in production
      });

      Logger.d('✅ OTP email queued for $email');
      return true;
    } catch (e) {
      Logger.d('❌ Error sending OTP email: $e');
      return false;
    }
  }

  /// Generate, store, and send OTP
  static Future<bool> sendOTP(String email) async {
    try {
      final otp = generateOTP();
      await storeOTP(email: email, otp: otp);
      final sent = await sendOTPEmail(email: email, otp: otp);
      return sent;
    } catch (e) {
      Logger.d('❌ Error in sendOTP: $e');
      return false;
    }
  }

  /// Clean up expired OTPs (call periodically)
  static Future<void> cleanupExpiredOTPs() async {
    try {
      final now = Timestamp.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('otp_codes')
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      Logger.d('✅ Cleaned up ${snapshot.docs.length} expired OTPs');
    } catch (e) {
      Logger.d('❌ Error cleaning up OTPs: $e');
    }
  }
}
