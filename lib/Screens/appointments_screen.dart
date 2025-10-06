import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _selectedNavIndex = 0;
  final Color primaryColor = const Color(0xFFFF6B6B);

  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _appointments = [];
        _loading = false;
      });
      return;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .get();

    setState(() {
      _appointments = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "clinicName": data["clinicName"] ?? "",
          "clinicId": data["clinicId"] ?? "",
          "date": data["date"] ?? "",
          "time": data["time"] ?? "",
          "status": data["status"] ?? "",
          "type": data["type"] ?? "",
          "notes": data["notes"] ?? "",
          "doctorName": data["doctorName"] ?? "",
        };
      }).toList();
      _loading = false;
    });
  }

  void _onNavItemTapped(int index) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Eye Scan tapped")),
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

  void _viewAppointmentDetails(
      BuildContext context, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Appointment Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Type", appointment["type"] ?? ""),
            _buildDetailRow("Status", appointment["status"] ?? ""),
            if ((appointment["doctorName"] ?? "").isNotEmpty)
              _buildDetailRow("Doctor", appointment["doctorName"]),
            _buildDetailRow("Clinic", appointment["clinicName"] ?? ""),
            _buildDetailRow("Date", appointment["date"] ?? ""),
            _buildDetailRow("Time", appointment["time"] ?? ""),
            if ((appointment["notes"] ?? "").isNotEmpty)
              _buildDetailRow("Notes", appointment["notes"]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.normal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointments"),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade50,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? const Center(child: Text("No appointments found."))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _appointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, idx) {
                    final app = _appointments[idx];
                    final isUpcoming = app["status"] == "Upcoming";

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      color: isUpcoming ? Colors.white : Colors.grey.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main appointment info
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      primaryColor.withOpacity(0.15),
                                  child: Icon(
                                    isUpcoming
                                        ? Icons.event_available
                                        : Icons.event_note,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${app["type"]?.isNotEmpty == true ? app["type"] : "Appointment"}"
                                        "${(app["doctorName"] != null && app["doctorName"].toString().isNotEmpty) ? " with ${app["doctorName"]}" : ""}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        app["clinicName"] ?? "",
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "${app["date"]} • ${app["time"]}",
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        app["status"] ?? "",
                                        style: TextStyle(
                                          color: isUpcoming
                                              ? Colors.green
                                              : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Action buttons - separate row at bottom
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text("View",
                                      style: TextStyle(fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade400,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(30, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    elevation: 0,
                                  ),
                                  onPressed: () =>
                                      _viewAppointmentDetails(context, app),
                                ),
                                if (isUpcoming)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.cancel, size: 16),
                                    label: const Text("Cancel",
                                        style: TextStyle(fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade400,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(30, 32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title:
                                              const Text("Cancel Appointment"),
                                          content: Text(
                                            "Are you sure you want to cancel your appointment${(app["doctorName"] != null && app["doctorName"].toString().isNotEmpty) ? " with ${app["doctorName"]}" : ""}?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("No"),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                final appointment =
                                                    _appointments[idx];
                                                final String id =
                                                    appointment["id"];
                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection(
                                                          'appointments')
                                                      .doc(id)
                                                      .update({
                                                    "status": "Cancelled"
                                                  });
                                                  setState(() {
                                                    _appointments[idx]
                                                            ["status"] =
                                                        "Cancelled";
                                                  });
                                                  // AUDIT LOG HERE
                                                  await AuditLogService
                                                      .logAction(
                                                    action:
                                                        'appointment_cancelled',
                                                    details:
                                                        'Cancelled appointment at ${appointment["clinicName"]} on ${appointment["date"]} at ${appointment["time"]}.',
                                                    appointmentId: id,
                                                  );
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "Appointment cancelled.")),
                                                  );
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "Failed to cancel appointment.")),
                                                  );
                                                }
                                              },
                                              child: const Text("Yes, Cancel"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                if (isUpcoming)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check_circle,
                                        size: 16),
                                    label: const Text("Complete",
                                        style: TextStyle(fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade400,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(30, 32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      elevation: 0,
                                    ),
                                    onPressed: () async {
                                      final appointment = _appointments[idx];
                                      final String id = appointment["id"];
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('appointments')
                                            .doc(id)
                                            .update({"status": "Completed"});
                                        setState(() {
                                          _appointments[idx]["status"] =
                                              "Completed";
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Appointment marked as completed.")),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Failed to mark appointment as completed.")),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
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
