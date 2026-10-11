import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

class AssessmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Save assessment answers to Firestore
  Future<void> saveAssessmentAnswers(Map<String, String> answers) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Create an assessment document with answers and metadata
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('assessments')
          .add({
        'answers': answers,
        'timestamp': FieldValue.serverTimestamp(),
        'completed': true
      });
    } catch (e) {
      Logger.d('Error saving assessment: $e');
      rethrow;
    }
  }

  // Get user's assessment history
  Future<List<Map<String, dynamic>>> getAssessmentHistory() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('assessments')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      Logger.d('Error getting assessment history: $e');
      rethrow;
    }
  }
}
