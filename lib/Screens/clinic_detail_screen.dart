import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';
import 'package:flutter/services.dart';

class ClinicDetailScreen extends StatefulWidget {
  final String clinicId;

  const ClinicDetailScreen({super.key, required this.clinicId});

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  int _selectedNavIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);
    final double cardElevation = 3.0;
    final BorderRadius cardRadius = BorderRadius.circular(18);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('clinics')
            .doc(widget.clinicId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Clinic not found.'));
          }
          final clinic = snapshot.data!.data() as Map<String, dynamic>;
          final phone = (clinic["phone"] ?? clinic["contactPhone"] ?? "")
              .toString()
              .trim();

          return CustomScrollView(
            slivers: [
              // Modern App Bar with gradient
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Clinic Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor,
                          primaryColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clinic Header Card
                      Card(
                        elevation: cardElevation,
                        shape: RoundedRectangleBorder(borderRadius: cardRadius),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.local_hospital,
                                      color: primaryColor,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          clinic["name"] ?? "",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                            color: Colors.grey.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.red,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                clinic["address"] ?? "",
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Info Grid
                      Row(
                        children: [
                          // Distance Card
                          Expanded(
                            child: Card(
                              elevation: cardElevation,
                              shape: RoundedRectangleBorder(
                                  borderRadius: cardRadius),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.directions_walk,
                                        color: primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Distance',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      clinic["distance"] ?? "N/A",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Hours Card
                          Expanded(
                            child: Card(
                              elevation: cardElevation,
                              shape: RoundedRectangleBorder(
                                  borderRadius: cardRadius),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.access_time,
                                        color: Colors.orange.shade700,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Hours',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      clinic["hours"] ?? "N/A",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Phone Card
                      Card(
                        elevation: cardElevation,
                        shape: RoundedRectangleBorder(borderRadius: cardRadius),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.phone, color: primaryColor),
                          ),
                          title: const Text(
                            "Phone",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: phone.isNotEmpty
                              ? SelectableText(
                                  phone,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade900,
                                  ),
                                )
                              : Text(
                                  "No phone number available",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                          trailing: phone.isNotEmpty
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.copy, color: primaryColor),
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: phone));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle,
                                                  color: Colors.white),
                                              SizedBox(width: 12),
                                              Text("Phone number copied!"),
                                            ],
                                          ),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Doctor In Charge Card
                      if ((clinic["doctorInCharge"] ?? "").isNotEmpty)
                        Card(
                          elevation: cardElevation,
                          shape:
                              RoundedRectangleBorder(borderRadius: cardRadius),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.person, color: primaryColor),
                            ),
                            title: const Text(
                              "Doctor In Charge",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              clinic["doctorInCharge"],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                        ),
                      if ((clinic["doctorInCharge"] ?? "").isNotEmpty)
                        const SizedBox(height: 16),

                      // About Clinic Card
                      Card(
                        elevation: cardElevation,
                        shape: RoundedRectangleBorder(borderRadius: cardRadius),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.info_outline,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "About Clinic",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                (clinic["about"] ?? "").isNotEmpty
                                    ? clinic["about"]
                                    : "No description available.",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade700,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
}
