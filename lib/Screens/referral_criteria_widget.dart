import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/appointments_screen.dart';

class ReferralCriteriaCard extends StatelessWidget {
  final String prediction;
  final double healthScore;
  final double symptomScore;
  final double confidence;
  final String stage;

  const ReferralCriteriaCard({
    Key? key,
    required this.prediction,
    required this.healthScore,
    required this.symptomScore,
    required this.confidence,
    required this.stage,
  }) : super(key: key);

  /// Define the official referral trigger thresholds
  static const double HEALTH_SCORE_THRESHOLD = 60.0;
  static const double SYMPTOM_SCORE_HIGH_RISK = 0.5;
  static const double CONFIDENCE_HIGH_THRESHOLD = 0.7;

  /// Check each trigger condition
  bool get hasCataractDetected => !prediction.toLowerCase().contains('normal');

  bool get hasLowHealthScore => healthScore < HEALTH_SCORE_THRESHOLD;

  bool get hasHighSymptomScore => symptomScore >= SYMPTOM_SCORE_HIGH_RISK;

  bool get hasAdvancedStage =>
      stage.toLowerCase() == 'mature' || stage.toLowerCase() == 'advanced';

  bool get shouldRefer =>
      hasCataractDetected ||
      hasLowHealthScore ||
      hasAdvancedStage ||
      (hasHighSymptomScore && confidence >= CONFIDENCE_HIGH_THRESHOLD);

  List<Map<String, dynamic>> get triggeredCriteria {
    final List<Map<String, dynamic>> triggers = [];

    if (hasCataractDetected) {
      triggers.add({
        'icon': Icons.warning_amber,
        'color': Colors.red,
        'title': 'Cataract Detected',
        'description': 'AI analysis detected signs of cataract:  $prediction',
      });
    }

    if (hasLowHealthScore) {
      triggers.add({
        'icon': Icons.health_and_safety,
        'color': Colors.orange,
        'title': 'Low Health Score',
        'description':
            'Health score ${healthScore.round()}% is below threshold (${HEALTH_SCORE_THRESHOLD.round()}%)',
      });
    }

    if (hasAdvancedStage) {
      triggers.add({
        'icon': Icons.escalator_warning,
        'color': Colors.red,
        'title': 'Advanced Stage',
        'description': 'Cataract stage "$stage" requires specialist evaluation',
      });
    }

    if (hasHighSymptomScore && confidence >= CONFIDENCE_HIGH_THRESHOLD) {
      triggers.add({
        'icon': Icons.visibility_off,
        'color': Colors.amber,
        'title': 'Significant Symptoms',
        'description':
            'High symptom score (${(symptomScore * 100).round()}%) with confident detection',
      });
    }

    return triggers;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldRefer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Referral Recommended',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Based on your scan results, we recommend consulting an eye care specialist.  The following criteria triggered this referral:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Display each triggered criterion
          ...triggeredCriteria
              .map((trigger) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (trigger['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            trigger['icon'] as IconData,
                            color: trigger['color'] as Color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trigger['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                trigger['description'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),

          const Divider(height: 24),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: const Text('View Referral Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                // Navigate to appointments/referrals screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppointmentsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
