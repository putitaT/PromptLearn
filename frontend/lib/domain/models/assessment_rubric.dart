enum RubricAlignment {
  notChecked('not_checked'),
  aligned('aligned'),
  outOfScope('out_of_scope'),
  unclear('unclear');

  const RubricAlignment(this.value);
  final String value;
}

String rubricScore(num value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();

double? parseRubricScore(String value) {
  final score = double.tryParse(value.trim().replaceAll(',', '.'));
  return score != null && score.isFinite ? score : null;
}

class RubricCriterion {
  const RubricCriterion({
    required this.name,
    required this.fullScore,
    this.description = '',
    this.fullDescription = '',
    this.partialScore = '',
    this.partialDescription = '',
    this.noneDescription = '',
  });

  factory RubricCriterion.fromJson(Map<String, Object?> json) {
    String score(Object? value) => switch (value) {
      final num n => rubricScore(n),
      final String text => text,
      _ => '',
    };

    return RubricCriterion(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      fullScore: score(json['full_points']),
      fullDescription: json['full_description'] as String? ?? '',
      partialScore: score(json['partial_points']),
      partialDescription: json['partial_description'] as String? ?? '',
      noneDescription: json['none_description'] as String? ?? '',
    );
  }

  final String name;
  final String description;
  final String fullScore;
  final String fullDescription;
  final String partialScore;
  final String partialDescription;
  final String noneDescription;

  double? get fullPoints => parseRubricScore(fullScore);
  double? get partialPoints => parseRubricScore(partialScore);

  bool get isValid {
    final full = fullPoints;
    final partial = partialPoints;
    return name.trim().isNotEmpty &&
        full != null &&
        full > 0 &&
        (partialScore.trim().isEmpty ||
            (partial != null && partial >= 0 && partial <= full));
  }

  RubricCriterion copyWith({
    String? name,
    String? description,
    String? fullScore,
    String? fullDescription,
    String? partialScore,
    String? partialDescription,
    String? noneDescription,
  }) => RubricCriterion(
    name: name ?? this.name,
    description: description ?? this.description,
    fullScore: fullScore ?? this.fullScore,
    fullDescription: fullDescription ?? this.fullDescription,
    partialScore: partialScore ?? this.partialScore,
    partialDescription: partialDescription ?? this.partialDescription,
    noneDescription: noneDescription ?? this.noneDescription,
  );

  Map<String, Object?> toJson({bool forApi = false}) => {
    'name': name,
    'description': description,
    'full_points': forApi ? fullPoints ?? 0 : fullScore,
    'full_description': fullDescription,
    'partial_points': forApi ? partialPoints : partialScore,
    'partial_description': partialDescription,
    'none_description': noneDescription,
  };
}

class RubricMistake {
  const RubricMistake(this.example, this.reason);

  factory RubricMistake.fromJson(Map<String, Object?> json) =>
      RubricMistake(json['example'] as String, json['reason'] as String);

  final String example;
  final String reason;

  Map<String, Object?> toJson() => {'example': example, 'reason': reason};
}

class QuestionRubric {
  const QuestionRubric({
    this.answer = '',
    this.correctOption,
    this.alignment = RubricAlignment.notChecked,
    this.alignmentReason = '',
    this.criteria = const [],
    this.mistakes = const [],
    this.note = '',
    this.approved = false,
    this.keptByTeacher = false,
  });

  factory QuestionRubric.fromJson(Map<String, Object?> json) => QuestionRubric(
    answer: json['answer'] as String,
    correctOption: json['correct_option'] as int?,
    alignment: RubricAlignment.values.firstWhere(
      (alignment) => alignment.value == json['alignment'],
    ),
    alignmentReason: json['alignment_reason'] as String? ?? '',
    criteria: List.unmodifiable([
      for (final item in json['criteria'] as List<Object?>)
        RubricCriterion.fromJson(item as Map<String, Object?>),
    ]),
    mistakes: List.unmodifiable([
      for (final item in json['mistakes'] as List<Object?>)
        RubricMistake.fromJson(item as Map<String, Object?>),
    ]),
    note: json['note'] as String? ?? '',
    approved: json['approved'] as bool? ?? false,
    keptByTeacher: json['kept_by_teacher'] as bool? ?? false,
  );

  final String answer;
  final int? correctOption;
  final RubricAlignment alignment;
  final String alignmentReason;
  final List<RubricCriterion> criteria;
  final List<RubricMistake> mistakes;
  final String note;
  final bool approved;
  final bool keptByTeacher;

  bool get flagged => alignment == RubricAlignment.outOfScope && !keptByTeacher;
  double get fullPoints =>
      criteria.fold(0, (sum, row) => sum + (row.fullPoints ?? 0));

  bool matchesQuestionPoints(int points) =>
      criteria.isNotEmpty &&
      criteria.every((row) => row.isValid) &&
      (fullPoints - points).abs() < 0.000001;

  QuestionRubric copyWith({
    String? answer,
    int? correctOption,
    List<RubricCriterion>? criteria,
    bool? approved,
    bool? keptByTeacher,
  }) => QuestionRubric(
    answer: answer ?? this.answer,
    correctOption: correctOption ?? this.correctOption,
    alignment: alignment,
    alignmentReason: alignmentReason,
    criteria: criteria == null ? this.criteria : List.unmodifiable(criteria),
    mistakes: mistakes,
    note: note,
    approved: approved ?? this.approved,
    keptByTeacher: keptByTeacher ?? this.keptByTeacher,
  );

  Map<String, Object?> toJson({bool forApi = false}) => {
    'answer': answer,
    'correct_option': correctOption,
    'alignment': alignment.value,
    'alignment_reason': alignmentReason,
    'criteria': [for (final row in criteria) row.toJson(forApi: forApi)],
    'mistakes': [for (final mistake in mistakes) mistake.toJson()],
    'note': note,
    if (!forApi) 'approved': approved,
    if (!forApi) 'kept_by_teacher': keptByTeacher,
  };
}
