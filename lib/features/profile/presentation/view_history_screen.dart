import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/features/eye_scan/presentation/full_report_screen.dart';
import 'package:flutter_application_1/features/home/presentation/home_screen.dart';
import 'package:flutter_application_1/features/profile/presentation/profile_screen.dart';
import 'package:flutter_application_1/features/profile/presentation/progress_screen.dart';
import 'package:flutter_application_1/features/reminders/presentation/reminder_screen.dart';
import 'package:flutter_application_1/features/symptom_assessment/presentation/symptom_assessment_screen.dart';
import 'package:flutter_application_1/services/offline_sync_service.dart';

class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({super.key});

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  int _selectedNavIndex = 2; // Default to Eye Scan tab (middle tab)

  // Replace dummy data with a list that will be populated from Firebase
  List<Map<String, dynamic>> scanHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchScanHistory();
  }

  // Method to fetch scan history from Firebase
  Future<void> _fetchScanHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use OfflineSyncService to get ALL scans (online + offline)
      final List<Map<String, dynamic>> allScans =
          await OfflineSyncService().getAllScans();

      // Convert to list of maps for the UI
      final List<Map<String, dynamic>> scans = [];

      for (var data in allScans) {
        // Handle both Timestamp and String timestamps
        dynamic timestamp = data['timestamp'];
        DateTime? dateTime;

        if (timestamp is Timestamp) {
          dateTime = timestamp.toDate();
        } else if (timestamp is String) {
          dateTime = DateTime.tryParse(timestamp);
        }

        // Format date and time
        final date = dateTime != null
            ? "${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)}"
            : "Unknown date";

        final time = dateTime != null
            ? "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}"
            : "Unknown time";

        // Get prediction and confidence
        final prediction = data['prediction'] as String? ?? 'Unknown';
        final confidence = data['confidence'] as double? ?? 0.0;
        final eye = data['eye'] as String? ?? 'Unknown';

        // Determine classification and result
        final bool isNormal = prediction.toLowerCase().contains('normal') ||
            prediction.toLowerCase() == "no cataract";

        final classification = isNormal ? 'Normal' : 'Immature';
        final result = isNormal ? 'No Cataract' : 'Initial Stage';

        // Add to scan history
        scans.add({
          "id": data['scanId'] ??
              data['id'] ??
              'unknown', // Support multiple ID fields
          "date": date,
          "time": time,
          "eye": eye,
          "healthScore": data['healthScore'] != null
              ? "${data['healthScore'].round()}%"
              : "${(confidence * 100).round()}%",
          "classification": classification,
          "result": result,
          "source": data['source'] ?? 'firestore', // Track source
          "rawData": data,
        });
      }

      setState(() {
        scanHistory = scans;
        _isLoading = false;
      });

      print('✅ History loaded: ${scanHistory.length} scans');
    } catch (e) {
      print('Error fetching scan history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  void _onNavItemTapped(int index) {
    if (_selectedNavIndex == index) return; // Already on this tab

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
      case 1: // Progress
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProgressScreen()),
          (route) => false,
        );
        break;
      case 2: // Eye Scan
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
      default:
        break;
    }
  }

  String _getNavItemName(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Progress';
      case 2:
        return 'Eye Scan';
      case 3:
        return 'Reminders';
      case 4:
        return 'Profile';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Scan History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Add a refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchScanHistory,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : scanHistory.isEmpty
              ? Center(
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
                        'Complete an eye scan to see your history',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: scanHistory.length,
                  itemBuilder: (context, index) {
                    final scan = scanHistory[index];
                    final isRightEye = scan["eye"] == "Right Eye";

                    // Determine colors based on classification
                    final Color statusColor = scan["classification"] == "Normal"
                        ? Colors.green
                        : Colors.amber;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        leading: CircleAvatar(
                          backgroundColor: isRightEye
                              ? Colors.green.withOpacity(0.15)
                              : Colors.amber.withOpacity(0.15),
                          child: Icon(
                            Icons.remove_red_eye,
                            color: isRightEye ? Colors.green : Colors.amber,
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${scan["eye"]}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                scan["classification"],
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
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Date: ${scan["date"]}  •  Time: ${scan["time"]}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Health Score: ${scan["healthScore"]}   |   ${scan["result"]}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FullReportScreen(scanId: scan["id"]),
                            ),
                          );
                        },
                      ),
                    );
                  },
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
