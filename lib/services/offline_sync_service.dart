import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/Screens/scoring_service.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  // Firebase Storage reference
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Save scan result offline (will sync later)
  Future<void> saveScanOffline(Map<String, dynamic> scanData) async {
    try {
      final scansBox = await Hive.openBox('scansBox');
      final syncQueue = await Hive.openBox('syncQueueBox');

      // Create Hive-compatible scan data (remove FieldValue)
      final hiveCompatibleScanData = Map<String, dynamic>.from(scanData);
      // Replace FieldValue with regular timestamp for offline storage
      hiveCompatibleScanData['timestamp'] = DateTime.now().toUtc().toString();
      hiveCompatibleScanData['offline'] = true;
      hiveCompatibleScanData['createdOffline'] =
          DateTime.now().toIso8601String();

      final scanId = hiveCompatibleScanData['scanId'];
      if (scanId == null || scanId.toString().isEmpty) {
        print('⚠️ Cannot save scan: scanId is null or empty');
        return;
      }

      await scansBox.put(scanId, hiveCompatibleScanData);

      // Add to sync queue
      await syncQueue.put(scanId, {
        'type': 'scan',
        'data': hiveCompatibleScanData,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      });

      print('✅ Scan saved offline: $scanId');
      print('📁 Image path: ${hiveCompatibleScanData['imageUrl']}');
    } catch (e) {
      print('❌ Error saving scan offline: $e');
      rethrow;
    }
  }

  /// Save assessment result offline
  Future<void> saveAssessmentOffline(
      Map<String, dynamic> assessmentData) async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');

      // Generate unique assessment ID for offline storage
      final assessmentId =
          'assessment_${DateTime.now().millisecondsSinceEpoch}';

      // Create Hive-compatible assessment data
      final hiveCompatibleAssessmentData =
          Map<String, dynamic>.from(assessmentData);
      // Replace FieldValue with regular timestamp for offline storage
      hiveCompatibleAssessmentData['timestamp'] =
          DateTime.now().toUtc().toString();
      hiveCompatibleAssessmentData['offline'] = true;
      hiveCompatibleAssessmentData['createdOffline'] =
          DateTime.now().toIso8601String();

      // Add to sync queue
      await syncQueue.put(assessmentId, {
        'type': 'assessment',
        'data': hiveCompatibleAssessmentData,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      });

      print('✅ Assessment saved offline: $assessmentId');
    } catch (e) {
      print('❌ Error saving assessment offline: $e');
      rethrow;
    }
  }

  /// Upload offline image to Firebase Storage
  Future<String?> _uploadOfflineImageToStorage(
      String localImagePath, String scanId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('❌ Cannot upload: User not logged in');
        return null;
      }

      final imageFile = File(localImagePath);
      if (!await imageFile.exists()) {
        print('❌ Local image file not found: $localImagePath');
        return null;
      }

      final fileSize = await imageFile.length();
      print('📤 Uploading offline image to Firebase Storage...');
      print('📁 Local path: $localImagePath');
      print('📁 File size: $fileSize bytes');
      print('📁 Scan ID: $scanId');

      // Create Storage reference
      final ref =
          _storage.ref().child('eye_scans').child(userId).child('$scanId.jpg');

      // Upload file with progress monitoring
      final uploadTask = ref.putFile(imageFile);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for upload completion
      final taskSnapshot = await uploadTask;
      final storageUrl = await taskSnapshot.ref.getDownloadURL();

      print('✅ Offline image uploaded successfully!');
      print('🔗 Storage URL: $storageUrl');
      return storageUrl;
    } catch (e) {
      print('❌ Error uploading offline image: $e');
      print('📁 Failed file: $localImagePath');
      return null;
    }
  }

  /// Get all scans (online + offline)
  Future<List<Map<String, dynamic>>> getAllScans() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No user logged in for getAllScans');
        return [];
      }

      final scansBox = await Hive.openBox('scansBox');
      List<Map<String, dynamic>> allScans = [];

      // Get offline scans first
      for (var key in scansBox.keys) {
        try {
          final scanData = scansBox.get(key);
          if (scanData is Map) {
            final scanMap = Map<String, dynamic>.from(scanData);
            scanMap['source'] = 'offline';
            allScans.add(scanMap);
          }
        } catch (e) {
          print('⚠️ Error reading offline scan $key: $e');
        }
      }

      // Try to get Firestore scans if online
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('scans')
            .orderBy('timestamp', descending: true)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 5));

        for (var doc in querySnapshot.docs) {
          final scanData = doc.data();
          scanData['id'] = doc.id;
          scanData['source'] = 'firestore';
          allScans.add(scanData);
        }

        print(
            '✅ Retrieved ${querySnapshot.docs.length} scans from Firestore cache');
      } catch (e) {
        print('⚠️ Using offline scans only: $e');
      }

      // Remove duplicates (prefer Firestore version)
      final Map<String, Map<String, dynamic>> uniqueScans = {};
      for (var scan in allScans) {
        final scanId = scan['scanId'];
        if (scanId != null) {
          if (!uniqueScans.containsKey(scanId) ||
              scan['source'] == 'firestore') {
            uniqueScans[scanId] = scan;
          }
        }
      }

      final result = uniqueScans.values.toList();
      result.sort((a, b) {
        final aTime = a['timestamp']?.toString() ?? '';
        final bTime = b['timestamp']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });

      print('✅ Total scans retrieved: ${result.length}');
      return result;
    } catch (e) {
      print('❌ Error in getAllScans: $e');
      return [];
    }
  }

  /// Sync all pending data when online
  Future<void> syncAllPendingData() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('⚠️ No user logged in, cannot sync');
        return;
      }

      final totalItems = syncQueue.keys.length;
      if (totalItems == 0) {
        print('✅ No items to sync');
        return;
      }

      print('🔄 Starting sync of $totalItems items...');
      print('👤 User: ${user.email} (${user.uid})');
      print('📅 Sync started: ${DateTime.now().toUtc().toIso8601String()}');

      int syncedCount = 0;
      int failedCount = 0;

      for (var key in List.from(syncQueue.keys)) {
        try {
          final item = syncQueue.get(key);
          if (item == null) {
            print('⚠️ Sync item $key is null, removing from queue');
            await syncQueue.delete(key);
            continue;
          }

          final type = item['type'];
          final data = item['data'];
          final retryCount = item['retryCount'] ?? 0;

          print('\n🔄 Syncing $type: $key (attempt ${retryCount + 1})');

          if (type == 'scan') {
            await _syncScanData(key, data, user.uid, syncQueue);
            syncedCount++;
          } else if (type == 'assessment') {
            await _syncAssessmentData(key, data, user.uid, syncQueue);
            syncedCount++;
          } else {
            print('⚠️ Unknown sync type: $type');
            await syncQueue.delete(key);
          }
        } catch (e) {
          print('❌ Error syncing item $key: $e');
          failedCount++;

          // Update retry count
          try {
            final item = syncQueue.get(key);
            if (item != null) {
              item['retryCount'] = (item['retryCount'] ?? 0) + 1;

              // Remove from queue after 3 failed attempts
              if (item['retryCount'] >= 3) {
                print('🗑️ Removing $key after 3 failed attempts');
                await syncQueue.delete(key);
              } else {
                await syncQueue.put(key, item);
              }
            }
          } catch (retryError) {
            print('⚠️ Error updating retry count for $key: $retryError');
          }
        }
      }

      print('\n✅ Sync completed:');
      print('   📊 Total items: $totalItems');
      print('   ✅ Synced: $syncedCount');
      print('   ❌ Failed: $failedCount');
      print('   📤 Remaining in queue: ${syncQueue.keys.length}');
      print('   📅 Sync finished: ${DateTime.now().toUtc().toIso8601String()}');
    } catch (e) {
      print('❌ Error in syncAllPendingData: $e');
      rethrow;
    }
  }

  /// Sync individual scan data
  Future<void> _syncScanData(String key, Map<String, dynamic> data,
      String userId, Box syncQueue) async {
    final onlineData = Map<String, dynamic>.from(data);
    final currentImageUrl = onlineData['imageUrl'];
    final scanId = onlineData['scanId'];

    print('🔍 Syncing scan: $scanId');
    print('📁 Current imageUrl: $currentImageUrl');

    // Check if imageUrl is a local path that needs uploading
    if (currentImageUrl != null &&
        currentImageUrl.startsWith('/data/user/0/')) {
      print('📤 Local image detected, uploading to Firebase Storage...');

      // Upload image to Firebase Storage
      final storageUrl =
          await _uploadOfflineImageToStorage(currentImageUrl, scanId);

      if (storageUrl != null) {
        // Update with Storage URL
        onlineData['imageUrl'] = storageUrl;
        onlineData['originalImage'] = storageUrl;
        onlineData['synced'] = true;
        onlineData['syncedAt'] = FieldValue.serverTimestamp();
        onlineData['syncedFrom'] = 'offline';

        print('✅ Image uploaded successfully');
        print('🔗 New Storage URL: $storageUrl');
      } else {
        print('⚠️ Failed to upload image, will keep local path');
        // Don't fail the entire sync if image upload fails
      }
    } else if (currentImageUrl != null &&
        currentImageUrl.startsWith('https://')) {
      print('✅ Image already has Storage URL');
    } else {
      print('⚠️ Unexpected imageUrl format: $currentImageUrl');
    }

    // Always recompute healthScore and riskLevel based on the latest data
    final double? confidence = (onlineData['confidence'] as num?)?.toDouble();
    final double? symptomScore =
        (onlineData['symptomScore'] as num?)?.toDouble();
    final String? prediction = onlineData['prediction'] as String?;
    if (confidence != null && symptomScore != null && prediction != null) {
      final scoring = ScoringService();
      final healthScore = scoring
          .calculateHealthScore(
            imageScore: confidence,
            symptomScore: symptomScore,
            prediction: prediction,
          )
          .round();
      onlineData['healthScore'] = healthScore;

      // Correct riskLevel logic
      if (healthScore >= 80) {
        onlineData['riskLevel'] = "Low";
      } else if (healthScore >= 60) {
        onlineData['riskLevel'] = "Moderate";
      } else {
        onlineData['riskLevel'] = "High";
      }
    } else {
      onlineData['healthScore'] = null;
      onlineData['riskLevel'] = null;
    }

    // Remove offline-specific fields
    onlineData.remove('offline');
    onlineData.remove('createdOffline');

    // Convert timestamp for Firestore
    onlineData['timestamp'] = FieldValue.serverTimestamp();

    // Save to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('scans')
        .doc(scanId)
        .set(onlineData, SetOptions(merge: true));

    print('✅ Scan data saved to Firestore: $scanId');

    // Clean up local image file after successful sync (only if we uploaded it)
    if (currentImageUrl != null &&
        currentImageUrl.startsWith('/data/user/0/') &&
        onlineData['imageUrl'] != currentImageUrl) {
      try {
        final localFile = File(currentImageUrl);
        if (await localFile.exists()) {
          await localFile.delete();
          print('🗑️ Deleted local image file: $currentImageUrl');
        }
      } catch (e) {
        print('⚠️ Could not delete local file: $e');
      }
    }

    // Remove from sync queue
    await syncQueue.delete(key);
    print('✅ Removed $key from sync queue');
  }

  /// Sync individual assessment data
  Future<void> _syncAssessmentData(String key, Map<String, dynamic> data,
      String userId, Box syncQueue) async {
    final onlineData = Map<String, dynamic>.from(data);

    // Remove offline-specific fields
    onlineData.remove('offline');
    onlineData.remove('createdOffline');

    // Convert timestamp for Firestore
    onlineData['timestamp'] = FieldValue.serverTimestamp();
    onlineData['synced'] = true;
    onlineData['syncedAt'] = FieldValue.serverTimestamp();
    onlineData['syncedFrom'] = 'offline';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .add(onlineData);

    print('✅ Assessment synced: $key');

    // Remove from sync queue
    await syncQueue.delete(key);
  }

  /// Check sync status and pending items
  Future<void> checkPendingSync() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      final pendingCount = syncQueue.keys.length;

      print('\n📤 SYNC STATUS CHECK');
      print('==================');

      if (pendingCount > 0) {
        print('📊 $pendingCount items pending sync');

        int scanCount = 0;
        int assessmentCount = 0;
        int localImageCount = 0;

        for (var key in syncQueue.keys) {
          final item = syncQueue.get(key);
          if (item != null) {
            final type = item['type'];
            final retryCount = item['retryCount'] ?? 0;

            if (type == 'scan') {
              scanCount++;
              final scanData = item['data'];
              final imageUrl = scanData['imageUrl'];
              final isLocal = imageUrl?.startsWith('/data/user/0/') ?? false;
              if (isLocal) localImageCount++;

              print(
                  '   📸 Scan: ${scanData['scanId']} (local image: $isLocal, retries: $retryCount)');
            } else if (type == 'assessment') {
              assessmentCount++;
              print('   📋 Assessment: $key (retries: $retryCount)');
            }
          }
        }

        print('\n📊 Summary:');
        print('   🔹 Scans: $scanCount');
        print('   🔹 Assessments: $assessmentCount');
        print('   🔹 Local images: $localImageCount');
      } else {
        print('✅ No items pending sync');
      }

      print('📅 Check time: ${DateTime.now().toUtc().toIso8601String()}');
      print('==================\n');
    } catch (e) {
      print('❌ Error checking pending sync: $e');
    }
  }

  /// Debug method to print sync queue contents
  Future<void> debugPrintQueue() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      print('\n📦 SYNC QUEUE DEBUG');
      print('===================');
      print('Total items: ${syncQueue.keys.length}');

      for (var key in syncQueue.keys) {
        final item = syncQueue.get(key);
        if (item != null) {
          print('\n🔑 Key: $key');
          print('   📝 Type: ${item['type']}');
          print('   🔄 Retry Count: ${item['retryCount'] ?? 0}');
          print('   📅 Created: ${item['timestamp']}');

          if (item['type'] == 'scan' && item['data'] != null) {
            final scanData = item['data'];
            print('   📸 Scan ID: ${scanData['scanId']}');
            print('   🖼️  Image URL: ${scanData['imageUrl']}');
            print('   👁️  Eye: ${scanData['eye']}');
            print('   🔍 Prediction: ${scanData['prediction']}');
          }
        } else {
          print('🔑 Key: $key (NULL DATA)');
        }
      }
      print('===================\n');
    } catch (e) {
      print('❌ Error in debugPrintQueue: $e');
    }
  }

  /// Clean up invalid items from sync queue
  Future<void> cleanupInvalidItems() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      final keysToDelete = <dynamic>[];

      print('🧹 Starting cleanup of sync queue...');

      for (var key in syncQueue.keys) {
        try {
          final item = syncQueue.get(key);
          if (item == null) {
            keysToDelete.add(key);
            continue;
          }

          final type = item['type'];
          final data = item['data'];

          // Check for scans with empty scanId
          if (type == 'scan') {
            final scanId = data?['scanId'];
            if (scanId == null || scanId.toString().isEmpty) {
              print('🗑️ Found invalid scan with empty scanId: $key');
              keysToDelete.add(key);
              continue;
            }

            // Check for very old items (older than 7 days)
            final timestamp = item['timestamp'];
            if (timestamp != null) {
              try {
                final itemDate = DateTime.parse(timestamp);
                final now = DateTime.now();
                final daysDiff = now.difference(itemDate).inDays;

                if (daysDiff > 7) {
                  print('🗑️ Found old sync item (${daysDiff} days): $key');
                  keysToDelete.add(key);
                }
              } catch (e) {
                print('⚠️ Invalid timestamp format in $key: $timestamp');
              }
            }
          }

          // Check retry count
          final retryCount = item['retryCount'] ?? 0;
          if (retryCount >= 5) {
            print('🗑️ Found item with too many retries ($retryCount): $key');
            keysToDelete.add(key);
          }
        } catch (e) {
          print('⚠️ Error checking item $key: $e');
          keysToDelete.add(key);
        }
      }

      // Delete invalid items
      for (var key in keysToDelete) {
        await syncQueue.delete(key);
        print('✅ Deleted invalid/old item: $key');
      }

      print('🧹 Cleanup complete: ${keysToDelete.length} items removed');
      print('📊 Remaining items: ${syncQueue.keys.length}');
    } catch (e) {
      print('❌ Error in cleanupInvalidItems: $e');
    }
  }

  /// Force sync a specific scan by scanId
  Future<bool> forceSyncScan(String scanId) async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('❌ No user logged in for force sync');
        return false;
      }

      final item = syncQueue.get(scanId);
      if (item == null || item['type'] != 'scan') {
        print('❌ Scan $scanId not found in sync queue');
        return false;
      }

      print('🔄 Force syncing scan: $scanId');
      await _syncScanData(scanId, item['data'], user.uid, syncQueue);
      print('✅ Force sync completed for: $scanId');
      return true;
    } catch (e) {
      print('❌ Error in force sync: $e');
      return false;
    }
  }

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');

      int totalPending = syncQueue.keys.length;
      int scansCount = 0;
      int assessmentsCount = 0;
      int localImagesCount = 0;
      int highRetryCount = 0;

      for (var key in syncQueue.keys) {
        final item = syncQueue.get(key);
        if (item != null) {
          final type = item['type'];
          final retryCount = item['retryCount'] ?? 0;

          if (type == 'scan') {
            scansCount++;
            final scanData = item['data'];
            final imageUrl = scanData?['imageUrl'];
            if (imageUrl?.startsWith('/data/user/0/') == true) {
              localImagesCount++;
            }
          } else if (type == 'assessment') {
            assessmentsCount++;
          }

          if (retryCount >= 2) {
            highRetryCount++;
          }
        }
      }

      return {
        'totalPending': totalPending,
        'scansCount': scansCount,
        'assessmentsCount': assessmentsCount,
        'localImagesCount': localImagesCount,
        'highRetryCount': highRetryCount,
      };
    } catch (e) {
      print('❌ Error getting sync stats: $e');
      return {};
    }
  }
}
