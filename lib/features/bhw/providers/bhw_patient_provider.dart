import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../data/models/bhw_patient_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class BHWPatientProvider extends ChangeNotifier {
  // ========== DATA STORAGE ==========
  List<BHWPatient> _patients = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Hive box reference
  Box<BHWPatient>? _bhwPatientsBox;

  // Current BHW info
  String? _currentBHWId;
  String? _currentBHWName;
  String? _currentBHWBarangay;

  // ========== GETTERS ==========
  List<BHWPatient> get patients => _patients;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get patientCount => _patients.length;

  // Get patients by risk level
  List<BHWPatient> get lowRiskPatients =>
      _patients.where((p) => p.riskLevel.toUpperCase() == 'LOW').toList();

  List<BHWPatient> get moderateRiskPatients =>
      _patients.where((p) => p.riskLevel.toUpperCase() == 'MODERATE').toList();

  List<BHWPatient> get highRiskPatients =>
      _patients.where((p) => p.riskLevel.toUpperCase() == 'HIGH').toList();

  List<BHWPatient> get criticalRiskPatients =>
      _patients.where((p) => p.riskLevel.toUpperCase() == 'CRITICAL').toList();

  // Get unsynced patients
  List<BHWPatient> get unsyncedPatients =>
      _patients.where((p) => !p.isSyncedToFirestore).toList();

  int get unsyncedCount => unsyncedPatients.length;

  // Get today's scans
  List<BHWPatient> get todaysScans {
    final now = DateTime.now();
    return _patients.where((p) {
      return p.scanDate.year == now.year &&
          p.scanDate.month == now.month &&
          p.scanDate.day == now.day;
    }).toList();
  }

  // Get this week's scans
  List<BHWPatient> get thisWeeksScans {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _patients.where((p) => p.scanDate.isAfter(weekStart)).toList();
  }

  // ========== INITIALIZATION ==========
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get current BHW info
      await _loadBHWInfo();

      // Open Hive box
      _bhwPatientsBox = await Hive.openBox<BHWPatient>('bhwPatientsBox');

      // Load patients from Hive
      await loadPatientsFromHive();

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
      print('BHWPatientProvider initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load current BHW info from Firebase
  Future<void> _loadBHWInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          _currentBHWId = user.uid;
          _currentBHWName = data?['name'] ?? data?['displayName'] ?? 'BHW';
          _currentBHWBarangay = data?['barangay'] ?? 'Unknown';
        }
      }
    } catch (e) {
      print('Error loading BHW info: $e');
    }
  }

  // ========== LOAD FROM HIVE (OFFLINE) ==========
  Future<void> loadPatientsFromHive() async {
    try {
      if (_bhwPatientsBox == null) {
        _bhwPatientsBox = await Hive.openBox<BHWPatient>('bhwPatientsBox');
      }

      _patients = _bhwPatientsBox!.values.toList();

      // Sort by scan date (newest first)
      _patients.sort((a, b) => b.scanDate.compareTo(a.scanDate));

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load patients: $e';
      print('Error loading from Hive: $e');
    }
  }

  // ========== ADD NEW PATIENT ==========
  Future<String> addPatient(BHWPatient patient) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Ensure BHW info is set
      if (patient.scannedByBHWId.isEmpty && _currentBHWId != null) {
        patient = patient.copyWith(
          scannedByBHWId: _currentBHWId!,
          scannedByBHWName: _currentBHWName ?? 'BHW',
          scannedByBHWBarangay: _currentBHWBarangay ?? 'Unknown',
        );
      }

      // Save to Hive
      await _bhwPatientsBox?.add(patient);

      // Add to local list
      _patients.insert(0, patient); // Add to beginning

      _errorMessage = null;
      notifyListeners();

      // Try to sync to Firestore (but don't block)
      _syncPatientToFirestore(patient);

      return patient.id;
    } catch (e) {
      _errorMessage = 'Failed to add patient: $e';
      print('Error adding patient: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== UPDATE PATIENT ==========
  Future<void> updatePatient(BHWPatient patient) async {
    try {
      // Update in Hive
      await patient.save();

      // Update in local list
      final index = _patients.indexWhere((p) => p.id == patient.id);
      if (index != -1) {
        _patients[index] = patient.copyWith(
          updatedAt: DateTime.now(),
          isSyncedToFirestore: false, // Mark for re-sync
        );
      }

      notifyListeners();

      // Try to sync to Firestore
      _syncPatientToFirestore(patient);
    } catch (e) {
      _errorMessage = 'Failed to update patient: $e';
      print('Error updating patient: $e');
    }
  }

  // ========== DELETE PATIENT ==========
  Future<void> deletePatient(String patientId) async {
    try {
      final patient = _patients.firstWhere((p) => p.id == patientId);

      // Delete from Hive
      await patient.delete();

      // Remove from local list
      _patients.removeWhere((p) => p.id == patientId);

      notifyListeners();

      // Delete from Firestore if synced
      if (patient.isSyncedToFirestore && patient.firestoreDocId != null) {
        await FirebaseFirestore.instance
            .collection('bhw_scans')
            .doc(patient.firestoreDocId)
            .delete();
      }
    } catch (e) {
      _errorMessage = 'Failed to delete patient: $e';
      print('Error deleting patient: $e');
    }
  }

  // ========== SYNC TO FIRESTORE ==========
  Future<void> _syncPatientToFirestore(BHWPatient patient) async {
    try {
      // Upload scan image if exists
      String? imageUrl;
      if (patient.scanImagePath != null && patient.scanImagePath!.isNotEmpty) {
        imageUrl = await _uploadScanImage(patient.scanImagePath!, patient.id);
      }

      // Prepare data for Firestore
      final data = patient.toJson();
      if (imageUrl != null) {
        data['scanImageUrl'] = imageUrl;
      }

      // Upload to Firestore
      DocumentReference docRef;
      if (patient.firestoreDocId != null) {
        // Update existing document
        docRef = FirebaseFirestore.instance
            .collection('bhw_scans')
            .doc(patient.firestoreDocId);
        await docRef.update(data);
      } else {
        // Create new document
        docRef =
            await FirebaseFirestore.instance.collection('bhw_scans').add(data);
      }

      // Update patient with sync info
      final updatedPatient = patient.copyWith(
        isSyncedToFirestore: true,
        lastSyncedAt: DateTime.now(),
        firestoreDocId: docRef.id,
        scanImageUrl: imageUrl,
      );

      await updatedPatient.save();

      // Update local list
      final index = _patients.indexWhere((p) => p.id == patient.id);
      if (index != -1) {
        _patients[index] = updatedPatient;
        notifyListeners();
      }

      print('✅ Patient synced to Firestore: ${patient.id}');
    } catch (e) {
      print('❌ Failed to sync patient to Firestore: $e');
      // Don't throw - allow offline operation
    }
  }

  // Upload scan image to Firebase Storage
  Future<String?> _uploadScanImage(String imagePath, String patientId) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('bhw_scans')
          .child('$patientId.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading scan image: $e');
      return null;
    }
  }

  // ========== SYNC ALL UNSYNCED PATIENTS ==========
  Future<void> syncAllPatients() async {
    try {
      _isLoading = true;
      notifyListeners();

      final unsynced = unsyncedPatients;

      for (var patient in unsynced) {
        await _syncPatientToFirestore(patient);
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to sync patients: $e';
      print('Error syncing all patients: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== SEARCH PATIENTS ==========
  List<BHWPatient> searchPatients(String query) {
    if (query.isEmpty) return _patients;

    final lowerQuery = query.toLowerCase();
    return _patients.where((patient) {
      return patient.name.toLowerCase().contains(lowerQuery) ||
          patient.barangay.toLowerCase().contains(lowerQuery) ||
          patient.id.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ========== GET PATIENT HISTORY ==========
  List<BHWPatient> getPatientHistory(String patientName) {
    return _patients
        .where((p) => p.name.toLowerCase() == patientName.toLowerCase())
        .toList()
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
  }

  // ========== FILTER BY BARANGAY ==========
  List<BHWPatient> filterByBarangay(String barangay) {
    return _patients
        .where((p) => p.barangay.toLowerCase() == barangay.toLowerCase())
        .toList();
  }

  // ========== FILTER BY DATE RANGE ==========
  List<BHWPatient> filterByDateRange(DateTime start, DateTime end) {
    return _patients.where((p) {
      return p.scanDate.isAfter(start) && p.scanDate.isBefore(end);
    }).toList();
  }

  // ========== GET STATISTICS ==========
  Map<String, dynamic> getStatistics() {
    return {
      'total': patientCount,
      'today': todaysScans.length,
      'thisWeek': thisWeeksScans.length,
      'low': lowRiskPatients.length,
      'moderate': moderateRiskPatients.length,
      'high': highRiskPatients.length,
      'critical': criticalRiskPatients.length,
      'unsynced': unsyncedCount,
      'referred': _patients.where((p) => p.referredToClinic).length,
    };
  }

  // ========== CLEAR ERROR ==========
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ========== DISPOSE ==========
  @override
  void dispose() {
    _bhwPatientsBox?.close();
    super.dispose();
  }
}
