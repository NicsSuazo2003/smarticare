import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/symptom_questions.dart';
import '../domain/symptom_question.dart';
import '../providers/symptom_assessment_provider.dart';
import 'symptom_assessment_q7_screen.dart';
import 'symptom_assessment_q7_screen.dart';

class SymptomQuestionScreen extends StatefulWidget {
  const SymptomQuestionScreen({
    super.key,
    required this.question,
  });

  final SymptomQuestion question;

  @override
  State<SymptomQuestionScreen> createState() => _SymptomQuestionScreenState();
}

class _SymptomQuestionScreenState extends State<SymptomQuestionScreen> {
  static const _primaryColor = Color(0xFFFF6B6B);
  static const _options = [
    'Never',
    'Rarely (few times a year)',
    'Sometimes (few times a month)',
    'Often (few times a week)',
    'Always (daily)',
  ];

  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    // Restore previous answer if the user came back.
    _selectedAnswer = context
        .read<SymptomAssessmentProvider>()
        .getAnswer(widget.question.answerKey);
  }

  void _selectAnswer(String option) {
    setState(() => _selectedAnswer = option);
    context
        .read<SymptomAssessmentProvider>()
        .setAnswer(widget.question.answerKey, option);
  }

  void _goNext() {
    final next = SymptomQuestions.nextNumber(widget.question.number);

    if (next == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SymptomAssessmentQ7Screen(
            onAnswer: (answer) {
              context
                  .read<SymptomAssessmentProvider>()
                  .setAnswer('q7', answer);
            },
            onPrevious: () => Navigator.pop(context),
            onFinish: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SymptomQuestionScreen(
          question: SymptomQuestions.questionFor(next),
        ),
      ),
    );
  }

  void _goPrevious() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final canContinue = _selectedAnswer != null;
    final hasPrevious = SymptomQuestions.previousNumber(q.number) != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'Symptom Assessment', onBack: _goPrevious),
            _Progress(q: q),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.text,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _QuestionImage(asset: q.imageAsset),
                    const SizedBox(height: 24),
                    _InfoBox(text: q.description),
                    const SizedBox(height: 32),
                    ..._options.map(
                      (option) => _AnswerOption(
                        option: option,
                        isSelected: _selectedAnswer == option,
                        onTap: () => _selectAnswer(option),
                        primaryColor: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Footer(
              canContinue: canContinue,
              hasPrevious: hasPrevious,
              onPrevious: _goPrevious,
              onNext: _goNext,
              primaryColor: _primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets — pure presentational, no state, no logic.
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, size: 24),
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.q});
  final SymptomQuestion q;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${q.number} of ${q.total}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '${q.progressPercent}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: q.progress,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFFFF6B6B),
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.asset});
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: AssetImage(asset),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.blue.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
  });

  final String option;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color:
                isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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

class _Footer extends StatelessWidget {
  const _Footer({
    required this.canContinue,
    required this.hasPrevious,
    required this.onPrevious,
    required this.onNext,
    required this.primaryColor,
  });

  final bool canContinue;
  final bool hasPrevious;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: hasPrevious
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.end,
        children: [
          if (hasPrevious)
            SizedBox(
              width: 120,
              height: 50,
              child: OutlinedButton(
                onPressed: onPrevious,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
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
                      'Previous',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: 120,
            height: 50,
            child: ElevatedButton(
              onPressed: canContinue ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                elevation: canContinue ? 2 : 0,
                shadowColor: primaryColor.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
