import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/features/reminders/data/bhw_patient_repository.dart';
import 'package:flutter_application_1/features/reminders/data/bhw_queries.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/bhw_patient_model.dart';
import '../data/bhw_patient_repository.dart';
import '../data/bhw_queries.dart';

class BHWPatientProvider extends ChangeNotifier {
  BHWPatientProvider({BHWPatientRepository? repository})
      : _repo = repository ?? BHWPatientRepository();

  final BHWPatientRepository _repo;

  // ---- State ----
  List<BHWPatient> _patients = [];
  bool _isLoading = false;
  String? _errorMessage;
  BHWInfo? _currentBHW;

  // ---- Getters ----
  List<BHWPatient> get patients => List.unmodifiable(_patients);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get patientCount => _patients.length;

  List<BHWPatient> get lowRiskPatients => BHWQueries.byRisk(_patients, 'LOW');
  List<BHWPatient> get moderateRiskPatients =>
      BHWQueries.byRisk(_patients, 'MODERATE');
  List<BHWPatient> get highRiskPatients => BHWQueries.byRisk(_patients, 'HIGH');
  List<BHWPatient> get criticalRiskPatients =>
      BHWQueries.byRisk(_patients, 'CRITICAL');
  List<BHWPatient> get unsyncedPatients => BHWQueries.unsynced(_patients);
  int get unsyncedCount => unsyncedPatients.length;
  List<BHWPatient> get todaysScans => BHWQueries.today(_patients);
  List<BHWPatient> get thisWeeksScans => BHWQueries.thisWeek(_patients);

  // ---- Lifecycle ----
  Future<void> initialize() async {
    await _run(() async {
      _currentBHW = await _repo.loadCurrentBHW();
      _patients = await _repo.loadAll();
    }, errorPrefix: 'Failed to initialize');
  }

  Future<void> loadPatientsFromHive() => _run(() async {
        _patients = await _repo.loadAll();
      });

  // ---- CRUD ----
  Future<String> addPatient(BHWPatient patient) async {
    final withBHW = _attachBHWIfMissing(patient);
    await _run(() async {
      await _repo.save(withBHW);
      _patients.insert(0, withBHW);
    }, errorPrefix: 'Failed to add patient');
    _syncInBackground(withBHW);
    return withBHW.id;
  }

  Future<void> updatePatient(BHWPatient patient) async {
    final updated = patient.copyWith(
      updatedAt: DateTime.now(),
      isSyncedToFirestore: false,
    );
    await _run(() async {
      await _repo.update(updated);
      final i = _patients.indexWhere((p) => p.id == updated.id);
      if (i != -1) _patients[i] = updated;
    }, errorPrefix: 'Failed to update patient');
    _syncInBackground(updated);
  }

  Future<void> deletePatient(String patientId) async {
    final i = _patients.indexWhere((p) => p.id == patientId);
    if (i == -1) return;
    final patient = _patients[i];
    await _run(() async {
      await _repo.delete(patient);
      _patients.removeAt(i);
    }, errorPrefix: 'Failed to delete patient');
    await _repo.deleteFromFirestore(patient);
  }

  // ---- Sync ----
  Future<void> syncAllPatients() async {
    await _run(() async {
      for (final p in unsyncedPatients) {
        final synced = await _repo.syncToFirestore(p);
        _replaceInList(synced);
      }
    }, errorPrefix: 'Failed to sync patients');
  }

  // ---- Query passthroughs (delegating to pure functions) ----
  List<BHWPatient> searchPatients(String query) =>
      BHWQueries.search(_patients, query);

  List<BHWPatient> getPatientHistory(String name) =>
      BHWQueries.historyFor(_patients, name);

  List<BHWPatient> filterByBarangay(String barangay) =>
      BHWQueries.byBarangay(_patients, barangay);

  List<BHWPatient> filterByDateRange(DateTime start, DateTime end) =>
      BHWQueries.byDateRange(_patients, start, end);

  Map<String, dynamic> getStatistics() => BHWQueries.statistics(_patients);

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---- Helpers ----
  Future<void> _run(Future<void> Function() body,
      {required String errorPrefix}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await body();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '$errorPrefix: $e';
      Logger.d('$_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  BHWPatient _attachBHWIfMissing(BHWPatient patient) {
    if (patient.scannedByBHWId.isNotEmpty || _currentBHW == null)
      return patient;
    return patient.copyWith(
      scannedByBHWId: _currentBHW!.id,
      scannedByBHWName: _currentBHW!.name,
      scannedByBHWBarangay: _currentBHW!.barangay,
    );
  }

  void _syncInBackground(BHWPatient patient) {
    _repo.syncToFirestore(patient).then((synced) {
      _replaceInList(synced);
      notifyListeners();
    });
  }

  void _replaceInList(BHWPatient patient) {
    final i = _patients.indexWhere((p) => p.id == patient.id);
    if (i != -1) _patients[i] = patient;
  }

  @override
  void dispose() {
    _repo.closeBox();
    super.dispose();
  }
}
