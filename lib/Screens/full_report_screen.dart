import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Screens/scoring_service.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:flutter_application_1/services/staging_service.dart';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'find_clinics_screen.dart';
import 'reminder_screen.dart';

class FullReportScreen extends StatefulWidget {
  final String? scanId;
  const FullReportScreen({super.key, this.scanId});

  @override
  State<FullReportScreen> createState() => _FullReportScreenState();
}

class _FullReportScreenState extends State<FullReportScreen> {
  bool _isLoading = true;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _assessment;
  Map<String, dynamic>? _scan;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  int? _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;

    try {
      final birth = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - birth.year;

      // Adjust age if birthday hasn't occurred this year
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }

      return age;
    } catch (e) {
      print('Error parsing birth date: $e');
      return null;
    }
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final userId = user.uid;

    // Fetch user profile
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final profile = userDoc.data();

    DocumentSnapshot? scanDoc;
    Map<String, dynamic>? scan;

    // Fetch scan: specific if scanId, else latest
    if (widget.scanId != null) {
      scanDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('scans')
          .doc(widget.scanId)
          .get();
      scan = scanDoc.exists ? scanDoc.data() as Map<String, dynamic>? : null;
    } else {
      final scanDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      scan = scanDocs.docs.isNotEmpty ? scanDocs.docs.first.data() : {};
      scanDoc = scanDocs.docs.isNotEmpty ? scanDocs.docs.first : null;
    }

    // Ensure scan is never null
    scan ??= {};

    // Fetch assessment: latest if none, else match timestamp if possible
    QuerySnapshot assessmentDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    Map<String, dynamic>? assessment = assessmentDocs.docs.isNotEmpty
        ? assessmentDocs.docs.first.data() as Map<String, dynamic>
        : {};

    setState(() {
      _profile = profile;
      _assessment = assessment;
      _scan = scan;
      _isLoading = false;
    });
  }

  List<String> getTipsForPrediction(String prediction) {
    final pred = prediction.toLowerCase();
    if (pred.contains('normal') || pred.contains('no cataract')) {
      return [
        'Maintain a healthy diet rich in leafy greens and fish.',
        'Wear sunglasses that block UV rays outdoors.',
        'Schedule annual eye check-ups.',
        'Take regular breaks from screens to reduce eye strain.',
      ];
    } else if (pred.contains('immature') || pred.contains('initial')) {
      return [
        'Monitor your vision for any changes.',
        'Protect your eyes from sunlight with UV-blocking sunglasses.',
        'Reduce night driving if glare or halos are noticed.',
        'Consult your eye doctor for follow-up and advice.',
      ];
    } else if (pred.contains('mature') ||
        pred.contains('severe') ||
        pred.contains('advanced')) {
      return [
        'Consult an ophthalmologist as soon as possible.',
        'Prepare questions for your doctor about treatment options.',
        'Follow medical advice strictly.',
        'Ensure good lighting at home to reduce accidents.',
      ];
    } else {
      return [
        'Repeat the scan in good lighting.',
        'Make sure your eye is centered in the frame.',
        'If problems persist, consult an eye care professional.',
      ];
    }
  }

  // Helper function to format dates
  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    // Expecting date in YYYY-MM-DD
    return date;
  }

  String _generateShortId(String? patientId, String? scanId) {
    // If patientId exists and is not empty, use first 6 characters
    if (patientId != null && patientId.isNotEmpty) {
      return 'SC-${patientId.substring(0, min(6, patientId.length)).toUpperCase()}';
    }

    // If scanId exists, use first 8 characters
    if (scanId != null && scanId.isNotEmpty) {
      return 'SC-${scanId.substring(0, min(8, scanId.length)).toUpperCase()}';
    }

    // Fallback to short timestamp-based ID
    return 'SC-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (ts is String) return ts;
      if (ts is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return ts.toString();
    } catch (_) {
      return ts.toString();
    }
  }

  bool isCataractResult(String? prediction) {
    if (prediction == null) return false;
    final p = prediction.toLowerCase();
    return !(p.contains('normal') || p.contains('no cataract'));
  }

  String _riskLevelFromScore(double score) {
    if (score >= 80) return 'Low';
    if (score >= 60) return 'Moderate';
    return 'High';
  }

  String _deriveStage(Map<String, dynamic>? scan) {
    if (scan == null) return 'Unknown';

    // Prefer saved field, if present from ScanResultScreen
    final saved = scan['enhancedStaging'] as String?;
    if (saved != null && saved.isNotEmpty) return saved;

    final prediction = (scan['prediction'] as String?) ?? 'Normal';

    // Clamp to 0..1 and ensure double
    final double confidence =
        ((((scan['confidence'] as num?) ?? 0.0).toDouble()).clamp(0.0, 1.0)
                as num)
            .toDouble();
    final double symptom = ((((scan['symptomScore'] as num?) ?? 0.0).toDouble())
            .clamp(0.0, 1.0) as num)
        .toDouble();

    return StagingService.determineStage(
      prediction: prediction,
      symptomScore: symptom,
      confidence: confidence,
    );
  }

  double? _computeHealthScoreFallback(Map<String, dynamic>? scan) {
    if (scan == null) return null;
    final saved = (scan['healthScore'] as num?)?.toDouble();
    if (saved != null && saved > 0) return saved;

    final double? imageScore = (scan['confidence'] as num?)?.toDouble();
    final double? symptomScore = (scan['symptomScore'] as num?)?.toDouble();
    final String? prediction = scan['prediction'] as String?;
    if (imageScore == null || symptomScore == null) return null;

    final scoring = ScoringService();
    return scoring.calculateHealthScore(
      imageScore: imageScore,
      symptomScore: symptomScore,
      prediction: prediction,
    );
  }

  void _printReport() {
    AuditLogService.logAction(
      action: 'report_printed',
      details: 'ScanId: ${widget.scanId ?? "latest"}',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing report for printing...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    final scan = _scan;
    final stage = _deriveStage(scan);
    DateTime? scanDateTime;
    final double? pdfHealthScore = _computeHealthScoreFallback(scan);
    final String pdfRiskLevel = (scan?['riskLevel'] as String?) ??
        (pdfHealthScore != null ? _riskLevelFromScore(pdfHealthScore) : 'N/A');

    if (scan != null && scan['timestamp'] != null) {
      final ts = scan['timestamp'];
      if (ts is Timestamp) {
        scanDateTime = ts.toDate();
      } else if (ts is String) {
        scanDateTime = DateTime.tryParse(ts);
      }
    }
    String reportDate = scanDateTime != null
        ? "${scanDateTime.year}-${scanDateTime.month.toString().padLeft(2, '0')}-${scanDateTime.day.toString().padLeft(2, '0')}"
        : "";
    String reportTime = scanDateTime != null
        ? "${scanDateTime.hour.toString().padLeft(2, '0')}:${scanDateTime.minute.toString().padLeft(2, '0')}"
        : "";

    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Uncomment to use a logo
              // pw.Image(logoImage, width: 56, height: 56),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SmartiCare',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      )),
                  pw.Text('Cataract Screening Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      )),
                ],
              ),
              pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                      '#${_generateShortId(_profile?["patientId"], widget.scanId)}',
                      style: pw.TextStyle(
                          color: PdfColors.teal800,
                          fontWeight: pw.FontWeight.bold))),
            ],
          ),
          pw.Divider(thickness: 2, color: PdfColors.teal100),
          pw.SizedBox(height: 12),

          // Patient Information Card
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.teal50),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 48,
                  height: 48,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      (_profile?['firstName'] ?? 'U')
                          .toString()
                          .substring(0, 1)
                          .toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${_profile?['firstName'] ?? 'N/A'} ${_profile?['lastName'] ?? ''}'
                            .trim(),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 16),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                          'Age: ${_calculateAge(_profile?["birthDate"]) ?? "N/A"}   Gender: ${_profile?["gender"] ?? "N/A"}',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(
                          'Patient ID: ${(_profile?["patientId"] != null && (_profile!["patientId"] as String).isNotEmpty) ? _profile!["patientId"] : "Not Set"}',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Date of Birth: ${_profile?["birthDate"] ?? "-"}',
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: $reportDate',
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('Time: $reportTime',
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Section: Scan Summary
          pw.Text('Scan Summary',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
                  fontSize: 15)),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.teal100),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Eye: ${scan?['eye'] ?? 'N/A'}',
                  style: const pw.TextStyle(fontSize: 13)),
              pw.Text('Stage: $stage',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('Health Score: ', style: const pw.TextStyle(fontSize: 13)),
            pw.Text(
                pdfHealthScore != null ? '${pdfHealthScore.round()}%' : 'N/A',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            pw.SizedBox(width: 16),
            pw.Text('Risk Level: ', style: const pw.TextStyle(fontSize: 13)),
            pw.Text(pdfRiskLevel,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
          ]),
          pw.SizedBox(height: 10),
          if (scan?['symptomScore'] != null)
            pw.Text('Symptom Score: ${scan?['symptomScore']}',
                style: const pw.TextStyle(fontSize: 12)),
          if (scan?['scanDate'] != null)
            pw.Text('Scan Date: ${scan?['scanDate']}',
                style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),

          // Section: Recommendations / Tips
          pw.Text('Recommendations',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 15,
                  color: PdfColors.teal800)),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.teal100),
          pw.SizedBox(height: 6),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ...getTipsForPrediction(stage).map(
                (tip) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(tip, style: const pw.TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Section: Contact
          pw.Text('Contact & Follow-Up',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 15,
                  color: PdfColors.teal800)),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.teal100),
          pw.SizedBox(height: 4),
          pw.Text(
              'Phone: ${_profile?["phoneNumber"] ?? _profile?["contact"] ?? _profile?["phone"] ?? "N/A"}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Email: ${_profile?["email"] ?? "N/A"}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Address: ${_profile?["address"] ?? "N/A"}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),

          // Section: Disclaimer
// Section: Disclaimer
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'This report is generated based on computer vision analysis and self-reported symptoms. It is not a definitive medical diagnosis and should not replace professional medical advice. Always consult with a qualified eye care specialist for evaluation and treatment.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 16),

          // Footer
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('SmartiCare Eye',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800)),
                pw.Text('Report generated on $reportDate at $reportTime UTC',
                    style:
                        pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Icon(pw.IconData(0xe6b1),
                        color: PdfColors.teal800, size: 14), // verified icon
                    pw.SizedBox(width: 6),
                    pw.Text('Verified Report',
                        style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.teal800,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Save to device instead of sharing
    final bytes = await pdfDoc.save();

    // Build a base filename without extension (file_saver adds ext)
    String baseName = reportDate.isNotEmpty
        ? 'Cataract_Report_${reportDate.replaceAll('-', '')}'
        : 'Cataract_Report_${DateTime.now().toUtc().toIso8601String().substring(0, 10).replaceAll('-', '')}';

    try {
      // Correct usage for FileSaver 0.3.1 with named parameters
      await FileSaver.instance.saveAs(
        name: baseName, // required
        bytes: bytes, // file bytes
        fileExtension: 'pdf', // required
        mimeType: MimeType.pdf, // required
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);
    const Color successColor = Color(0xFF28A745);
    final bool cataract = isCataractResult(_scan?['prediction']);
    final double? uiHealthScore = _computeHealthScoreFallback(_scan);
    final String uiRiskLevel = (_scan?['riskLevel'] as String?) ??
        (uiHealthScore != null ? _riskLevelFromScore(uiHealthScore) : 'N/A');

    String displayName = _profile?['firstName'] ??
        _profile?['username'] ??
        FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.email?.split('@')[0] ??
        "User";
    String iconLetter = displayName.isNotEmpty ? displayName[0] : "U";

    // Replace the currentDate/currentTime with this logic:
    DateTime? scanDateTime;
    if (_scan != null && _scan!['timestamp'] != null) {
      final ts = _scan!['timestamp'];
      if (ts is Timestamp) {
        scanDateTime = ts.toDate();
      } else if (ts is String) {
        scanDateTime = DateTime.tryParse(ts);
      }
    }
    String reportDate = scanDateTime != null
        ? "${scanDateTime.year}-${scanDateTime.month.toString().padLeft(2, '0')}-${scanDateTime.day.toString().padLeft(2, '0')}"
        : "";
    String reportTime = scanDateTime != null
        ? "${scanDateTime.hour.toString().padLeft(2, '0')}:${scanDateTime.minute.toString().padLeft(2, '0')}"
        : "";
    final String username =
        FirebaseAuth.instance.currentUser?.displayName ?? "SmartiCare User";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Full Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.description_outlined,
                                      color: primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cataract Screening Report',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Comprehensive Analysis',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: _formatDate(reportDate),
                            ),
                            _buildInfoItem(
                              icon: Icons.access_time,
                              label: 'Time',
                              value: reportTime,
                            ),
                            _buildInfoItem(
                              icon: Icons.person_outline,
                              label: 'User',
                              value: displayName,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Patient Demographics Section
                  _buildSectionTitle('Patient Demographics'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _profile == null
                        ? const Text('No profile data found')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(40),
                                    child: Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.blue.shade100,
                                      child: Center(
                                        child: Text(
                                          iconLetter,
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (_profile?['firstName'] != null &&
                                                  (_profile?['firstName']
                                                          as String)
                                                      .isNotEmpty)
                                              ? "${_profile?['firstName'] ?? ""} ${_profile?['middleName'] ?? ""} ${_profile?['lastName'] ?? ""}"
                                                  .trim()
                                              : displayName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                "${_calculateAge(_profile?["birthDate"]) ?? "N/A"} years",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                _profile?["gender"] ?? "N/A",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.purple.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (_profile?["patientId"] !=
                                                    null &&
                                                (_profile!["patientId"]
                                                        as String)
                                                    .isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  "ID: ${_profile!["patientId"]}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.amber.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "DOB: ${_profile?["birthDate"] ?? "N/A"}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              const Text(
                                'Contact Information',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDemographicsRow(
                                icon: Icons.phone,
                                label: 'Phone',
                                value: _profile?["phoneNumber"] ??
                                    _profile?["contact"] ??
                                    _profile?["phone"] ??
                                    "N/A",
                                color: Colors.green,
                              ),
                              const SizedBox(height: 12),
                              _buildDemographicsRow(
                                icon: Icons.email,
                                label: 'Email',
                                value: _profile?["email"] ?? "N/A",
                                color: Colors.red,
                              ),
                              const SizedBox(height: 12),
                              _buildDemographicsRow(
                                icon: Icons.location_on,
                                label: 'Address',
                                value: _profile?["address"] ?? "N/A",
                                color: Colors.blue,
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle('Eye Scan Summary'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _scan == null
                        ? const Text("No scan data found.")
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with eye result
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_scan?['eye'] ?? "Eye"} Result',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      _scan?['prediction'] ?? 'No data',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'AI Image Analysis',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${((_scan?['confidence'] as num?) != null ? ((_scan!['confidence'] as num) * 100).round() : 0)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ✅ NEW: Health Score and Risk Level with Tooltips
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        // Health Score with tooltip
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: cataract
                                                  ? Colors.red
                                                  : const Color(0xFF28A745),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Health Score',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            // ✅ Tooltip icon for Health Score
                                            InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: Row(
                                                      children: [
                                                        Icon(Icons.info_outline,
                                                            color: Colors
                                                                .blue.shade700),
                                                        SizedBox(width: 12),
                                                        Text('Health Score'),
                                                      ],
                                                    ),
                                                    content:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'What is Health Score?',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          SizedBox(height: 8),
                                                          Text(
                                                            'Your Health Score (0-100%) represents the overall health of your eye based on:',
                                                            style: TextStyle(
                                                                height: 1.5),
                                                          ),
                                                          SizedBox(height: 12),
                                                          _buildScoreComponent(
                                                            icon: Icons
                                                                .camera_alt,
                                                            label:
                                                                'AI Image Analysis (70%)',
                                                            description:
                                                                'Computer vision analysis of your eye scan',
                                                          ),
                                                          SizedBox(height: 12),
                                                          _buildScoreComponent(
                                                            icon: Icons
                                                                .psychology,
                                                            label:
                                                                'Symptom Assessment (30%)',
                                                            description:
                                                                'Your self-reported symptoms',
                                                          ),
                                                          SizedBox(height: 16),
                                                          Container(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    12),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .blue.shade50,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .lightbulb_outline,
                                                                    color: Colors
                                                                        .blue
                                                                        .shade700,
                                                                    size: 20),
                                                                SizedBox(
                                                                    width: 8),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Higher scores (80-100%) indicate healthier eyes with no cataract signs.',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .blue
                                                                          .shade900,
                                                                      height:
                                                                          1.4,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: Text('Got It'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.help_outline,
                                                  color: Colors.blue.shade700,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _scan?['healthScore'] != null
                                              ? '${(_scan!['healthScore'] is double ? _scan!['healthScore'].round() : _scan!['healthScore'])}%'
                                              : 'N/A',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: cataract
                                                ? Colors.red
                                                : const Color(0xFF28A745),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey.shade300,
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        // Risk Level with tooltip
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: cataract
                                                  ? Colors.red
                                                  : const Color(0xFF28A745),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Risk Level',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            // ✅ Tooltip icon for Risk Level
                                            InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: Row(
                                                      children: [
                                                        Icon(
                                                            Icons.warning_amber,
                                                            color: Colors.orange
                                                                .shade700),
                                                        SizedBox(width: 12),
                                                        Text('Risk Level'),
                                                      ],
                                                    ),
                                                    content:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'What is Risk Level?',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          SizedBox(height: 8),
                                                          Text(
                                                            'Risk Level indicates the urgency of medical attention needed based on your Health Score:',
                                                            style: TextStyle(
                                                                height: 1.5),
                                                          ),
                                                          SizedBox(height: 16),
                                                          _buildRiskLevelExample(
                                                            color: Colors.green,
                                                            level: 'Low Risk',
                                                            range:
                                                                '80-100% Health Score',
                                                            description:
                                                                'No immediate action needed. Continue regular checkups.',
                                                            icon: Icons
                                                                .check_circle,
                                                          ),
                                                          SizedBox(height: 12),
                                                          _buildRiskLevelExample(
                                                            color:
                                                                Colors.orange,
                                                            level:
                                                                'Moderate Risk',
                                                            range:
                                                                '60-79% Health Score',
                                                            description:
                                                                'Schedule a follow-up appointment within 1-2 months.',
                                                            icon: Icons
                                                                .warning_amber,
                                                          ),
                                                          SizedBox(height: 12),
                                                          _buildRiskLevelExample(
                                                            color: Colors.red,
                                                            level: 'High Risk',
                                                            range:
                                                                'Below 60% Health Score',
                                                            description:
                                                                'Consult an ophthalmologist as soon as possible.',
                                                            icon: Icons.error,
                                                          ),
                                                          SizedBox(height: 16),
                                                          Container(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    12),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .red.shade50,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .medical_services,
                                                                    color: Colors
                                                                        .red
                                                                        .shade700,
                                                                    size: 20),
                                                                SizedBox(
                                                                    width: 8),
                                                                Expanded(
                                                                  child: Text(
                                                                    'This is a screening tool, not a diagnosis. Always consult a medical professional.',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .red
                                                                          .shade900,
                                                                      height:
                                                                          1.4,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: Text('Got It'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.help_outline,
                                                  color: Colors.orange.shade700,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _scan?['riskLevel'] ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: cataract
                                                ? Colors.red
                                                : const Color(0xFF28A745),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Eye image (if available)
                              Builder(
                                builder: (context) {
                                  final imageUrl = _scan?['originalImage'] ??
                                      _scan?['imageUrl'];
                                  if (imageUrl != null && imageUrl.isNotEmpty) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Original Scan',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Center(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              imageUrl,
                                              width: 200,
                                              height: 200,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Container(
                                                color: Colors.grey[200],
                                                width: 200,
                                                height: 200,
                                                child: const Icon(
                                                    Icons.broken_image,
                                                    size: 48,
                                                    color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Symptom Assessment Section
                  _buildSectionTitle('Symptom Assessment Results'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _assessment == null
                        ? const Text("No assessment data found.")
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              const Text(
                                'Assessment Conclusion',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  _assessment?['conclusion'] ??
                                      'No conclusion found.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              // >>> Insert warning here <<
                              if ((_scan?['riskLevel']?.toLowerCase() ==
                                          'high' ||
                                      isCataractResult(_scan?['prediction'])) &&
                                  (_assessment?['conclusion']
                                          ?.toLowerCase()
                                          .contains('low risk') ??
                                      false)) ...[
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: Colors.orange.shade700),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "A cataract was detected by the scan, but you reported few symptoms. Cataracts can develop before you notice symptoms. Please consult an eye care specialist even if you feel well.",
                                          style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Recommendations
                  _buildSectionTitle('Recommendations'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...getTipsForPrediction(_scan?['prediction']).map(
                          (tip) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text('• $tip',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                )),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Medical Disclaimer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This report is generated based on computer vision analysis and self-reported symptoms. It is not a medical diagnosis and should not replace professional medical advice. Always consult with a qualified eye care specialist for proper evaluation and treatment.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Certification footer
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'SmartiCare Eye',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Report generated on $reportDate at $reportTime UTC',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 16,
                              color: primaryColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Verified Report',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _downloadPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text(
                        'Download Full Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Helper method for score components
  Widget _buildScoreComponent({
    required IconData icon,
    required String label,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// Helper method for risk level examples
  Widget _buildRiskLevelExample({
    required Color color,
    required String level,
    required String range,
    required String description,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              SizedBox(height: 2),
              Text(
                range,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper widgets
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDemographicsRow({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildResultMetric({
    required String label,
    required String value,
    required Color iconColor,
    Color? valueColor, // Add this param
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor ?? iconColor, // Use valueColor if provided
          ),
        ),
      ],
    );
  }

  Widget _buildAssessmentItem({
    required String question,
    required String answer,
  }) {
    Color answerColor = Colors.grey.shade800;
    if (answer.contains('Often') || answer.contains('Always')) {
      answerColor = Colors.orange.shade700;
    } else if (answer.contains('Sometimes')) {
      answerColor = Colors.amber.shade700;
    } else if (answer.contains('Never') || answer.contains('Rarely')) {
      answerColor = Colors.green.shade700;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: answerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    answer,
                    style: TextStyle(
                      fontSize: 14,
                      color: answerColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePanel({
    String? originalImagePath,
    String? overlayImagePath,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eye Scan Images',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                        image: originalImagePath != null
                            ? DecorationImage(
                                image: NetworkImage(originalImagePath),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: originalImagePath == null
                          ? Center(
                              child: Icon(
                                Icons.visibility,
                                size: 30,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Original Scan',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                        image: overlayImagePath != null
                            ? DecorationImage(
                                image: NetworkImage(overlayImagePath),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: overlayImagePath == null
                          ? Center(
                              child: Icon(
                                Icons.auto_fix_high,
                                size: 30,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Analysis Overlay',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(actionText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
