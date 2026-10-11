import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../data/models/bhw_patient_model.dart';
import '../providers/bhw_patient_provider.dart';
import 'bhw_result_slip_screen.dart';

class BHWSymptomAssessmentScreen extends StatefulWidget {
  final BHWPatient patient;

  const BHWSymptomAssessmentScreen({
    super.key,
    required this.patient,
  });

  @override
  State<BHWSymptomAssessmentScreen> createState() =>
      _BHWSymptomAssessmentScreenState();
}

class _BHWSymptomAssessmentScreenState
    extends State<BHWSymptomAssessmentScreen> {
  int _currentQuestionIndex = 0;
  final Map<String, bool> _answers = {};
  final TextEditingController _notesController = TextEditingController();

  // Symptom questions for BHW to ask patient
  final List<Map<String, dynamic>> _questions = [
    {
      'id': 'blurred_vision',
      'question': 'Do you have blurred or hazy vision?',
      'tagalog': 'Mayroon ka bang malabo o mahamog na paningin?',
      'bisaya': 'Naa kay malabo o dili klaro nga panan-aw?',
      'icon': Icons.remove_red_eye,
    },
    {
      'id': 'floaters',
      'question': 'Do you see spots or floaters in your vision?',
      'tagalog': 'Nakikita mo ba ang mga batik o lumilipad sa iyong paningin?',
      'bisaya': 'Makita ba nimo ang mga tipik o naglupad sa imong panan-aw?',
      'icon': Icons.blur_on,
    },
    {
      'id': 'night_vision',
      'question': 'Do you have difficulty seeing at night?',
      'tagalog': 'Nahihirapan ka bang makakita sa gabi?',
      'bisaya': 'Lisud ba ka makakita sa gabii?',
      'icon': Icons.nightlight,
    },
    {
      'id': 'color_vision',
      'question': 'Do you have trouble distinguishing colors?',
      'tagalog': 'Nahihirapan ka bang makilala ang mga kulay?',
      'bisaya': 'Lisud ba nimo mailhan ang mga kolor?',
      'icon': Icons.palette,
    },
    {
      'id': 'eye_pain',
      'question': 'Do you experience eye pain or discomfort?',
      'tagalog': 'Nakakaramdam ka ba ng sakit o hindi kaginhawahan sa mata?',
      'bisaya': 'Gibati ba nimo ang sakit o kakulangan sa kadasig sa mata?',
      'icon': Icons.healing,
    },
    {
      'id': 'sudden_vision_loss',
      'question': 'Have you experienced sudden vision loss?',
      'tagalog': 'Nakaranas ka na ba ng biglang pagkawala ng paningin?',
      'bisaya': 'Nakasinati ka na ba og kalit nga pagkawala sa panan-aw?',
      'icon': Icons.visibility_off,
    },
    {
      'id': 'dark_spots',
      'question': 'Do you see dark or empty areas in your vision?',
      'tagalog':
          'Nakikita mo ba ang madilim o walang laman na mga lugar sa iyong paningin?',
      'bisaya':
          'Makita ba nimo ang mangitngit o walay sulod nga mga lugar sa imong panan-aw?',
      'icon': Icons.crop_square,
    },
    {
      'id': 'reading_difficulty',
      'question': 'Do you have difficulty reading or seeing fine details?',
      'tagalog':
          'Nahihirapan ka bang magbasa o makita ang mga maliit na detalye?',
      'bisaya': 'Lisud ba ka magbasa o makakita sa mga gagmay nga detalye?',
      'icon': Icons.menu_book,
    },
  ];

  String _selectedLanguage = 'english';
  bool _isProcessing = false;
  File? _capturedImage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastQuestion = _currentQuestionIndex >= _questions.length;

    return WillPopScope(
      onWillPop: () async {
        final confirm = await _showExitConfirmation();
        return confirm ?? false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFF6B6B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              final confirm = await _showExitConfirmation();
              if (confirm == true && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            isLastQuestion ? 'Eye Scan' : 'Symptom Assessment',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (!isLastQuestion)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${_currentQuestionIndex + 1}/${_questions.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : isLastQuestion
                ? _buildEyeScanScreen()
                : _buildQuestionScreen(),
      ),
    );
  }

  // ========== QUESTION SCREEN ==========
  Widget _buildQuestionScreen() {
    final question = _questions[_currentQuestionIndex];
    final hasAnswer = _answers.containsKey(question['id']);

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _questions.length,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Patient info card
                  _buildPatientInfoCard(),
                  const SizedBox(height: 24),

                  // Language selector
                  _buildLanguageSelector(),
                  const SizedBox(height: 24),

                  // Question card
                  _buildQuestionCard(question),
                  const SizedBox(height: 24),

                  // Answer buttons
                  _buildAnswerButtons(question['id']),
                  const SizedBox(height: 32),

                  // Navigation buttons
                  _buildNavigationButtons(hasAnswer),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== PATIENT INFO CARD ==========
  Widget _buildPatientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.1),
            child: const Icon(
              Icons.person,
              color: Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.patient.age} years • ${widget.patient.sex} • ${widget.patient.barangay}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== LANGUAGE SELECTOR ==========
  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildLanguageButton('English', 'english'),
          _buildLanguageButton('Tagalog', 'tagalog'),
          _buildLanguageButton('Bisaya', 'bisaya'),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(String label, String value) {
    final isSelected = _selectedLanguage == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLanguage = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF6B6B) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  // ========== QUESTION CARD ==========
  Widget _buildQuestionCard(Map<String, dynamic> question) {
    String displayQuestion;
    switch (_selectedLanguage) {
      case 'tagalog':
        displayQuestion = question['tagalog'];
        break;
      case 'bisaya':
        displayQuestion = question['bisaya'];
        break;
      default:
        displayQuestion = question['question'];
    }

    return Container(
      padding: const EdgeInsets.all(24),
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
          Icon(
            question['icon'],
            size: 48,
            color: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 20),
          const Text(
            '💡 ASK THE PATIENT:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6B6B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayQuestion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ========== ANSWER BUTTONS ==========
  Widget _buildAnswerButtons(String questionId) {
    final currentAnswer = _answers[questionId];

    return Column(
      children: [
        const Text(
          '👤 PATIENT SAYS:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAnswerButton(
                'YES',
                Icons.check_circle,
                Colors.green,
                currentAnswer == true,
                () {
                  setState(() {
                    _answers[questionId] = true;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnswerButton(
                'NO',
                Icons.cancel,
                Colors.red,
                currentAnswer == false,
                () {
                  setState(() {
                    _answers[questionId] = false;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnswerButton(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? color : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== NAVIGATION BUTTONS ==========
  Widget _buildNavigationButtons(bool hasAnswer) {
    return Row(
      children: [
        // Back button
        if (_currentQuestionIndex > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentQuestionIndex--;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFFF6B6B)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ),
          ),
        if (_currentQuestionIndex > 0) const SizedBox(width: 12),

        // Next button
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: hasAnswer ? _handleNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(
              _currentQuestionIndex == _questions.length - 1
                  ? 'Next: Eye Scan'
                  : 'Next Question',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== EYE SCAN SCREEN ==========
  Widget _buildEyeScanScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Patient info
            _buildPatientInfoCard(),
            const SizedBox(height: 24),

            // Summary of symptoms
            _buildSymptomSummary(),
            const SizedBox(height: 24),

            // Camera preview or captured image
            _buildImageSection(),
            const SizedBox(height: 24),

            // Additional notes
            _buildNotesSection(),
            const SizedBox(height: 32),

            // Submit button
            _buildSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ========== SYMPTOM SUMMARY ==========
  Widget _buildSymptomSummary() {
    final symptoms =
        _answers.entries.where((entry) => entry.value == true).map((entry) {
      final question = _questions.firstWhere((q) => q['id'] == entry.key);
      return question['question'] as String;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
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
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              Text(
                'Reported Symptoms',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (symptoms.isEmpty)
            Text(
              'No symptoms reported',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            )
          else
            ...symptoms.map((symptom) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          symptom,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ========== IMAGE SECTION ==========
  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Row(
            children: [
              Icon(Icons.camera_alt, color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              Text(
                'Eye Scan Image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Image preview or placeholder
          if (_capturedImage != null)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _capturedImage!,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _capturedImage = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake Photo'),
                ),
              ],
            )
          else
            Column(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No image captured',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Camera button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _captureEyeScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(
                      'Capture Eye Scan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ========== NOTES SECTION ==========
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Row(
            children: [
              Icon(Icons.note, color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              Text(
                'Additional Notes (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add any observations or concerns...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== SUBMIT BUTTON ==========
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _capturedImage != null ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: const Text(
          'Complete Scan & View Result',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ========== HANDLERS ==========
  void _handleNext() {
    setState(() {
      _currentQuestionIndex++;
    });
  }

  Future<void> _captureEyeScan() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Simulate AI analysis (replace with actual ML model)
      await Future.delayed(const Duration(seconds: 2));

      // Calculate risk level based on symptoms
      final symptomCount = _answers.values.where((v) => v == true).length;
      final riskLevel = _calculateRiskLevel(symptomCount);
      final recommendation = _generateRecommendation(riskLevel);
      final urgency = _determineUrgency(riskLevel);

      // Get symptom list
      final symptoms =
          _answers.entries.where((entry) => entry.value == true).map((entry) {
        final question = _questions.firstWhere((q) => q['id'] == entry.key);
        return question['question'] as String;
      }).toList();

      // Create complete patient record
      final completedPatient = widget.patient.copyWith(
        symptoms: symptoms,
        symptomResponses: _answers,
        additionalNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        riskLevel: riskLevel,
        scanImagePath: _capturedImage?.path,
        recommendation: recommendation,
        urgency: urgency,
        updatedAt: DateTime.now(),
      );

      // Save to provider
      final provider = Provider.of<BHWPatientProvider>(context, listen: false);
      await provider.addPatient(completedPatient);

      // Navigate to result slip
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BHWResultSlipScreen(
              patient: completedPatient,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save patient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ========== RISK CALCULATION ==========
  String _calculateRiskLevel(int symptomCount) {
    if (symptomCount == 0) return 'LOW';
    if (symptomCount <= 2) return 'MODERATE';
    if (symptomCount <= 4) return 'HIGH';
    return 'CRITICAL';
  }

  String _generateRecommendation(String riskLevel) {
    switch (riskLevel) {
      case 'LOW':
        return 'Schedule routine eye check-up within 6 months. Continue monitoring.';
      case 'MODERATE':
        return 'Visit Rural Health Unit within 1 month for comprehensive eye examination.';
      case 'HIGH':
        return 'URGENT: Visit Rural Health Unit within 1 week. Requires immediate attention.';
      case 'CRITICAL':
        return 'EMERGENCY: Seek immediate medical attention. Visit eye specialist as soon as possible.';
      default:
        return 'Consult healthcare provider for evaluation.';
    }
  }

  String _determineUrgency(String riskLevel) {
    switch (riskLevel) {
      case 'LOW':
        return 'Routine';
      case 'MODERATE':
        return 'Routine';
      case 'HIGH':
        return 'Urgent';
      case 'CRITICAL':
        return 'Emergency';
      default:
        return 'Routine';
    }
  }

  // ========== EXIT CONFIRMATION ==========
  Future<bool?> _showExitConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Assessment?'),
        content: const Text(
          'Are you sure you want to exit? All progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
