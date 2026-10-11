/// Configuration for a single symptom-assessment question.
/// Used by the shared [SymptomQuestionScreen].
class SymptomQuestion {
  const SymptomQuestion({
    required this.number, // 1..6
    required this.total, // 6 (or 7 for future)
    required this.text,
    required this.imageAsset,
    required this.description,
    required this.answerKey, // 'q1'..'q6'
  });

  final int number;
  final int total;
  final String text;
  final String imageAsset;
  final String description;
  final String answerKey;

  double get progress => number / total;
  int get progressPercent => (progress * 100).round();
}
