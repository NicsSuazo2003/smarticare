import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:intl/intl.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import 'symptom_assessment_screen.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  int _selectedTab = 0; // 0: Today, 1: Upcoming, 2: Completed
  int _selectedNavIndex = 3; // 3: Reminders as active tab

  List<Map<String, dynamic>> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReminders();
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
        "dateTime": (data["dateTime"] as Timestamp).toDate(),
        "completed": data["completed"] ?? false,
        "repeat": data["repeat"] ?? "",
        "notification": data["notification"] ?? false,
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
              "Are you sure you want to delete this reminder? This action cannot be undone."),
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

  void _showReminderDetailsDialog(Map<String, dynamic> reminder, int index) {
    const Color primaryColor = Color(0xFFFF6B6B);
    final DateTime dt = reminder["dateTime"] as DateTime;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Colors.white,
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
                  _buildDetailItem("Clinic Name", reminder["clinicName"] ?? ""),
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

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                        await AuditLogService.logAction(
                          action: newStatus
                              ? 'reminder_completed'
                              : 'reminder_marked_incomplete',
                          details:
                              'Reminder with id "$id" marked as ${newStatus ? "completed" : "incomplete"}.',
                        );
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: valueColor,
              ),
            ),
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

    // Navigation handling for each nav bar item
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
        // Already on this screen
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

  void _openNewReminderDialog() async {
    final newReminder = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _NewReminderDialog(),
    );
    if (newReminder != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('reminders').add({
        ...newReminder,
        "userId": user.uid,
        "dateTime":
            newReminder["dateTime"], // DateTime, will be stored as Timestamp
      });
      await AuditLogService.logAction(
        action: 'reminder_created',
        details: 'Reminder titled "${newReminder["title"]}" created for user.',
      );
      _fetchReminders();
      Future.delayed(const Duration(milliseconds: 100), () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Reminder Saved!"),
            content: const Text(
                "Your reminder has been successfully saved. You can view it in your reminders list."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              )
            ],
          ),
        );
      });
    }
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
        actions: [
          // Profile Logo to the right
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                  (route) => false,
                );
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: primaryColor.withOpacity(0.2),
                child: const Icon(Icons.person,
                    color: Color(0xFFFF6B6B), size: 26),
              ),
            ),
          ),
        ],
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date/time display
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          const Text(
                            "UTC: 2025-06-15 17:11:22",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // User info
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          const Text(
                            "User: Arsisjayright",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _buildTab("Today", 0),
                const SizedBox(width: 18),
                _buildTab("Upcoming", 1),
                const SizedBox(width: 18),
                _buildTab("Completed", 2),
              ],
            ),
          ),
          // Reminders list
          Expanded(
            child: filteredReminders.isEmpty
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
                      final originalIndex = _reminders.indexWhere((element) =>
                          element["title"] == r["title"] &&
                          element["dateTime"] == r["dateTime"]);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 2,
                        child: InkWell(
                          onTap: () =>
                              _showReminderDetailsDialog(r, originalIndex),
                          borderRadius: BorderRadius.circular(15),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: r["type"] == "Medication"
                                ? const Icon(Icons.medication,
                                    color: primaryColor)
                                : const Icon(Icons.remove_red_eye,
                                    color: primaryColor),
                            title: Text(
                              r["title"],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (r["description"] != null &&
                                    r["description"].toString().isNotEmpty)
                                  Text(r["description"],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                Text(
                                  "${DateFormat.yMMMEd().format(dt)} at ${DateFormat.jm().format(dt)}",
                                  style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13),
                                ),
                                if (r["repeat"] != null &&
                                    r["repeat"] != "None")
                                  Text("Repeat: ${r["repeat"]}",
                                      style: const TextStyle(fontSize: 13)),
                                if (r["notification"] == true)
                                  const Row(
                                    children: [
                                      Icon(Icons.notifications_active,
                                          size: 16, color: Colors.green),
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
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
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

  void _save() {
    if (_title.text.trim().isEmpty || _date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill title, date and time')),
      );
      return;
    }
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
    });
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Save Reminder"),
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
            Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
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
