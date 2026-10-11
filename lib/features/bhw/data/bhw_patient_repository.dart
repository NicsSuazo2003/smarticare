import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/bhw_patient_model.dart';

/// Owns everything BHW-patient-data-related:
/// Hive persistence, Firestore sync, Storage uploads, and BHW identity lookup.
///
/// The provider and UI never touch Firebase or Hive directly.
class BHWPatientRepository {
  BHWPatientRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    Box<BHWPatient>? box,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _box = box;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  Box<BHWPatient>? _box;

  static const _boxName = 'bhwPatientsBox';
  static const _collection = 'bhw_scans';

  // ---------- Hive ----------

  Future<void> init() async {
    _box ??= await Hive.openBox<BHWPatient>(_boxName);
  }

  Future<List<BHWPatient>> loadAll() async {
    await init();
    final list = _box!.values.toList();
    list.sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return list;
  }

  Future<void> save(BHWPatient patient) async {
    await init();
    await _box!.add(patient);
  }

  Future<void> update(BHWPatient patient) async {
    await patient.save();
  }

  Future<void> delete(BHWPatient patient) async {
    await patient.delete();
  }

  Future<void> closeBox() async {
    await _box?.close();
    _box = null;
  }

  // ---------- BHW identity ----------

  Future<BHWInfo?> loadCurrentBHW() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      return BHWInfo(
        id: user.uid,
        name: (data['name'] ?? data['displayName'] ?? 'BHW') as String,
        barangay: (data['barangay'] ?? 'Unknown') as String,
      );
    } catch (e) {
      Logger.d('Error loading BHW info: $e');
      return null;
    }
  }

  // ---------- Firestore sync ----------

  /// Returns the updated patient (with sync metadata filled in), or the
  /// original if sync fails. Never throws — offline is a valid state.
  Future<BHWPatient> syncToFirestore(BHWPatient patient) async {
    try {
      String? imageUrl = patient.scanImageUrl;
      if (imageUrl == null &&
          patient.scanImagePath != null &&
          patient.scanImagePath!.isNotEmpty) {
        imageUrl = await _uploadScanImage(patient.scanImagePath!, patient.id);
      }

      final data = patient.toJson();
      if (imageUrl != null) data['scanImageUrl'] = imageUrl;

      final DocumentReference docRef;
      if (patient.firestoreDocId != null) {
        docRef = _firestore.collection(_collection).doc(patient.firestoreDocId);
        await docRef.update(data);
      } else {
        docRef = await _firestore.collection(_collection).add(data);
      }

      final updated = patient.copyWith(
        isSyncedToFirestore: true,
        lastSyncedAt: DateTime.now(),
        firestoreDocId: docRef.id,
        scanImageUrl: imageUrl,
      );
      await updated.save();

      Logger.d('✅ Synced patient ${patient.id} to Firestore');
      return updated;
    } catch (e) {
      Logger.d('❌ Sync failed for ${patient.id}: $e');
      return patient;
    }
  }

  Future<void> deleteFromFirestore(BHWPatient patient) async {
    if (!patient.isSyncedToFirestore || patient.firestoreDocId == null) return;
    try {
      await _firestore
          .collection(_collection)
          .doc(patient.firestoreDocId)
          .delete();
    } catch (e) {
      Logger.d('Error deleting from Firestore: $e');
    }
  }

  Future<String?> _uploadScanImage(String imagePath, String patientId) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final ref = _storage.ref().child('bhw_scans').child('$patientId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      Logger.d('Error uploading scan image: $e');
      return null;
    }
  }
}

/// Small value object for the current BHW's identity.
class BHWInfo {
  const BHWInfo({required this.id, required this.name, required this.barangay});
  final String id;
  final String name;
  final String barangay;
}
