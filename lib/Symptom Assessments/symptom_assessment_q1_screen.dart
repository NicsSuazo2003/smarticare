import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/symptom_assessment_provider.dart';
import 'package:provider/provider.dart';
import 'symptom_assessment_q2_screen.dart'; // Import Q2 screen

class SymptomAssessmentQ1Screen extends StatefulWidget {
  final Function(String) onAnswer;

  const SymptomAssessmentQ1Screen({
    super.key,
    required this.onAnswer,
    required Null Function() onNext,
  });

  @override
  State<SymptomAssessmentQ1Screen> createState() =>
      _SymptomAssessmentQ1ScreenState();
}

class _SymptomAssessmentQ1ScreenState extends State<SymptomAssessmentQ1Screen> {
  String? _selectedAnswer;
  final List<String> _options = [
    'Never',
    'Rarely (few times a year)',
    'Sometimes (few times a month)',
    'Often (few times a week)',
    'Always (daily)',
  ];

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 24,
                      ),
                    ),
                  ),

                  // Title
                  const Text(
                    'Symptom Assessment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Empty space to balance the layout
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question 1 of 7',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Text(
                        '14%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.14,
                    backgroundColor: Colors.grey.shade200,
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 8,
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question
                    const Text(
                      'Do you experience blurry or cloudy vision?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Image
                    // Image container (overlay icon removed)
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/blurry_vision.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
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
                              'Blurry or cloudy vision can be an early sign of cataracts. It may appear as if you\'re looking through a foggy window.',
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

                    // Answer options
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
                          Provider.of<SymptomAssessmentProvider>(context,
                                  listen: false)
                              .setAnswer('q1', option);
                        },
                        primaryColor: primaryColor,
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Next button with navigation to Q2
            // ✅ FIXED - Remove Previous button from Q1
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end, // ✅ Align Next button to right
                children: [
                  // ✅ NO Previous button - this is Question 1!

                  // Next button
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedAnswer != null
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SymptomAssessmentQ2Screen(
                                    onAnswer: (answer) {
                                      Provider.of<SymptomAssessmentProvider>(
                                              context,
                                              listen: false)
                                          .setAnswer('q2', answer);
                                    },
                                    onNext: () {
                                      Navigator.pop(context);
                                    },
                                    onPrevious: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                              );
                            }
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
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
