import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application_1/Screens/scoring_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class EyeScanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScoringService _scoringService = ScoringService();

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> saveScanWithImage({
    required File imageFile,
    required String prediction,
    required double confidence,
    required String eye,
    required String scanDate,
    required double symptomScore,
    required String userId, // Get from FirebaseAuth.instance.currentUser.uid
  }) async {
    // 1. Upload image to Storage
    final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.png';
    final storageRef =
        FirebaseStorage.instance.ref().child('users/$userId/scans/$fileName');
    await storageRef.putFile(imageFile);

    // 2. Get download URL
    final imageUrl = await storageRef.getDownloadURL();

    // 3. Save metadata + imageUrl in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('scans')
        .add({
      'imageUrl': imageUrl,
      'prediction': prediction,
      'confidence': confidence,
      'eye': eye,
      'scanDate': scanDate,
      'symptomScore': symptomScore,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> saveScanResult({
    required File imageFile,
    required String prediction,
    required double confidence,
    required String eye,
    double? symptomScore, // optional, use if available
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // 1. Upload image to Firebase Storage
      final String fileName =
          'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/$currentUserId/scans/$fileName');
      await storageRef.putFile(imageFile);

      // 2. Get the download URL
      final String imageUrl = await storageRef.getDownloadURL();

      // 3. Calculate healthScore and riskLevel
      final double normalizedConfidence = confidence.clamp(0, 1);
      final double normalizedSymptomScore = (symptomScore ?? 0.5).clamp(0, 1);

      final double healthScore = _scoringService.calculateHealthScore(
        imageScore: normalizedConfidence,
        symptomScore: normalizedSymptomScore,
      );

      String riskLevel;
      if (healthScore >= 0.95) {
        riskLevel = "Very Low";
      } else if (healthScore >= 0.80) {
        riskLevel = "Low";
      } else if (healthScore >= 0.60) {
        riskLevel = "Medium";
      } else {
        riskLevel = "High";
      }

      // 4. Save scan metadata to Firestore
      final scanData = {
        'imageUrl': imageUrl,
        'prediction': prediction,
        'confidence': confidence,
        'eye': eye,
        'timestamp': FieldValue.serverTimestamp(),
        'fileName': fileName,
        'healthScore': healthScore,
        'riskLevel': riskLevel,
        if (symptomScore != null) 'symptomScore': symptomScore,
      };

      final DocumentReference scanRef = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('scans')
          .add(scanData);

      return scanRef.id;
    } catch (e) {
      print('Error saving scan result: $e');
      throw e;
    }
  }

  // Get user's scan history
  Future<List<Map<String, dynamic>>> getScanHistory() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error getting scan history: $e');
      throw e;
    }
  }
}
