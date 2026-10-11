import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/logger.dart';

/// Owns the Firestore query for the current user's audit log.
class ActivityLogRepository {
  ActivityLogRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Returns the raw documents for the current user, newest first.
  /// Empty list if not signed in.
  Future<List<Map<String, dynamic>>> fetchRawActivities() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('audit_logs')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    Logger.d('Fetched ${snapshot.docs.length} logs for userId=${user.uid}');
    return snapshot.docs.map((d) => d.data()).toList();
  }
}
