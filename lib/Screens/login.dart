import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/complete_profile_screen.dart';
import 'package:flutter_application_1/Screens/forgot_password_screen.dart';
import 'package:flutter_application_1/Screens/latest_scan_cache.dart';
import 'package:flutter_application_1/Screens/symptom_assessment_screen.dart';
import 'package:flutter_application_1/Screens/terms_of_service_screen.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:flutter_svg/svg.dart';
import 'app_permission_screen.dart';
import 'package:provider/provider.dart';
import '../user_session_provider.dart'; // adjust the path as needed
import 'eye_scan_screen.dart'; // for direct navigation
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'privacy_policy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _obscureText = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  final _emailController = TextEditingController();

  Future<void> saveTokenToFirestore(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    }
  }

  void _showSnackBar(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color ?? Colors.red,
    ));
  }

  // Add this function to check and reactivate user status
  Future<bool> _checkAndReactivateUser(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String status = userData['status'] ?? 'active';

        if (status == 'inactive') {
          // Reactivate the account
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'status': 'active',
            'reactivatedAt': FieldValue.serverTimestamp(),
          });

          // Log the reactivation
          await AuditLogService.logAction(
            action: 'account_reactivated',
            details: 'User reactivated their account by logging in.',
          );

          // Notify admin
          await FirebaseFirestore.instance
              .collection('admin_notifications')
              .add({
            'type': 'account_reactivated',
            'message':
                'User ${userData["firstName"]} ${userData["lastName"]} reactivated their account.',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
            'relatedUserId': userId,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome back! Your account has been reactivated.'),
              backgroundColor: Colors.green,
            ),
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking user status: $e');
      return false;
    }
  }

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        _formKey.currentState!.save();

        // Authenticate
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // ✅ CHECK EMAIL VERIFICATION
        if (!userCredential.user!.emailVerified) {
          await FirebaseAuth.instance.signOut();

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Email Not Verified'),
              content: const Text(
                'Please verify your email address before logging in.\n\n'
                'Check your inbox for the verification link.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await userCredential.user!.sendEmailVerification();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification email sent!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to send email.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Resend Email'),
                ),
              ],
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        LatestScanCache.clearCache();

        // ✅ CHECK AND REACTIVATE USER STATUS
        await _checkAndReactivateUser(userCredential.user!.uid);

        await AuditLogService.logAction(
          action: 'login',
          details: 'User logged in with email: $_email',
        );

        // Continue with normal login flow
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await saveTokenToFirestore(user.uid);
          await _afterLoginFlow(context, user.uid);
        }
      } on FirebaseAuthException catch (e) {
        // Show red SnackBar for wrong credentials or user not found, etc.
        String message = "Invalid email or password";
        // You can further customize by checking e.code if needed
        _showSnackBar(message, color: Colors.red);
      } catch (_) {
        _showSnackBar("Invalid email or password", color: Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    String email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar("Please enter your email address.", color: Colors.red);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackBar("Password reset email sent!", color: Colors.green);
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred.";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email address.";
      }
      _showSnackBar(message, color: Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _afterLoginFlow(BuildContext context, String userId) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Check for assessment history
    final assessments = await firestore
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .limit(1)
        .get();

    // 2. Check for scan history
    final scans = await firestore
        .collection('users')
        .doc(userId)
        .collection('scans')
        .limit(1)
        .get();

    if (assessments.docs.isEmpty || scans.docs.isEmpty) {
      // If either is missing, go to the assessment flow
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SymptomAssessmentScreen(
            onStart: () {
              // After assessment, go to Eye Scan
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EyeScanScreen(
                      symptomScore: 0.0), // TODO: pass actual symptom score
                ),
              );
            },
          ),
        ),
      );
    } else {
      // User already has data, go to Home
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> startOnboardingFlowIfFirstTime(
      BuildContext context, String userId) async {
    final firestore = FirebaseFirestore.instance;

    // Check if the user has any completed assessments
    final assessments = await firestore
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .limit(1)
        .get();

    // Check if the user has any scans
    final scans = await firestore
        .collection('users')
        .doc(userId)
        .collection('scans')
        .limit(1)
        .get();

    if (assessments.docs.isEmpty || scans.docs.isEmpty) {
      // If either is missing, start the assessment flow
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SymptomAssessmentScreen(
            onStart: () {
              // At the end of symptom assessment, navigate to Eye Scan
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EyeScanScreen(
                      symptomScore: /* pass the calculated score here */ 0.0),
                ),
              );
            },
          ),
        ),
      );
    } else {
      // Otherwise, go to home screen as normal
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // Removed _continueAsGuest

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await GoogleSignIn().signOut();
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // ✅ CHECK AND REACTIVATE USER STATUS
      await _checkAndReactivateUser(userCredential.user!.uid);

      // After signing in, check Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      await saveTokenToFirestore(userCredential.user!.uid);

      if (!userDoc.exists) {
        // No profile in Firestore: sign out and show error
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account is not registered in this app.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      await AuditLogService.logAction(
        action: 'login_google',
        details: 'User logged in with Google: ${userCredential.user?.email}',
      );

      // User exists in Firestore, proceed as normal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppPermissionScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> handleGoogleSignIn(BuildContext context) async {
    try {
      await GoogleSignIn().signOut();
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // user cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) return;
      LatestScanCache.clearCache();

      // ✅ CHECK AND REACTIVATE USER STATUS
      await _checkAndReactivateUser(user.uid);

      // Check Firestore profile
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // ✅ NEW USER: Show Terms and Conditions Dialog
        final bool agreedToTerms = await _showTermsDialog(context);

        if (!agreedToTerms) {
          // User declined terms, sign them out and show message
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'You must agree to the Terms and Conditions to create an account'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Parse first/last name
        String firstName = "";
        String lastName = "";
        if (googleUser.displayName != null) {
          final parts = googleUser.displayName!.split(" ");
          firstName = parts.isNotEmpty ? parts.first : "";
          lastName = parts.length > 1 ? parts.sublist(1).join(" ") : "";
        }

        // Navigate to complete profile screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompleteProfileScreen(
              uid: user.uid,
              email: googleUser.email,
              firstName: firstName,
              lastName: lastName,
            ),
          ),
        );
      } else {
        // Profile exists, go to home
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
  }

  Future<bool> _showTermsDialog(BuildContext context) async {
    bool agreed = false;
    bool scrolledToEnd = false;
    const double _endTolerance = 20.0; // px tolerance from bottom

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: const Text('Terms and Conditions'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scrollable terms content wrapped in a NotificationListener
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (scrollNotification) {
                          final metrics = scrollNotification.metrics;
                          // If content is non-scrollable (maxScrollExtent == 0) treat as already at end
                          final atEnd = metrics.maxScrollExtent <= 0 ||
                              metrics.pixels >=
                                  metrics.maxScrollExtent - _endTolerance;
                          if (atEnd && !scrolledToEnd) {
                            setState(() {
                              scrolledToEnd = true;
                            });
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.blue.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Please read carefully before continuing',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Effective Date: October 1, 2025',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 16),

                              // 1. Acceptance of Terms
                              const Text(
                                '1. Acceptance of Terms',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'By using SmartiCare, users agree to comply with these terms. If a user disagrees, they should stop using the app.',
                                style: TextStyle(fontSize: 14, height: 1.6),
                              ),
                              const SizedBox(height: 16),

                              // 2. Purpose of the Application
                              const Text(
                                '2. Purpose of the Application',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'SmartiCare is a cataract pre-screening tool developed for public health awareness and early detection support. It is not intended to replace medical consultations or professional diagnosis.',
                                style: TextStyle(fontSize: 14, height: 1.6),
                              ),
                              const SizedBox(height: 16),

                              // 3. User Responsibilities
                              const Text(
                                '3. User Responsibilities',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Users must:',
                                style: TextStyle(fontSize: 14, height: 1.6),
                              ),
                              const SizedBox(height: 8),
                              const _Bullet(
                                  'Use the app only for personal or educational purposes.'),
                              const _Bullet(
                                  'Understand that results generated are estimates and should not be treated as final medical assessments.'),
                              const _Bullet(
                                  'Consult a certified eye specialist for confirmation of results.'),
                              const SizedBox(height: 16),

                              // 4. Limitation of Liability
                              const Text(
                                '4. Limitation of Liability',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'The developers and partner barangay health units are not responsible for:',
                                style: TextStyle(fontSize: 14, height: 1.6),
                              ),
                              const SizedBox(height: 8),
                              const _Bullet(
                                  'Misinterpretation of pre-screening results.'),
                              const _Bullet(
                                  'Consequences arising from failure to seek professional care.'),
                              const _Bullet(
                                  'Technical issues beyond their control (e.g., internet outages, device errors).'),
                              const SizedBox(height: 16),

                              // 5. Data Accuracy and Availability
                              const Text(
                                '5. Data Accuracy and Availability',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'SmartiCare\'s results depend on the quality of the captured image and device performance. Accuracy may vary depending on camera quality, lighting conditions, and device specifications.',
                                style: TextStyle(fontSize: 14, height: 1.6),
                              ),
                              const SizedBox(height: 16),

                              // 6. Contact Information
                              const Text(
                                '6. Contact Information',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'For questions or concerns about this policy, users may contact: smarticare25@gmail.com',
                                style: TextStyle(fontSize: 14, height: 1.6),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Checkbox row; disable the checkbox until user has scrolled to end
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: agreed,
                          onChanged: scrolledToEnd
                              ? (value) {
                                  setState(() {
                                    agreed = value ?? false;
                                  });
                                }
                              : null, // disabled until scrolled
                          activeColor: const Color(0xFFFF6B6B),
                        ),
                        Expanded(
                          child: Text(
                            scrolledToEnd
                                ? 'I have read and agree to the Terms of Service'
                                : 'Scroll to the bottom to enable agreement',
                            style: TextStyle(
                              fontSize: 13,
                              color: scrolledToEnd
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Optional small link to open the full screen Terms page
                    // Links to read full Terms and Privacy Policy
                    // Link to view Privacy Policy
                    Center(
                      child: TextButton(
                        onPressed: _openPrivacyPolicyDialog,
                        child: const Text(
                          'View Privacy Policy',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: agreed ? () => Navigator.pop(context, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).primaryColor, // background color
                    foregroundColor: Colors.white, // text (and icon) color
                  ),
                  child: const Text('Continue'),
                )
              ],
            );
          }),
        ) ??
        false;
  }

// Place these two helpers inside _LoginScreenState (below other methods)

  Future<void> _openPrivacyPolicyDialog() async {
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

// Small bullet helper widget used in the dialogs above
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);
    final Size size = MediaQuery.of(context).size;

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
            child: Container(
              height: size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  // Logo & Header
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
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
                      const SizedBox(height: 24),
                      const Text(
                        'SmartiCare',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sign in to your account',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email label
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Email',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        // Email field
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            prefixIcon: Icon(Icons.email_outlined,
                                color: Colors.grey.shade600),
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
                              borderSide:
                                  BorderSide(color: primaryColor, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Colors.red, width: 1.5),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onSaved: (value) => _email = value ?? '',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$")
                                .hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Password label
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Password',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        // Password field
                        TextFormField(
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: Icon(Icons.lock_outline,
                                color: Colors.grey.shade600),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureText = !_obscureText),
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
                              borderSide:
                                  BorderSide(color: primaryColor, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Colors.red, width: 1.5),
                            ),
                          ),
                          obscureText: _obscureText,
                          onSaved: (value) => _password = value ?? '',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        // Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed:
                                  _isLoading ? null : _sendPasswordResetEmail,
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: _isLoading ? 0 : 2,
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
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: SvgPicture.asset(
                        'assets/google_logo.svg',
                        height: 24,
                      ), // Add Google logo to assets
                      label: const Text('Sign in with Google'),
                      onPressed:
                          _isLoading ? null : () => handleGoogleSignIn(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // CONTINUE AS GUEST BUTTON REMOVED
                  // const Spacer(),
                  // Register option
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to Register Screen
                          Navigator.pushNamed(context, '/register');
                        },
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.only(left: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Register',
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
          ),
        ),
      ),
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
