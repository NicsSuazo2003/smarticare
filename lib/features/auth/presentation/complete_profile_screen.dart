import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/Screens/home_screen.dart';

import 'package:flutter_application_1/audit_log_service.dart';
import 'package:flutter_application_1/features/auth/presentation/login.dart';
import 'package:intl/intl.dart';
import '../../../Screens/eye_scan_screen.dart';
import '../../../Screens/symptom_assessment_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;

  const CompleteProfileScreen({
    Key? key,
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
  }) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _selectedGender = 'Select Gender';
  DateTime? _selectedDate;

  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.firstName;
    _lastNameController.text = widget.lastName;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true ||
        _selectedGender == 'Select Gender' ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'firstName': _firstNameController.text.trim(),
        'middleName': _middleNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'gender': _selectedGender,
        'birthDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'email': widget.email,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'zipCode': _zipCodeController.text.trim(),
        'username': _usernameController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
        'role': 'Patient',
        'status': 'active',
        'agreedToTerms': true,
        'agreedToTermsAt': FieldValue.serverTimestamp(),
        'emailVerified': true,
      });

      await AuditLogService.logAction(
        action: 'complete_profile',
        details: 'User completed profile with email: ${widget.email}',
      );

      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'type': 'profile_completed',
        'message': 'User completed profile: ${widget.email}',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'relatedUserId': widget.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile completed!')),
      );

      // After successfully writing profile, route appropriately
      await _afterProfileComplete(context, widget.uid);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _afterProfileComplete(
      BuildContext context, String userId) async {
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
      // Clear the entire stack and start fresh with assessment flow
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => SymptomAssessmentScreen(
            onStart: () {
              // Don't navigate here - let the assessment screen handle it
            },
          ),
        ),
        (route) => false, // Clear entire stack
      );
    } else {
      // User already has data, go to Home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false, // Clear entire stack
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    // Wrap scaffold with WillPopScope to intercept device back press
    return WillPopScope(
      onWillPop: () async {
        // Ask user for confirmation before leaving incomplete profile flow
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave registration?'),
            content: const Text(
              'Your profile is not yet complete. If you leave now you will be signed out and will need to sign in again to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white, // 👈 makes the text white
                ),
                child: const Text('Leave'),
              ),
            ],
          ),
        );

        if (shouldLeave == true) {
          // Sign out the Firebase user so app won't treat them as fully logged-in
          try {
            await FirebaseAuth.instance.signOut();
          } catch (e) {
            print('Sign out error: $e');
          }

          // Navigate to login and clear stack
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
          return false; // we handled navigation
        }

        // stay in place (do not pop)
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Complete Your Profile')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First Name
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Middle Name
                TextFormField(
                  controller: _middleNameController,
                  decoration: const InputDecoration(labelText: 'Middle Name'),
                ),
                const SizedBox(height: 12),
                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Gender
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  items: [
                    'Select Gender',
                    'Male',
                    'Female',
                    'Non-binary',
                    'Prefer not to say'
                  ]
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedGender = val!),
                  decoration: const InputDecoration(labelText: 'Gender *'),
                  validator: (val) =>
                      val == 'Select Gender' ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Date of Birth
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(labelText: "Date of Birth *"),
                    child: Text(
                      _selectedDate == null
                          ? 'Tap to select date'
                          : DateFormat('MMMM d, yyyy').format(_selectedDate!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration:
                      const InputDecoration(labelText: 'Phone Number *'),
                  keyboardType: TextInputType.phone,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // City
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // ZIP Code
                TextFormField(
                  controller: _zipCodeController,
                  decoration: const InputDecoration(labelText: 'ZIP Code *'),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, // background color
                      foregroundColor: Colors.white, // text & icon color
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text('Complete Registration'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
