import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application_1/Screens/scoring_service.dart';

class EyeScanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScoringService _scoringService = ScoringService();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Save scan result with health score and risk level
  /// ✅ FIXED: Ensures image is uploaded FIRST, then saved to Firestore
  Future<String> saveScanResult({
    required File imageFile,
    required String prediction,
    required double confidence,
    required String eye,
    required double symptomScore,
    required String scanId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    // ✅ STEP 1: Upload image FIRST with retry logic
    String imageUrl = '';
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries && imageUrl.isEmpty) {
      try {
        imageUrl = await _uploadImageWithRetry(imageFile, scanId, retryCount);
        print('✅ Image upload succeeded on attempt ${retryCount + 1}');
        break;
      } catch (e) {
        retryCount++;
        print('⚠️ Upload attempt ${retryCount} failed: $e');

        if (retryCount >= maxRetries) {
          print('❌ All upload attempts failed. Last error: $e');
          rethrow; // Don't save to Firestore if upload fails
        }

        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }

    if (imageUrl.isEmpty) {
      throw Exception('Failed to upload image after $maxRetries attempts');
    }

    // ✅ STEP 2: Calculate health score
    final double computedHealthScore = _scoringService.calculateHealthScore(
      imageScore: confidence,
      symptomScore: symptomScore,
      prediction: prediction,
    );

    // ✅ STEP 3: Determine risk level
    String riskLevel;
    if (computedHealthScore >= 80) {
      riskLevel = "Low";
    } else if (computedHealthScore >= 60) {
      riskLevel = "Moderate";
    } else {
      riskLevel = "High";
    }

    // ✅ STEP 4: Save to Firestore with confirmed Storage URL
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('scans')
          .doc(scanId)
          .set({
        'scanId': scanId,
        'imageUrl': imageUrl, // ✅ Now guaranteed to be Storage URL
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
        'uploadedAt': FieldValue.serverTimestamp(), // Track upload time
      }, SetOptions(merge: true));

      print('✅ Scan data saved to Firestore with Storage URL');
      return scanId;
    } catch (e) {
      print('❌ Failed to save scan to Firestore: $e');
      rethrow;
    }
  }

  /// Upload image with retry logic and better error handling
  /// ✅ FIXED: Returns only when upload is completely verified
  Future<String> _uploadImageWithRetry(
    File imageFile,
    String scanId,
    int attemptNumber,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    try {
      print('📤 Upload attempt ${attemptNumber + 1} - File: ${imageFile.path}');

      final fileSize = await imageFile.length();
      print('📁 File size: ${(fileSize / 1024).toStringAsFixed(1)} KB');

      if (fileSize == 0) {
        throw Exception('Image file is empty (0 bytes)');
      }

      if (fileSize > 50 * 1024 * 1024) {
        // 50MB limit
        throw Exception('Image file too large (max 50MB)');
      }

      // Create storage reference
      final ref =
          _storage.ref().child('eye_scans').child(userId).child('$scanId.jpg');

      print('📍 Storage path: ${ref.fullPath}');

      // Upload file
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'scanId': scanId,
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print(
            '📊 Upload progress: ${progress.toStringAsFixed(1)}% (${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes)');
      });

      // ✅ Wait for upload completion with timeout
      final taskSnapshot = await uploadTask.timeout(
        const Duration(minutes: 5), // Increased from 2 to 5 minutes
        onTimeout: () {
          throw TimeoutException('Upload timeout after 5 minutes');
        },
      );

      print('✅ Upload completed: ${taskSnapshot.state}');

      // ✅ Verify upload by getting download URL
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      if (downloadUrl.isEmpty) {
        throw Exception('Download URL is empty after upload');
      }

      if (!downloadUrl.startsWith('https://firebasestorage.googleapis.com/')) {
        throw Exception('Invalid Storage URL: $downloadUrl');
      }

      print('✅ Download URL verified: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Upload error on attempt ${attemptNumber + 1}: $e');
      rethrow;
    }
  }

  /// Get user's scan history
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
      rethrow;
    }
  }
}
