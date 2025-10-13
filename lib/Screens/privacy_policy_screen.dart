import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';
import 'symptom_assessment_screen.dart';

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
                    'Last Updated: June 1, 2025',
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
                    'SmartiCare (“we”, “our”, “us”) is committed to protecting your privacy. This Privacy Policy describes how we collect, use, disclose, and safeguard your information when you use the SmartiCare mobile application (“App”).'
                    '\n\nPlease read this Privacy Policy carefully. By using the Application, you agree to the collection and use of information in accordance with this policy. If you do not agree with our policies and practices, do not use our Application.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Information We Collect
                  const Text(
                    'Information We Collect',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We collect several types of information from and about users of our Application, including:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                      'Personal Information: Name, email address, gender, date of birth, and basic profile details used for account creation and personalization.'),
                  _buildBulletItem(
                      'Health Information: Eye scan results, symptom assessments, appointment and reminder details, and progress tracking data. These are stored securely and used to support your personal eye health monitoring.'),
                  _buildBulletItem(
                      'Technical Information: hnical details such as device type, operating system, and app version for support and security.'),
                  _buildBulletItem(
                      'Usage Data: Actions such as scan history, appointment creation, and reminder usage to improve user experience.'),
                  const SizedBox(height: 20),

                  // How We Use Your Information
                  const Text(
                    'How We Use Your Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We may use the information we collect from you for various purposes, including:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                      'Provide and improve our medical screening and health monitoring services'),
                  _buildBulletItem(
                      'Analyze eye images and symptoms using AI and medical guidelines'),
                  _buildBulletItem(
                      'Personalize your experience and recommendations'),
                  _buildBulletItem(
                      'Communicate important updates, results, or reminders'),
                  _buildBulletItem(
                      'Comply with legal, regulatory, and ethical obligations'),
                  _buildBulletItem('To provide customer support'),
                  _buildBulletItem(
                      'Conduct anonymized research and analytics (you will never be personally identified in published results)'),
                  _buildBulletItem('To monitor usage of our Application'),
                  _buildBulletItem(
                      'To detect, prevent, and address technical issues'),
                  const SizedBox(height: 20),

                  // Disclosure of Your Information
                  const Text(
                    'Disclosure of Your Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We may disclose information that we collect in the following circumstances:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem('To our subsidiaries and affiliates'),
                  _buildBulletItem(
                      'To healthcare providers with your explicit consent'),
                  _buildBulletItem(
                      'To contractors, service providers, and other third parties we use to support our business'),
                  _buildBulletItem(
                      'To fulfill the purpose for which you provide it'),
                  _buildBulletItem(
                      'For any other purpose disclosed by us when you provide the information'),
                  _buildBulletItem('With your consent'),
                  _buildBulletItem(
                      'To comply with any court order, law, or legal process'),
                  _buildBulletItem(
                      'To enforce our rights arising from any contracts entered into between you and us'),
                  _buildBulletItem(
                      'If we believe disclosure is necessary to protect the rights, property, or safety of our company, our customers, or others'),
                  const SizedBox(height: 20),

                  // Data Security
                  const Text(
                    'Data Security',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We have implemented measures designed to secure your personal information from accidental loss and unauthorized access, use, alteration, and disclosure. All information you provide to us is stored on secure servers behind firewalls.'
                    '\n\nThe safety and security of your information also depends on you. Where we have given you (or where you have chosen) a password for access to certain parts of our Application, you are responsible for keeping this password confidential.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Your Rights
                  const Text(
                    'Your Rights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'You have the right to:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                      'Access and receive a copy of your personal data'),
                  _buildBulletItem(
                      'Rectify inaccurate or incomplete personal data'),
                  _buildBulletItem(
                      'Request the deletion of your personal data'),
                  _buildBulletItem(
                      'Object to the processing of your personal data'),
                  _buildBulletItem(
                      'Withdraw consent at any time where we relied on your consent to process your personal data'),
                  const SizedBox(height: 20),

                  // Changes to Our Privacy Policy
                  const Text(
                    'Changes to Our Privacy Policy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date at the top of this Privacy Policy.'
                    '\n\nYou are advised to review this Privacy Policy periodically for any changes. Changes to this Privacy Policy are effective when they are posted on this page.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Contact Us
                  const Text(
                    'Contact Us',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'If you have any questions about this Privacy Policy, please contact us at:'
                    '\n\nSmartiCare.'
                    '\nEmail: privacy@smarticare.com'
                    '\nPhone: 09071355012'
                    '\nAddress: Brgy. Poblacion, Sta. Maria, Davao Occidental',
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
