import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../home/presentation/home_screen.dart';
import '../../../features/profile/presentation/progress_screen.dart';
import '../../reminders/presentation/reminder_screen.dart';
import '../../../features/profile/presentation/profile_screen.dart';
import 'clinic_detail_screen.dart';

class FindClinicsScreen extends StatefulWidget {
  const FindClinicsScreen({super.key});

  @override
  State<FindClinicsScreen> createState() => _FindClinicsScreenState();
}

class _FindClinicsScreenState extends State<FindClinicsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  int _selectedNavIndex = 0;

  List<Map<String, String>> _allClinics = [];

  @override
  void initState() {
    super.initState();
    _loadClinics();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim();
      });
    });
  }

  Future<void> _loadClinics() async {
    final box = await Hive.openBox('clinicsBox');
    List<Map<String, String>> clinics = [];

    try {
      // Try to fetch from Firestore
      final snapshot =
          await FirebaseFirestore.instance.collection('clinics').get();
      clinics = snapshot.docs.map<Map<String, String>>((doc) {
        final data = doc.data();
        final map =
            data.map((key, value) => MapEntry(key, value?.toString() ?? ""));
        map['id'] = doc.id; // This is important!
        return map;
      }).toList();

      // Save to Hive for offline use
      await box.put('clinics', clinics);
    } catch (e) {
      // If Firestore fails, load from Hive
      clinics = (box.get('clinics', defaultValue: []) as List)
          .map<Map<String, String>>((e) => Map<String, String>.from(
              e.map((k, v) => MapEntry(k, v?.toString() ?? ""))))
          .toList();
    }

    setState(() => _allClinics = clinics);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredClinics {
    if (_searchText.isEmpty) return _allClinics;
    return _allClinics
        .where((clinic) =>
            (clinic["name"] ?? "")
                .toLowerCase()
                .contains(_searchText.toLowerCase()) ||
            (clinic["address"] ?? "")
                .toLowerCase()
                .contains(_searchText.toLowerCase()))
        .toList();
  }

  void _onNavItemTapped(int index) {
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
      case 2: // Eye Scan (you can handle as needed)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Eye Scan tapped")),
        );
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Find Clinics",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search for clinics or location",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredClinics.isEmpty
                ? Center(
                    child: Text(
                      "No clinics found.",
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    itemCount: _filteredClinics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final clinic = _filteredClinics[idx];
                      return GestureDetector(
                        onTap: () {
                          final clinicId = clinic['id'];
                          if (clinicId != null && clinicId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ClinicDetailScreen(clinicId: clinicId),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Clinic ID is missing. Cannot open details.')),
                            );
                          }
                        },
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_hospital,
                                        color: primaryColor, size: 28),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        clinic["name"] ?? "",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                    ),
                                    if ((clinic["distance"] ?? "").isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          clinic["distance"]!,
                                          style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        clinic["address"] ?? "",
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 5),
                                    Text(
                                      clinic["hours"] ?? "",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.phone,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 5),
                                    Text(
                                      clinic["phone"] ??
                                          clinic["contactPhone"] ??
                                          "",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
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
