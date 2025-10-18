// Updated to ensure all answers q1..q7 are saved and to generate an automatic
// clinical summary (notes) based on the answers before writing the assessment.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Screens/eye_scan_screen.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:provider/provider.dart';
import '../screens/symptom_assessment_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Add this import at the top

class SymptomAssessmentQ7Screen extends StatefulWidget {
  final Function(String) onAnswer;
  final VoidCallback onPrevious;
  final VoidCallback onFinish; // Make sure this is used in the parent!

  const SymptomAssessmentQ7Screen({
    super.key,
    required this.onAnswer,
    required this.onPrevious,
    required this.onFinish,
  });

  @override
  State<SymptomAssessmentQ7Screen> createState() =>
      _SymptomAssessmentQ7ScreenState();
}

class _SymptomAssessmentQ7ScreenState extends State<SymptomAssessmentQ7Screen> {
  String? _selectedAnswer;
  final List<String> _options = [
    'Never',
    'Rarely (few times a year)',
    'Sometimes (few times a month)',
    'Often (few times a week)',
    'Always (daily)',
  ];
  bool _isSaving = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ensure answers contains keys q1..q7. If any are missing, fill with 'Never' (no symptom).
  Map<String, String> _ensureAllQuestionsPresent(Map<String, String> answers) {
    final result = Map<String, String>.from(answers);
    for (int i = 1; i <= 7; i++) {
      final key = 'q$i';
      if (!result.containsKey(key) || result[key] == null) {
        result[key] = 'Never';
      }
    }
    return result;
  }

  /// Map answer keys to human friendly symptom labels
  static const Map<String, String> _symptomMap = {
    'q1': 'Blurry vision',
    'q2': 'Glare sensitivity',
    'q3': 'Difficulty seeing at night',
    'q4': 'Halos around lights',
    'q5': 'Faded colors',
    'q6': 'Double vision',
    'q7': 'Frequent prescription change',
  };

  /// Convert answers map into a list of reported symptoms (tolerant check).
  List<String> _answersToSymptoms(Map<String, String> answers) {
    final List<String> symptoms = [];
    answers.forEach((key, value) {
      if (!_symptomMap.containsKey(key)) return;
      final valStr = value?.toString().toLowerCase() ?? '';
      if (valStr.isEmpty) return;
      if (valStr == 'never' || valStr == 'no' || valStr == '0') return;
      // Treat any other value as indicating the symptom
      symptoms.add(_symptomMap[key]!);
    });
    return symptoms;
  }

  /// Create an automatic clinical summary based on answers + symptom score
  String _buildClinicalSummary(
      Map<String, String> answers, double symptomScore, String conclusionText) {
    final symptoms = _answersToSymptoms(answers);
    final symptomPart = symptoms.isEmpty
        ? 'No reported symptoms from the questionnaire.'
        : 'Reported symptoms (${symptoms.length}/${_symptomMap.length}): ${symptoms.join(', ')}.';

    final scorePart =
        'Symptom score: ${(symptomScore * 100).toStringAsFixed(0)}%. Conclusion: $conclusionText.';

    final recommendation = symptomScore >= 0.7
        ? 'Recommend prompt ophthalmology referral.'
        : (symptomScore >= 0.4
            ? 'Recommend specialist follow-up within 1-2 months.'
            : 'Recommend routine monitoring and follow-up as needed.');

    return '$symptomPart $scorePart $recommendation';
  }

  Future<void> _saveAssessmentAndProceed() async {
    if (_selectedAnswer == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final assessmentProvider =
          Provider.of<SymptomAssessmentProvider>(context, listen: false);

      // Save the final answer into provider
      assessmentProvider.setAnswer('q7', _selectedAnswer!);

      // Collect answers and ensure all q1..q7 exist
      final Map<String, String> rawAnswers =
          Map<String, String>.from(assessmentProvider.answers);
      final allAnswers = _ensureAllQuestionsPresent(rawAnswers);

      // Debug: print answers being saved
      print('DEBUG: Saving assessment answers: $allAnswers');

      // Compute symptom score
      final double symptomScore = assessmentProvider.getSymptomScore();

      // Normalize risk (canonical token) based on symptomScore
      // You can tweak thresholds as needed
      String normalizedRisk;
      if (symptomScore >= 0.7) {
        normalizedRisk = 'High';
      } else if (symptomScore >= 0.4) {
        normalizedRisk = 'Medium';
      } else {
        normalizedRisk = 'Low';
      }

      // Human-friendly conclusion text
      String conclusionText;
      switch (normalizedRisk) {
        case 'High':
          conclusionText = 'High risk of symptoms';
          break;
        case 'Medium':
          conclusionText = 'Moderate risk of symptoms';
          break;
        default:
          conclusionText = 'Low risk of symptoms';
      }

      // Build automatic clinical summary and include in 'notes'
      final clinicalSummary =
          _buildClinicalSummary(allAnswers, symptomScore, conclusionText);

      // Gather patient info (current user)
      final userId = _auth.currentUser?.uid;
      String patientName = '';
      if (userId != null) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(userId)
              .get()
              .timeout(const Duration(seconds: 2));
          if (userDoc.exists) {
            final u = userDoc.data() as Map<String, dynamic>;
            patientName =
                '${(u['firstName'] ?? u['firstname'] ?? '').toString().trim()} ${(u['lastName'] ?? u['lastname'] ?? '').toString().trim()}'
                    .trim();
          }
        } catch (e) {
          print('DEBUG: Failed to fetch user doc for patientName: $e');
        }
      }

      // Prepare payload with full answers + generated notes + canonical riskLevel
      final payload = {
        'answers': allAnswers,
        'score': symptomScore,
        'conclusion': conclusionText,
        'riskLevel': normalizedRisk, // canonical token for filtering
        'completed': true,
        'scanDate': DateTime.now().toUtc().toString().split('.').first,
        'timestamp': FieldValue.serverTimestamp(),
        'patientId': userId ?? '',
        'patientName': patientName,
        'notes': clinicalSummary,
      };

      // Check connectivity quickly
      bool isOnline = false;
      try {
        final connectivityResult = await Connectivity()
            .checkConnectivity()
            .timeout(const Duration(milliseconds: 500));
        isOnline = connectivityResult != ConnectivityResult.none;
      } catch (_) {
        isOnline = false;
      }

      if (isOnline && userId != null) {
        try {
          // Save with short timeout (non-blocking if slow)
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('assessments')
              .add(payload)
              .timeout(const Duration(seconds: 2));
          print('✅ Assessment saved to Firestore with payload: $payload');
        } catch (e) {
          print('⚠️ Failed to save assessment (proceeding anyway): $e');
          // Attempt a background save that won't block navigation
          _saveAssessmentInBackground(allAnswers, symptomScore, conclusionText,
              patientName, userId, clinicalSummary, normalizedRisk);
        }
      } else {
        print('📴 Offline or no user - queuing background save if possible');
        // Start background save if userId present (best-effort)
        if (userId != null) {
          _saveAssessmentInBackground(allAnswers, symptomScore, conclusionText,
              patientName, userId, clinicalSummary, normalizedRisk);
        }
      }

      // Optionally clear provider answers after save if you don't need to reuse them
      // assessmentProvider.clear();

      // Navigate to EyeScanScreen always
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EyeScanScreen(symptomScore: symptomScore),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in assessment completion: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EyeScanScreen(symptomScore: 0.5),
          ),
        );
      }
    }
  }

// Background save now accepts patient info and clinical summary and normalizedRisk; tolerant to timeouts.
  void _saveAssessmentInBackground(
    Map<String, String> allAnswers,
    double symptomScore,
    String conclusionText,
    String patientName,
    String? patientId,
    String clinicalSummary,
    String normalizedRisk,
  ) {
    Future(() async {
      if (patientId == null || patientId.isEmpty) return;
      try {
        final payload = {
          'answers': allAnswers,
          'score': symptomScore,
          'conclusion': conclusionText,
          'riskLevel':
              normalizedRisk, // <-- ensure canonical token is saved even in background
          'completed': true,
          'scanDate': DateTime.now().toUtc().toString().split('.').first,
          'timestamp': FieldValue.serverTimestamp(),
          'patientId': patientId,
          'patientName': patientName,
          'notes': clinicalSummary,
        };
        await _firestore
            .collection('users')
            .doc(patientId)
            .collection('assessments')
            .add(payload)
            .timeout(const Duration(seconds: 3));
        print('✅ Background assessment saved: $payload');
      } catch (e) {
        print('⚠️ Background save failed (not blocking UI): $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // ... [AppBar, Progress, Question, Image, Info, etc.] ...

            // Answer options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Have your eyeglass or contact lens prescriptions changed frequently in recent years?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Image container (overlay icon removed)
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: AssetImage(
                              'assets/images/glasses_prescription.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade100,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Needing increasingly stronger glasses or contacts, or frequent prescription changes, can signal cataract development.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.blue.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...List.generate(_options.length, (index) {
                      final option = _options[index];
                      return _buildAnswerOption(
                        option: option,
                        isSelected: _selectedAnswer == option,
                        onTap: () {
                          setState(() {
                            _selectedAnswer = option;
                          });
                          widget.onAnswer(option);
                        },
                        primaryColor: primaryColor,
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Navigation buttons (Previous & Finish)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: widget.onPrevious,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade800,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Finish
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedAnswer != null && !_isSaving
                          ? _saveAssessmentAndProceed
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        elevation: _selectedAnswer != null ? 2 : 0,
                        shadowColor: primaryColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Finish',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOption({
    required String option,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor,
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
              const SizedBox(width: 16),
              Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primaryColor : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
