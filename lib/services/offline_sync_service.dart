import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  // ✅ Save scan result offline (will sync later)
  Future<void> saveScanOffline(Map<String, dynamic> scanData) async {
    final scansBox = await Hive.openBox('scansBox');
    final syncQueue = await Hive.openBox('syncQueueBox');

    final scanId = scanData['scanId'];
    await scansBox.put(scanId, scanData);

    // Add to sync queue
    await syncQueue.put(scanId, {
      'type': 'scan',
      'data': scanData,
      'timestamp': DateTime.now().toIso8601String(),
    });

    print('✅ Scan saved offline: $scanId');
  }

  // ✅ Get all scans (online + offline)
  Future<List<Map<String, dynamic>>> getAllScans() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final scansBox = await Hive.openBox('scansBox');
    List<Map<String, dynamic>> allScans = [];

    // Get offline scans
    for (var key in scansBox.keys) {
      final scanData = scansBox.get(key);
      if (scanData is Map) {
        allScans.add(Map<String, dynamic>.from(scanData));
      }
    }

    // Try to get Firestore scans if online
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .get(const GetOptions(source: Source.cache)); // ✅ Try cache first

      for (var doc in querySnapshot.docs) {
        allScans.add({...doc.data(), 'id': doc.id});
      }
    } catch (e) {
      print('Using offline scans only: $e');
    }

    return allScans;
  }

  // ✅ Sync all pending data when online
  Future<void> syncAllPendingData() async {
    final syncQueue = await Hive.openBox('syncQueueBox');
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print('⚠️ No user logged in, cannot sync');
      return;
    }

    for (var key in syncQueue.keys) {
      try {
        final item = syncQueue.get(key);
        if (item == null) continue;

        final type = item['type'];
        final data = item['data'];

        if (type == 'scan') {
          // Upload scan to Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('scans')
              .doc(data['scanId'])
              .set(data, SetOptions(merge: true));

          print('✅ Synced scan: ${data['scanId']}');
        }

        // Remove from queue after successful sync
        await syncQueue.delete(key);
      } catch (e) {
        print('❌ Error syncing item $key: $e');
      }
    }

    print('✅ All data synced');
  }
}
