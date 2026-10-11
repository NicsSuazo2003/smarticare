import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/bhw_patient_model.dart';

class BHWResultSlipScreen extends StatefulWidget {
  final BHWPatient patient;

  const BHWResultSlipScreen({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  State<BHWResultSlipScreen> createState() => _BHWResultSlipScreenState();
}

class _BHWResultSlipScreenState extends State<BHWResultSlipScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B6B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        title: const Text(
          'Scan Result',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareResultSlip,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Result Slip (screenshot area)
            Screenshot(
              controller: _screenshotController,
              child: _buildResultSlip(),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildActionButton(
                    'Share Result',
                    Icons.share,
                    const Color(0xFF2196F3),
                    _shareResultSlip,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    'View All Patients',
                    Icons.list,
                    const Color(0xFF4CAF50),
                    () {
                      Navigator.pushReplacementNamed(
                          context, '/bhw-patient-list');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    'Scan Another Patient',
                    Icons.camera_alt,
                    const Color(0xFFFF6B6B),
                    () {
                      Navigator.pushReplacementNamed(
                          context, '/bhw-scan-patient');
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFFF6B6B)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home, color: Color(0xFFFF6B6B)),
                        SizedBox(width: 8),
                        Text(
                          'Back to Dashboard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      ],
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

  // ========== RESULT SLIP (PRINT-FRIENDLY) ==========
  Widget _buildResultSlip() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 24),
          const Divider(thickness: 2),
          const SizedBox(height: 24),

          // Patient Information
          _buildPatientInfo(),
          const SizedBox(height: 24),

          // Risk Level (PROMINENT)
          _buildRiskLevelCard(),
          const SizedBox(height: 24),

          // Symptoms Detected
          _buildSymptomsSection(),
          const SizedBox(height: 24),

          // Recommendation
          _buildRecommendationSection(),
          const SizedBox(height: 24),

          // Next Steps
          _buildNextStepsSection(),
          const SizedBox(height: 24),
          const Divider(thickness: 2),
          const SizedBox(height: 16),

          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  // ========== HEADER ==========
  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medical_services,
                color: Color(0xFFFF6B6B),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏥 SMARTICARE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B6B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Diabetic Retinopathy Screening',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Scan ID: ${widget.patient.id}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  // ========== PATIENT INFO ==========
  Widget _buildPatientInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PATIENT INFORMATION',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Name', widget.patient.name),
        _buildInfoRow('Age', '${widget.patient.age} years old'),
        _buildInfoRow('Sex', widget.patient.sex),
        _buildInfoRow('Barangay', widget.patient.barangay),
        if (widget.patient.purok != null)
          _buildInfoRow('Purok/Sitio', widget.patient.purok!),
        if (widget.patient.contactNumber != null)
          _buildInfoRow('Contact', widget.patient.contactNumber!),
        _buildInfoRow(
            'Date', DateFormat('MMMM d, yyyy').format(widget.patient.scanDate)),
        _buildInfoRow(
            'Time', DateFormat('h:mm a').format(widget.patient.scanDate)),
        _buildInfoRow('Scanned by', widget.patient.scannedByBHWName),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== RISK LEVEL CARD ==========
  Widget _buildRiskLevelCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.patient.getRiskColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.patient.getRiskColor(),
          width: 3,
        ),
      ),
      child: Column(
        children: [
          Icon(
            widget.patient.getRiskIcon(),
            size: 48,
            color: widget.patient.getRiskColor(),
          ),
          const SizedBox(height: 12),
          const Text(
            'RISK LEVEL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.patient.riskLevel,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: widget.patient.getRiskColor(),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ========== SYMPTOMS SECTION ==========
  Widget _buildSymptomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SYMPTOMS DETECTED',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.patient.symptoms.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'No symptoms reported',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.patient.symptoms.map((symptom) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          symptom,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ========== RECOMMENDATION SECTION ==========
  Widget _buildRecommendationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.patient.urgency == 'Emergency'
                  ? Icons.emergency
                  : widget.patient.urgency == 'Urgent'
                      ? Icons.warning
                      : Icons.info,
              color: widget.patient.getUrgencyColor(),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'RECOMMENDATION',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.patient.getUrgencyColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.patient.getUrgencyColor(),
              width: 2,
            ),
          ),
          child: Text(
            widget.patient.recommendation,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ========== NEXT STEPS SECTION ==========
  Widget _buildNextStepsSection() {
    final steps = _getNextSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT STEPS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2196F3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<String> _getNextSteps() {
    switch (widget.patient.riskLevel.toUpperCase()) {
      case 'LOW':
        return [
          'Keep this result slip for your records',
          'Schedule a routine eye check-up in 6 months',
          'Continue healthy lifestyle habits',
          'Monitor blood sugar if diabetic',
        ];
      case 'MODERATE':
        return [
          'Bring this result slip to the Rural Health Unit',
          'Schedule an appointment within 1 month',
          'Ask for comprehensive eye examination',
          'Monitor and report any vision changes',
        ];
      case 'HIGH':
        return [
          'URGENT: Visit Rural Health Unit within 1 week',
          'Bring this result slip to the health center',
          'Request immediate eye specialist referral',
          'Do not delay - seek attention as soon as possible',
        ];
      case 'CRITICAL':
        return [
          'EMERGENCY: Seek immediate medical attention',
          'Visit eye specialist TODAY if possible',
          'Bring this result slip to the clinic',
          'Contact emergency services if experiencing severe symptoms',
        ];
      default:
        return [
          'Consult with healthcare provider',
          'Bring this result slip for reference',
        ];
    }
  }

  // ========== FOOTER ==========
  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For questions, contact:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '📞 0917-XXX-XXXX',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    '📧 smarticare@health.gov.ph',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber[900]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is a screening result, not a diagnosis. Please consult a healthcare professional for proper evaluation.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.amber[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Generated by SmartiCare • ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  // ========== ACTION BUTTON ==========
  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCapturing ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ========== SHARE RESULT SLIP ==========
  Future<void> _shareResultSlip() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      // Capture screenshot
      final image = await _screenshotController.capture();
      if (image == null) throw Exception('Failed to capture screenshot');

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/result_${widget.patient.id}.png');
      await file.writeAsBytes(image);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'SmartiCare Screening Result - ${widget.patient.name}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }
}
