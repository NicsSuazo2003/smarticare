import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/latest_scan_cache.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/security_service.dart';
import '../features/home/presentation/home_screen.dart';
import 'progress_screen.dart';
import 'reminder_screen.dart';
import 'symptom_assessment_screen.dart';

import 'faqs_screen.dart'; // Import for FAQsScreen
import '../features/onboarding/presentation/privacy_policy_screen.dart'; // Import for PrivacyPolicyScreen
import '../features/onboarding/presentation/terms_of_service_screen.dart'; // Added import for TermsOfServiceScreen
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import '../features/auth/presentation/login.dart'; // Import the login screen

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

final User? user = FirebaseAuth.instance.currentUser;
void _updateEmail(BuildContext context) {
  final TextEditingController emailController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Update Email'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'New Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              try {
                String newEmail = emailController.text.trim();
                if (newEmail.isNotEmpty) {
                  await FirebaseAuth.instance.currentUser
                      ?.updateEmail(newEmail);
                  await AuditLogService.logAction(
                    action: 'email_changed',
                    details: 'User changed email to $newEmail.',
                  );
                  await FirebaseFirestore.instance
                      .collection('admin_notifications')
                      .add({
                    'type': 'email_changed',
                    'message': 'User changed email to $newEmail.',
                    'createdAt': FieldValue.serverTimestamp(),
                    'read': false,
                    'relatedUserId':
                        FirebaseAuth.instance.currentUser?.uid ?? "",
                  });
                  final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('notifications')
                      .add({
                    "type": "system",
                    "title": "Email Updated",
                    "message": "Your Email was updated successfully.",
                    "timestamp": FieldValue.serverTimestamp(),
                    "isRead": false,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email updated successfully')),
                  );
                }
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update email: $e')),
                );
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      );
    },
  );
}

// Replace the existing _updatePassword method with this enhanced version
void _updatePassword(BuildContext context) {
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  bool isStrongPassword(String password) {
    // At least 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char
    final regex =
        RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
    return regex.hasMatch(password);
  }

  // Check if user has password provider
  final user = FirebaseAuth.instance.currentUser;
  final hasPasswordProvider =
      user?.providerData.any((provider) => provider.providerId == 'password') ??
          false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasPasswordProvider
                            ? 'Update Password'
                            : 'Set Password',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Only show current password if user has password provider
                      if (hasPasswordProvider) ...[
                        TextField(
                          controller: currentPasswordController,
                          obscureText: obscureCurrent,
                          decoration: InputDecoration(
                            labelText: 'Current Password *',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(obscureCurrent
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => obscureCurrent = !obscureCurrent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your account was created with Google. You can set a password to enable email login.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Rest of the password fields remain the same...
                      TextField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),

                      if (newPasswordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildPasswordStrengthIndicator(
                            newPasswordController.text),
                      ],

                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                      ),

                      // Password requirements...
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password must contain:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildRequirement('At least 8 characters',
                                newPasswordController.text.length >= 8),
                            _buildRequirement(
                                'One uppercase letter (A-Z)',
                                newPasswordController.text
                                    .contains(RegExp(r'[A-Z]'))),
                            _buildRequirement(
                                'One lowercase letter (a-z)',
                                newPasswordController.text
                                    .contains(RegExp(r'[a-z]'))),
                            _buildRequirement(
                                'One number (0-9)',
                                newPasswordController.text
                                    .contains(RegExp(r'[0-9]'))),
                            _buildRequirement(
                                'One special character (!@#\$&*~)',
                                newPasswordController.text
                                    .contains(RegExp(r'[!@#\$&*~]'))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary, // Primary color background
                              foregroundColor: Colors.white, // White text
                            ),
                            onPressed: () async {
                              final newPassword =
                                  newPasswordController.text.trim();
                              final confirmPassword =
                                  confirmPasswordController.text.trim();

                              // Validation
                              if (hasPasswordProvider &&
                                  currentPasswordController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please enter current password')),
                                );
                                return;
                              }

                              if (newPassword.isEmpty ||
                                  confirmPassword.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please fill all fields')),
                                );
                                return;
                              }

                              if (newPassword != confirmPassword) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('New passwords do not match')),
                                );
                                return;
                              }

                              if (!isStrongPassword(newPassword)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please meet all password requirements')),
                                );
                                return;
                              }

                              if (hasPasswordProvider &&
                                  currentPasswordController.text ==
                                      newPassword) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'New password must be different from current password')),
                                );
                                return;
                              }

                              try {
                                if (hasPasswordProvider) {
                                  final credential =
                                      EmailAuthProvider.credential(
                                    email: user!.email!,
                                    password: currentPasswordController.text,
                                  );
                                  await user
                                      .reauthenticateWithCredential(credential);
                                  await user.updatePassword(newPassword);
                                } else {
                                  await FirebaseAuth.instance
                                      .sendPasswordResetEmail(
                                          email: user!.email!);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Password set instructions sent to your email'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  return;
                                }

                                await AuditLogService.logAction(
                                  action: 'password_changed',
                                  details: 'User changed their password.',
                                );

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Password updated successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } on FirebaseAuthException catch (e) {
                                String errorMessage;
                                if (e.code == 'wrong-password') {
                                  errorMessage =
                                      'Current password is incorrect';
                                } else if (e.code == 'weak-password') {
                                  errorMessage = 'New password is too weak';
                                } else if (e.code == 'requires-recent-login') {
                                  errorMessage =
                                      'Please log out and log in again to change password';
                                } else {
                                  errorMessage =
                                      'Failed to update password: ${e.message}';
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Failed to update password: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Text(hasPasswordProvider
                                ? 'UPDATE'
                                : 'SET PASSWORD'),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// Helper widget for password strength indicator
Widget _buildPasswordStrengthIndicator(String password) {
  double strength = 0;
  if (password.isNotEmpty) {
    if (password.length >= 8) strength += 0.2;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#\$&*~\.]'))) strength += 0.2;
  }

  String strengthText;
  Color strengthColor;

  if (strength <= 0.4) {
    strengthText = "Weak";
    strengthColor = Colors.red;
  } else if (strength <= 0.7) {
    strengthText = "Fair";
    strengthColor = Colors.orange;
  } else if (strength <= 0.9) {
    strengthText = "Good";
    strengthColor = Colors.yellow.shade700;
  } else {
    strengthText = "Strong";
    strengthColor = Colors.green;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LinearProgressIndicator(
        value: strength,
        backgroundColor: Colors.grey.shade300,
        color: strengthColor,
        minHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),
      const SizedBox(height: 4),
      Text(
        'Password Strength: $strengthText',
        style: TextStyle(
          fontSize: 12,
          color: strengthColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

// Helper widget for password requirements
Widget _buildRequirement(String text, bool isMet) {
  return Row(
    children: [
      Icon(
        isMet ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 14,
        color: isMet ? Colors.green : Colors.grey,
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isMet ? Colors.green : Colors.grey,
        ),
      ),
    ],
  );
}

void _deleteAccount(BuildContext context) {
  final User? user = FirebaseAuth.instance.currentUser;
  final String? uid = user?.uid;

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        title: const Text('Delete Account Permanently'),
        content: const Text(
            'This action is irreversible. All your scan history, assessments, and personal profile data will be permanently deleted from our servers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              try {
                if (uid == null) return;

                // 1. Wipe Firestore Data (Sub-collections + Profile)
                final batch = FirebaseFirestore.instance.batch();
                final userRef =
                    FirebaseFirestore.instance.collection('users').doc(uid);

                // Helper to add sub-collection docs to batch
                Future<void> addCollectionToBatch(String collectionName) async {
                  final snapshots =
                      await userRef.collection(collectionName).get();
                  for (var doc in snapshots.docs) {
                    batch.delete(doc.reference);
                  }
                }

                await addCollectionToBatch('scans');
                await addCollectionToBatch('assessments');
                await addCollectionToBatch('notifications');

                // Delete the main profile document
                batch.delete(userRef);

                // 2. Commit Firestore Deletion
                await batch.commit();

                // 3. Delete Firebase Authentication Record
                await user?.delete();

                // 4. Cleanup & Redirect
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Account and all data permanently deleted.')),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (e.code == 'requires-recent-login') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please logout and login again to verify your identity before deleting.')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error during deletion: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE EVERYTHING'),
          ),
        ],
      );
    },
  );
}

void _logout(BuildContext context) async {
  try {
    LatestScanCache.clearCache();
    await FirebaseAuth.instance.signOut();

    // ✅ ADD THIS: Reset hasSeenWelcome on logout
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logout failed: $e')),
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedNavIndex = 4; // Set to 4 for Profile tab
  final Color primaryColor = const Color(0xFFFF6B6B);
  User? _currentUser;
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    }
  }

  // Helper to get full name
  String get _fullName {
    return [
      _userData["firstName"] ?? "",
      _userData["middleName"] ?? "",
      _userData["lastName"] ?? "",
    ].where((part) => part.isNotEmpty).join(" ");
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProgressScreen()),
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReminderScreen()),
        );
        break;
      case 4:
        // Already on profile screen
        break;
    }
  }

  void _showEditProfileDialog() {
    // Create text controllers with current values
    final TextEditingController firstNameController =
        TextEditingController(text: _userData["firstName"]);
    final TextEditingController middleNameController =
        TextEditingController(text: _userData["middleName"]);
    final TextEditingController lastNameController =
        TextEditingController(text: _userData["lastName"]);
    final TextEditingController emailController =
        TextEditingController(text: _userData["email"]);
    final TextEditingController phoneController =
        TextEditingController(text: _userData["phone"]);
    final TextEditingController dobController =
        TextEditingController(text: _userData["birthDate"]); // ✅ CORRECT
    final TextEditingController addressController =
        TextEditingController(text: _userData["address"]);
    final TextEditingController cityController =
        TextEditingController(text: _userData["city"]);
    final TextEditingController zipCodeController =
        TextEditingController(text: _userData["zipCode"]);

    String selectedGender = _userData["gender"] ?? "Male";
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Personal Information
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: middleNameController,
                        decoration: const InputDecoration(
                          labelText: 'Middle Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Gender dropdown
                      const Text(
                        'Gender*',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: <String>['Male', 'Female', 'Other']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedGender = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Replace the existing DOB TextFormField with this read-only picker field:
                      GestureDetector(
                        onTap: () async {
                          // parse existing date in controller if available, otherwise use a sensible default
                          DateTime initialDate;
                          try {
                            initialDate = DateFormat('yyyy-MM-dd')
                                .parse(dobController.text);
                          } catch (_) {
                            initialDate = DateTime.now()
                                .subtract(const Duration(days: 365 * 25));
                          }

                          final DateTime firstDate = DateTime(1900);
                          final DateTime lastDate = DateTime.now();

                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: firstDate,
                            lastDate: lastDate,
                            builder: (context, child) {
                              // Optional: keep the dialog themed similarly
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary:
                                        primaryColor, // header background color
                                    onPrimary:
                                        Colors.white, // header text color
                                    onSurface: Colors.black, // body text color
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                        foregroundColor: primaryColor),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (picked != null) {
                            final formatted =
                                DateFormat('yyyy-MM-dd').format(picked);
                            setState(() {
                              dobController.text = formatted;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: dobController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth (YYYY-MM-DD)*',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your date of birth';
                              }
                              // keep basic YYYY-MM-DD validation
                              final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                              if (!dateRegex.hasMatch(value)) {
                                return 'Please use YYYY-MM-DD format';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Section 2: Contact Information
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          final emailRegex =
                              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: 'City*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your city';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: zipCodeController,
                        decoration: const InputDecoration(
                          labelText: 'ZIP Code*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your ZIP code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '* Required fields',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        // 1. Update Firestore data
                        // ✅ FIXED: Only update user-editable fields
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(_currentUser!.uid)
                            .update({
                          'firstName': firstNameController.text.trim(),
                          'middleName': middleNameController.text.trim(),
                          'lastName': lastNameController.text.trim(),
                          'gender': selectedGender,
                          'phone': phoneController.text.trim(),
                          'address': addressController.text.trim(),
                          'city': cityController.text.trim(),
                          'zipCode': zipCodeController.text.trim(),
                          'birthDate': dobController.text.trim(),
                          // ❌ DO NOT UPDATE: role, status, createdAt, email, username
                          // ❌ DO NOT CREATE: firstname, lastname, name
                        });

// ✅ Handle email update separately through Firebase Auth
                        if (emailController.text.trim() != _userData['email']) {
                          try {
                            await _currentUser!
                                .updateEmail(emailController.text.trim());
                            // Then update Firestore
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_currentUser!.uid)
                                .update({'email': emailController.text.trim()});
                          } catch (e) {
                            // Handle re-authentication requirement
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Email update failed. Please re-login and try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                        await AuditLogService.logAction(
                          action: 'profile_updated',
                          details: 'User updated profile information.',
                        );

                        // 3. Refresh UI
                        _loadUserData();

                        // Close dialog
                        Navigator.pop(context, true);

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Error updating profile: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    'SAVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close the dialog
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog first
                try {
                  LatestScanCache.clearCache();
                  await FirebaseAuth.instance.signOut(); // Sign out the user
                  // Navigate to the login screen
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false, // Remove all previous routes
                  );
                } catch (e) {
                  // Handle logout error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile Settings',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildProfileHeader(),
          _buildProfileDetails(),
          _buildSecuritySection(),
          _buildSupportSection(),

          // Logout button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () => _confirmLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Logout', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),

          // App version
          Center(
            child: Text(
              'SmartiCare v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 20, bottom: 30),
      child: Column(
        children: [
          // Avatar with letter only
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              _userData["firstName"]?.substring(0, 1).toUpperCase() ?? "A",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userData["email"] ?? "",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _showEditProfileDialog,
                  color: primaryColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(),

          // Name section with header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Name Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ),
          _buildDetailItem(
            icon: Icons.badge_outlined,
            label: 'First Name',
            value: _userData["firstName"] ?? "Not provided",
          ),
          _buildDetailItem(
            icon: Icons.badge_outlined,
            label: 'Middle Name',
            value: _userData["middleName"] ?? "Not provided",
          ),
          _buildDetailItem(
            icon: Icons.badge_outlined,
            label: 'Last Name',
            value: _userData["lastName"] ?? "Not provided",
          ),

          // Basic info section with header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ),
          _buildDetailItem(
            icon: Icons.people_outlined,
            label: 'Gender',
            value: _userData["gender"] ?? "Not provided",
          ),
          _buildDetailItem(
            icon: Icons.cake_outlined,
            label: 'Date of Birth',
            value: _userData["birthDate"] ??
                "Not provided", // ✅ CORRECT FIELD NAME
          ),

          // Contact info section with header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ),
          _buildDetailItem(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: _userData["email"] ?? "Not provided",
          ),
          _buildDetailItem(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: _userData["phone"] ?? "Not provided",
          ),

          // Address section with header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Address Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ),
          _buildDetailItem(
            icon: Icons.home_outlined,
            label: 'Address',
            value: _userData["address"] ?? "Not provided",
          ),
          _buildDetailItem(
            icon: Icons.location_city_outlined,
            label: 'City',
            value: _userData["city"] ?? "Not provided",
          ),
          _buildDetailItem(
            icon: Icons.pin_outlined,
            label: 'ZIP Code',
            value: _userData["zipCode"] ?? "Not provided",
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// Build Security Section
  Widget _buildSecuritySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Security & Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: () => _updatePassword(context),
          ),
          _buildSettingTile(
            icon: Icons.history,
            title: 'Login Activity',
            onTap: () => _showLoginActivity(context),
          ),
          _buildSettingTile(
            icon: Icons.verified_user,
            title: 'Two-Factor Authentication',
            subtitle: 'Add extra security to your account',
            onTap: () => _show2FASettings(context),
          ),
          _buildSettingTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            isDestructive: true,
            onTap: () => _deleteAccount(context),
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// Show login activity
  void _showLoginActivity(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.login, color: Colors.blue),
            SizedBox(width: 10),
            Text('Login Activity'),
          ],
        ),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: SecurityService.getLoginActivity(_currentUser?.email ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('No login activity found.');
            }

            final activities = snapshot.data!;

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final log = activities[index];
                  final timestamp = (log['timestamp'] as Timestamp).toDate();

                  return ListTile(
                    leading: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: const Text('Successful Login'),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy HH:mm').format(timestamp),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show 2FA settings
  void _show2FASettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.green),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Two-Factor Authentication',
                overflow: TextOverflow.ellipsis, // optional
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add an extra layer of security to your account.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'We\'ll send a verification code to your email when you login from a new device.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _enable2FA(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Enable 2FA'),
          ),
        ],
      ),
    );
  }

  /// Enable 2FA
  Future<void> _enable2FA(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await SecurityService.enable2FA(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Two-factor authentication enabled!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

// Replace your existing _deactivateAccount with this version
  void _deactivateAccount(BuildContext context) {
    // Capture the parent (ProfileScreen) context, not the dialog context
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Deactivate Account'),
          content: const Text(
            'Your account will be deactivated. You will be logged out immediately. All your data will be preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                // 1) Close the confirmation dialog
                Navigator.pop(dialogCtx);
                // 2) Call deactivation on the parent context on next frame
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _performDeactivation(parentContext);
                });
              },
              style: TextButton.styleFrom(
                backgroundColor:
                    Theme.of(context).primaryColor, // button background
                foregroundColor: Colors.white, // text color
              ),
              child: const Text('DEACTIVATE'),
            )
          ],
        );
      },
    );
  }

  // Replace the existing _performDeactivation(...) in profile_screen.dart with this updated version.

  // Replace your existing _performDeactivation with this version
  Future<void> _performDeactivation(BuildContext context) async {
    final nav = Navigator.of(context, rootNavigator: true);

    // Show blocking loader on the ROOT navigator
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final uid = _currentUser?.uid;
    if (uid == null) {
      // Close loader safely and report error
      if (nav.canPop()) nav.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user is currently logged in.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool success = false;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'inactive',
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      await AuditLogService.logAction(
        action: 'account_deactivated',
        details: 'User deactivated their account.',
      );

      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'type': 'account_deactivated',
        'message': 'User deactivated their account.',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'relatedUserId': uid,
      });

      success = true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to deactivate account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Always try to close the loader
      if (nav.canPop()) {
        try {
          nav.pop();
        } catch (_) {}
      }
    }

    if (!success) return;

    // Sign out; even if it fails, continue to navigate to login
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Non-fatal: show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Sign out error: $e'), backgroundColor: Colors.red),
      );
    }

    if (!mounted) return;

    // Navigate to Login on the root navigator after the loader is definitely closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });

    // Optional: If you still want a success message, do it after a slight delay so
    // the login screen has built. This uses the same root navigator context.
    Future.delayed(const Duration(milliseconds: 300), () {
      // It's okay if this fails silently when the new route replaces scaffold
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deactivated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (_) {}
    });
  }

  Widget _buildSupportSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildSettingTile(
            icon: Icons.help_outline,
            title: 'FAQs',
            onTap: () {
              // Navigate to FAQsScreen when FAQs is tapped
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FAQsScreen(),
                ),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              // Navigate to PrivacyPolicyScreen when Privacy Policy is tapped
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {
              // Navigate to TermsOfServiceScreen when Terms of Service is tapped
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsOfServiceScreen(),
                ),
              );
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            color: isDestructive ? Colors.red : Colors.grey.shade700,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isDestructive ? Colors.red : null,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: const Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),
          onTap: onTap,
        ),
        if (!isLast) const Divider(height: 1, indent: 70),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
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
