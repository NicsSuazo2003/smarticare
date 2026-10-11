import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/bhw_patient_model.dart';
import '../providers/bhw_patient_provider.dart';
import '../../../features/symptom_assessment/providers/symptom_assessment_provider.dart';
import 'bhw_symptom_assessment_screen.dart';

class BHWScanPatientScreen extends StatefulWidget {
  const BHWScanPatientScreen({Key? key}) : super(key: key);

  @override
  State<BHWScanPatientScreen> createState() => _BHWScanPatientScreenState();
}

class _BHWScanPatientScreenState extends State<BHWScanPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _barangayController = TextEditingController();
  final _purokController = TextEditingController();
  final _contactController = TextEditingController();

  // Form values
  String _selectedSex = 'Male';
  String _diabeticStatus = 'Unknown';

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _barangayController.dispose();
    _purokController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B6B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Register New Patient',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header instruction
                      _buildInstructionCard(),
                      const SizedBox(height: 20),

                      // Patient Information Section
                      _buildSectionHeader('Patient Information'),
                      const SizedBox(height: 16),
                      _buildPatientInfoFields(),
                      const SizedBox(height: 24),

                      // Medical History Section
                      _buildSectionHeader('Medical History'),
                      const SizedBox(height: 16),
                      _buildMedicalHistoryFields(),
                      const SizedBox(height: 32),

                      // Next button
                      _buildNextButton(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ========== INSTRUCTION CARD ==========
  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFF2196F3),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill out patient information, then proceed to symptom assessment and eye scan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== SECTION HEADER ==========
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // ========== PATIENT INFO FIELDS ==========
  Widget _buildPatientInfoFields() {
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
        children: [
          // Full Name
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: 'Juan Dela Cruz',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter patient name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Age and Sex Row
          Row(
            children: [
              // Age
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Age *',
                    hintText: '52',
                    prefixIcon: const Icon(Icons.cake),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 1 || age > 120) {
                      return 'Invalid age';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Sex
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedSex,
                  decoration: InputDecoration(
                    labelText: 'Sex *',
                    prefixIcon: const Icon(Icons.wc),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: ['Male', 'Female'].map((sex) {
                    return DropdownMenuItem(
                      value: sex,
                      child: Text(sex),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSex = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barangay
          TextFormField(
            controller: _barangayController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Barangay *',
              hintText: 'San Isidro',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter barangay';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Purok/Sitio (Optional)
          TextFormField(
            controller: _purokController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Purok/Sitio (Optional)',
              hintText: 'Purok 5',
              prefixIcon: const Icon(Icons.home),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contact Number (Optional)
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: InputDecoration(
              labelText: 'Contact Number (Optional)',
              hintText: '09171234567',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== MEDICAL HISTORY FIELDS ==========
  Widget _buildMedicalHistoryFields() {
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
          const Text(
            'Is the patient diabetic?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Radio buttons
          _buildRadioOption('Yes', Icons.check_circle, Colors.green),
          _buildRadioOption('No', Icons.cancel, Colors.red),
          _buildRadioOption('Unknown', Icons.help, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String value, IconData icon, Color color) {
    final isSelected = _diabeticStatus == value;

    return InkWell(
      onTap: () {
        setState(() {
          _diabeticStatus = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ========== NEXT BUTTON ==========
  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _handleNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Next: Symptom Assessment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }

  // ========== HANDLE NEXT ==========
  void _handleNext() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Generate patient ID
    final barangayCode = _barangayController.text
        .trim()
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join('')
        .substring(0, 3);

    final patientId = BHWPatient.generateId(barangayCode);

    // Get current BHW info
    final user = FirebaseAuth.instance.currentUser;
    final bhwId = user?.uid ?? '';
    final bhwName = user?.displayName ?? 'BHW';

    // Create temporary patient object (will be completed after scan)
    final tempPatient = BHWPatient(
      id: patientId,
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text),
      sex: _selectedSex,
      barangay: _barangayController.text.trim(),
      purok: _purokController.text.trim().isEmpty
          ? null
          : _purokController.text.trim(),
      contactNumber: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      isDiabetic: _diabeticStatus == 'Yes',
      diabeticStatus: _diabeticStatus,
      symptoms: [], // Will be filled after assessment
      symptomResponses: {}, // Will be filled after assessment
      riskLevel: 'PENDING', // Will be filled after scan
      scanDate: DateTime.now(),
      scannedByBHWId: bhwId,
      scannedByBHWName: bhwName,
      scannedByBHWBarangay: _barangayController.text.trim(),
      recommendation: 'Pending assessment', // Will be filled after scan
      urgency: 'Routine',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Reset symptom assessment provider
    // Clear symptom assessment provider
    final symptomProvider = Provider.of<SymptomAssessmentProvider>(
      context,
      listen: false,
    );
    symptomProvider.clear(); // ✅ Use existing clear() method

    // Navigate to symptom assessment
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BHWSymptomAssessmentScreen(
          patient: tempPatient,
        ),
      ),
    );
  }
}
