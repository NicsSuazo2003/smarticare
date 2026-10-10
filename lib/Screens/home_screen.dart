import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_application_1/Screens/latest_scan_cache.dart';
import 'package:flutter_application_1/services/offline_sync_service.dart';
import 'package:flutter_application_1/services/ml/staging_service.dart';
import 'symptom_assessment_screen.dart';
import 'find_clinics_screen.dart';
import 'appointments_screen.dart';
import 'progress_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';
import 'activity_log_screen.dart';
import 'view_history_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shimmer/shimmer.dart';
import 'full_report_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool refreshData;

  const HomeScreen({
    super.key,
    this.refreshData = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  late String _formattedDateTime;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String _username = "";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _recentScans = [];
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Map<String, dynamic> _eyeHealthData = {
    'leftEye': {'status': '', 'score': 0, 'stage': ''},
    'rightEye': {'status': '', 'score': 0, 'stage': ''},
    'overallScore': 0
  };
  bool _isLoadingMetrics = true;

  @override
  void initState() {
    super.initState();
    print("HomeScreen initState called");

    _updateDateTime();
    _fetchEyeHealthData();
    _fetchRecentActivities();
    _fetchRecentScans();
    _setupConnectivityListener();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'reminder_channel', // channel id
              'Reminders', // channel name
              channelDescription: 'Channel for reminder notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    if (widget.refreshData) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _fetchEyeHealthData();
        _fetchRecentScans();
      });
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        if (result != ConnectivityResult.none) {
          print('🌐 Back online - checking for pending sync...');

          // Check sync stats first
          final syncStats = await OfflineSyncService().getSyncStats();
          if (syncStats['totalPending']! > 0) {
            print(
                '🔄 Found ${syncStats['totalPending']} pending items - starting sync...');
            await OfflineSyncService().syncAllPendingData();

            // Refresh data after sync
            _fetchEyeHealthData();
            _fetchRecentScans();
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchRecentScans() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return;
      }

      final List<Map<String, dynamic>> allScans =
          await OfflineSyncService().getAllScans();

      allScans.sort((a, b) {
        final aTime = a['timestamp']?.toString() ?? '';
        final bTime = b['timestamp']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });

      setState(() {
        _recentScans = allScans;
      });

      print('Loaded ${_recentScans.length} scans (online + offline)');
    } catch (e) {
      print('Error fetching recent scans: $e');
    }
  }

  Color _getStatusColor(String status, bool isLeftEye) {
    final s = status.toLowerCase();
    if (s == 'normal') return Colors.green;
    if (s == 'immature') return Colors.amber;
    if (s == 'mature') return Colors.orange; // NEW
    if (s == 'advanced') return Colors.red; // NEW
    if (s == 'unknown') return Colors.grey;
    return isLeftEye ? Colors.amber : Colors.green;
  }

  String getEyeHealthStatusTitle() {
    final leftScore = _eyeHealthData['leftEye']['score'] as int;
    final rightScore = _eyeHealthData['rightEye']['score'] as int;
    final leftStatus = _eyeHealthData['leftEye']['status'] as String;
    final rightStatus = _eyeHealthData['rightEye']['status'] as String;

    if (leftScore == 0 && rightScore == 0) {
      return "No Data Yet";
    }

    final leftNeedsAttention =
        leftScore < 60 && leftStatus != 'Normal' && leftStatus != 'Unknown';
    final rightNeedsAttention =
        rightScore < 60 && rightStatus != 'Normal' && rightStatus != 'Unknown';

    final leftEarlyWarning =
        leftScore >= 60 && leftScore < 80 && leftStatus != 'Normal';
    final rightEarlyWarning =
        rightScore >= 60 && rightScore < 80 && rightStatus != 'Normal';

    // If EITHER eye needs urgent attention
    if (leftNeedsAttention || rightNeedsAttention) {
      return "Attention Needed";
    }

    // If EITHER eye needs monitoring
    if (leftEarlyWarning || rightEarlyWarning) {
      return "Monitor Health";
    }

    // Both eyes are healthy
    return "Healthy Eyes";
  }

  Color _getOverallHealthColor() {
    final overallScore = _eyeHealthData['overallScore'] as int;

    if (overallScore >= 80) {
      return Colors.white;
    } else if (overallScore >= 60) {
      return Colors.white;
    } else if (overallScore > 0) {
      return Colors.white;
    } else {
      return Colors.white70;
    }
  }

  String _getHealthDescription() {
    final leftScore = _eyeHealthData['leftEye']['score'] as int;
    final rightScore = _eyeHealthData['rightEye']['score'] as int;
    final leftStatus = _eyeHealthData['leftEye']['status'] as String;
    final rightStatus = _eyeHealthData['rightEye']['status'] as String;

    // Check each eye INDIVIDUALLY (DON'T average)
    final leftNeedsAttention =
        leftScore < 60 && leftStatus != 'Normal' && leftStatus != 'Unknown';
    final rightNeedsAttention =
        rightScore < 60 && rightStatus != 'Normal' && rightStatus != 'Unknown';

    final leftEarlyWarning =
        leftScore >= 60 && leftScore < 80 && leftStatus != 'Normal';
    final rightEarlyWarning =
        rightScore >= 60 && rightScore < 80 && rightStatus != 'Normal';

    if (leftNeedsAttention && rightNeedsAttention) {
      return "Both Eyes:  Cataract detected. Please consult a specialist soon.";
    }

    if (leftNeedsAttention && !rightNeedsAttention) {
      return "Left Eye:  Cataract detected.  Please consult a specialist soon.";
    }

    if (rightNeedsAttention && !leftNeedsAttention) {
      return "Right Eye:  Cataract detected. Please consult a specialist soon.";
    }

    if (leftEarlyWarning && rightEarlyWarning) {
      return "Both Eyes: Early signs detected.  Regular monitoring recommended.";
    }

    if (leftEarlyWarning && !rightEarlyWarning) {
      return "Left Eye: Early signs detected. Regular monitoring recommended.";
    }

    if (rightEarlyWarning && !leftEarlyWarning) {
      return "Right Eye:  Early signs detected. Regular monitoring recommended. ";
    }

    return "Both eyes are in excellent condition with no signs of cataract.";
  }

  List<Map<String, dynamic>> _recentActivities = [];
  bool _loadingActivities = true;

  Future<void> _fetchRecentActivities() async {
    setState(() => _loadingActivities = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _recentActivities = [];
        _loadingActivities = false;
      });
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('audit_logs')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(3) // fetch the latest 3 activities
        .get();

    final mapped = snapshot.docs.map((doc) {
      final data = doc.data();
      final action = data['action'] as String? ?? '';
      final DateTime ts =
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

      IconData icon = Icons.help_outline;
      Color color = Colors.grey;
      String title = action;
      String subtitle = data['details'] ?? '';

      switch (action) {
        case 'scan_completed':
          icon = Icons.camera_alt;
          color = const Color(0xFFFF6B6B);
          title = "Eye Scan Completed";
          break;
        case 'symptom_assessment_completed':
          icon = Icons.help;
          color = Colors.teal;
          title = "Symptom Assessment";
          break;
        case 'appointment_completed':
          icon = Icons.local_hospital;
          color = Colors.blue;
          title = "Doctor's Appointment Completed";
          break;
        case 'appointment_cancelled':
          icon = Icons.local_hospital;
          color = Colors.red;
          title = "Doctor's Appointment Cancelled";
          break;
        case 'reminder_created':
          icon = Icons.notification_important;
          color = Colors.amber;
          title = "Reminder Created";
          break;
        case 'reminder_completed':
          icon = Icons.notification_important;
          color = Colors.green;
          title = "Reminder Completed";
          break;
        case 'reminder_deleted':
          icon = Icons.delete_outline;
          color = Colors.red;
          title = "Reminder Deleted";
          break;
        case 'profile_updated':
          icon = Icons.person;
          color = Colors.purple;
          title = "Profile Updated";
          break;
        case 'password_changed':
          icon = Icons.lock;
          color = Colors.deepPurple;
          title = "Password Changed";
          break;
        case 'email_changed':
          icon = Icons.email;
          color = Colors.orange;
          title = "Email Changed";
          break;
        case 'account_deleted':
          icon = Icons.person_off;
          color = Colors.redAccent;
          title = "Account Deleted";
          break;
        default:
          title = action.replaceAll('_', ' ').replaceFirstMapped(
                RegExp(r'^\w'),
                (m) => m.group(0)!.toUpperCase(),
              );
      }

      final time =
          "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";

      return {
        "icon": icon,
        "color": color,
        "title": title,
        "subtitle": subtitle,
        "time": time,
      };
    }).toList();

    setState(() {
      _recentActivities = mapped;
      _loadingActivities = false;
    });
  }

  List<FlSpot> _generateScanCountSpots() {
    final leftCount = _recentScans
        .where((scan) => (scan['eye'] as String?)?.toLowerCase() == 'left eye')
        .length;
    final rightCount = _recentScans
        .where((scan) => (scan['eye'] as String?)?.toLowerCase() == 'right eye')
        .length;
    return [
      FlSpot(0, leftCount.toDouble()),
      FlSpot(1, rightCount.toDouble()),
    ];
  }

  Future<void> _fetchEyeHealthData() async {
    try {
      print('🔵 _fetchEyeHealthData START');
      setState(() {
        _isLoadingMetrics = true;
      });

      final userId = FirebaseAuth.instance.currentUser?.uid;
      print('🔵 userId: $userId');

      if (userId == null) {
        print('🔴 No userId - aborting');
        setState(() {
          _isLoadingMetrics = false;
        });
        return;
      }

      Map<String, dynamic> leftEyeData = {
        'status': 'Unknown',
        'score': 0,
        'stage': 'No Data'
      };

      Map<String, dynamic> rightEyeData = {
        'status': 'Unknown',
        'score': 0,
        'stage': 'No Data'
      };

      bool leftFetched = false;
      bool rightFetched = false;

      bool isOnline = true;
      try {
        final connectivity = Connectivity();
        final result = await connectivity.checkConnectivity();
        isOnline = result != ConnectivityResult.none;
        print(' Online:  $isOnline');
      } catch (e) {
        print('Connectivity check failed: $e');
        isOnline = false;
      }

      if (isOnline) {
        print('Fetching from Firestore.. .');
        try {
          final leftEyeQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('scans')
              .where('eye', isEqualTo: 'Left Eye')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));

          print(' Left eye query returned ${leftEyeQuery.docs.length} docs');

          if (leftEyeQuery.docs.isNotEmpty) {
            final doc = leftEyeQuery.docs.first;
            final data = doc.data();
            print('Left eye raw data: $data');

            final prediction = data['prediction'] as String? ?? '';
            final double healthScore =
                (data['healthScore'] as num?)?.toDouble() ?? 0.0;
            final double confidence =
                (data['confidence'] as num?)?.toDouble() ?? 0.0;
            final double symptomScore =
                (data['symptomScore'] as num?)?.toDouble() ?? 0.0;

            final String stage = StagingService.determineStage(
              prediction: prediction,
              symptomScore: symptomScore.clamp(0.0, 1.0),
              confidence: confidence.clamp(0.0, 1.0),
            );

            final double finalScore =
                healthScore > 0 ? healthScore : (confidence * 100);

            leftEyeData = {
              'status': stage,
              'score': finalScore.round().clamp(0, 100),
              'stage': stage == 'Normal' ? 'No Cataract' : stage
            };

            LatestScanCache.updateLeftEye(prediction, finalScore);
            leftFetched = true;
          } else {
            print('⚠️ No left eye scans found in Firestore');
          }

          final rightEyeQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('scans')
              .where('eye', isEqualTo: 'Right Eye')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));

          print(' Right eye query returned ${rightEyeQuery.docs.length} docs');

          if (rightEyeQuery.docs.isNotEmpty) {
            final doc = rightEyeQuery.docs.first;
            final data = doc.data();
            print('Right eye raw data: $data');

            final prediction = data['prediction'] as String? ?? '';
            final double healthScore =
                (data['healthScore'] as num?)?.toDouble() ?? 0.0;
            final double confidence =
                (data['confidence'] as num?)?.toDouble() ?? 0.0;
            final double symptomScore =
                (data['symptomScore'] as num?)?.toDouble() ?? 0.0;

            final String stage = StagingService.determineStage(
              prediction: prediction,
              symptomScore: symptomScore.clamp(0.0, 1.0),
              confidence: confidence.clamp(0.0, 1.0),
            );

            final double finalScore =
                healthScore > 0 ? healthScore : (confidence * 100);

            rightEyeData = {
              'status': stage,
              'score': finalScore.round().clamp(0, 100),
              'stage': stage == 'Normal' ? 'No Cataract' : stage
            };

            LatestScanCache.updateRightEye(prediction, finalScore);
            rightFetched = true;
          } else {
            print(' No right eye scans found in Firestore');
          }
        } catch (e) {
          print(' Firestore fetch error: $e');
          isOnline = false; // Treat as offline
        }
      }

      if (!leftFetched && !isOnline) {
        print(' Checking OFFLINE LEFT eye data...');
        try {
          final allScans = await OfflineSyncService().getAllScans();
          final leftScans = allScans
              .where((scan) =>
                  (scan['eye'] as String?)?.toLowerCase() == 'left eye')
              .toList();

          if (leftScans.isNotEmpty) {
            final latestLeftScan = leftScans.first;
            final prediction = latestLeftScan['prediction'] as String? ?? '';
            final double healthScore =
                (latestLeftScan['healthScore'] as num?)?.toDouble() ?? 0.0;
            final double confidence =
                (latestLeftScan['confidence'] as num?)?.toDouble() ?? 0.0;
            final double symptomScore =
                (latestLeftScan['symptomScore'] as num?)?.toDouble() ?? 0.0;

            final String stage = StagingService.determineStage(
              prediction: prediction,
              symptomScore: symptomScore.clamp(0.0, 1.0),
              confidence: confidence.clamp(0.0, 1.0),
            );

            final double finalScore =
                healthScore > 0 ? healthScore : (confidence * 100);

            leftEyeData = {
              'status': stage,
              'score': finalScore.round().clamp(0, 100),
              'stage': stage == 'Normal' ? 'No Cataract' : stage
            };

            print(
                '📦 LEFT eye from offline cache: $prediction, ${finalScore.round()}%');
            leftFetched = true;
          } else {
            print('⚠️ No left eye scans in offline cache');
          }
        } catch (e) {
          print('⚠️ Error fetching offline left eye data: $e');
        }
      }

      if (!rightFetched && !isOnline) {
        print('📴 Checking OFFLINE RIGHT eye data...');
        try {
          final allScans = await OfflineSyncService().getAllScans();
          final rightScans = allScans
              .where((scan) =>
                  (scan['eye'] as String?)?.toLowerCase() == 'right eye')
              .toList();

          if (rightScans.isNotEmpty) {
            final latestRightScan = rightScans.first;
            final prediction = latestRightScan['prediction'] as String? ?? '';
            final double healthScore =
                (latestRightScan['healthScore'] as num?)?.toDouble() ?? 0.0;
            final double confidence =
                (latestRightScan['confidence'] as num?)?.toDouble() ?? 0.0;
            final double symptomScore =
                (latestRightScan['symptomScore'] as num?)?.toDouble() ?? 0.0;

            final String stage = StagingService.determineStage(
              prediction: prediction,
              symptomScore: symptomScore.clamp(0.0, 1.0),
              confidence: confidence.clamp(0.0, 1.0),
            );

            final double finalScore =
                healthScore > 0 ? healthScore : (confidence * 100);

            rightEyeData = {
              'status': stage,
              'score': finalScore.round().clamp(0, 100),
              'stage': stage == 'Normal' ? 'No Cataract' : stage
            };

            print(
                '📦 RIGHT eye from offline cache: $prediction, ${finalScore.round()}%');
            rightFetched = true;
          } else {
            print('⚠️ No right eye scans in offline cache');
          }
        } catch (e) {
          print('⚠️ Error fetching offline right eye data: $e');
        }
      }

      int overallScore = 0;
      if ((leftEyeData['score'] as num) > 0 ||
          (rightEyeData['score'] as num) > 0) {
        int divisor = 0;
        int sum = 0;

        if ((leftEyeData['score'] as num) > 0) {
          sum += (leftEyeData['score'] as num).toInt();
          divisor++;
        }

        if ((rightEyeData['score'] as num) > 0) {
          sum += (rightEyeData['score'] as num).toInt();
          divisor++;
        }

        overallScore = divisor > 0 ? (sum / divisor).round() : 0;
      }

      print(
          ' Final data - Left:  ${leftEyeData['score']}%, Right: ${rightEyeData['score']}%, Overall: $overallScore%');

      setState(() {
        _eyeHealthData = {
          'leftEye': leftEyeData,
          'rightEye': rightEyeData,
          'overallScore': overallScore
        };
        _isLoadingMetrics = false;
      });
    } catch (e) {
      print('❌ Error in _fetchEyeHealthData: $e');
      setState(() {
        _isLoadingMetrics = false;
      });
    }
  }

  void _updateDateTime() {
    // Get actual current date/time in UTC
    final now = DateTime.now().toUtc();
    final formatted =
        "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} "
        "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}";

    setState(() {
      _formattedDateTime = formatted;
    });

    // Try to get username from Firebase
    _fetchUsername();
  }

  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  Future<void> _fetchUsername() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
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

  void _onNavItemTapped(int index) {
    if (index == 2) {
      // Show disclaimer dialog for eye scan
      _showEyeScanDisclaimer(context, false);
      return; // Don't update selected index for Eye Scan
    }

    if (_selectedNavIndex == index) {
      return;
    }

    setState(() {
      _selectedNavIndex = index;
    });

    switch (index) {
      case 0: // Home
        break;
      case 1: // Progress
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProgressScreen()),
          (route) => false,
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

  // Helper method for score range tooltip
  Widget _buildScoreRangeTooltip({
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

// Helper method for eye status example
  Widget _buildEyeStatusExample({
    required Color color,
    required String status,
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
                status,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
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

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);
    const Color secondaryColor = Color(0xFF4A6572);
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/icon.png',
                              fit: BoxFit.cover,
                              width: 40,
                              height: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SmartiCare',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Profile avatar
                    GestureDetector(
                      onTap: () {
                        // Navigate to profile when avatar is tapped
                        _onNavItemTapped(4);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _username.isNotEmpty
                                ? _username[0].toUpperCase()
                                : "A",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // User greeting
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Hello, $_username",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "👋",
                          style: TextStyle(
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Monitor your eye health and detect cataract",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // Eye Health Score Card
              // Eye Health Score Card
              // Eye Health Score Card
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade700,
                        Colors.blue.shade800,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoadingMetrics
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Health Status with tooltip
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    getEyeHealthStatusTitle(),
                                                    style: TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          _getOverallHealthColor(),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Tooltip icon
                                                  InkWell(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) =>
                                                            AlertDialog(
                                                          title: Row(
                                                            children: [
                                                              Icon(
                                                                  Icons
                                                                      .info_outline,
                                                                  color: Colors
                                                                      .blue
                                                                      .shade700),
                                                              SizedBox(
                                                                  width: 12),
                                                              Text(
                                                                  'Overall Health Score'),
                                                            ],
                                                          ),
                                                          content:
                                                              SingleChildScrollView(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Text(
                                                                  'What does this score mean?',
                                                                  style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          16),
                                                                ),
                                                                SizedBox(
                                                                    height: 8),
                                                                Text(
                                                                  'Your Overall Health Score is the average of both eyes\' health scores.',
                                                                  style: TextStyle(
                                                                      height:
                                                                          1.5),
                                                                ),
                                                                SizedBox(
                                                                    height: 16),
                                                                _buildScoreRangeTooltip(
                                                                  color: Colors
                                                                      .green,
                                                                  range:
                                                                      '80-100%',
                                                                  label:
                                                                      'Healthy',
                                                                  description:
                                                                      'Both eyes are in excellent condition',
                                                                ),
                                                                SizedBox(
                                                                    height: 12),
                                                                _buildScoreRangeTooltip(
                                                                  color: Colors
                                                                      .orange,
                                                                  range:
                                                                      '60-79%',
                                                                  label:
                                                                      'Monitor',
                                                                  description:
                                                                      'Early signs detected. Schedule follow-up',
                                                                ),
                                                                SizedBox(
                                                                    height: 12),
                                                                _buildScoreRangeTooltip(
                                                                  color: Colors
                                                                      .red,
                                                                  range:
                                                                      'Below 60%',
                                                                  label:
                                                                      'Attention Needed',
                                                                  description:
                                                                      'Cataract detected. Consult specialist',
                                                                ),
                                                                SizedBox(
                                                                    height: 16),
                                                                Container(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .all(
                                                                              12),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .blue
                                                                        .shade50,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  child: Row(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Icon(
                                                                          Icons
                                                                              .tips_and_updates,
                                                                          color: Colors
                                                                              .blue
                                                                              .shade700,
                                                                          size:
                                                                              20),
                                                                      SizedBox(
                                                                          width:
                                                                              8),
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          'The score combines AI analysis and your symptom assessment for accuracy.',
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                            color:
                                                                                Colors.blue.shade900,
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
                                                              child: Text(
                                                                  'Got It'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.2),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.help_outline,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                width: size.width * 0.6,
                                                child: Text(
                                                  _getHealthDescription(),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Score Circle
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              // Your Eye Health Section
              // Your Eye Health Section
              // Your Eye Health Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Your Eye Health",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(Icons.remove_red_eye,
                                        color: Colors.blue.shade700),
                                    SizedBox(width: 12),
                                    Text('Individual Eye Health'),
                                  ],
                                ),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Understanding Your Eye Health Cards',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Each card shows the health status of one eye based on your most recent scan.',
                                        style: TextStyle(height: 1.5),
                                      ),
                                      SizedBox(height: 16),
                                      _buildEyeStatusExample(
                                        color: Colors.green,
                                        status: 'Normal',
                                        description:
                                            'No signs of cataract detected',
                                        icon: Icons.check_circle,
                                      ),
                                      SizedBox(height: 12),
                                      _buildEyeStatusExample(
                                        color: Colors.amber,
                                        status: 'Immature',
                                        description:
                                            'Early stage cataract detected',
                                        icon: Icons.warning_amber,
                                      ),
                                      SizedBox(height: 12),
                                      _buildEyeStatusExample(
                                        color: Colors.grey,
                                        status: 'Unknown',
                                        description:
                                            'No scan data available yet',
                                        icon: Icons.help_outline,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'What is the percentage bar?',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'The percentage shows your eye health score (0-100%). Higher scores mean better eye health.',
                                        style: TextStyle(
                                            height: 1.5, fontSize: 14),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Left and Right Eye Cards
                    Row(
                      children: [
                        // Left Eye Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isLoadingMetrics
                                ? Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.amber))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                      _eyeHealthData['leftEye']
                                                          ['status'],
                                                      true)
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.remove_red_eye,
                                              color: _getStatusColor(
                                                  _eyeHealthData['leftEye']
                                                      ['status'],
                                                  true),
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Left Eye",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _eyeHealthData['leftEye']['status'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(
                                              _eyeHealthData['leftEye']
                                                  ['status'],
                                              true),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _eyeHealthData['leftEye']['stage'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // FIXED: Use proper width calculation for left eye
                                      Container(
                                        width: double.infinity,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            double leftPercent =
                                                ((_eyeHealthData['leftEye']
                                                                ['score'] ??
                                                            0) /
                                                        100.0)
                                                    .clamp(0.0, 1.0);
                                            double leftBarWidth =
                                                constraints.maxWidth *
                                                    leftPercent;
                                            return Row(
                                              children: [
                                                Container(
                                                  width: leftBarWidth,
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                        _eyeHealthData[
                                                                'leftEye']
                                                            ['status'],
                                                        true),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            3),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${_eyeHealthData['leftEye']['score']}%",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Right Eye Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isLoadingMetrics
                                ? Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.green))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                      _eyeHealthData['rightEye']
                                                          ['status'],
                                                      false)
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.remove_red_eye,
                                              color: _getStatusColor(
                                                  _eyeHealthData['rightEye']
                                                      ['status'],
                                                  false),
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Right Eye",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _eyeHealthData['rightEye']['status'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(
                                              _eyeHealthData['rightEye']
                                                  ['status'],
                                              false),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _eyeHealthData['rightEye']['stage'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // FIXED: Use proper width calculation for right eye
                                      Container(
                                        width: double.infinity,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            double rightPercent =
                                                ((_eyeHealthData['rightEye']
                                                                ['score'] ??
                                                            0) /
                                                        100.0)
                                                    .clamp(0.0, 1.0);
                                            double rightBarWidth =
                                                constraints.maxWidth *
                                                    rightPercent;
                                            return Row(
                                              children: [
                                                Container(
                                                  width: rightBarWidth,
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                        _eyeHealthData[
                                                                'rightEye']
                                                            ['status'],
                                                        false),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            3),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${_eyeHealthData['rightEye']['score']}%",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Data Analysis Chart
              // ...inside your build method...

              // ...inside your build method...

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Number of Scans per Eye",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _onNavItemTapped(1);
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
                    const SizedBox(height: 18),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 18),
                        child: _recentScans.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.insert_chart_outlined,
                                        size: 44, color: Colors.grey.shade400),
                                    const SizedBox(height: 14),
                                    Text(
                                      'No scan data available yet',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Complete eye scans to see your progress',
                                      style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  minY: 0,
                                  maxY: (_recentScans.length < 5)
                                      ? 5
                                      : _recentScans.length.toDouble(),
                                  barTouchData: BarTouchData(enabled: true),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          switch (value.toInt()) {
                                            case 0:
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 6),
                                                child: Text(
                                                  'Left Eye',
                                                  style: TextStyle(
                                                    color: Colors.amber[800],
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              );
                                            case 1:
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 6),
                                                child: Text(
                                                  'Right Eye',
                                                  style: TextStyle(
                                                    color: Colors.green[700],
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              );
                                            default:
                                              return const SizedBox.shrink();
                                          }
                                        },
                                        reservedSize: 44,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          // Only show every 2nd or 5th value (depending on range)
                                          final maxY = (_recentScans.length < 5)
                                              ? 5
                                              : _recentScans.length.toDouble();
                                          // If range is small, show every other number
                                          if (maxY <= 10) {
                                            if (value % 2 == 0) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 6),
                                                child: Text(
                                                  '${value.toInt()}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              );
                                            }
                                          } else {
                                            // For larger ranges, show every 5th value
                                            if (value % 5 == 0) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 6),
                                                child: Text(
                                                  '${value.toInt()}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                          return const SizedBox.shrink();
                                        },
                                        reservedSize: 40,
                                        interval: 1,
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: 1,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: Colors.grey.shade200,
                                      strokeWidth: 1.5,
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: [
                                    BarChartGroupData(
                                      x: 0,
                                      barRods: [
                                        BarChartRodData(
                                          toY: _recentScans
                                              .where((scan) =>
                                                  (scan['eye'] as String?)
                                                      ?.toLowerCase() ==
                                                  'left eye')
                                              .length
                                              .toDouble(),
                                          color: Colors.amber[700],
                                          width: 32,
                                          borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(10),
                                              topRight: Radius.circular(10)),
                                          backDrawRodData:
                                              BackgroundBarChartRodData(
                                            show: true,
                                            toY: (_recentScans.length < 5)
                                                ? 5
                                                : _recentScans.length
                                                    .toDouble(),
                                            color:
                                                Colors.amber.withOpacity(0.08),
                                          ),
                                        ),
                                      ],
                                    ),
                                    BarChartGroupData(
                                      x: 1,
                                      barRods: [
                                        BarChartRodData(
                                          toY: _recentScans
                                              .where((scan) =>
                                                  (scan['eye'] as String?)
                                                      ?.toLowerCase() ==
                                                  'right eye')
                                              .length
                                              .toDouble(),
                                          color: Colors.green[600],
                                          width: 32,
                                          borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(10),
                                              topRight: Radius.circular(10)),
                                          backDrawRodData:
                                              BackgroundBarChartRodData(
                                            show: true,
                                            toY: (_recentScans.length < 5)
                                                ? 5
                                                : _recentScans.length
                                                    .toDouble(),
                                            color:
                                                Colors.green.withOpacity(0.08),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick action items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickAction(
                          icon: Icons.location_on,
                          color: Colors.blue,
                          label: "Find Clinics",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FindClinicsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildQuickAction(
                          icon: Icons.calendar_today,
                          color: Colors.green,
                          label: "Referral",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AppointmentsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildQuickAction(
                          icon: Icons.history,
                          color: Colors.purple,
                          label: "View History",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ViewHistoryScreen(),
                              ),
                            );
                          },
                        ),
                        _buildQuickAction(
                          icon: Icons.document_scanner,
                          color: primaryColor,
                          label: "Recent Scan",
                          onTap: () {
                            // Check if there are any scans before navigating
                            if (_recentScans.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'No scan data available yet. Please complete an eye scan first.'),
                                  duration: Duration(seconds: 3),
                                  action: SnackBarAction(
                                    label: 'Start Scan',
                                    onPressed: () {
                                      _showEyeScanDisclaimer(context, true);
                                    },
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FullReportScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Recent Activity
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recent Activity",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ActivityLogScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(60, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text("See All"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _loadingActivities
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: _recentActivities.isEmpty
                                ? [
                                    Text(
                                      "No recent activity.",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ]
                                : _recentActivities.map((activity) {
                                    return _buildActivityItem(
                                      icon: activity["icon"],
                                      color: activity["color"],
                                      title: activity["title"],
                                      subtitle: activity["subtitle"],
                                      time: activity["time"],
                                    );
                                  }).toList(),
                          )
                  ],
                ),
              ),

              // Extra space at bottom for navigation bar
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(primaryColor),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(
          5,
          (index) => Container(
            margin: EdgeInsets.only(bottom: 16),
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
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
        // Eye Scan as the center item with a special design
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

  Widget _buildQuickAction({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this method in _HomeScreenState class (around line 800-850)
  void _showEyeScanDisclaimer(BuildContext context, bool fromQuickAction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool hasAgreed = false;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Text(
                  'Eye Scan Data Storage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Before proceeding with your eye scan, please review how your data will be stored:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data storage points
                  _buildDisclaimerPoint(
                    icon: Icons.cloud_upload,
                    color: Colors.blue,
                    title: 'Cloud Storage',
                    description:
                        'Your scan results will be securely stored in our cloud database (Firebase) for tracking and monitoring.',
                  ),
                  const SizedBox(height: 12),

                  _buildDisclaimerPoint(
                    icon: Icons.devices,
                    color: Colors.green,
                    title: 'Local Storage',
                    description:
                        'Data will also be stored locally on your device when offline and automatically synchronized when online.',
                  ),
                  const SizedBox(height: 12),

                  _buildDisclaimerPoint(
                    icon: Icons.shield,
                    color: Colors.purple,
                    title: 'Data Security',
                    description:
                        'All data is encrypted and only accessible to authorized health administrators for monitoring purposes.',
                  ),
                  const SizedBox(height: 12),

                  _buildDisclaimerPoint(
                    icon: Icons.visibility,
                    color: Colors.orange,
                    title: 'Accessibility',
                    description:
                        'You can view, track, and delete your scan history at any time through the Progress section.',
                  ),
                  const SizedBox(height: 16),

                  const Divider(),
                  const SizedBox(height: 12),

                  // Agreement checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: hasAgreed,
                        onChanged: (value) {
                          setState(() {
                            hasAgreed = value ?? false;
                          });
                        },
                        activeColor: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'I understand and agree',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'I acknowledge that my eye scan data will be stored as described above for health monitoring purposes.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Log that user declined
                  _logDisclaimerAction('declined');
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: !hasAgreed
                    ? null
                    : () async {
                        // Log agreement
                        await _logDisclaimerAction('accepted');

                        Navigator.pop(context);

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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text('Continue to Scan'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisclaimerPoint({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logDisclaimerAction(String action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'action': 'eye_scan_disclaimer_$action',
        'details': 'User $action eye scan data storage disclaimer',
        'userAgent': 'Mobile App',
      });
      print('Eye scan disclaimer $action logged');
    } catch (e) {
      print(' Error logging disclaimer action: $e');
    }
  }
}
