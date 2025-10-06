import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';
import 'symptom_assessment_screen.dart';

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
  String _formattedDateTime = "";
  String _username = "User";
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

    // Format the date
    final date = scan["date"] as DateTime;
    final formattedDate = DateFormat.yMMMMd().format(date);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with eye icon and classification
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.15),
                      radius: 25,
                      child: Icon(
                        Icons.remove_red_eye,
                        color: primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan["eye"] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              scan["classification"] as String,
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
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

                // Score visualization
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          CircularProgressIndicator(
                            value: (scan["score"] as int) / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              (scan["score"] as int) > 90
                                  ? Colors.green
                                  : primaryColor,
                            ),
                          ),
                          Text(
                            "${scan["score"]}%",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Health Score",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        scan["result"] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Scan details
                _buildDetailSection("Scan Date", formattedDate),
                _buildDetailSection("Analysis By", scan["doctor"] as String),
                _buildDetailSection("Details", scan["details"] as String),
                _buildDetailSection(
                    "Recommendations", scan["recommendations"] as String),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Scan details shared")),
                        );
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text("Share"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text("Close"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  void _onNavItemTapped(int index) {
    if (_selectedNavIndex == index) {
      return;
    }
    setState(() {
      _selectedNavIndex = index;
    });
    switch (index) {
      case 0: // Home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        break;
      case 1: // Progress (already here)
        break;
      case 2: // Eye Scan - Changed to navigate to SymptomAssessmentScreen
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
      case 3: // Reminders
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ReminderScreen()),
          (route) => false,
        );
        break;
      case 4: // Profile
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
          (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    // Extract data for chart
    List<int> rightEyeScores = [];
    List<int> leftEyeScores = [];
    List<String> labels = [];

    if (progressData.isNotEmpty) {
      // Get unique dates for labels (we'll show at most 6 dates)
      final Set<String> uniqueDates = {};
      final sortedData = List<Map<String, dynamic>>.from(progressData)
        ..sort(
            (a, b) => (a["date"] as DateTime).compareTo(b["date"] as DateTime));

      // Limit to at most 6 latest dates
      final limitedData = sortedData.length > 6
          ? sortedData.sublist(sortedData.length - 6)
          : sortedData;

      // Process data by eye type
      final rightEyeData =
          limitedData.where((scan) => scan["eye"] == "Right Eye").toList();

      final leftEyeData =
          limitedData.where((scan) => scan["eye"] == "Left Eye").toList();

      // Extract scores and dates
      rightEyeScores = rightEyeData.map((e) => e["score"] as int).toList();
      leftEyeScores = leftEyeData.map((e) => e["score"] as int).toList();

      // Create labels from all dates (right and left eye combined)
      final allDates = limitedData
          .map((e) => e["date"] as DateTime)
          .toSet()
          .toList()
        ..sort();

      labels = allDates.map((date) => DateFormat.MMMd().format(date)).toList();
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
          // Add refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchProgressData,
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
                (route) => false,
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: primaryColor.withOpacity(0.2),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFFFF6B6B),
                  size: 24,
                ),
              ),
            ),
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
                // User and date info
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): $_formattedDateTime",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            "Current User's Login: $_username",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Progress Chart Section
                _EyeHealthProgressionChart(
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
                    // Add count of scans
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

                // Show message if no scans
                if (progressData.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
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
                      ],
                    ),
                  )
                else
                  // List of Progress Cards
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

class _EyeHealthProgressionChart extends StatelessWidget {
  final List<int> rightEyeScores;
  final List<int> leftEyeScores;
  final List<String> labels;
  final bool isEmpty;

  const _EyeHealthProgressionChart({
    required this.rightEyeScores,
    required this.leftEyeScores,
    required this.labels,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 220,
        width: double.infinity,
        child: isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No progression data yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete multiple eye scans to see your progression',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Eye Health Progression',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Left Eye",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Right Eye",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: CustomPaint(
                      painter: _DualLineChartPainter(
                        rightEyeScores: rightEyeScores,
                        leftEyeScores: leftEyeScores,
                        rightEyeColor: Colors.green,
                        leftEyeColor: Colors.amber,
                      ),
                      child: Container(),
                    ),
                  ),
                  // Only show x-axis labels if we have any
                  if (labels.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ...labels.map((e) => Text(e,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700))),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}

class _DualLineChartPainter extends CustomPainter {
  final List<int> rightEyeScores;
  final List<int> leftEyeScores;
  final Color rightEyeColor;
  final Color leftEyeColor;

  _DualLineChartPainter({
    required this.rightEyeScores,
    required this.leftEyeScores,
    required this.rightEyeColor,
    required this.leftEyeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Skip if no data
    if (rightEyeScores.isEmpty && leftEyeScores.isEmpty) return;

    // Set min/max scores for y-axis scaling
    double minScore = 0;
    double maxScore = 100;

    // Create paints
    final rightEyePaint = Paint()
      ..color = rightEyeColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final leftEyePaint = Paint()
      ..color = leftEyeColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final rightEyeDotPaint = Paint()
      ..color = rightEyeColor
      ..style = PaintingStyle.fill;

    final leftEyeDotPaint = Paint()
      ..color = leftEyeColor
      ..style = PaintingStyle.fill;

    final double chartHeight = size.height - 20;
    final double chartWidth = size.width;

    // Draw right eye line
    if (rightEyeScores.isNotEmpty) {
      final rightEyePoints = <Offset>[];
      final double dxStep = chartWidth /
          (rightEyeScores.length > 1 ? rightEyeScores.length - 1 : 1);

      for (int i = 0; i < rightEyeScores.length; i++) {
        final x = dxStep * i;
        final double normalized =
            (rightEyeScores[i] - minScore) / (maxScore - minScore);
        final y = chartHeight - normalized * (chartHeight - 20) + 10;
        rightEyePoints.add(Offset(x, y));
      }

      // Draw line for right eye
      for (int i = 0; i < rightEyePoints.length - 1; i++) {
        canvas.drawLine(
            rightEyePoints[i], rightEyePoints[i + 1], rightEyePaint);
      }

      // Draw dots for right eye
      for (final p in rightEyePoints) {
        canvas.drawCircle(p, 6, rightEyeDotPaint);
        canvas.drawCircle(
            p, 9, rightEyeDotPaint..color = rightEyeColor.withOpacity(0.15));
        rightEyeDotPaint.color = rightEyeColor; // Reset after opacity
      }
    }

    // Draw left eye line
    if (leftEyeScores.isNotEmpty) {
      final leftEyePoints = <Offset>[];
      final double dxStep = chartWidth /
          (leftEyeScores.length > 1 ? leftEyeScores.length - 1 : 1);

      for (int i = 0; i < leftEyeScores.length; i++) {
        final x = dxStep * i;
        final double normalized =
            (leftEyeScores[i] - minScore) / (maxScore - minScore);
        final y = chartHeight - normalized * (chartHeight - 20) + 10;
        leftEyePoints.add(Offset(x, y));
      }

      // Draw line for left eye
      for (int i = 0; i < leftEyePoints.length - 1; i++) {
        canvas.drawLine(leftEyePoints[i], leftEyePoints[i + 1], leftEyePaint);
      }

      // Draw dots for left eye
      for (final p in leftEyePoints) {
        canvas.drawCircle(p, 6, leftEyeDotPaint);
        canvas.drawCircle(
            p, 9, leftEyeDotPaint..color = leftEyeColor.withOpacity(0.15));
        leftEyeDotPaint.color = leftEyeColor; // Reset after opacity
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
