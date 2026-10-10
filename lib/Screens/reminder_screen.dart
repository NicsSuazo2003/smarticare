import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/data/models/reminder_model.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import 'package:timezone/timezone.dart' as tz;
import 'symptom_assessment_screen.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  int _selectedTab = 0; // 0: Today, 1: Upcoming, 2: Completed
  int _selectedNavIndex = 3; // 3: Reminders as active tab
  List<Map<String, dynamic>> _notifications = [];
  bool _loadingNotifications = true;

  List<Map<String, dynamic>> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReminders();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _loadingNotifications = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _notifications = [];
        _loadingNotifications = false;
      });
      return;
    }
    final notificationSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();

    final userNotifications = notificationSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "id": doc.id,
        "type": data["type"] ?? "",
        "title": data["title"] ?? "",
        "message": data["message"] ?? "",
        "timestamp": (data["timestamp"] is Timestamp)
            ? (data["timestamp"] as Timestamp).toDate()
            : DateTime.tryParse(data["timestamp"]?.toString() ?? ""),
        "isRead": data["isRead"] ?? false,
      };
    }).toList();

    setState(() {
      _notifications = userNotifications;
      _loadingNotifications = false;
    });
  }

// Inside _ReminderScreenState class in reminder_screen.dart

  Future<void> _scheduleNotification(Reminder reminder) async {
    if (!reminder.notification)
      return; // Don't schedule if notifications are off

    // 1. Calculate the Trigger Time
    final tz.TZDateTime eventDate = tz.TZDateTime.from(
      reminder.dateTime,
      tz.local,
    );

    // Subtract the "notifyBefore" minutes
    final tz.TZDateTime scheduledDate =
        eventDate.subtract(Duration(minutes: reminder.notifyBefore));

    // 2. Safety Check: If time is already past, don't crash
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      print("Skipping notification: Time is in the past");
      return;
    }

    // 3. Custom Message based on time
    String bodyText = reminder.description;
    if (reminder.notifyBefore > 0) {
      // Helper to make text pretty (e.g. "15 minutes" vs "1 hour")
      String timeString = "${reminder.notifyBefore} minutes";
      if (reminder.notifyBefore == 60) timeString = "1 hour";
      if (reminder.notifyBefore == 1440) timeString = "1 day";

      bodyText = "Upcoming in $timeString: ${reminder.title}";
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      reminder.id.hashCode,
      reminder.title,
      bodyText, // Use the custom body text
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> _fetchReminders() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _reminders = [];
        _loading = false;
      });
      return;
    }

    // Only fetch reminders for this user
    final reminderSnapshot = await FirebaseFirestore.instance
        .collection('reminders')
        .where('userId', isEqualTo: user.uid)
        .get();

    final userReminders = reminderSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "id": doc.id,
        "type": data["type"] ?? "",
        "title": data["title"] ?? "",
        "description": data["description"] ?? "",
        "dateTime": (data["dateTime"] as Timestamp).toDate().toLocal(),
        "completed": data["completed"] ?? false,
        "repeat": data["repeat"] ?? "",
        "notification": data["notification"] ?? false,
        "notifyBefore": data["notifyBefore"] ?? 0,
      };
    }).toList();

    setState(() {
      _reminders = userReminders;
      _loading = false;
    });
  }

  void _confirmDeleteReminder(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Reminder"),
          content: const Text(
              "Are you sure you want to delete this reminder?  This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final id = _reminders[index]["id"];
                await FirebaseFirestore.instance
                    .collection('reminders')
                    .doc(id)
                    .delete();
                await AuditLogService.logAction(
                  action: 'reminder_deleted',
                  details: 'Reminder with id "$id" deleted.',
                );
                await FirebaseFirestore.instance
                    .collection('admin_notifications')
                    .add({
                  'type': 'reminder_deleted',
                  'message':
                      'Reminder titled "${_reminders[index]["title"]}" deleted by user.',
                  'createdAt': FieldValue.serverTimestamp(),
                  'timestamp':
                      FieldValue.serverTimestamp(), // add this for future use

                  'read': false,
                  'relatedUserId': FirebaseAuth.instance.currentUser?.uid ?? "",
                  'reminderId': _reminders[index]["id"],
                });
                _fetchReminders();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Reminder deleted"),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("DELETE"),
            ),
          ],
        );
      },
    );
  }

  void _openEditReminderDialog(Map<String, dynamic> reminder, int index) async {
    final connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    final isOnline = connectivityProvider.isOnline;

    if (!isOnline) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 10),
              Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'Editing reminders requires an internet connection.  Please check your connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final editedReminder = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditReminderDialog(reminder: reminder),
    );

    if (editedReminder != null) {
      final id = reminder["id"];

      try {
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('reminders')
            .doc(id)
            .update({
          "type": editedReminder["type"],
          "title": editedReminder["title"],
          "description": editedReminder["description"],
          "dateTime": editedReminder["dateTime"],
          "repeat": editedReminder["repeat"],
          "notification": editedReminder["notification"],
          "notifyBefore": editedReminder["notifyBefore"],
        });

        // Create user notification
        final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          "type": "reminder",
          "title": "Reminder Updated",
          "message": "You updated the reminder:  '${editedReminder["title"]}'.",
          "timestamp": FieldValue.serverTimestamp(),
          "isRead": false,
        });

        // Create admin notification
        await FirebaseFirestore.instance.collection('admin_notifications').add({
          'type': 'reminder_updated',
          'message':
              'Reminder titled "${editedReminder["title"]}" was updated by user.',
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'relatedUserId': userId,
          'reminderId': id,
        });

        // Log to audit
        await AuditLogService.logAction(
          action: 'reminder_updated',
          details:
              'Reminder with id "$id" updated.  New title: "${editedReminder["title"]}".',
        );

        _fetchNotifications();
        _fetchReminders();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder updated successfully! '),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update reminder: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _openEditReminderDialog(reminder, index),
            ),
          ),
        );
      }
    }
  }

  void _showReminderDetailsDialog(Map<String, dynamic> reminder, int index) {
    const Color primaryColor = Color(0xFFFF6B6B);
    final DateTime dt = reminder["dateTime"] as DateTime;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            // Added SingleChildScrollView
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          reminder["type"] == "Medication"
                              ? Icons.medication
                              : Icons.remove_red_eye,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder["title"],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              reminder["type"],
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  if (reminder["type"] == "Appointment") ...[
                    _buildDetailItem(
                        "Patient Name", reminder["patientName"] ?? ""),
                    _buildDetailItem(
                        "Clinic Name", reminder["clinicName"] ?? ""),
                    _buildDetailItem("Date", reminder["date"] ?? ""),
                    _buildDetailItem("Time", reminder["time"] ?? ""),
                    _buildDetailItem("Status", reminder["status"] ?? ""),
                    _buildDetailItem("Notes", reminder["notes"] ?? ""),
                  ],

                  // Reminder details
                  if (reminder["description"] != null &&
                      reminder["description"].toString().isNotEmpty)
                    _buildDetailItem(
                        "Description", reminder["description"].toString()),

                  _buildDetailItem("Date & Time",
                      "${DateFormat.yMMMMd().format(dt)} at ${DateFormat.jm().format(dt)}"),

                  _buildDetailItem("Repeat", reminder["repeat"]),

                  _buildDetailItem(
                      "Notification", reminder["notification"] ? "On" : "Off"),

                  _buildDetailItem(
                      "Status", reminder["completed"] ? "Completed" : "Pending",
                      valueColor:
                          reminder["completed"] ? Colors.green : Colors.orange),

                  const SizedBox(height: 20),

                  // Actions - FIXED: Using Wrap for better responsive layout
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Delete button
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDeleteReminder(index);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Delete"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),

                      // Edit button
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openEditReminderDialog(reminder, index);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text("Edit"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                        ),
                      ),

                      // Mark as complete/incomplete button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final id = _reminders[index]["id"];
                          final newStatus = !_reminders[index]["completed"];
                          await FirebaseFirestore.instance
                              .collection('reminders')
                              .doc(id)
                              .update({
                            "completed": newStatus,
                          });

                          final userId =
                              FirebaseAuth.instance.currentUser?.uid ?? "";
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('notifications')
                              .add({
                            "type": "reminder",
                            "title": newStatus
                                ? "Reminder Completed"
                                : "Reminder Updated",
                            "message": newStatus
                                ? "You marked '${reminder["title"]}' as completed.  Great job!"
                                : "You updated the status of '${reminder["title"]}'.",
                            "timestamp": FieldValue.serverTimestamp(),
                            "isRead": false,
                          });

                          _fetchNotifications();
                          await AuditLogService.logAction(
                            action: newStatus
                                ? 'reminder_completed'
                                : 'reminder_marked_incomplete',
                            details:
                                'Reminder with id "$id" marked as ${newStatus ? "completed" : "incomplete"}.',
                          );

                          if (newStatus) {
                            await FirebaseFirestore.instance
                                .collection('admin_notifications')
                                .add({
                              'type': 'reminder_completed',
                              'message':
                                  'Reminder titled "${reminder["title"]}" marked as completed by user.',
                              'createdAt': FieldValue.serverTimestamp(),
                              'timestamp': FieldValue.serverTimestamp(),
                              'read': false,
                              'relatedUserId':
                                  FirebaseAuth.instance.currentUser?.uid ?? "",
                              'reminderId': reminder["id"],
                            });
                          }

                          _fetchReminders();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "Reminder marked as ${newStatus ? "completed" : "incomplete"}"),
                              backgroundColor:
                                  newStatus ? Colors.green : Colors.orange,
                            ),
                          );
                        },
                        icon: Icon(reminder["completed"]
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank),
                        label: Text(reminder["completed"]
                            ? "Mark as Incomplete"
                            : "Mark as Complete"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: reminder["completed"]
                              ? Colors.green.shade100
                              : primaryColor,
                          foregroundColor: reminder["completed"]
                              ? Colors.green.shade800
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: valueColor ?? Colors.black,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get filteredReminders {
    final now = DateTime.now();
    if (_selectedTab == 0) {
      // Today
      return _reminders.where((r) {
        final dt = r["dateTime"] as DateTime;
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day &&
            !r["completed"];
      }).toList();
    } else if (_selectedTab == 1) {
      // Upcoming
      return _reminders.where((r) {
        final dt = r["dateTime"] as DateTime;
        return dt.isAfter(now) && !r["completed"];
      }).toList();
    } else {
      // Completed
      return _reminders.where((r) => r["completed"] == true).toList();
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
      case 0: // Home
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1: // Progress
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProgressScreen()),
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
        // Already on reminders screen
        break;
      case 4: // Profile
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
    }
  }

  void _openNewReminderDialog() async {
    // ✅ REPLACED:  Use ConnectivityProvider instead of ConnectivityService
    final connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    final isOnline = connectivityProvider.isOnline;

    if (!isOnline) {
      // Show offline dialog manually
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 10),
              Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'This action requires an internet connection. Please check your connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Rest of your existing code remains the same...
    final newReminder = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _NewReminderDialog(),
    );

    if (newReminder != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ OPTIMISTIC UPDATE: Add to UI immediately
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _reminders.insert(0, {
          "id": tempId,
          "type": newReminder["type"],
          "title": newReminder["title"],
          "description": newReminder["description"],
          "dateTime": newReminder["dateTime"],
          "completed": false,
          "repeat": newReminder["repeat"],
          "notification": newReminder["notification"],
          "notifyBefore": newReminder["notifyBefore"],
          "_isPending": true, // ✅ Mark as pending
        });
      });

      try {
        // Save to Firestore in background
        var docRef =
            await FirebaseFirestore.instance.collection('reminders').add({
          ...newReminder,
          "userId": user.uid,
          "dateTime": newReminder["dateTime"],
        });

        // ✅ UPDATE WITH REAL ID
        setState(() {
          final index = _reminders.indexWhere((r) => r["id"] == tempId);
          if (index != -1) {
            _reminders[index]["id"] = docRef.id;
            _reminders[index].remove("_isPending");
          }
        });

        // Notifications and audit logs
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
          "type": "reminder",
          "title": "Reminder Created",
          "message": "You created a reminder:  '${newReminder["title"]}'.",
          "timestamp": FieldValue.serverTimestamp(),
          "isRead": false,
        });

        await FirebaseFirestore.instance.collection('admin_notifications').add({
          'type': 'reminder_created',
          'message':
              'Reminder titled "${newReminder["title"]}" created by user.',
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(), // add this for future use

          'read': false,
          'relatedUserId': user.uid,
          'reminderId': docRef.id,
        });

        await AuditLogService.logAction(
          action: 'reminder_created',
          details:
              'Reminder titled "${newReminder["title"]}" created for user.',
        );

        _fetchNotifications();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // ✅ ROLLBACK ON ERROR
        setState(() {
          _reminders.removeWhere((r) => r["id"] == tempId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create reminder: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _openNewReminderDialog(),
            ),
          ),
        );
      }
    }
  }

  Widget _buildNotificationsTab() {
    IconData _iconForType(String type) {
      switch (type) {
        case "appointment":
          return Icons.event_note;
        case "reminder":
          return Icons.alarm;
        case "scan":
          return Icons.remove_red_eye;
        case "system":
          return Icons.settings;
        case "tip":
          return Icons.health_and_safety;
        default:
          return Icons.notifications;
      }
    }

    Future<void> _markAsRead(String notificationId) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      setState(() {
        final idx = _notifications.indexWhere((n) => n["id"] == notificationId);
        if (idx != -1) _notifications[idx]["isRead"] = true;
      });
    }

    void _showMessageDialog(Map<String, dynamic> notification) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(_iconForType(notification["type"]), color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notification["title"] ?? "Notification",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(notification["message"] ?? ""),
          actions: [
            if (!(notification["isRead"] ?? false))
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _markAsRead(notification["id"]);
                },
                child: const Text('Mark as Read'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return _loadingNotifications
        ? const Center(child: CircularProgressIndicator())
        : _notifications.isEmpty
            ? Center(
                child: Text(
                  "No notifications yet.",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              )
            : ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final isUnread = !(notification["isRead"] ?? false);
                  return ListTile(
                    title: Text(
                      notification["title"] ?? "",
                      style: TextStyle(
                        fontWeight:
                            isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(notification["message"] ?? ""),
                    trailing: Text(
                      notification["timestamp"] != null
                          ? DateFormat.yMd()
                              .add_jm()
                              .format(notification["timestamp"])
                          : "",
                      style: const TextStyle(fontSize: 12),
                    ),
                    leading: Icon(
                      _iconForType(notification["type"] ?? ""),
                      color: isUnread ? Colors.blue : Colors.grey,
                    ),
                    onTap: () {
                      _showMessageDialog(notification);
                      if (isUnread) _markAsRead(notification["id"]);
                    },
                  );
                },
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
        titleSpacing: 0,
        title: const Text(
          'Smarticare',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reminders title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Reminders',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Calendar and Current Time
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 20, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat.yMMMMEEEEd().format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Split the date/time and user info into separate containers to avoid overflow
              ],
            ),
          ),
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab("Today", 0),
                  const SizedBox(width: 18),
                  _buildTab("Upcoming", 1),
                  const SizedBox(width: 18),
                  _buildTab("Completed", 2),
                  // <-- Added Notifications tab
                ],
              ),
            ),
          ),
          // Reminders list
          Expanded(
            child: _selectedTab == 3
                ? _buildNotificationsTab() // New branch to show Notifications
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredReminders.isEmpty
                        ? Center(
                            child: Text(
                              _selectedTab == 2
                                  ? "No completed reminders."
                                  : "No reminders found.",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            itemCount: filteredReminders.length,
                            itemBuilder: (context, idx) {
                              final r = filteredReminders[idx];
                              final dt = r["dateTime"] as DateTime;

                              // Find the original index in the main reminders list
                              // Find the original index in the main reminders list
                              final originalIndex = _reminders.indexWhere(
                                  (element) =>
                                      element["title"] == r["title"] &&
                                      element["dateTime"] == r["dateTime"]);

                              // In the ListView. builder for reminders, update the ListTile:
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 2,
                                child: InkWell(
                                  onTap: () => _showReminderDetailsDialog(
                                      r, originalIndex),
                                  borderRadius: BorderRadius.circular(15),
                                  child: Stack(
                                    children: [
                                      ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                        leading: r["type"] == "Medication"
                                            ? const Icon(Icons.medication,
                                                color: primaryColor)
                                            : const Icon(Icons.remove_red_eye,
                                                color: primaryColor),
                                        title: Text(
                                          r["title"],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (r["description"] != null &&
                                                r["description"]
                                                    .toString()
                                                    .isNotEmpty)
                                              Text(r["description"],
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            Text(
                                              "${DateFormat.yMMMEd().format(dt)} at ${DateFormat.jm().format(dt)}",
                                              style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 13),
                                            ),
                                            if (r["repeat"] != null &&
                                                r["repeat"] != "None")
                                              Text("Repeat: ${r["repeat"]}",
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            if (r["notification"] == true)
                                              const Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .notifications_active,
                                                      size: 16,
                                                      color: Colors.green),
                                                  SizedBox(width: 4),
                                                  Text("Notification On",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.green)),
                                                ],
                                              )
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_selectedTab == 2)
                                              Icon(Icons.check_circle,
                                                  color: Colors.green.shade600),
                                            // ✅ SHOW SYNCING INDICATOR
                                            if (r["_isPending"] == true)
                                              const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            else
                                              const Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 16,
                                                  color: Colors.grey),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          // Create new reminder button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openNewReminderDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Create New Reminder"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(primaryColor),
    );
  }

  Widget _buildTab(String label, int tabIdx) {
    const Color primaryColor = Color(0xFFFF6B6B);
    final bool selected = _selectedTab == tabIdx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabIdx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? primaryColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 15,
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
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 10, // Reduced from 12
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 10, // Reduced from 12
      ),
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
            height: 35, // Reduced from 40
            width: 35, // Reduced from 40
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 20, // Reduced size
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

class _NewReminderDialog extends StatefulWidget {
  const _NewReminderDialog();

  @override
  State<_NewReminderDialog> createState() => _NewReminderDialogState();
}

class _NewReminderDialogState extends State<_NewReminderDialog> {
  String _type = "Eye Scan";
  final TextEditingController _title = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  String _repeat = "None";
  bool _notification = true;
  bool _isLoading = false;

  int _notifyBefore = 0; // Default 0
  final Map<int, String> _notifyOptions = {
    0: "At time of event",
    5: "5 minutes before",
    15: "15 minutes before",
    30: "30 minutes before",
    60: "1 hour before",
    1440: "1 day before",
  };

  final List<String> repeatOptions = ["None", "Daily", "Weekly", "Monthly"];

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() async {
    // ✅ MAKE ASYNC
    if (_title.text.trim().isEmpty || _date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill title, date and time')),
      );
      return;
    }

    setState(() {
      _isLoading = true; // ✅ SHOW LOADING
    });

    try {
      final DateTime finalDateTime = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );

      Navigator.pop(context, {
        "type": _type,
        "title": _title.text.trim(),
        "description": _desc.text.trim(),
        "dateTime": finalDateTime,
        "completed": false,
        "repeat": _repeat,
        "notification": _notification,
        "notifyBefore": _notifyBefore,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create reminder.  Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Create New Reminder",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            // Type selection
            Row(
              children: [
                Expanded(
                  child: _buildTypeRadio("Eye Scan"),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTypeRadio("Medication"),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Title
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: "Title",
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            // Description
            TextField(
              controller: _desc,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description",
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            // Date and Time row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: "Date",
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                          hintText: _date == null
                              ? "Select date"
                              : DateFormat.yMMMEd().format(_date!),
                        ),
                        controller: TextEditingController(
                          text: _date == null
                              ? ""
                              : DateFormat.yMMMEd().format(_date!),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: "Time",
                          prefixIcon: const Icon(Icons.access_time),
                          border: const OutlineInputBorder(),
                          hintText: _time == null
                              ? "Select time"
                              : _time!.format(context),
                        ),
                        controller: TextEditingController(
                          text: _time == null ? "" : _time!.format(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Repeat
            DropdownButtonFormField<String>(
              value: _repeat,
              items: repeatOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _repeat = v ?? "None"),
              decoration: const InputDecoration(
                labelText: "Repeat",
                prefixIcon: Icon(Icons.repeat),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            // Notification switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Notification"),
              value: _notification,
              onChanged: (v) => setState(() => _notification = v),
              activeColor: primaryColor,
              secondary: Icon(
                _notification
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _notification ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _notifyBefore,
              items: _notifyOptions.entries.map((e) {
                return DropdownMenuItem<int>(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
              onChanged: (v) => setState(() => _notifyBefore = v ?? 0),
              decoration: const InputDecoration(
                labelText: "Notify me",
                prefixIcon: Icon(Icons.alarm),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: primaryColor,
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading // ✅ SHOW SPINNER
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("Save Reminder"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTypeRadio(String value) {
    const Color primaryColor = Color(0xFFFF6B6B);
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _type == value
              ? primaryColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _type == value ? primaryColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value == "Eye Scan" ? Icons.remove_red_eye : Icons.medication,
              color: primaryColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            // Wrap the label in Flexible so it can ellipsize if there's not enough space.
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _type,
              onChanged: (v) => setState(() => _type = v!),
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ NEW:  Edit Reminder Dialog
class _EditReminderDialog extends StatefulWidget {
  final Map<String, dynamic> reminder;

  const _EditReminderDialog({required this.reminder});

  @override
  State<_EditReminderDialog> createState() => _EditReminderDialogState();
}

class _EditReminderDialogState extends State<_EditReminderDialog> {
  late String _type;
  late TextEditingController _title;
  late TextEditingController _desc;
  late DateTime _date;
  late TimeOfDay _time;
  late String _repeat;
  late bool _notification;
  bool _isLoading = false;

  int _notifyBefore = 0;
  final Map<int, String> _notifyOptions = {
    0: "At time of event",
    5: "5 minutes before",
    15: "15 minutes before",
    30: "30 minutes before",
    60: "1 hour before",
    1440: "1 day before",
  };
  final List<String> repeatOptions = ["None", "Daily", "Weekly", "Monthly"];

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing reminder data
    _type = widget.reminder["type"] ?? "Eye Scan";
    _title = TextEditingController(text: widget.reminder["title"] ?? "");
    _desc = TextEditingController(text: widget.reminder["description"] ?? "");

    final dt = widget.reminder["dateTime"] as DateTime;
    _date = dt;
    _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    _repeat = widget.reminder["repeat"] ?? "None";
    _notification = widget.reminder["notification"] ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the title')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final DateTime finalDateTime = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

      Navigator.pop(context, {
        "type": _type,
        "title": _title.text.trim(),
        "description": _desc.text.trim(),
        "dateTime": finalDateTime,
        "repeat": _repeat,
        "notification": _notification,
        "notifyBefore": _notifyBefore,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update reminder. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Edit Reminder",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            // Type selection
            Row(
              children: [
                Expanded(
                  child: _buildTypeRadio("Eye Scan"),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTypeRadio("Medication"),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Title
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: "Title",
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            // Description
            TextField(
              controller: _desc,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description",
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            // Date and Time row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: "Date",
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                          hintText: DateFormat.yMMMEd().format(_date),
                        ),
                        controller: TextEditingController(
                          text: DateFormat.yMMMEd().format(_date),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: "Time",
                          prefixIcon: const Icon(Icons.access_time),
                          border: const OutlineInputBorder(),
                          hintText: _time.format(context),
                        ),
                        controller: TextEditingController(
                          text: _time.format(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Repeat
            DropdownButtonFormField<String>(
              value: _repeat,
              items: repeatOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _repeat = v ?? "None"),
              decoration: const InputDecoration(
                labelText: "Repeat",
                prefixIcon: Icon(Icons.repeat),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
// Notification switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Notification"),
              value: _notification,
              onChanged: (v) => setState(() => _notification = v),
              activeColor: primaryColor,
              secondary: Icon(
                _notification
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _notification ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(height: 14),
// Notify before dropdown - ONLY ONE, NOT DUPLICATED
            DropdownButtonFormField<int>(
              value: _notifyBefore,
              items: _notifyOptions.entries.map((e) {
                return DropdownMenuItem<int>(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
              onChanged: (v) => setState(() => _notifyBefore = v ?? 0),
              decoration: const InputDecoration(
                labelText: "Notify me",
                prefixIcon: Icon(Icons.alarm),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: primaryColor,
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("Save Changes"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTypeRadio(String value) {
    const Color primaryColor = Color(0xFFFF6B6B);
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _type == value
              ? primaryColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _type == value ? primaryColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value == "Eye Scan" ? Icons.remove_red_eye : Icons.medication,
              color: primaryColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _type,
              onChanged: (v) => setState(() => _type = v!),
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
