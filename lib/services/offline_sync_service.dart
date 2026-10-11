import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/features/symptom_assessment/services/scoring_service.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter_application_1/core/utils/logger.dart';

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
        Logger.d('⚠️ Cannot save scan: scanId is null or empty');
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

      Logger.d('✅ Scan saved offline: $scanId');
      Logger.d('📁 Image path: ${hiveCompatibleScanData['imageUrl']}');
    } catch (e) {
      Logger.d('❌ Error saving scan offline: $e');
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
      hiveCompatibleAssessmentData['synced'] = false;

      // Add to sync queue
      await syncQueue.put(assessmentId, {
        'type': 'assessment',
        'data': hiveCompatibleAssessmentData,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      });

      Logger.d('✅ Assessment saved offline: $assessmentId');
    } catch (e) {
      Logger.d('❌ Error saving assessment offline: $e');
      rethrow;
    }
  }

  /// Upload offline image to Firebase Storage
  Future<String?> _uploadOfflineImageToStorage(
      String localImagePath, String scanId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        Logger.d('❌ Cannot upload: User not logged in');
        return null;
      }

      final imageFile = File(localImagePath);
      if (!await imageFile.exists()) {
        Logger.d('❌ Local image file not found: $localImagePath');
        return null;
      }

      final fileSize = await imageFile.length();
      Logger.d('📤 Uploading offline image to Firebase Storage...');
      Logger.d('📁 Local path: $localImagePath');
      Logger.d('📁 File size: $fileSize bytes');
      Logger.d('📁 Scan ID: $scanId');

      // Create Storage reference
      final ref =
          _storage.ref().child('eye_scans').child(userId).child('$scanId.jpg');

      // Upload file with progress monitoring
      final uploadTask = ref.putFile(imageFile);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        Logger.d('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for upload completion
      final taskSnapshot = await uploadTask;
      final storageUrl = await taskSnapshot.ref.getDownloadURL();

      Logger.d('✅ Offline image uploaded successfully!');
      Logger.d('🔗 Storage URL: $storageUrl');
      return storageUrl;
    } catch (e) {
      Logger.d('❌ Error uploading offline image: $e');
      Logger.d('📁 Failed file: $localImagePath');
      return null;
    }
  }

  /// Get all scans (online + offline)
  Future<List<Map<String, dynamic>>> getAllScans() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Logger.d('⚠️ No user logged in for getAllScans');
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
          Logger.d('⚠️ Error reading offline scan $key: $e');
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

        Logger.d(
            '✅ Retrieved ${querySnapshot.docs.length} scans from Firestore cache');
      } catch (e) {
        Logger.d('⚠️ Using offline scans only: $e');
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

      Logger.d('✅ Total scans retrieved: ${result.length}');
      return result;
    } catch (e) {
      Logger.d('❌ Error in getAllScans: $e');
      return [];
    }
  }

  /// Sync all pending data when online
  Future<void> syncAllPendingData() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        Logger.d('⚠️ No user logged in, cannot sync');
        return;
      }

      final totalItems = syncQueue.keys.length;
      if (totalItems == 0) {
        Logger.d('✅ No items to sync');
        return;
      }

      Logger.d('🔄 Starting sync of $totalItems items...');
      Logger.d('👤 User: ${user.email} (${user.uid})');
      Logger.d('📅 Sync started: ${DateTime.now().toUtc().toIso8601String()}');

      int syncedCount = 0;
      int failedCount = 0;

      for (var key in List.from(syncQueue.keys)) {
        try {
          final item = syncQueue.get(key);
          if (item == null) {
            Logger.d('⚠️ Sync item $key is null, removing from queue');
            await syncQueue.delete(key);
            continue;
          }

          final type = item['type'];
          final data = item['data'];
          final retryCount = item['retryCount'] ?? 0;

          Logger.d('\n🔄 Syncing $type: $key (attempt ${retryCount + 1})');

          if (type == 'scan') {
            await _syncScanData(key, data, user.uid, syncQueue);
            syncedCount++;
          } else if (type == 'assessment') {
            await _syncAssessmentData(key, data, user.uid, syncQueue);
            syncedCount++;
          } else {
            Logger.d('⚠️ Unknown sync type: $type');
            await syncQueue.delete(key);
          }
        } catch (e) {
          Logger.d('❌ Error syncing item $key: $e');
          failedCount++;

          // Update retry count
          try {
            final item = syncQueue.get(key);
            if (item != null) {
              item['retryCount'] = (item['retryCount'] ?? 0) + 1;

              // Remove from queue after 3 failed attempts
              if (item['retryCount'] >= 3) {
                Logger.d('🗑️ Removing $key after 3 failed attempts');
                await syncQueue.delete(key);
              } else {
                await syncQueue.put(key, item);
              }
            }
          } catch (retryError) {
            Logger.d('⚠️ Error updating retry count for $key: $retryError');
          }
        }
      }

      Logger.d('\n✅ Sync completed:');
      Logger.d('   📊 Total items: $totalItems');
      Logger.d('   ✅ Synced: $syncedCount');
      Logger.d('   ❌ Failed: $failedCount');
      Logger.d('   📤 Remaining in queue: ${syncQueue.keys.length}');
      Logger.d('   📅 Sync finished: ${DateTime.now().toUtc().toIso8601String()}');
    } catch (e) {
      Logger.d('❌ Error in syncAllPendingData: $e');
      rethrow;
    }
  }

  /// Sync individual scan data
  Future<void> _syncScanData(String key, Map<String, dynamic> data,
      String userId, Box syncQueue) async {
    final onlineData = Map<String, dynamic>.from(data);
    final currentImageUrl = onlineData['imageUrl'];
    final scanId = onlineData['scanId'];

    Logger.d('🔍 Syncing scan: $scanId');
    Logger.d('📁 Current imageUrl: $currentImageUrl');

    // Check if imageUrl is a local path that needs uploading
    if (currentImageUrl != null &&
        currentImageUrl.startsWith('/data/user/0/')) {
      Logger.d('📤 Local image detected, uploading to Firebase Storage...');

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

        Logger.d('✅ Image uploaded successfully');
        Logger.d('🔗 New Storage URL: $storageUrl');
      } else {
        Logger.d('⚠️ Failed to upload image, will keep local path');
        // Don't fail the entire sync if image upload fails
      }
    } else if (currentImageUrl != null &&
        currentImageUrl.startsWith('https://')) {
      Logger.d('✅ Image already has Storage URL');
    } else {
      Logger.d('⚠️ Unexpected imageUrl format: $currentImageUrl');
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

    Logger.d('✅ Scan data saved to Firestore: $scanId');

    // Clean up local image file after successful sync (only if we uploaded it)
    if (currentImageUrl != null &&
        currentImageUrl.startsWith('/data/user/0/') &&
        onlineData['imageUrl'] != currentImageUrl) {
      try {
        final localFile = File(currentImageUrl);
        if (await localFile.exists()) {
          await localFile.delete();
          Logger.d('🗑️ Deleted local image file: $currentImageUrl');
        }
      } catch (e) {
        Logger.d('⚠️ Could not delete local file: $e');
      }
    }

    await syncQueue.delete(key);
    Logger.d('✅ Removed $key from sync queue');
  }

  /// Sync individual assessment data
  Future<void> _syncAssessmentData(String key, Map<String, dynamic> data,
      String userId, Box syncQueue) async {
    final onlineData = Map<String, dynamic>.from(data);

    
    if (onlineData['synced'] == true) {
      Logger.d('⚠️ Assessment $key already synced, skipping');
      await syncQueue.delete(key);
      return;
    }

    // Remove offline-specific fields
    onlineData.remove('offline');
    onlineData.remove('createdOffline');

    // Convert timestamp for Firestore
    onlineData['timestamp'] = FieldValue.serverTimestamp();
    onlineData['synced'] = true;
    onlineData['syncedAt'] = FieldValue.serverTimestamp();
    onlineData['syncedFrom'] = 'offline';

   
    Logger.d('🔄 Syncing assessment from offline queue: $key');

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('assessments')
          .add(onlineData);

      Logger.d('✅ Assessment synced: $key');

      // ✅ FIX 3: Only delete after successful sync
      await syncQueue.delete(key);
      Logger.d('✅ Removed $key from sync queue');
    } catch (e) {
      Logger.d('❌ Failed to sync assessment $key: $e');
      // ✅ FIX 4: Don't delete on failure, let retry happen
      rethrow;
    }
  }

  /// Check sync status and pending items
  Future<void> checkPendingSync() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      final pendingCount = syncQueue.keys.length;

      Logger.d('\n📤 SYNC STATUS CHECK');
      Logger.d('==================');

      if (pendingCount > 0) {
        Logger.d('📊 $pendingCount items pending sync');

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

              Logger.d(
                  '   📸 Scan: ${scanData['scanId']} (local image: $isLocal, retries: $retryCount)');
            } else if (type == 'assessment') {
              assessmentCount++;
              Logger.d('   📋 Assessment: $key (retries: $retryCount)');
            }
          }
        }

        Logger.d('\n📊 Summary:');
        Logger.d('   🔹 Scans: $scanCount');
        Logger.d('   🔹 Assessments: $assessmentCount');
        Logger.d('   🔹 Local images: $localImageCount');
      } else {
        Logger.d('✅ No items pending sync');
      }

      Logger.d('📅 Check time: ${DateTime.now().toUtc().toIso8601String()}');
      Logger.d('==================\n');
    } catch (e) {
      Logger.d('❌ Error checking pending sync: $e');
    }
  }

  /// Debug method to print sync queue contents
  Future<void> debugPrintQueue() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      Logger.d('\n📦 SYNC QUEUE DEBUG');
      Logger.d('===================');
      Logger.d('Total items: ${syncQueue.keys.length}');

      for (var key in syncQueue.keys) {
        final item = syncQueue.get(key);
        if (item != null) {
          Logger.d('\n🔑 Key: $key');
          Logger.d('   📝 Type: ${item['type']}');
          Logger.d('   🔄 Retry Count: ${item['retryCount'] ?? 0}');
          Logger.d('   📅 Created: ${item['timestamp']}');

          if (item['type'] == 'scan' && item['data'] != null) {
            final scanData = item['data'];
            Logger.d('   📸 Scan ID: ${scanData['scanId']}');
            Logger.d('   🖼️  Image URL: ${scanData['imageUrl']}');
            Logger.d('   👁️  Eye: ${scanData['eye']}');
            Logger.d('   🔍 Prediction: ${scanData['prediction']}');
          }
        } else {
          Logger.d('🔑 Key: $key (NULL DATA)');
        }
      }
      Logger.d('===================\n');
    } catch (e) {
      Logger.d('❌ Error in debugPrintQueue: $e');
    }
  }

  /// Clean up invalid items from sync queue
  Future<void> cleanupInvalidItems() async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      final keysToDelete = <dynamic>[];

      Logger.d('🧹 Starting cleanup of sync queue...');

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
              Logger.d('🗑️ Found invalid scan with empty scanId: $key');
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
                  Logger.d('🗑️ Found old sync item ($daysDiff days): $key');
                  keysToDelete.add(key);
                }
              } catch (e) {
                Logger.d('⚠️ Invalid timestamp format in $key: $timestamp');
              }
            }
          }

          // Check retry count
          final retryCount = item['retryCount'] ?? 0;
          if (retryCount >= 5) {
            Logger.d('🗑️ Found item with too many retries ($retryCount): $key');
            keysToDelete.add(key);
          }
        } catch (e) {
          Logger.d('⚠️ Error checking item $key: $e');
          keysToDelete.add(key);
        }
      }

      // Delete invalid items
      for (var key in keysToDelete) {
        await syncQueue.delete(key);
        Logger.d('✅ Deleted invalid/old item: $key');
      }

      Logger.d('🧹 Cleanup complete: ${keysToDelete.length} items removed');
      Logger.d('📊 Remaining items: ${syncQueue.keys.length}');
    } catch (e) {
      Logger.d('❌ Error in cleanupInvalidItems: $e');
    }
  }

  /// Force sync a specific scan by scanId
  Future<bool> forceSyncScan(String scanId) async {
    try {
      final syncQueue = await Hive.openBox('syncQueueBox');
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        Logger.d('❌ No user logged in for force sync');
        return false;
      }

      final item = syncQueue.get(scanId);
      if (item == null || item['type'] != 'scan') {
        Logger.d('❌ Scan $scanId not found in sync queue');
        return false;
      }

      Logger.d('🔄 Force syncing scan: $scanId');
      await _syncScanData(scanId, item['data'], user.uid, syncQueue);
      Logger.d('✅ Force sync completed for: $scanId');
      return true;
    } catch (e) {
      Logger.d('❌ Error in force sync: $e');
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
      Logger.d('❌ Error getting sync stats: $e');
      return {};
    }
  }
}
