import 'package:cloud_firestore/cloud_firestore.dart';
import 'data/models/reminder_model.dart';
import 'package:hive/hive.dart';

class ReminderSyncService {
  final Box<Reminder> _reminderBox = Hive.box<Reminder>('remindersBox');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Push unsynced reminders to Firestore
  Future<void> syncToFirestore(String userId) async {
    final unsynced = _reminderBox.values.where((r) => r.needsSync).toList();
    for (final r in unsynced) {
      await _firestore.collection('reminders').doc(r.id).set(r.toJson());
      r.needsSync = false;
      await r.save();
    }
  }

  /// Pull latest reminders from Firestore and update local
  Future<void> syncFromFirestore(String userId) async {
    final snapshot = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in snapshot.docs) {
      final remote = Reminder.fromJson(doc.data());
      final local = _reminderBox.get(remote.id);
      if (local == null || remote.lastUpdated.isAfter(local.lastUpdated)) {
        _reminderBox.put(remote.id, remote);
      }
    }
  }

  /// Full sync
  Future<void> syncAll(String userId) async {
    await syncToFirestore(userId);
    await syncFromFirestore(userId);
  }
}
