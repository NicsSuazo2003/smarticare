import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application_1/features/symptom_assessment/services/scoring_service.dart';

class EyeScanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScoringService _scoringService = ScoringService();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> saveScanResult({
    required File imageFile,
    required String prediction,
    required double confidence,
    required String eye,
    required double symptomScore,
    required String scanId,
    String? assessmentId, // ✅ NEW
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    // 1) Upload image first
    String imageUrl = '';
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries && imageUrl.isEmpty) {
      try {
        imageUrl = await _uploadImageWithRetry(imageFile, scanId, retryCount);
        break;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }

    if (imageUrl.isEmpty) {
      throw Exception('Failed to upload image after $maxRetries attempts');
    }

    // 2) Compute health score + risk level
    final double computedHealthScore = _scoringService.calculateHealthScore(
      imageScore: confidence,
      symptomScore: symptomScore,
      prediction: prediction,
    );

    String riskLevel;
    if (computedHealthScore >= 80) {
      riskLevel = "Low";
    } else if (computedHealthScore >= 60) {
      riskLevel = "Moderate";
    } else {
      riskLevel = "High";
    }

    // 3) Save scan (✅ includes assessmentId)
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('scans')
        .doc(scanId)
        .set({
      'scanId': scanId,
      'assessmentId': assessmentId, // ✅ NEW (can be null)
      'imageUrl': imageUrl,
      'originalImage': imageUrl,
      'prediction': prediction,
      'confidence': confidence,
      'eye': eye,
      'symptomScore': symptomScore,
      'healthScore': computedHealthScore.round(),
      'riskLevel': riskLevel,
      'timestamp': FieldValue.serverTimestamp(),
      'scanDate': DateTime.now().toUtc().toString().split('.').first,
      'userId': userId,
      'uploadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return scanId;
  }

  Future<String> _uploadImageWithRetry(
    File imageFile,
    String scanId,
    int attemptNumber,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    final ref =
        _storage.ref().child('eye_scans').child(userId).child('$scanId.jpg');

    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final taskSnapshot = await uploadTask.timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw TimeoutException('Upload timeout after 5 minutes'),
    );

    final downloadUrl = await taskSnapshot.ref.getDownloadURL();
    if (!downloadUrl.startsWith('https://firebasestorage.googleapis.com/')) {
      throw Exception('Invalid Storage URL: $downloadUrl');
    }
    return downloadUrl;
  }

  Future<List<Map<String, dynamic>>> getScanHistory() async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final querySnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('scans')
        .orderBy('timestamp', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }
}
