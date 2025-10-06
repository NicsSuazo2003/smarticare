import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'dart:math';

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
      scan = scanDocs.docs.isNotEmpty ? scanDocs.docs.first.data() : null;
      scanDoc = scanDocs.docs.isNotEmpty ? scanDocs.docs.first : null;
    }

    // Fetch assessment: latest if none, else match timestamp if possible
    QuerySnapshot assessmentDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    Map<String, dynamic>? assessment = (assessmentDocs.docs.isNotEmpty
        ? assessmentDocs.docs.first.data()
        : null) as Map<String, dynamic>?;

    setState(() {
      _profile = profile;
      _assessment = assessment;
      _scan = scan;
      _isLoading = false;
    });
  }

  // Helper function to format dates
  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    // Expecting date in YYYY-MM-DD
    return date;
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

  void _shareReport() {
    AuditLogService.logAction(
      action: 'report_shared',
      details: 'ScanId: ${widget.scanId ?? "latest"}',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing report...'),
        duration: Duration(seconds: 2),
      ),
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

  void _downloadPdf() {
    AuditLogService.logAction(
      action: 'report_downloaded',
      details: 'ScanId: ${widget.scanId ?? "latest"}',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading report as PDF...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);
    const Color successColor = Color(0xFF28A745);

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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.share),
                          title: const Text('Share Report'),
                          onTap: () {
                            Navigator.pop(context);
                            _shareReport();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.print),
                          title: const Text('Print Report'),
                          onTap: () {
                            Navigator.pop(context);
                            _printReport();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.download),
                          title: const Text('Download PDF'),
                          onTap: () {
                            Navigator.pop(context);
                            _downloadPdf();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'ID: #SC${Random().nextInt(90000) + 10000}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                                                "${_profile?["age"] ?? "N/A"} years",
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
                                            if (_profile?["patientId"] != null)
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
                                                  "ID: ${_profile?["patientId"]}",
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
                                value: _profile?["contact"] ?? "N/A",
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
                              const SizedBox(height: 12),
                              _buildDemographicsRow(
                                icon: Icons.emergency,
                                label: 'Emergency',
                                value: _profile?["emergencyContact"] ?? "N/A",
                                color: Colors.orange,
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Eye Scan Summary Section

                  // Eye Scan Summary Section
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
                                      _scan?['prediction'] ?? 'Unknown',
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
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildResultMetric(
                                      label: 'Health Score',
                                      value: _scan?['healthScore'] != null
                                          ? '${_scan!['healthScore']}%'
                                          : 'N/A',
                                      iconColor: const Color(0xFF28A745),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey.shade300,
                                  ),
                                  Expanded(
                                    child: _buildResultMetric(
                                      label: 'Risk Level',
                                      value: _scan?['riskLevel'] ?? 'N/A',
                                      iconColor: const Color(0xFF28A745),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 👇 Eye image block (safe for both fields)
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
                        _buildRecommendationItem(
                          icon: Icons.calendar_month,
                          title: 'Schedule Follow-up',
                          description:
                              'Book your next eye scan in 6 months to monitor any changes.',
                          actionText: 'Set Reminder',
                          onAction: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReminderScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _buildRecommendationItem(
                          icon: Icons.visibility,
                          title: 'Professional Examination',
                          description:
                              'Schedule an annual comprehensive eye exam with an ophthalmologist.',
                          actionText: 'Find Specialists',
                          onAction: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FindClinicsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _buildRecommendationItem(
                          icon: Icons.wb_sunny,
                          title: 'Eye Protection',
                          description:
                              'Wear sunglasses with UVA/UVB protection outdoors to protect your eyes.',
                          actionText: 'Learn More',
                          onAction: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Opening eye protection guide...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
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
                          'SmartiCare™ Eye Analysis Platform',
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
            color: iconColor,
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
