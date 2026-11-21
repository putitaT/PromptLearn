import 'assessment_rubric.dart';

enum AssessmentKind { quiz, homework }

enum AssessmentQuestionKind { shortAnswer, showWork, multipleChoice, trueFalse }

class AssessmentQuestion {
  const AssessmentQuestion({
    required this.kind,
    required this.prompt,
    required this.points,
    this.options = const [],
    this.rubric,
  });

  factory AssessmentQuestion.fromJson(Map<String, Object?> json) {
    return switch (json) {
      {'kind': String kind, 'prompt': String prompt, 'points': int points} =>
        AssessmentQuestion(
          kind: AssessmentQuestionKind.values.byName(kind),
          prompt: prompt,
          points: points,
          options: List<String>.unmodifiable(
            (json['options'] as List<Object?>? ?? []).cast<String>(),
          ),
          rubric: switch (json['rubric']) {
            final Map<String, Object?> value => QuestionRubric.fromJson(value),
            _ => null,
          },
        ),
      _ => throw const FormatException('Invalid assessment question.'),
    };
  }

  final AssessmentQuestionKind kind;
  final String prompt;
  final int points;
  final List<String> options;
  final QuestionRubric? rubric;

  AssessmentQuestion withRubric(QuestionRubric? next) => AssessmentQuestion(
    kind: kind,
    prompt: prompt,
    points: points,
    options: options,
    rubric: next,
  );

  bool sameContentAs(AssessmentQuestion other) =>
      kind == other.kind &&
      prompt == other.prompt &&
      points == other.points &&
      options.length == other.options.length &&
      options.asMap().entries.every(
        (entry) => entry.value == other.options[entry.key],
      );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'prompt': prompt,
    'points': points,
    if (options.isNotEmpty) 'options': options,
    if (rubric case final rubric?) 'rubric': rubric.toJson(),
  };
}

class AssessmentDraft {
  const AssessmentDraft({
    this.kind = AssessmentKind.quiz,
    this.questions = const [],
    this.timeLimitMinutes = 0,
    this.requireShownWork = true,
    this.acceptPhotos = true,
    this.homeworkHints = false,
    this.shuffleQuestions = true,
  });

  factory AssessmentDraft.fromJson(Map<String, Object?> json) {
    return AssessmentDraft(
      kind: AssessmentKind.values.byName(json['kind'] as String? ?? 'quiz'),
      questions: List.unmodifiable([
        for (final question in json['questions'] as List<Object?>? ?? [])
          AssessmentQuestion.fromJson(question as Map<String, Object?>),
      ]),
      timeLimitMinutes: json['timeLimitMinutes'] as int? ?? 0,
      requireShownWork: json['requireShownWork'] as bool? ?? true,
      acceptPhotos: json['acceptPhotos'] as bool? ?? true,
      homeworkHints: json['homeworkHints'] as bool? ?? false,
      shuffleQuestions: json['shuffleQuestions'] as bool? ?? true,
    );
  }

  final AssessmentKind kind;
  final List<AssessmentQuestion> questions;
  final int timeLimitMinutes;
  final bool requireShownWork;
  final bool acceptPhotos;
  final bool homeworkHints;
  final bool shuffleQuestions;

  int get totalPoints =>
      questions.fold(0, (sum, question) => sum + question.points);

  AssessmentDraft copyWith({
    AssessmentKind? kind,
    List<AssessmentQuestion>? questions,
    int? timeLimitMinutes,
    bool? requireShownWork,
    bool? acceptPhotos,
    bool? homeworkHints,
    bool? shuffleQuestions,
  }) => AssessmentDraft(
    kind: kind ?? this.kind,
    questions: questions == null
        ? this.questions
        : List.unmodifiable(questions),
    timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
    requireShownWork: requireShownWork ?? this.requireShownWork,
    acceptPhotos: acceptPhotos ?? this.acceptPhotos,
    homeworkHints: homeworkHints ?? this.homeworkHints,
    shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'questions': [for (final question in questions) question.toJson()],
    'timeLimitMinutes': timeLimitMinutes,
    'requireShownWork': requireShownWork,
    'acceptPhotos': acceptPhotos,
    'homeworkHints': homeworkHints,
    'shuffleQuestions': shuffleQuestions,
  };
}
