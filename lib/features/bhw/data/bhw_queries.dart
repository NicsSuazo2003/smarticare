import '../../../data/models/bhw_patient_model.dart';

/// Pure queries on a list of patients. No state, no Firebase, no Hive.
/// Every function takes the list and returns a new list or value.
class BHWQueries {
  BHWQueries._();

  static List<BHWPatient> byRisk(List<BHWPatient> patients, String level) {
    final upper = level.toUpperCase();
    return patients.where((p) => p.riskLevel.toUpperCase() == upper).toList();
  }

  static List<BHWPatient> unsynced(List<BHWPatient> patients) =>
      patients.where((p) => !p.isSyncedToFirestore).toList();

  static List<BHWPatient> today(List<BHWPatient> patients) {
    final now = DateTime.now();
    return patients
        .where((p) =>
            p.scanDate.year == now.year &&
            p.scanDate.month == now.month &&
            p.scanDate.day == now.day)
        .toList();
  }

  static List<BHWPatient> thisWeek(List<BHWPatient> patients) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return patients.where((p) => p.scanDate.isAfter(weekStart)).toList();
  }

  static List<BHWPatient> search(List<BHWPatient> patients, String query) {
    if (query.isEmpty) return patients;
    final q = query.toLowerCase();
    return patients
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.barangay.toLowerCase().contains(q) ||
            p.id.toLowerCase().contains(q))
        .toList();
  }

  static List<BHWPatient> byBarangay(
      List<BHWPatient> patients, String barangay) {
    final b = barangay.toLowerCase();
    return patients.where((p) => p.barangay.toLowerCase() == b).toList();
  }

  static List<BHWPatient> byDateRange(
      List<BHWPatient> patients, DateTime start, DateTime end) {
    return patients
        .where((p) => p.scanDate.isAfter(start) && p.scanDate.isBefore(end))
        .toList();
  }

  static List<BHWPatient> historyFor(
      List<BHWPatient> patients, String patientName) {
    final n = patientName.toLowerCase();
    final result = patients.where((p) => p.name.toLowerCase() == n).toList()
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return result;
  }

  static Map<String, dynamic> statistics(List<BHWPatient> patients) {
    return {
      'total': patients.length,
      'today': today(patients).length,
      'thisWeek': thisWeek(patients).length,
      'low': byRisk(patients, 'LOW').length,
      'moderate': byRisk(patients, 'MODERATE').length,
      'high': byRisk(patients, 'HIGH').length,
      'critical': byRisk(patients, 'CRITICAL').length,
      'unsynced': unsynced(patients).length,
      'referred': patients.where((p) => p.referredToClinic).length,
    };
  }
}
