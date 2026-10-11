import 'package:flutter/material.dart';
import '../../../features/home/presentation/home_screen.dart';
import '../../../features/profile/presentation/progress_screen.dart';
import '../../../features/reminders/presentation/reminder_screen.dart';
import '../../../features/profile/presentation/profile_screen.dart';
import '../../../features/symptom_assessment/presentation/symptom_assessment_screen.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  int _selectedNavIndex =
      4; // Default to profile since this is accessed from profile

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Date and User info
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),

          // Privacy Policy Content
          // Replace the entire privacy policy content section with this:

// Privacy Policy Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Effective Date: October 1, 2025',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Introduction
                  const Text(
                    'Introduction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SmartiCare respects the privacy of its users and is committed to protecting personal information. This Privacy Policy explains how the app collects, uses, and safeguards the data provided by users.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Information We Collect
                  const Text(
                    '1. Information We Collect',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SmartiCare may collect the following information:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                      'Personal details such as email address for account registration and verification.'),
                  _buildBulletItem(
                      'Assessment results from symptom-based questionnaires and eye image analysis.'),
                  _buildBulletItem(
                      'System-generated data such as timestamps and usage records stored securely in Firebase.'),
                  const SizedBox(height: 20),

                  // Purpose of Data Collection
                  const Text(
                    '2. Purpose of Data Collection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The information gathered is used to:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                      'Generate pre-screening results and monitor cataract progression.'),
                  _buildBulletItem(
                      'Improve the accuracy and performance of the system.'),
                  _buildBulletItem(
                      'Provide Barangay Health administrators with summary reports for health monitoring purposes.'),
                  const SizedBox(height: 10),
                  const Text(
                    'SmartiCare does not provide a medical diagnosis. All outputs are for pre-screening and awareness only. Users are encouraged to consult an eye specialist for proper evaluation.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Data Storage and Protection
                  const Text(
                    '3. Data Storage and Protection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'All collected data are securely stored in Firebase, with encryption and restricted access to authorized personnel only. No data will be shared with third parties without user consent. Offline data stored on the device is automatically synchronized once an internet connection is available.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // User Rights
                  const Text(
                    '4. User Rights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Users have the right to:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                      'Access their personal data and assessment history.'),
                  _buildBulletItem('Users can delete their account.'),
                  _buildBulletItem(
                      'Refuse data collection by uninstalling the app.'),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),

// Data Management and Viewing
                  const Text(
                    '5. Data Management and Viewing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SmartiCare provides the following data management capabilities:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                      'Storing:  All scan results and assessments are automatically stored in your account for tracking and monitoring purposes.'),
                  _buildBulletItem(
                      'Viewing: You can view your complete scan history and assessment results at any time through the Progress and History sections of the app.'),
                  _buildBulletItem(
                      'Deleting: Users may delete their account, which will remove all associated personal data from our systems.'),
                  _buildBulletItem(
                      'Offline Access: When offline, data is stored locally on your device and will sync automatically when an internet connection is restored.'),
                  const SizedBox(height: 10),
                  const Text(
                    'Please note that once data is deleted through account deactivation, it cannot be recovered.  We recommend downloading your reports before deactivating your account if you wish to retain personal records.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Policy Updates
                  const Text(
                    '6. Policy Updates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This Privacy Policy may be updated as the system improves. Any major changes will be communicated within the app.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    const Color primaryColor = Color(0xFFFF6B6B);

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
            decoration: const BoxDecoration(
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
