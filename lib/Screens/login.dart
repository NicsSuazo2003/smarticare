import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/complete_profile_screen.dart';
import 'package:flutter_application_1/Screens/forgot_password_screen.dart';
import 'package:flutter_application_1/Screens/latest_scan_cache.dart';
import 'package:flutter_application_1/Screens/symptom_assessment_screen.dart';
import 'package:flutter_application_1/Screens/terms_of_service_screen.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:flutter_application_1/services/otp_service.dart';
import 'package:flutter_application_1/services/security_service.dart';
import 'package:flutter_svg/svg.dart';
import 'app_permission_screen.dart';
import 'package:provider/provider.dart';
import '../user_session_provider.dart'; // adjust the path as needed
import 'eye_scan_screen.dart'; // for direct navigation
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'otp_verification_screen.dart';
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

  // Update the _login() method in login.dart
  // Find the _login() method and update after successful authentication:

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        _formKey.currentState!.save();

        // ✅ CHECK IF ACCOUNT IS LOCKED
        if (await SecurityService.isAccountLocked(_email)) {
          final remainingMinutes =
              await SecurityService.getRemainingLockoutMinutes(_email);
          setState(() => _isLoading = false);
          _showSnackBar(
            'Account temporarily locked due to too many failed attempts. Try again in $remainingMinutes minutes.',
            color: Colors.orange,
          );
          return;
        }
        // Add this RIGHT AFTER the account lockout check and BEFORE authentication
        try {
          final signInMethods =
              await FirebaseAuth.instance.fetchSignInMethodsForEmail(_email);

          if (signInMethods.isNotEmpty &&
              signInMethods.contains('google.com') &&
              !signInMethods.contains('password')) {
            setState(() => _isLoading = false);
            _showGoogleAccountDialog(); // You already have this method
            return;
          }
        } catch (e) {
          print('Error checking sign-in methods: $e');
          // Continue with normal flow if this fails
        }

        // Authenticate
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // ✅ CHECK EMAIL VERIFICATION
        if (!userCredential.user!.emailVerified) {
          await FirebaseAuth.instance.signOut();
          await SecurityService.recordFailedAttempt(_email);

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

        // ✅ CHECK IF 2FA IS ENABLED
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        final userData = userDoc.data() as Map<String, dynamic>?;
        final twoFactorEnabled = userData?['twoFactorEnabled'] ?? false;

        setState(() => _isLoading = false);

        if (twoFactorEnabled) {
          // ✅ SEND OTP
          final otpSent = await OTPService.sendOTP(_email);

          if (!otpSent) {
            _showSnackBar('Failed to send verification code',
                color: Colors.red);
            await FirebaseAuth.instance.signOut();
            return;
          }

          // ✅ SHOW OTP VERIFICATION SCREEN
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                email: _email,
                onVerified: () async {
                  // OTP verified - complete login
                  await _completeLogin(userCredential);
                },
              ),
            ),
          );
        } else {
          // No 2FA - complete login directly
          await _completeLogin(userCredential);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          final signInMethods =
              await FirebaseAuth.instance.fetchSignInMethodsForEmail(_email);

          if (signInMethods.contains('google.com')) {
            setState(() => _isLoading = false);
            _showGoogleAccountDialog();
            return;
          }
        }
        // ✅ RECORD FAILED ATTEMPT
        await SecurityService.recordFailedAttempt(_email);

        // ✅ CHECK IF ACCOUNT JUST GOT LOCKED
        final isLocked = await SecurityService.isAccountLocked(_email);

        String message = "Invalid email or password";

        if (isLocked) {
          final remainingMinutes =
              await SecurityService.getRemainingLockoutMinutes(_email);
          message = 'Account locked. Try again in $remainingMinutes minutes.';

          await SecurityService.sendSecurityAlert(
            email: _email,
            subject: 'Account Locked - SmartiCare',
            body:
                'Your SmartiCare account has been temporarily locked due to multiple failed login attempts. The lock will expire in $remainingMinutes minutes.',
          );
        } else {
          final doc = await FirebaseFirestore.instance
              .collection('security_logs')
              .doc(_email)
              .get();

          int failedAttempts = 0;
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            failedAttempts = (data['failedAttempts'] as int?) ?? 0;
          }

          final remainingAttempts =
              SecurityService.MAX_FAILED_ATTEMPTS - failedAttempts;

          if (remainingAttempts < 3) {
            message =
                'Invalid credentials. $remainingAttempts attempts remaining.';
          }
        }

        _showSnackBar(message, color: Colors.red);
      } catch (_) {
        await SecurityService.recordFailedAttempt(_email);
        _showSnackBar("Invalid email or password", color: Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ ADD THIS NEW METHOD
  void _showGoogleAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(child: Text('Google Account Detected')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This account was created using Google Sign-In and doesn\'t have a password.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Colors.blue.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please use the "Sign in with Google" button below to continue.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
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
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              handleGoogleSignIn(context);
            },
            icon: Icon(Icons.login, size: 18),
            label: Text('Sign in with Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

// ✅ ADD PASSWORD SETUP METHOD
  void _showSetPasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Set Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                    ),
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
                onPressed: () async {
                  if (newPasswordController.text !=
                      confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match')),
                    );
                    return;
                  }

                  if (newPasswordController.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Password must be at least 6 characters')),
                    );
                    return;
                  }

                  try {
                    // Send password reset email to set password
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: _email);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Password set instructions sent to your email'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to set password: $e')),
                    );
                  }
                },
                child: const Text('Set Password'),
              ),
            ],
          );
        },
      ),
    );
  }

// ✅ ADD NEW METHOD TO COMPLETE LOGIN
  Future<void> _completeLogin(UserCredential userCredential) async {
    try {
      await SecurityService.resetFailedAttempts(_email);
      await SecurityService.checkSuspiciousActivity(
        email: _email,
        action: 'successful_login',
      );

      LatestScanCache.clearCache();

      await AuditLogService.logAction(
        action: 'login',
        details: 'User logged in with email: $_email',
      );

      await SecurityService.sendSecurityAlert(
        email: _email,
        subject: 'Successful Login - SmartiCare',
        body:
            'A successful login was detected for your SmartiCare account from ${DateTime.now()}.',
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await saveTokenToFirestore(user.uid);
        await _afterLoginFlow(context, user.uid);
      }
    } catch (e) {
      _showSnackBar('Login completion failed: $e', color: Colors.red);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar("Please enter your email address.", color: Colors.red);
      return;
    }

    // Validate email format
    if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email)) {
      _showSnackBar("Please enter a valid email address.", color: Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ CHECK RATE LIMIT
      final canRequest = await SecurityService.canRequestPasswordReset(email);

      if (!canRequest) {
        // Get cooldown information
        final cooldown = await SecurityService.getPasswordResetCooldown(email);

        String message;
        if (cooldown != null) {
          if (cooldown.inHours > 0) {
            message =
                "Too many password reset attempts. Please try again in ${cooldown.inMinutes} minutes.";
          } else if (cooldown.inMinutes > 0) {
            message =
                "Please wait ${cooldown.inMinutes} minute(s) before requesting another password reset.";
          } else {
            message =
                "Please wait ${cooldown.inSeconds} seconds before trying again.";
          }
        } else {
          message = "Too many password reset attempts. Please try again later.";
        }

        setState(() => _isLoading = false);
        _showSnackBar(message, color: Colors.orange);

        // Show detailed dialog
        _showRateLimitDialog(cooldown);
        return;
      }

      // ✅ SEND PASSWORD RESET EMAIL
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      // ✅ LOG SECURITY EVENT
      await SecurityService.logSecurityEvent(
        action: 'password_reset_requested',
        email: email,
        details: 'Password reset email sent',
        severity: 'LOW',
      );

      // ✅ SEND SECURITY ALERT
      await SecurityService.sendSecurityAlert(
        email: email,
        subject: 'Password Reset Requested - SmartiCare',
        body: '''
Hello,

A password reset was requested for your SmartiCare account.

If you did not request this, please ignore this email and ensure your account is secure.

If you did request this, please check your inbox for the password reset link.

Time: ${DateTime.now().toString()}

SmartiCare Security Team
      ''',
      );

      setState(() => _isLoading = false);
      _showSnackBar(
        "Password reset email sent! Please check your inbox.",
        color: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String message = "An error occurred.";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email address.";
      } else if (e.code == 'too-many-requests') {
        message = "Too many requests. Please try again later.";
      }

      _showSnackBar(message, color: Colors.red);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to send password reset email. Please try again.",
          color: Colors.red);
    }
  }

// ✅ ADD THIS NEW METHOD
  void _showRateLimitDialog(Duration? cooldown) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            const Expanded(child: Text('Rate Limit Reached')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You\'ve requested too many password resets in a short time.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Rate Limit Policy:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Maximum 3 requests per hour\n'
                    '• Minimum 5 minutes between requests\n'
                    '• Automatic reset after 1 hour',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
            if (cooldown != null) ...[
              const SizedBox(height: 12),
              Text(
                'You can try again in: ${_formatDuration(cooldown)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'If you didn\'t make these requests, please contact support immediately.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

// ✅ ADD THIS HELPER METHOD
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours}h ${minutes}m';
    } else if (duration.inMinutes > 0) {
      final seconds = duration.inSeconds % 60;
      return '${duration.inMinutes}m ${seconds}s';
    } else {
      return '${duration.inSeconds} seconds';
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

      await SecurityService.resetFailedAttempts(userCredential.user!.email!);
      await SecurityService.checkSuspiciousActivity(
        email: userCredential.user!.email!,
        action: 'successful_google_login',
      );

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
