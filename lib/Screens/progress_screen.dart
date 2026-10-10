import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/symptom_assessment/services/scoring_service.dart';
import 'package:flutter_application_1/Screens/view_history_screen.dart';
import 'package:flutter_application_1/services/ml/staging_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/home/presentation/home_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';
import '../features/symptom_assessment/presentation/symptom_assessment_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _selectedNavIndex = 1; // Progress is at index 1
  bool _isLoading = true;
  final int _pageSize = 10;
  DocumentSnapshot? _lastDoc;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> progressData = [];
  String? _formattedDateTime;
  String? _username;

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _fetchProgressData();
  }

  void _updateDateTime() {
    // Get current date/time in UTC
    final now = DateTime.now().toUtc();
    final formatted =
        "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} "
        "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}";

    setState(() {
      _formattedDateTime = formatted;
    });

    // Get username
    _fetchUsername();
  }

  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  Future<void> _fetchUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!mounted) return;
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            setState(() {
              _username = userData['firstName'] ??
                  userData['username'] ??
                  user.email?.split('@')[0] ??
                  "User";
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
    }
  }

  Future<void> _fetchProgressData({bool loadMore = false}) async {
    if (_isLoadingMore || (!_hasMore && loadMore)) return;
    setState(() {
      _isLoading = !loadMore;
      _isLoadingMore = loadMore;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('scans')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (loadMore && _lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    try {
      final querySnapshot = await query.get();
      final List<Map<String, dynamic>> scans = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        // Null safety for data map
        if (data is Map<String, dynamic>) {
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp == null) continue;

          final date = timestamp.toDate();
          final prediction = data['prediction'] as String? ?? 'Unknown';
          final numConfidence = (data['confidence'] as num?) ?? 0;
          final eye = data['eye'] as String? ?? 'Unknown';
          final double symptomScore = ((data['symptomScore'] as num?) ?? 0.0)
              .toDouble()
              .clamp(0.0, 1.0);

             // Stage (classification)
          final String classification = StagingService.determineStage(
            prediction: prediction,
            symptomScore: symptomScore,
            confidence: (numConfidence.toDouble()).clamp(0.0, 1.0),
          );


          String result =
              classification; // Shows: "Normal", "Immature", "Mature", or "Advanced"
          String details;
          String recommendations;

          switch (classification) {
            case 'Normal':
              details =
                  "Your eye health is excellent. No signs of cataract formation detected.";
              recommendations =
                  "Continue with regular checkups every 6–12 months.";
              break;
            case 'Immature':
              details =
                  "Early-stage cataract features present. Monitoring recommended based on symptoms.";
              recommendations =
                  "Protect from UV light, monitor symptoms, consider follow-up if changes occur.";
              break;
            case 'Mature':
              details =
                  "Cataract appears significant with functional impact reported.";
              recommendations =
                  "Schedule a consultation with an ophthalmologist within 1–2 months.";
              break;
            default: // Advanced
              details =
                  "Advanced cataract detected with notable functional impact.";
              recommendations =
                  "Consult an ophthalmologist as soon as possible for evaluation.";
          }

// Health score
          final scoringService = ScoringService();
          final healthScore = scoringService.calculateHealthScore(
            imageScore: numConfidence.toDouble(),
            symptomScore: symptomScore,
            prediction: prediction,
          );
          scans.add({
            "id": doc.id,
            "date": date,
            "eye": eye,
            "aiConfidence":
                (numConfidence * 100).round(), 
            "healthScore": healthScore.round(), 
            "classification": classification,
            "result": result,
            "details": details,
            "recommendations": recommendations,
            "doctor": "AI Assisted Analysis",
            "rawData": data,
          });
        }
      }

      if (!mounted) return;
      setState(() {
        if (loadMore && progressData.isNotEmpty) {
          progressData.addAll(scans);
        } else {
          progressData = scans;
        }
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = querySnapshot.docs.length == _pageSize;
        if (querySnapshot.docs.isNotEmpty) {
          _lastDoc = querySnapshot.docs.last;
        }
      });
    } catch (e) {
      debugPrint('Error fetching progress data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _showScanDetails(Map<String, dynamic> scan) {
    const Color primaryColor = Color(0xFFFF6B6B);
    final date = scan["date"] as DateTime;
    final formattedDate = DateFormat.yMMMMd().format(date);
    final String eye = scan["eye"] ?? '';
    final String result = scan["result"] ?? '';
    final String details = scan["details"] ?? '';
    final String recommendations = scan["recommendations"] ?? '';
    final String classification = scan["classification"] ?? '';
    final Color statusColor =
        classification == "Normal" ? Colors.green : Colors.amber;

   
    final int currentIndex =
        progressData.indexWhere((s) => s["id"] == scan["id"]);
    final Map<String, dynamic>? previousScan = _getPreviousScan(currentIndex);

    String? comparisonText;
    Color? comparisonColor;
    IconData? comparisonIcon;
    String? progressionStatus;

    if (previousScan != null && previousScan["eye"] == eye) {
      final prevClassification = previousScan["classification"] as String;
      final prevDate = previousScan["date"] as DateTime;
      final prevFormattedDate = DateFormat.yMMMMd().format(prevDate);

      // Calculate progression
      const severityMap = {
        'Normal': 0,
        'Immature': 1,
        'Mature': 2,
        'Advanced': 3,
      };
      final currentSeverity = severityMap[classification] ?? 0;
      final previousSeverity = severityMap[prevClassification] ?? 0;

      if (currentSeverity > previousSeverity) {
        progressionStatus = 'WORSENING';
        comparisonColor = Colors.red;
        comparisonIcon = Icons.trending_down;
        comparisonText =
            'Compared to your scan on $prevFormattedDate:\n$prevClassification → $classification';
      } else if (currentSeverity < previousSeverity) {
        progressionStatus = 'IMPROVING';
        comparisonColor = Colors.green;
        comparisonIcon = Icons.trending_up;
        comparisonText =
            'Compared to your scan on $prevFormattedDate:\n$prevClassification → $classification';
      } else {
        progressionStatus = 'STABLE';
        comparisonColor = Colors.orange;
        comparisonIcon = Icons.trending_flat;
        comparisonText =
            'Compared to your scan on $prevFormattedDate:\nNo change in classification';
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 18, color: Colors.black12)],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.18),
                        radius: 28,
                        child: Icon(
                          Icons.remove_red_eye,
                          color: statusColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eye,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                classification,
                                style: TextStyle(
                                  color: statusColor.darken(0.2),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 10),

                  // Result summary
                  Row(
                    children: [
                      Icon(Icons.event,
                          size: 20, color: Colors.blueGrey.shade400),
                      const SizedBox(width: 8),
                      Text(
                        'Date: $formattedDate',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.verified_user,
                          size: 20, color: Colors.blueGrey.shade400),
                      const SizedBox(width: 8),
                      Text(
                        "Analysis: AI Assisted",
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.emoji_events, size: 20, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        "Result: $result",
                        style: TextStyle(
                          color: statusColor.darken(0.3),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                 
                  if (comparisonText != null && comparisonColor != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: comparisonColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: comparisonColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                comparisonIcon,
                                color: comparisonColor,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Progression: $progressionStatus',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: comparisonColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            comparisonText,
                            style: TextStyle(
                              fontSize: 14,
                              color: comparisonColor.darken(0.2),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fiber_new,
                            color: Colors.blue.shade700,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'First scan of this eye - Complete another $eye scan to track progression',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  // Details
                  Text(
                    "Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recommendations
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.local_hospital,
                            color: primaryColor, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            recommendations,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: primaryColor.darken(0.1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text("Close"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$title:",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onNavItemTapped(int index) {
   
    if (index == 2) {
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
      return;
    }

    
    if (_selectedNavIndex == index) {
      return;
    }

    setState(() {
      _selectedNavIndex = index;
    });

    switch (index) {
      case 0: // Home
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1: // Progress
        // Already on progress screen
        break;
      case 3: // Reminders
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReminderScreen()),
        );
        break;
      case 4: // Profile
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
    }
  }

  /// Helper function to get the previous scan for comparison
  Map<String, dynamic>? _getPreviousScan(int currentIndex) {
    if (currentIndex < progressData.length - 1) {
      return progressData[currentIndex + 1];
    }
    return null;
  }

  void _showHealthScoreInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFFF6B6B)),
            SizedBox(width: 12),
            Text('Understanding Your Score'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What is Health Score?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Your Health Score shows the overall condition of your eye based on AI analysis and your symptoms.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              _buildScoreRange(
                color: Colors.green,
                range: '80-100%',
                label: 'Healthy',
                description: 'No signs of cataract detected',
              ),
              SizedBox(height: 12),
              _buildScoreRange(
                color: Colors.orange,
                range: '60-79%',
                label: 'Monitor',
                description: 'Early signs detected. Schedule follow-up',
              ),
              SizedBox(height: 12),
              _buildScoreRange(
                color: Colors.red,
                range: 'Below 60%',
                label: 'Consult Doctor',
                description: 'Cataract detected. See specialist soon',
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates,
                        color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lower scores mean more attention needed for your eye health.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
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
            onPressed: () => Navigator.pop(context),
            child: Text('Got It'),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRange({
    required Color color,
    required String range,
    required String label,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    range,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
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

  Widget _buildProgressionExample({
    required String emoji,
    required String label,
    required String example,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          emoji,
          style: TextStyle(fontSize: 18),
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
                  color: color,
                ),
              ),
              SizedBox(height: 2),
              Text(
                example,
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

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
        centerTitle: true,
        title: const Text(
          'Progress',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchProgressData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Text(
                      'Eye Health Timeline',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Row(
                              children: [
                                Icon(Icons.timeline, color: Color(0xFFFF6B6B)),
                                SizedBox(width: 12),
                                Text('Progression Logic'),
                              ],
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'How is progression calculated?',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Each scan is compared to your previous scan of the SAME EYE to track changes:',
                                    style: TextStyle(height: 1.5),
                                  ),
                                  SizedBox(height: 16),
                                  _buildProgressionExample(
                                    emoji: '🔴',
                                    label: 'Worsening',
                                    example: 'Normal → Cataract',
                                    description: 'Condition got worse',
                                    color: Colors.red,
                                  ),
                                  SizedBox(height: 12),
                                  _buildProgressionExample(
                                    emoji: '🟢',
                                    label: 'Improving',
                                    example: 'Cataract → Normal',
                                    description: 'Condition got better',
                                    color: Colors.green,
                                  ),
                                  SizedBox(height: 12),
                                  _buildProgressionExample(
                                    emoji: '🟠',
                                    label: 'Stable',
                                    example: 'Normal → Normal',
                                    description: 'No change detected',
                                    color: Colors.orange,
                                  ),
                                  SizedBox(height: 12),
                                  _buildProgressionExample(
                                    emoji: '🆕',
                                    label: 'New',
                                    example: 'First scan',
                                    description: 'Need 2nd scan to compare',
                                    color: Colors.blueGrey,
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: Colors.blue.shade700,
                                            size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Left and Right eyes are tracked separately for accurate monitoring.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blue.shade900,
                                              height: 1.4,
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
                                onPressed: () => Navigator.pop(context),
                                child: Text('Got It'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your eye health status and progression over time.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),

                const SizedBox(height: 16),

                
                if (progressData.isEmpty)
                  _buildEmptyState(primaryColor)
                else
                  ..._buildTimelineCards(primaryColor),

                const SizedBox(height: 28),

                const SizedBox(height: 28),


                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Scans',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        fontSize: 18,
                      ),
                    ),
                   
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ViewHistoryScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text("View All"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (progressData.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No scan history found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete an eye scan to see your progress',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
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
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Start Eye Scan"),
                        ),
                      ],
                    ),
                  )
                else
                
                  ...progressData.take(5).map((scan) => _ProgressCard(
                        scan: scan,
                        primaryColor: primaryColor,
                        onTap: () => _showScanDetails(scan),
                      )),

                const SizedBox(height: 20),

                const SizedBox(height: 20),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigationBar(primaryColor),
    );
  }

  /// Build empty state widget
  Widget _buildEmptyState(Color primaryColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(28),
        height: 240,
        width: double.infinity,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timeline, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'No scan history yet',
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your first eye scan to track your eye health over time', 
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimelineCards(Color primaryColor) {
    final cards = <Widget>[];

    
    final int itemsToShow = progressData.length > 10 ? 10 : progressData.length;

    for (int i = 0; i < itemsToShow; i++) {
      final scan = progressData[i];
      final previousScan = _getPreviousScan(i);

      cards.add(
        _TimelineCard(
          scan: scan,
          previousScan: previousScan,
          primaryColor: primaryColor,
          onTap: () => _showScanDetails(scan),
        ),
      );
    }

    return cards;
  }

  Widget _buildBottomNavigationBar(Color primaryColor) {
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
}


class _TimelineCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  final Map<String, dynamic>? previousScan;
  final Color primaryColor;
  final VoidCallback onTap;

  const _TimelineCard({
    required this.scan,
    this.previousScan,
    required this.primaryColor,
    required this.onTap,
  });
  Color _getHealthScoreColor(int healthScore) {
    if (healthScore >= 80) return Colors.green;
    if (healthScore >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getHealthScoreLabel(int healthScore) {
    if (healthScore >= 80) return 'Healthy';
    if (healthScore >= 60) return 'Monitor';
    return 'See Doctor';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime date = scan["date"] as DateTime;
    final String classification = scan["classification"] as String;
    final String eye = scan["eye"] as String;

    // Determine if classification changed from previous scan
    final String? previousClassification =
        previousScan?["classification"] as String?;
    final bool statusChanged = previousClassification != null &&
        previousClassification != classification;

    // Color based on classification
    final Color statusColor =
        classification == "Normal" ? Colors.green : Colors.amber;

    // Icon based on classification
    final IconData statusIcon =
        classification == "Normal" ? Icons.check_circle : Icons.warning_amber;

    // Progression computation similar to admin
    String progressionStatus = 'NEW';
    if (previousClassification != null) {
      const severityMap = {
        'Normal': 0,
        'Immature': 1,
        'Mature': 2,
        'Advanced': 3,
      };
      final currentSeverity = severityMap[classification] ?? 0;
      final previousSeverity = severityMap[previousClassification] ?? 0;
      if (currentSeverity > previousSeverity) {
        progressionStatus = 'WORSENING';
      } else if (currentSeverity < previousSeverity) {
        progressionStatus = 'IMPROVING';
      } else {
        progressionStatus = 'STABLE';
      }
    }
    IconData progressionIcon;
    Color progressionColor;
    switch (progressionStatus) {
      case 'WORSENING':
        progressionIcon = Icons.trending_down;
        progressionColor = Colors.red;
        break;
      case 'IMPROVING':
        progressionIcon = Icons.trending_up;
        progressionColor = Colors.green;
        break;
      case 'STABLE':
        progressionIcon = Icons.trending_flat;
        progressionColor = Colors.orange;
        break;
      default:
        progressionIcon = Icons.fiber_new;
        progressionColor = Colors.blueGrey;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: statusColor.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header with status change badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('E, MMM d, yyyy').format(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (statusChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: progressionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: progressionColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          progressionIcon,
                          size: 12,
                          color: progressionColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          progressionStatus == 'IMPROVING'
                              ? 'Improved'
                              : (progressionStatus == 'WORSENING'
                                  ? 'Worsened'
                                  : 'Status changed'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: progressionColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              color: Colors.grey.shade200,
              height: 1,
            ),
            const SizedBox(height: 12),

            // Eye status display
            Row(
              children: [
                // Status icon
                Icon(
                  statusIcon,
                  size: 24,
                  color: statusColor,
                ),
                const SizedBox(width: 12),

                // Eye and classification info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eye,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        classification,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // AI confidence as secondary detail
                // Health score as primary indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Health Score',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${scan["healthScore"] ?? 0}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getHealthScoreColor(scan["healthScore"] ?? 0),
                      ),
                    ),
                    const SizedBox(height: 2),
                  
                    Text(
                      _getHealthScoreLabel(scan["healthScore"] ?? 0),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getHealthScoreColor(scan["healthScore"] ?? 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Add after classification display, before progression indicator
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eye Health Status',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (scan["healthScore"] ?? 0) / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            _getHealthScoreColor(scan["healthScore"] ?? 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Progression indicator (if previous exists)
            if (previousClassification != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: progressionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      progressionIcon,
                      size: 16,
                      color: progressionColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Progression: $progressionStatus',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: progressionColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($previousClassification → $classification)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: progressionColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tap indicator
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// EXISTING WIDGET: Progress Card (kept for "All Scans" section below timeline)
class _ProgressCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ProgressCard({
    required this.scan,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime date = scan["date"] as DateTime;
    final bool isRightEye = scan["eye"] == "Right Eye";
    final String classification = scan["classification"] as String;

    final Color statusColor =
        classification == "Normal" ? Colors.green : Colors.amber;
    final Color eyeColor = isRightEye ? Colors.green : Colors.amber;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              leading: CircleAvatar(
                backgroundColor: eyeColor.withOpacity(0.15),
                child: Icon(
                  Icons.remove_red_eye,
                  color: eyeColor,
                ),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    scan["eye"] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      classification,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Date: ${DateFormat.yMMMMd().format(date)}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Health Score: ${scan["healthScore"] ?? scan["score"]}%   |   ${scan["result"]}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
