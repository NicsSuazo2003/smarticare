
class TreatmentRecommendationService {
  /// Generate clinically valid treatment recommendations
  /// based on stage, health score, symptom score, and AI prediction
  static String getRecommendation({
    required String stage,
    required int healthScore,
    required double symptomScore,
    required String prediction,
    required double confidence,
  }) {
    final predLower = prediction.toLowerCase();
    final isNormalPrediction =
        predLower.contains('normal') || predLower.contains('no cataract');

    // ===== NORMAL STAGE =====
    if (stage == 'Normal') {
      return 'No signs of cataract detected. Your eyes are in good health. '
          'Continue with annual comprehensive eye examinations.  '
          'Wear UV-protective sunglasses outdoors to prevent future cataracts. '
          'Maintain a healthy diet rich in antioxidants (leafy greens, berries).';
    }

    // ===== IMMATURE STAGE =====
    if (stage == 'Immature') {
      // Case 1: Camera-Invisible Cataract
      // (AI says "Normal" but symptomScore is HIGH ≥ 0.4)
      if (isNormalPrediction && symptomScore >= 0.4) {
        return 'IMPORTANT: Your eye scan appears normal, but you reported '
            'significant vision symptoms. This may indicate: '
            '(1) Early-stage subclinical cataract (before visible opacity), '
            '(2) Other eye condition (dry eye, presbyopia, astigmatism), or '
            '(3) Refractive error requiring glasses update.\n\n'
            'RECOMMENDED ACTION: Schedule comprehensive eye exam with '
            'ophthalmologist within 2-3 weeks. Request:  slit-lamp examination, '
            'contrast sensitivity testing, wavefront analysis.  Bring your '
            'current eyeglass prescription and symptom history.';
      }
      // Case 2: Early Cataract Detected by AI
      // (AI says "Cataract" but symptomScore < 0.3)
      else {
        return 'Early-stage cataract detected.  Symptoms are currently mild.  '
            'Your vision may worsen gradually over months to years. '
            'MANAGEMENT: Update eyeglass/contact lens prescription as needed. '
            'Use brighter lighting for detailed tasks. Consider anti-glare '
            'coatings on glasses.\n\n'
            'FOLLOW-UP: Most early cataracts progress slowly. Monitor vision '
            'changes monthly. Consult ophthalmologist within 3-6 months or '
            'sooner if symptoms progress (increased glare, difficulty driving '
            'at night). Surgery is optional until vision significantly impacts '
            'daily life.';
      }
    }

    // ===== MATURE STAGE =====
    if (stage == 'Mature') {
      // Sub-case:  More advanced mature (health score < 40)
      if (healthScore < 40) {
        return 'Moderate-to-advanced cataract detected with visible opacity. '
            'Vision is noticeably affected (approximately 20/50 to 20/70). '
            'SYMPTOMS:  Glare, halos around lights, faded colors, difficulty '
            'with night driving, blurred vision at all distances.\n\n'
            'RECOMMENDED ACTION: Schedule ophthalmology consultation within '
            '2-4 WEEKS. Cataract surgery is likely to be discussed.\n\n'
            'PREPARE FOR APPOINTMENT: Bring current eyeglass prescription, '
            'list of daily activities affected by vision loss, medication list, '
            'insurance information. Ask about: surgical techniques '
            '(phacoemulsification vs. manual small-incision), intraocular lens '
            '(IOL) options, recovery time, potential risks/benefits.';
      }
      // Sub-case: Mild-to-moderate mature
      else {
        return 'Moderate cataract detected with visible opacity. '
            'Vision is affected but manageable (approximately 20/40 to 20/60). '
            'SYMPTOMS: Mild-to-moderate glare, some difficulty in dim lighting, '
            'gradual vision loss.\n\n'
            'RECOMMENDED ACTION:  Schedule ophthalmology consultation within '
            '4-8 WEEKS. Discuss whether cataract surgery is appropriate for you.\n\n'
            'MANAGEMENT OPTIONS: (1) Update eyeglass prescription (may help '
            'temporarily), (2) Use brighter lighting, (3) Consider cataract '
            'surgery if vision impacts quality of life (reading, driving, work). '
            'Surgery can wait if vision is still functional for your needs.\n\n'
            'PREPARE: Current eyeglass prescription, description of vision '
            'difficulties, medication and allergy list. ';
      }
    }

    return 'Unable to generate recommendation. Please consult an eye care specialist. ';
  }

  /// Get risk level color coding for UI
  static String getRiskLevelLabel(int healthScore) {
    if (healthScore >= 80) return 'Low Risk';
    if (healthScore >= 60) return 'Moderate Risk';
    if (healthScore >= 40) return 'High Risk';
    return 'Very High Risk';
  }

  /// Get urgency timeline
  static String getUrgencyTimeline({
    required String stage,
    required int healthScore,
  }) {
    if (stage == 'Normal') {
      return 'Annual checkup';
    } else if (stage == 'Immature') {
      return '3-6 months (or sooner if symptoms worsen)';
    } else if (stage == 'Mature') {
      if (healthScore < 40) {
        return '2-4 weeks';
      } else {
        return '4-8 weeks';
      }
    }
    return 'As soon as possible';
  }
}
