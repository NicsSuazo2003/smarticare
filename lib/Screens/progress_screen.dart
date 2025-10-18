import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';
import 'symptom_assessment_screen.dart';
import 'package:fl_chart/fl_chart.dart';

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

  // At the start of _ProgressScreenState

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
      print('Error fetching username: $e');
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
          final confidence = data['confidence'] as double? ?? 0.0;
          final eye = data['eye'] as String? ?? 'Unknown';
          final bool isNormal = prediction.toLowerCase().contains('normal') ||
              prediction.toLowerCase() == "no cataract";
          final classification = isNormal ? 'Normal' : 'Immature';
          final result = isNormal ? 'No Cataract' : 'Initial Stage';
          String details = isNormal
              ? "Your eye health is excellent. No signs of cataract formation detected."
              : "Early signs of cataract formation detected. Monitoring recommended.";
          String recommendations = isNormal
              ? "Continue with regular checkups every 6 months."
              : "Schedule an appointment with an ophthalmologist for further evaluation.";

          scans.add({
            "id": doc.id,
            "date": date,
            "eye": eye,
            "score": (confidence * 100).round(),
            "classification": classification,
            "result": result,
            "details": details,
            "recommendations": recommendations,
            "doctor": "AI Assisted Analysis",
            "rawData": data,
          });
        }
      }

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
      print('Error fetching progress data: $e');
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
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Implement actual sharing with share_plus
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Scan details shared")),
                          );
                        },
                        icon: const Icon(Icons.share_outlined),
                        label: const Text("Share"),
                      ),
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
                  // Optionally add a "Book Appointment" or "Download PDF" button here
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// --- Helper extension to darken a color

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
    // ✅ Special handling for Eye Scan - always allow it to open
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

    // ✅ For other tabs, check if already selected
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

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    // Extract data for chart
    // Extract data for chart
    // Replace the entire chart data extraction section in your build method with this:

// Extract data for chart
    List<int> rightEyeScores = [];
    List<int> leftEyeScores = [];
    List<String> labels = [];

    if (progressData.isNotEmpty) {
      // Sort by date ascending
      final sortedData = List<Map<String, dynamic>>.from(progressData)
        ..sort(
            (a, b) => (a["date"] as DateTime).compareTo(b["date"] as DateTime));

      // Take only the last 6 scans for the chart
      final limitedData = sortedData.length > 6
          ? sortedData.sublist(sortedData.length - 6)
          : sortedData;

      // Get unique dates for labels
      final uniqueDates = <DateTime>{};
      final dateScanMap = <DateTime, Map<String, int>>{};

      // Organize data by date and eye - FIXED VERSION
      for (var scan in limitedData) {
        final date = (scan["date"] as DateTime).toLocal();
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final eye = (scan["eye"] as String).toLowerCase();
        final score = scan["score"] as int;

        uniqueDates.add(normalizedDate);

        // Initialize if not exists, but don't overwrite existing data
        dateScanMap.putIfAbsent(normalizedDate, () => <String, int>{});

        // Store both eyes without overwriting
        if (eye.contains("right")) {
          dateScanMap[normalizedDate]!["right"] = score;
        } else if (eye.contains("left")) {
          dateScanMap[normalizedDate]!["left"] = score;
        }
      }

      // Sort dates and create labels - FIXED: Define sortedDates properly
      final sortedDatesList = uniqueDates.toList()..sort();
      labels = sortedDatesList
          .map((date) => DateFormat.MMMd().format(date))
          .toList();

      // Build score arrays aligned with dates
      for (var date in sortedDatesList) {
        final scores = dateScanMap[date];
        rightEyeScores.add(scores?["right"] ?? 0);
        leftEyeScores.add(scores?["left"] ?? 0);
      }

      // Debug print to verify data
      print("Chart Data - Labels: $labels");
      print("Chart Data - Right Eye: $rightEyeScores");
      print("Chart Data - Left Eye: $leftEyeScores");
    }

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
                      'Eye Health Progression',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Shows your eye scan results over time. '
                          'The score represents AI confidence in the analysis, not direct health status.',
                      child: Icon(Icons.info_outline,
                          color: Colors.blueGrey, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your eye scan history and AI analysis confidence levels.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Score: AI confidence level (0-100%)',
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message:
                          'Higher percentage means the AI is more confident in its analysis. '
                          'Focus on the Normal/Immature classification for health status.',
                      child: Icon(Icons.info_outline,
                          color: Colors.blueGrey, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LegendPill(color: Colors.amber, label: "Left Eye"),
                    const SizedBox(width: 10),
                    _LegendPill(color: Colors.green, label: "Right Eye"),
                  ],
                ),
                const SizedBox(height: 10),
                // --- ONLY THE CHART INSIDE THE CARD ---
                EyeHealthProgressionChart(
                  rightEyeScores: rightEyeScores,
                  leftEyeScores: leftEyeScores,
                  labels: labels,
                  isEmpty: progressData.isEmpty,
                ),

                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scan History',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${progressData.length} scans',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
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
                  ...progressData.map((scan) => _ProgressCard(
                        scan: scan,
                        primaryColor: primaryColor,
                        onTap: () => _showScanDetails(scan),
                      )),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _isLoadingMore
                          ? CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: () =>
                                  _fetchProgressData(loadMore: true),
                              child: Text('Load More'),
                            ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigationBar(primaryColor),
    );
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

class EyeHealthProgressionChart extends StatelessWidget {
  final List<int> rightEyeScores;
  final List<int> leftEyeScores;
  final List<String> labels;
  final bool isEmpty;

  const EyeHealthProgressionChart({
    required this.rightEyeScores,
    required this.leftEyeScores,
    required this.labels,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
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
                Icon(Icons.trending_up, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No progression data yet',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete multiple eye scans to see your progression',
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

    // Convert scores to FlSpot
    List<FlSpot> leftSpots = [];
    List<FlSpot> rightSpots = [];
    for (int i = 0; i < leftEyeScores.length; i++) {
      leftSpots.add(FlSpot(i.toDouble(), leftEyeScores[i].toDouble()));
    }
    for (int i = 0; i < rightEyeScores.length; i++) {
      rightSpots.add(FlSpot(i.toDouble(), rightEyeScores[i].toDouble()));
    }

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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        height: 270,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Y-axis label with more space
                  Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Text(
                          "Score",
                          style: TextStyle(
                            color: Colors.blueGrey.shade400,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 0.0, bottom: 12.0),
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: 100,
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    '${spot.bar.color == Colors.amber ? "Left" : "Right"} Eye\n'
                                    '${labels.isNotEmpty && spot.x.toInt() < labels.length ? labels[spot.x.toInt()] : ""}: '
                                    '${spot.y.toStringAsFixed(1)}%',
                                    const TextStyle(color: Colors.white),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: leftSpots,
                              isCurved: true,
                              color: Colors.amber,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            ),
                            LineChartBarData(
                              spots: rightSpots,
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 38,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < labels.length) {
                                    return Text(labels[idx],
                                        style: TextStyle(fontSize: 10));
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData:
                              FlGridData(show: true, horizontalInterval: 10),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // X-axis label
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Scan Date",
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern legend pill
class _LegendPill extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendPill({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.17),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.darken(0.3),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helper extension to darken a color

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

    // Set colors based on eye type and classification
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
                      "Health Score: ${scan["score"]}%   |   ${scan["result"]}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Visual indicator that card is tappable
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
