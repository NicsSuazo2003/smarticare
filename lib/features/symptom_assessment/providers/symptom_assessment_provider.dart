import 'package:flutter/foundation.dart';

class SymptomAssessmentProvider extends ChangeNotifier {
  final Map<String, String> _answers = {};

  Map<String, String> get answers => _answers;

  void setAnswer(String questionKey, String answer) {
    _answers[questionKey] = answer;
    notifyListeners();
  }

  String? getAnswer(String questionKey) => _answers[questionKey];

  void clear() {
    _answers.clear();
    notifyListeners();
  }

  /// Add this method for symptom scoring
  double getSymptomScore() {
    if (_answers.isEmpty) return 0.0;

    final Map<String, double> mapping = {
      'Never': 0.0,
      'Rarely (few times a year)': 0.25,
      'Sometimes (few times a month)': 0.5,
      'Often (few times a week)': 0.75,
      'Always (daily)': 1.0,
    };

    double total = 0.0;
    int count = 0;
    _answers.forEach((key, value) {
      final score = mapping[value] ?? 0.0;
      total += score;
      count++;
    });
    return count > 0 ? (total / count) : 0.0;
  }
}
