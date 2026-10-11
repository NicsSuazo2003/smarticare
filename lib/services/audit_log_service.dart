import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogService {
  static Future<void> logAction({
    required String action,
    required String details,
    String? scanId,
    String? appointmentId,
    String? assessmentId, // <--- add this
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'action': action,
      'details': details,
      'userId': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      if (scanId != null) 'scanId': scanId,
      if (appointmentId != null) 'appointmentId': appointmentId,
      if (assessmentId != null) 'assessmentId': assessmentId, // <--- add this
    };

    await FirebaseFirestore.instance.collection('audit_logs').add(data);
  }
}
