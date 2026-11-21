class CurriculumRow {
  const CurriculumRow(this.id, this.title, this.outcomes);

  factory CurriculumRow.fromJson(Map<String, dynamic> json) {
    return CurriculumRow(json['id'] as String, json['title'] as String, [
      for (final outcome in _objects(json['outcomes']))
        [
          if (outcome['code'] case final String code) code,
          (outcome['text'] as String).replaceAll('\n', ' '),
        ].join(' · '),
    ]);
  }

  final String id;
  final String title;
  final List<String> outcomes;
}

class CourseSyllabusSelection {
  const CourseSyllabusSelection({
    required this.grade,
    required this.term,
    required this.references,
  });

  static const periods = 54;
  static const minutes = 50;
  static const weights = {
    'Classwork': 40,
    'Unit Quizzes': 30,
    'Final Exam': 30,
  };

  final int grade;
  final int term;
  final List<String> references;

  String get courseName => 'Mathematics (Mathayom $grade)';

  Map<String, Object> toJson() => {
    'course_name': courseName,
    'grade': grade,
    'course_type': 'core',
    'term': term,
    'total_sessions': periods,
    'minutes_per_session': minutes,
    'reference_ids': references,
    'assessment_weights': [
      for (final weight in weights.entries)
        {'category': weight.key, 'points': weight.value},
    ],
  };
}

typedef SyllabusPeriod = ({int number, String title});
typedef SyllabusAssessment = ({
  String title,
  String category,
  int period,
  int points,
});

class CourseSyllabusUnit {
  const CourseSyllabusUnit({
    required this.title,
    required this.referenceIds,
    required this.periods,
    required this.assessments,
  });

  factory CourseSyllabusUnit.fromJson(Map<String, dynamic> json) {
    return CourseSyllabusUnit(
      title: json['title'] as String,
      referenceIds: (json['reference_ids'] as List).cast<String>(),
      periods: [
        for (final period in _objects(json['sessions']))
          (number: period['number'] as int, title: period['title'] as String),
      ],
      assessments: [
        for (final assessment in _objects(json['assessments']))
          (
            title: assessment['title'] as String,
            category: assessment['category'] as String,
            period: assessment['session'] as int,
            points: assessment['points'] as int,
          ),
      ],
    );
  }

  final String title;
  final List<String> referenceIds;
  final List<SyllabusPeriod> periods;
  final List<SyllabusAssessment> assessments;

  Map<String, Object> toEditedPlanJson() => {
    'title': title,
    'reference_ids': referenceIds,
    'session_titles': [for (final period in periods) period.title],
    'assessments': [
      for (final assessment in assessments)
        {
          'title': assessment.title,
          'category': assessment.category,
          // Draft responses number periods across the semester. Save expects
          // the assessment's period number within its unit.
          'session': assessment.period - periods.first.number + 1,
          'points': assessment.points,
        },
    ],
  };
}

class CourseSyllabusDraft {
  const CourseSyllabusDraft({
    required this.selection,
    required this.description,
    required this.references,
    required this.units,
    required this.documentHtml,
  });

  factory CourseSyllabusDraft.fromJson(
    CourseSyllabusSelection selection,
    Map<String, dynamic> json,
  ) {
    return CourseSyllabusDraft(
      selection: selection,
      description: json['description'] as String,
      references: [
        for (final reference in _objects(json['references']))
          CurriculumRow.fromJson(reference['row'] as Map<String, dynamic>),
      ],
      units: [
        for (final unit in _objects(json['units']))
          CourseSyllabusUnit.fromJson(unit),
      ],
      documentHtml: json['document_html'] as String,
    );
  }

  final CourseSyllabusSelection selection;
  final String description;
  final List<CurriculumRow> references;
  final List<CourseSyllabusUnit> units;
  final String documentHtml;

  Map<String, Object> toEditJson() => {
    'course': selection.toJson(),
    'plan': {
      'description': description,
      'units': [for (final unit in units) unit.toEditedPlanJson()],
    },
  };
}

List<Map<String, dynamic>> _objects(Object? json) =>
    (json as List? ?? const []).cast<Map<String, dynamic>>();
