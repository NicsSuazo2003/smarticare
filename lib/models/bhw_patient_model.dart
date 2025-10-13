import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'bhw_patient_model.g.dart';

@HiveType(typeId: 1)
class BHWPatient extends HiveObject {
  // ========== PATIENT IDENTIFICATION ==========
  @HiveField(0)
  String id; // Unique ID (format: DR-2025-0112-001)

  @HiveField(1)
  String name; // Full name

  @HiveField(2)
  int age; // Age in years

  @HiveField(3)
  String sex; // Male/Female

  @HiveField(4)
  String barangay; // Barangay name

  @HiveField(5)
  String? purok; // Optional: Purok/Sitio

  @HiveField(6)
  String? contactNumber; // Optional: Phone number

  @HiveField(7)
  bool isDiabetic; // Is patient diabetic?

  @HiveField(8)
  String diabeticStatus; // Yes/No/Unknown

  // ========== SYMPTOM ASSESSMENT ==========
  @HiveField(9)
  List<String> symptoms; // List of detected symptoms

  @HiveField(10)
  Map<String, bool> symptomResponses; // Question ID → Yes/No

  @HiveField(11)
  String? additionalNotes; // BHW's observations

  // ========== SCAN RESULTS ==========
  @HiveField(12)
  String riskLevel; // LOW, MODERATE, HIGH, CRITICAL

  @HiveField(13)
  String? scanImagePath; // Local path to eye scan image

  @HiveField(14)
  String? scanImageUrl; // Firestore URL after upload

  @HiveField(15)
  DateTime scanDate; // When scan was performed

  @HiveField(16)
  double? confidenceScore; // AI confidence (0.0 - 1.0)

  // ========== BHW INFORMATION ==========
  @HiveField(17)
  String scannedByBHWId; // BHW's Firebase user ID

  @HiveField(18)
  String scannedByBHWName; // BHW's display name

  @HiveField(19)
  String scannedByBHWBarangay; // BHW's assigned barangay

  // ========== RECOMMENDATION ==========
  @HiveField(20)
  String recommendation; // Action patient should take

  @HiveField(21)
  String urgency; // Routine/Urgent/Emergency

  @HiveField(22)
  bool referredToClinic; // Was patient referred?

  @HiveField(23)
  String? referredClinicName; // Which clinic

  // ========== SYNC STATUS ==========
  @HiveField(24)
  bool isSyncedToFirestore; // Uploaded to cloud?

  @HiveField(25)
  DateTime? lastSyncedAt; // When was last sync

  @HiveField(26)
  String? firestoreDocId; // Firestore document ID

  // ========== METADATA ==========
  @HiveField(27)
  DateTime createdAt; // When record was created locally

  @HiveField(28)
  DateTime updatedAt; // Last modified timestamp

  // ========== CONSTRUCTOR ==========
  BHWPatient({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.barangay,
    this.purok,
    this.contactNumber,
    required this.isDiabetic,
    required this.diabeticStatus,
    required this.symptoms,
    required this.symptomResponses,
    this.additionalNotes,
    required this.riskLevel,
    this.scanImagePath,
    this.scanImageUrl,
    required this.scanDate,
    this.confidenceScore,
    required this.scannedByBHWId,
    required this.scannedByBHWName,
    required this.scannedByBHWBarangay,
    required this.recommendation,
    required this.urgency,
    this.referredToClinic = false,
    this.referredClinicName,
    this.isSyncedToFirestore = false,
    this.lastSyncedAt,
    this.firestoreDocId,
    required this.createdAt,
    required this.updatedAt,
  });

  // ========== GENERATE UNIQUE ID ==========
  static String generateId(String barangayCode) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'DR-$dateStr-$barangayCode-$timeStr';
  }

  // ========== TO JSON (for Firestore) ==========
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'sex': sex,
      'barangay': barangay,
      'purok': purok,
      'contactNumber': contactNumber,
      'isDiabetic': isDiabetic,
      'diabeticStatus': diabeticStatus,
      'symptoms': symptoms,
      'symptomResponses': symptomResponses,
      'additionalNotes': additionalNotes,
      'riskLevel': riskLevel,
      'scanImagePath': scanImagePath,
      'scanImageUrl': scanImageUrl,
      'scanDate': scanDate.toIso8601String(),
      'confidenceScore': confidenceScore,
      'scannedByBHWId': scannedByBHWId,
      'scannedByBHWName': scannedByBHWName,
      'scannedByBHWBarangay': scannedByBHWBarangay,
      'recommendation': recommendation,
      'urgency': urgency,
      'referredToClinic': referredToClinic,
      'referredClinicName': referredClinicName,
      'isSyncedToFirestore': isSyncedToFirestore,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'firestoreDocId': firestoreDocId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // ========== FROM JSON (from Firestore) ==========
  factory BHWPatient.fromJson(Map<String, dynamic> json) {
    return BHWPatient(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      sex: json['sex'] ?? '',
      barangay: json['barangay'] ?? '',
      purok: json['purok'],
      contactNumber: json['contactNumber'],
      isDiabetic: json['isDiabetic'] ?? false,
      diabeticStatus: json['diabeticStatus'] ?? 'Unknown',
      symptoms: List<String>.from(json['symptoms'] ?? []),
      symptomResponses: Map<String, bool>.from(json['symptomResponses'] ?? {}),
      additionalNotes: json['additionalNotes'],
      riskLevel: json['riskLevel'] ?? 'UNKNOWN',
      scanImagePath: json['scanImagePath'],
      scanImageUrl: json['scanImageUrl'],
      scanDate: json['scanDate'] != null
          ? DateTime.parse(json['scanDate'])
          : DateTime.now(),
      confidenceScore: json['confidenceScore']?.toDouble(),
      scannedByBHWId: json['scannedByBHWId'] ?? '',
      scannedByBHWName: json['scannedByBHWName'] ?? '',
      scannedByBHWBarangay: json['scannedByBHWBarangay'] ?? '',
      recommendation: json['recommendation'] ?? '',
      urgency: json['urgency'] ?? 'Routine',
      referredToClinic: json['referredToClinic'] ?? false,
      referredClinicName: json['referredClinicName'],
      isSyncedToFirestore: json['isSyncedToFirestore'] ?? false,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'])
          : null,
      firestoreDocId: json['firestoreDocId'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  // ========== HELPER METHODS ==========

  // Get risk color
  Color getRiskColor() {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return const Color(0xFF4CAF50); // Green
      case 'MODERATE':
        return const Color(0xFFFFA726); // Orange
      case 'HIGH':
        return const Color(0xFFEF5350); // Red
      case 'CRITICAL':
        return const Color(0xFFB71C1C); // Dark Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  // Get risk icon
  IconData getRiskIcon() {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return Icons.check_circle;
      case 'MODERATE':
        return Icons.warning;
      case 'HIGH':
        return Icons.error;
      case 'CRITICAL':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  // Get urgency color
  Color getUrgencyColor() {
    switch (urgency.toLowerCase()) {
      case 'routine':
        return const Color(0xFF4CAF50);
      case 'urgent':
        return const Color(0xFFFFA726);
      case 'emergency':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  // Copy with method for updates
  BHWPatient copyWith({
    String? id,
    String? name,
    int? age,
    String? sex,
    String? barangay,
    String? purok,
    String? contactNumber,
    bool? isDiabetic,
    String? diabeticStatus,
    List<String>? symptoms,
    Map<String, bool>? symptomResponses,
    String? additionalNotes,
    String? riskLevel,
    String? scanImagePath,
    String? scanImageUrl,
    DateTime? scanDate,
    double? confidenceScore,
    String? scannedByBHWId,
    String? scannedByBHWName,
    String? scannedByBHWBarangay,
    String? recommendation,
    String? urgency,
    bool? referredToClinic,
    String? referredClinicName,
    bool? isSyncedToFirestore,
    DateTime? lastSyncedAt,
    String? firestoreDocId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BHWPatient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      barangay: barangay ?? this.barangay,
      purok: purok ?? this.purok,
      contactNumber: contactNumber ?? this.contactNumber,
      isDiabetic: isDiabetic ?? this.isDiabetic,
      diabeticStatus: diabeticStatus ?? this.diabeticStatus,
      symptoms: symptoms ?? this.symptoms,
      symptomResponses: symptomResponses ?? this.symptomResponses,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      riskLevel: riskLevel ?? this.riskLevel,
      scanImagePath: scanImagePath ?? this.scanImagePath,
      scanImageUrl: scanImageUrl ?? this.scanImageUrl,
      scanDate: scanDate ?? this.scanDate,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      scannedByBHWId: scannedByBHWId ?? this.scannedByBHWId,
      scannedByBHWName: scannedByBHWName ?? this.scannedByBHWName,
      scannedByBHWBarangay: scannedByBHWBarangay ?? this.scannedByBHWBarangay,
      recommendation: recommendation ?? this.recommendation,
      urgency: urgency ?? this.urgency,
      referredToClinic: referredToClinic ?? this.referredToClinic,
      referredClinicName: referredClinicName ?? this.referredClinicName,
      isSyncedToFirestore: isSyncedToFirestore ?? this.isSyncedToFirestore,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      firestoreDocId: firestoreDocId ?? this.firestoreDocId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
