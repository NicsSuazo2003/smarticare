import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/eye_scan/presentation/eye_scan_screen.dart';
import 'package:flutter_application_1/features/symptom_assessment/presentation/symptom_assessment_screen.dart';
import 'package:flutter_application_1/services/audit_log_service.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal Information controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _selectedGender = 'Select Gender';
  DateTime? _selectedDate;

  // Contact Information controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Account Security controllers
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  // Password strength variables
  double _passwordStrength = 0.0;
  String _passwordStrengthText = "Weak";
  Color _passwordStrengthColor = Colors.red;

  String _getReadableError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters with numbers and symbols.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  void _updatePasswordStrength(String password) {
    double strength = 0;
    if (password.isEmpty) {
      strength = 0;
    } else {
      if (password.length >= 8) strength += 0.25;
      if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
      if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
      if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        strength += 0.25;
      }
    }

    setState(() {
      _passwordStrength = strength;

      if (strength <= 0.25) {
        _passwordStrengthText = "Weak";
        _passwordStrengthColor = Colors.red;
      } else if (strength <= 0.5) {
        _passwordStrengthText = "Fair";
        _passwordStrengthColor = Colors.orange;
      } else if (strength <= 0.75) {
        _passwordStrengthText = "Good";
        _passwordStrengthColor = Colors.yellow.shade700;
      } else {
        _passwordStrengthText = "Strong";
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  // Date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ??
            DateTime.now()
                .subtract(const Duration(days: 365 * 18)), // 18 years ago
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFFFF6B6B)),
            ),
            child: child!,
          );
        });

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _showPrivacyPolicyDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Effective Date: October 1, 2025',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  const Text('Introduction',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'SmartiCare respects the privacy of its users and is committed to protecting personal information. '
                    'This Privacy Policy explains how the app collects, uses, and safeguards the data provided by users.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Text('1. Information We Collect',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const _Bullet(
                      'Personal details such as email address for account registration and verification.'),
                  const _Bullet(
                      'Assessment results from symptom-based questionnaires and eye image analysis.'),
                  const _Bullet(
                      'System-generated data such as timestamps and usage records stored securely in Firebase.'),
                  const SizedBox(height: 16),
                  const Text('2. Purpose of Data Collection',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const _Bullet(
                      'Generate pre-screening results and monitor cataract progression.'),
                  const _Bullet(
                      'Improve the accuracy and performance of the system.'),
                  const _Bullet(
                      'Provide Barangay Health administrators with summary reports for health monitoring purposes.'),
                  const SizedBox(height: 8),
                  const Text(
                    'SmartiCare does not provide a medical diagnosis. All outputs are for pre-screening and awareness only. '
                    'Users are encouraged to consult an eye specialist for proper evaluation.',
                    style: TextStyle(fontStyle: FontStyle.italic, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Text('3. Data Storage and Protection',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'All collected data are securely stored in Firebase, with encryption and restricted access to authorized personnel only. '
                    'No data will be shared with third parties without user consent. Offline data stored on the device is automatically '
                    'synchronized once an internet connection is available.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Text('4. User Rights',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const _Bullet(
                      'Access their personal data and assessment history.'),
                  const _Bullet(
                      'Request deletion of their account and data at any time.'),
                  const _Bullet(
                      'Refuse data collection by uninstalling the app.'),
                  const SizedBox(height: 16),
                  const Text('5. Policy Updates',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'This Privacy Policy may be updated as the system improves. Any major changes will be communicated within the app.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showTermsOfServiceDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of Service'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Effective Date: October 1, 2025',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  Text('1. Acceptance of Terms',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'By using SmartiCare, users agree to comply with these terms. If a user disagrees, they should stop using the app.',
                    style: TextStyle(height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Text('2. Purpose of the Application',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'SmartiCare is a cataract pre-screening tool developed for public health awareness and early detection support. '
                    'It is not intended to replace medical consultations or professional diagnosis.',
                    style: TextStyle(height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Text('3. User Responsibilities',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _Bullet(
                      'Use the app only for personal or educational purposes.'),
                  _Bullet(
                      'Understand that results generated are estimates and should not be treated as final medical assessments.'),
                  _Bullet(
                      'Consult a certified eye specialist for confirmation of results.'),
                  SizedBox(height: 16),
                  Text('4. Limitation of Liability',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                      'The developers and partner barangay health units are not responsible for:',
                      style: TextStyle(height: 1.5)),
                  _Bullet('Misinterpretation of pre-screening results.'),
                  _Bullet(
                      'Consequences arising from failure to seek professional care.'),
                  _Bullet(
                      'Technical issues beyond their control (e.g., internet outages, device errors).'),
                  SizedBox(height: 16),
                  Text('5. Data Accuracy and Availability',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'SmartiCare\'s results depend on the quality of the captured image and device performance. '
                    'Accuracy may vary depending on camera quality, lighting conditions, and device specifications.',
                    style: TextStyle(height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Text('6. Contact Information',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'For questions or concerns about this policy, users may contact: smarticare25@gmail.com',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _registerUser() async {
    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check gender selection
    if (_selectedGender == 'Select Gender') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check date of birth
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check terms agreement
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('You must agree to the Terms and Conditions to register'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create Firebase Auth user
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Send verification email
      await userCredential.user!.sendEmailVerification();

      // Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'firstName': _firstNameController.text.trim(),
        'middleName': _middleNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'gender': _selectedGender,
        'birthDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'zipCode': _zipCodeController.text.trim(),
        'username': _usernameController.text.trim(),
        'createdAt':
            DateTime.now().toUtc().toIso8601String(), // current UTC timestamp
        'role': 'Patient',
        'emailVerified': false,
        'status': 'active',
        'agreedToTerms': true,
        'agreedToTermsAt': FieldValue.serverTimestamp(),
      });

      // Log audit action
      await AuditLogService.logAction(
        action: 'user_registered',
        details:
            'New user registered: ${_emailController.text.trim()}, Username: ${_usernameController.text.trim()}',
      );

      // Create admin notification
      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'type': 'new_user',
        'message':
            'New user registered: ${_firstNameController.text.trim()} ${_lastNameController.text.trim()} (${_emailController.text.trim()})',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'relatedUserId': userCredential.user!.uid,
      });

      if (!mounted) return;

      // Show verification dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mark_email_read, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verify Your Email',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A verification email has been sent to:',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _emailController.text.trim(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please check your inbox and click the verification link to activate your account before logging in.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await userCredential.user!.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email sent again!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to resend: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Resend Email'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getReadableError(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Registration error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _afterRegisterFlow(BuildContext context, String userId) async {
    final firestore = FirebaseFirestore.instance;

    final assessments = await firestore
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .limit(1)
        .get();

    final scans = await firestore
        .collection('users')
        .doc(userId)
        .collection('scans')
        .limit(1)
        .get();

    if (assessments.docs.isEmpty || scans.docs.isEmpty) {
      // If either is missing, go to the assessment flow
      // Not currently called, but kept for completeness
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SymptomAssessmentScreen(
            onStart: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EyeScanScreen(symptomScore: 0.0),
                ),
              );
            },
          ),
        ),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    // Personal Information
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();

    // Contact Information
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();

    // Account Security
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade100,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    icon:
                        Icon(Icons.arrow_back_ios, color: Colors.grey.shade800),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 10),
                  // Centered logo and header
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/icon.png',
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Register to get started with SmartiCare',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Personal Information Section
                        _buildSectionHeader(
                            'Personal Information', primaryColor),
                        const SizedBox(height: 16),

                        // First Name
                        _buildFieldLabel('First Name*'),
                        _buildTextField(
                          controller: _firstNameController,
                          hintText: 'Enter your first name',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'First name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Middle Name
                        _buildFieldLabel('Middle Name (optional)'),
                        _buildTextField(
                          controller: _middleNameController,
                          hintText: 'Enter your middle name',
                          prefixIcon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),

                        // Last Name
                        _buildFieldLabel('Last Name*'),
                        _buildTextField(
                          controller: _lastNameController,
                          hintText: 'Enter your last name',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Last name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Gender dropdown
                        _buildFieldLabel('Gender*'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedGender,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.person_outline,
                                  color: Colors.grey.shade600),
                              enabledBorder: InputBorder.none,
                              border: InputBorder.none,
                            ),
                            items: <String>[
                              'Select Gender',
                              'Male',
                              'Female',
                              'Non-binary',
                              'Prefer not to say'
                            ].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedGender = newValue!;
                              });
                            },
                            validator: (value) {
                              if (value == 'Select Gender') {
                                return 'Please select a gender';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date of Birth
                        _buildFieldLabel('Date of Birth*'),
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    color: Colors.grey.shade600),
                                const SizedBox(height: 0, width: 16),
                                Expanded(
                                  child: Text(
                                    _selectedDate == null
                                        ? 'Select your date of birth'
                                        : DateFormat('MMMM d, yyyy')
                                            .format(_selectedDate!),
                                    style: TextStyle(
                                      color: _selectedDate == null
                                          ? Colors.grey.shade600
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _selectedDate == null
                            ? Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 8),
                                child: Text(
                                  'Date of birth is required',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        const SizedBox(height: 24),

                        // Contact Information Section
                        _buildSectionHeader(
                            'Contact Information', primaryColor),
                        const SizedBox(height: 16),

                        // Email
                        _buildFieldLabel('Email Address*'),
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'Enter your email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a valid email';
                            }
                            if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$")
                                .hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        _buildFieldLabel('Phone Number*'),
                        _buildTextField(
                          controller: _phoneController,
                          hintText: 'Enter your phone number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Phone number is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Address
                        _buildFieldLabel('Address*'),
                        _buildTextField(
                          controller: _addressController,
                          hintText: 'Enter your street address',
                          prefixIcon: Icons.home_outlined,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Address is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // City & ZIP Code (side by side)
                        Row(
                          children: [
                            // City
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('City*'),
                                  _buildTextField(
                                    controller: _cityController,
                                    hintText: 'Enter city',
                                    prefixIcon: Icons.location_city_outlined,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'City is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // ZIP Code
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('ZIP Code*'),
                                  _buildTextField(
                                    controller: _zipCodeController,
                                    hintText: 'ZIP Code',
                                    prefixIcon:
                                        Icons.markunread_mailbox_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Account Security Section
                        _buildSectionHeader('Account Security', primaryColor),
                        const SizedBox(height: 16),

                        // Username
                        _buildFieldLabel('Username*'),
                        _buildTextField(
                          controller: _usernameController,
                          hintText: 'Create a username',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Username is required';
                            }
                            if (value.length < 4) {
                              return 'Username must be at least 4 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _buildFieldLabel('Password*'),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            hintText: 'Create a password',
                            prefixIcon: Icon(Icons.lock_outline,
                                color: Colors.grey.shade600),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: primaryColor, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Colors.red, width: 1.5),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          onChanged: _updatePasswordStrength,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),

                        // Password strength indicator
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(
                                value: _passwordStrength,
                                backgroundColor: Colors.grey.shade200,
                                color: _passwordStrengthColor,
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  'Password Strength: $_passwordStrengthText',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _passwordStrengthColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        _buildFieldLabel('Confirm Password*'),
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          hintText: 'Confirm your password',
                          obscureText: _obscureConfirmPassword,
                          onToggleVisibility: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Terms and Conditions with detailed text and links
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _agreeToTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _agreeToTerms = value ?? false;
                                      });
                                    },
                                    activeColor: primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'I agree to the terms of service, privacy policy, and consent to the Processing of my personal health information for monitoring my eye health.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Links to read Terms and Privacy Policy (show as dialogs)
                            Row(
                              children: [
                                const SizedBox(
                                    width: 32), // Align with checkbox text
                                Expanded(
                                  child: Wrap(
                                    spacing: 16,
                                    children: [
                                      GestureDetector(
                                        onTap: _showTermsOfServiceDialog,
                                        child: Text(
                                          'Read Terms of Service',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _showPrivacyPolicyDialog,
                                        child: Text(
                                          'Read Privacy Policy',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: (_isLoading || !_agreeToTerms)
                                ? null
                                : () async {
                                    await _registerUser();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _agreeToTerms
                                  ? primaryColor
                                  : Colors.grey.shade300,
                              foregroundColor: _agreeToTerms
                                  ? Colors.white
                                  : Colors.grey.shade500,
                              elevation: (_isLoading || !_agreeToTerms) ? 0 : 2,
                              shadowColor: primaryColor.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _agreeToTerms
                                        ? 'Create Account'
                                        : 'Agree to Terms to Continue',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Back to Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                  context, '/login'),
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.only(left: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widgets/builders
  Widget _buildSectionHeader(String title, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.grey.shade200,
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey.shade600,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      obscureText: obscureText,
      validator: validator,
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
        ],
      ),
    );
  }
}
