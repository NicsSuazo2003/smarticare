import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/offline_sync_service.dart';
import '../Screens/scoring_service.dart';
import 'full_report_screen.dart';
import 'view_history_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'symptom_assessment_screen.dart';
import 'package:provider/provider.dart';
import '../user_session_provider.dart';

class ScanResultScreen extends StatefulWidget {
  final String imageUrl;
  final String prediction;
  final double confidence;
  final String eye; // 'Left Eye' or 'Right Eye'
  final String scanDate;
  final String scanId;
  final double symptomScore;

  const ScanResultScreen({
    super.key,
    required this.imageUrl,
    required this.prediction,
    required this.confidence,
    required this.eye,
    required this.scanDate,
    required this.scanId,
    required this.symptomScore,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  int _selectedNavIndex = 2;

  String getSymptomConclusion(double score) {
    if (score < 0.2) return "Low risk of symptoms";
    if (score < 0.5) return "Moderate risk of symptoms";
    return "High risk of symptoms";
  }

  // Replace the existing _saveScanResultToFirestore() with this implementation.
  Future<void> _saveScanResultToFirestore() async {
    try {
      final isGuest =
          Provider.of<UserSessionProvider>(context, listen: false).isGuest;
      if (isGuest) return;

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // ✅ ADD RETRY LOGIC - Scan might still be uploading
      bool scanExists = false;
      int retryCount = 0;
      const maxRetries = 5;

      while (!scanExists && retryCount < maxRetries) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('scans')
              .doc(widget.scanId)
              .get();

          if (doc.exists) {
            scanExists = true;
            final scanData = doc.data();

            // ✅ Verify the image URL is a Storage URL
            final imageUrl = scanData?['imageUrl'];
            if (imageUrl != null &&
                imageUrl
                    .startsWith('https://firebasestorage.googleapis.com/')) {
              print(
                  '✅ Scan verified: Storage URL present - ${imageUrl.substring(0, 50)}...');
            } else {
              print('❌ Scan verification failed: Invalid imageUrl - $imageUrl');
            }
            break;
          } else {
            retryCount++;
            print(
                '⏳ Scan not found yet, retrying... ($retryCount/$maxRetries)');
            await Future.delayed(
                Duration(seconds: retryCount * 1)); // Exponential backoff
          }
        } catch (e) {
          retryCount++;
          print('⚠️ Error checking scan existence: $e');
          if (retryCount >= maxRetries) break;
          await Future.delayed(Duration(seconds: retryCount * 1));
        }
      }

      if (!scanExists) {
        print('⚠️ Scan document not found after $maxRetries attempts');
        return;
      }

      // ✅ Rest of your notification code remains the same...
      final scoringService = ScoringService();
      final double computedHealthScore = scoringService.calculateHealthScore(
        imageScore: widget.confidence,
        symptomScore: widget.symptomScore,
        prediction: widget.prediction,
      );

      String riskLevel = "";
      if (computedHealthScore >= 80) {
        riskLevel = "Low";
      } else if (computedHealthScore >= 60) {
        riskLevel = "Moderate";
      } else {
        riskLevel = "High";
      }

      // Create user notification
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        "type": "scan",
        "title": "New Eye Scan Result",
        "message":
            "Your ${widget.eye.toLowerCase()} scan on ${widget.scanDate} completed. Result: ${widget.prediction}.",
        "timestamp": FieldValue.serverTimestamp(),
        "isRead": false,
      });

      // Check if alert notification needed
      final String predLower = widget.prediction.toLowerCase();
      final bool isCataract =
          !predLower.contains('normal') && !predLower.contains('no cataract');

      if (isCataract || riskLevel == 'High' || riskLevel == 'Moderate') {
        final String adminMessage =
            'Scan (${widget.scanId}) for user $userId on ${widget.scanDate} indicates ${widget.prediction} (risk: $riskLevel).';
        final String priority = (riskLevel == 'High') ? 'High' : 'Medium';

        await FirebaseFirestore.instance.collection('admin_notifications').add({
          'type': 'scan_alert',
          'title': 'Potential Cataract Detected',
          'message': adminMessage,
          'priority': priority,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'relatedUserId': userId,
          'scanId': widget.scanId,
        });
      }

      print('✅ Notifications created for scan: ${widget.scanId}');

      await AuditLogService.logAction(
        action: 'scan_completed',
        details:
            '${widget.eye} scan, ${(widget.confidence * 100).toStringAsFixed(0)}% confidence, result: ${widget.prediction}',
        scanId: widget.scanId,
      );
    } catch (e) {
      print('❌ Error in _saveScanResultToFirestore: $e');
    }
  }

  Future<void> _saveScanOffline(Map<String, dynamic> scanData) async {
    await OfflineSyncService().saveScanOffline(scanData);
  }

//
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

  @override
  void initState() {
    super.initState();
    _saveScanResultToFirestore();
    AuditLogService.logAction(
      action: 'scan_result_viewed',
      details:
          'ScanId: ${widget.scanId}, Eye: ${widget.eye}, Prediction: ${widget.prediction}',
    );
  }

  void _onNavItemTapped(int index) {
    if (_selectedNavIndex == index && index == 2) {
      return;
    }
    setState(() {
      _selectedNavIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProgressScreen()),
          (route) => false,
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SymptomAssessmentScreen(
              onStart: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
        break;
      case 3:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ReminderScreen()),
          (route) => false,
        );
        break;
      case 4:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
          (route) => false,
        );
        break;
    }
  }

  Widget buildScanImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        height: 180,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 180,
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) {
          print('Error loading image: $error'); // ✅ Add logging
          return Container(
            height: 180,
            color: Colors.grey.shade200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.error_outline, size: 40, color: Colors.red),
                SizedBox(height: 8),
                Text('Failed to load image'),
              ],
            ),
          );
        },
      );
    } else {
      try {
        return Image.file(File(imageUrl), height: 180, fit: BoxFit.cover);
      } catch (e) {
        print('Error loading file: $e');
        return Container(
          height: 180,
          color: Colors.grey.shade200,
          child: const Icon(Icons.error_outline, size: 40),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);
    const Color successColor = Color(0xFF28A745);
    const Color failColor = Color(0xFFDC3545);
    final bool isNormal = widget.prediction.toLowerCase().contains('normal') ||
        widget.prediction.toLowerCase() == "no cataract";
    final String symptomConclusion = getSymptomConclusion(widget.symptomScore);
    final Color classificationColor = isNormal ? successColor : failColor;

    final scoringService = ScoringService();
    final double computedHealthScore = scoringService.calculateHealthScore(
      imageScore: widget.confidence,
      symptomScore: widget.symptomScore,
      prediction: widget.prediction,
    );

    final isGuest = Provider.of<UserSessionProvider>(context).isGuest;

    // ADD WillPopScope to disable back button
    return WillPopScope(
      onWillPop: () async {
        // Return false to disable the back button
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 40), // Empty space for layout balance
                    const Text(
                      'Scan Result',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(width: 40), // Empty space for layout balance
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: buildScanImage(widget.imageUrl),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.analytics,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Symptom Assessment: $symptomConclusion (Score: ${widget.symptomScore.toStringAsFixed(2)})",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (
                          // Scan is "Cataract" or computedHealthScore is "High Risk"
                          (!isNormal && computedHealthScore < 60) &&
                              // Symptom assessment is "Low risk"
                              symptomConclusion
                                  .toLowerCase()
                                  .contains("low risk")) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isNormal
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isNormal
                                  ? Colors.green.shade200
                                  : Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isNormal
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isNormal
                                    ? Icons.check_rounded
                                    : Icons.warning_amber_rounded,
                                color: classificationColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isNormal
                                        ? 'Scan Completed Successfully'
                                        : 'Scan Completed',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: classificationColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Your ${widget.eye.toLowerCase()} scan has been analyzed.",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 10,
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
                                Text(
                                  '${widget.eye} Result',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    widget.scanDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Cataract Analysis',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(11),
                                        topRight: Radius.circular(11),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Health Score',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Classification',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            "${(widget.confidence * 100).toStringAsFixed(0)}%",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: classificationColor,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            widget.prediction,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: classificationColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Computed Health Score',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${computedHealthScore.round()}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: classificationColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Initial Stage',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            isNormal
                                                ? 'No Cataract'
                                                : 'Cataract',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Analysis Result',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isNormal
                                  ? 'Your ${widget.eye.toLowerCase()} shows no sign of cataract formation.'
                                  : 'Potential cataract detected in your ${widget.eye.toLowerCase()}. Please consult an ophthalmologist for further evaluation.',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTipsSection(widget.prediction),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recommendations',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildRecommendationItem(
                              icon: Icons.remove_red_eye_outlined,
                              title: 'Continue Monitoring',
                              description: isNormal
                                  ? 'Schedule your next eye scan in 6 months to track any changes.'
                                  : 'Schedule a follow-up scan and consult a specialist soon.',
                            ),
                            const SizedBox(height: 12),
                            _buildRecommendationItem(
                              icon: Icons.wb_sunny_outlined,
                              title: 'Wear UV Protection',
                              description:
                                  'Use sunglasses that block UVA and UVB rays when outdoors.',
                            ),
                            const SizedBox(height: 12),
                            _buildRecommendationItem(
                              icon: Icons.local_hospital_outlined,
                              title: 'Regular Check-ups',
                              description: isNormal
                                  ? 'Visit an ophthalmologist annually for comprehensive eye exams.'
                                  : 'Consult an ophthalmologist for further diagnosis and treatment.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.article_outlined,
                              label: 'View Full Report',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FullReportScreen(),
                                  ),
                                );
                              },
                              isPrimary: true,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.history,
                              label: 'View History',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ViewHistoryScreen(),
                                  ),
                                );
                              },
                              isPrimary: false,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildActionButton(
                        icon: Icons.check_circle_outline,
                        label: 'DONE',
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  HomeScreen(refreshData: true),
                            ),
                            (route) => false,
                          );
                        },
                        isPrimary: true,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 20),
                      if (isGuest)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 24.0, bottom: 8.0),
                          child: Column(
                            children: [
                              Text(
                                "Sign up to save your results and track your eye health!",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.blue.shade700),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/register');
                                },
                                child: Text("Sign Up Now"),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(primaryColor),
      ),
    );
  }

  Widget _buildTipsSection(String prediction) {
    final tips = getTipsForPrediction(prediction);
    return Column(
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
        ...tips.map((tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text('• $tip'),
            )),
      ],
    );
  }

  Widget _buildBottomNavigationBar(Color primaryColor) {
    final isGuest = Provider.of<UserSessionProvider>(context).isGuest;
    if (isGuest) {
      return BottomNavigationBar(
        currentIndex: 0,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
              ),
            ),
            label: 'Eye Scan',
          ),
          // <-- Add a second item (even if it's a dummy)
          const BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'Info',
          ),
        ],
        onTap: (_) {}, // Prevent navigation
      );
    }
    return BottomNavigationBar(
      currentIndex: _selectedNavIndex,
      onTap: _onNavItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
      elevation: 12,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.trending_up_outlined),
          activeIcon: Icon(Icons.trending_up),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
            ),
          ),
          label: 'Eye Scan',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Reminders',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildRecommendationItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
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
        const SizedBox(width: 16),
        Expanded(
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
                  height: 1.5,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? color : Colors.grey.shade400,
            width: isPrimary ? 0 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : Colors.grey.shade800,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
