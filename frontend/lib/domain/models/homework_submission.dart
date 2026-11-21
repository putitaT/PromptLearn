import 'homework_check.dart';

class HomeworkSubmittedQuestion {
  const HomeworkSubmittedQuestion({
    required this.position,
    required this.prompt,
    required this.work,
    required this.status,
    required this.message,
    required this.maximum,
    required this.points,
  });

  factory HomeworkSubmittedQuestion.fromJson(Map<String, dynamic> data) {
    return HomeworkSubmittedQuestion(
      position: data['position'] as int,
      prompt: data['prompt'] as String,
      work: data['recognized_work'] as String,
      status: HomeworkReviewStatus.fromApi(data['status']),
      message: data['message'] as String,
      maximum: data['max_points'] as num,
      points: data['awarded_points'] as num?,
    );
  }

  final int position;
  final String prompt;
  final String work;
  final HomeworkReviewStatus status;
  final String message;
  final num maximum;
  final num? points;
}

class HomeworkMistake {
  const HomeworkMistake({
    required this.position,
    required this.kind,
    required this.work,
    required this.observation,
    required this.hint,
  });

  factory HomeworkMistake.fromJson(Map<String, dynamic> data) =>
      HomeworkMistake(
        position: data['position'] as int,
        kind: data['kind'] as String,
        work: data['work'] as String,
        observation: data['observation'] as String,
        hint: data['hint'] as String,
      );

  final int position;
  final String kind;
  final String work;
  final String observation;
  final String hint;
}

class HomeworkSubmissionReport {
  const HomeworkSubmissionReport({
    required this.id,
    required this.points,
    required this.maximum,
    required this.pending,
    required this.questions,
    required this.mistakes,
  });

  factory HomeworkSubmissionReport.fromJson(Map<String, dynamic> data) =>
      HomeworkSubmissionReport(
        id: data['id'] as String,
        points: data['points'] as num,
        maximum: data['max_points'] as num,
        pending: data['pending'] as int,
        questions: [
          for (final question in data['questions'] as List)
            HomeworkSubmittedQuestion.fromJson(
              question as Map<String, dynamic>,
            ),
        ],
        mistakes: [
          for (final mistake in data['mistakes'] as List)
            HomeworkMistake.fromJson(mistake as Map<String, dynamic>),
        ],
      );

  final String id;
  final num points;
  final num maximum;
  final int pending;
  final List<HomeworkSubmittedQuestion> questions;
  final List<HomeworkMistake> mistakes;
}
