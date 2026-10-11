import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/presentation/home_screen.dart';
import 'progress_screen.dart';
import '../../reminders/presentation/reminder_screen.dart';
import 'profile_screen.dart';
import '../../symptom_assessment/presentation/symptom_assessment_screen.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  int _selectedNavIndex = 0;
  final Color primaryColor = const Color(0xFFFF6B6B);

  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _activities = [];
          _loading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('audit_logs')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      Logger.d('Fetched ${snapshot.docs.length} logs for userId=${user.uid}');

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
        final date =
            "${ts.year.toString().padLeft(4, '0')}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}";

        return {
          "icon": icon,
          "color": color,
          "title": title,
          "subtitle": subtitle,
          "time": time,
          "date": date,
        };
      }).toList();

      setState(() {
        _activities = mapped;
        _loading = false;
      });
    } catch (e, stack) {
    } catch (e, stack) {
      Logger.e('Error fetching activities: $e', stack);
      setState(() {
        _activities = [];
        _loading = false;
      });
      // Optional: Show a snackbar or message to the user here
    }
  }

  void _onNavItemTapped(int index) {
    if (_selectedNavIndex == index) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity Log"),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.grey.shade50,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final activity = _activities[index];

                // Add date header if this is the first item or if date changes
                bool showDateHeader = index == 0 ||
                    activity["date"] != _activities[index - 1]["date"];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) ...[
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 16, bottom: 8, left: 8),
                        child: Text(
                          _formatDateHeader(activity["date"]),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const Divider(),
                    ],
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 2),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: activity["color"].withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                activity["icon"],
                                color: activity["color"],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity["title"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activity["subtitle"],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              activity["time"],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  String _formatDateHeader(String date) {
    DateTime now = DateTime.now();
    DateTime activityDate = DateTime.tryParse(date) ?? now;

    int differenceInDays = now.difference(activityDate).inDays;

    if (differenceInDays == 0) {
      return "Today";
    } else if (differenceInDays == 1) {
      return "Yesterday";
    } else {
      return "${activityDate.year}/${activityDate.month.toString().padLeft(2, '0')}/${activityDate.day.toString().padLeft(2, '0')}";
    }
  }
}
