import '../domain/symptom_question.dart';

class SymptomQuestions {
  SymptomQuestions._();

  static const List<SymptomQuestion> all = [
    SymptomQuestion(
      number: 1,
      total: 6,
      text: 'Do you experience blurry or cloudy vision?',
      imageAsset: 'assets/images/blurry_vision.jpg',
      description:
          'Blurry or cloudy vision can be an early sign of cataracts. It may appear as if you\'re looking through a foggy window.',
      answerKey: 'q1',
    ),
    SymptomQuestion(
      number: 2,
      total: 6,
      text: 'Do you have increased sensitivity to light or see glare?',
      imageAsset: 'assets/images/light_sensitivity.jpg',
      description:
          'Sensitivity to bright lights or seeing glare around light sources can indicate cataract formation.',
      answerKey: 'q2',
    ),
    SymptomQuestion(
      number: 3,
      total: 6,
      text: 'Do you have difficulty seeing at night or in low light?',
      imageAsset: 'assets/images/night_vision.jpg',
      description:
          'Poor night vision or difficulty adjusting to darkness can be a significant sign of cataract development.',
      answerKey: 'q3',
    ),
    SymptomQuestion(
      number: 4,
      total: 6,
      text:
          'Do you see halos around lights (circles of light around bright objects)?',
      imageAsset: 'assets/images/light_halos.jpg',
      description:
          'Seeing rings or halos around lights, especially at night, can be a symptom of cataract.',
      answerKey: 'q4',
    ),
    SymptomQuestion(
      number: 5,
      total: 6,
      text: 'Have you noticed colors appearing faded or yellowed?',
      imageAsset: 'assets/images/faded_colors.jpg',
      description:
          'Colors that appear less vivid, or a yellowing/browning tint to your vision, can indicate cataracts.',
      answerKey: 'q5',
    ),
    SymptomQuestion(
      number: 6,
      total: 6,
      text: 'Do you experience double vision in one eye?',
      imageAsset: 'assets/images/double_vision.jpg',
      description:
          'Seeing duplicate images when looking through just one eye can be a symptom of cataracts.',
      answerKey: 'q6',
    ),
  ];

  /// Indexed lookup: [questionFor(1)] returns the first question.
  static SymptomQuestion questionFor(int number) => all[number - 1];

  /// Next question number, or null if this was the last.
  static int? nextNumber(int current) =>
      current >= all.length ? null : current + 1;

  /// Previous question number, or null if this was the first.
  static int? previousNumber(int current) => current <= 1 ? null : current - 1;
}
