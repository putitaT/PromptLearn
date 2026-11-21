import 'syllabus_preview.dart';

enum CoursePeriodStatus {
  taught('Taught'),
  rescheduled('Rescheduled'),
  today('Today'),
  quiz('Quiz'),
  upcoming('Upcoming');

  const CoursePeriodStatus(this.label);
  final String label;
}

typedef CoursePeriodPreview = ({
  DateTime date,
  String slot,
  String topic,
  String unit,
  CoursePeriodStatus status,
  String notes,
});

List<String> coursePreviewClasses(SyllabusPreview course) => [
  for (var index = 1; index <= course.classCount; index++)
    'M.${course.grade - 6}/$index',
];

List<CoursePeriodPreview> coursePreviewPeriods(
  SyllabusPreview course,
  int room,
) {
  final (unit, topics, nextUnit, nextTopic) = switch (course.title) {
    'Math 101' => (
      'Unit 3 · Exponents',
      [
        '3.1 What an exponent means',
        '3.1 What an exponent means',
        '3.2 Multiplying powers, same base',
        '3.2 Multiplying powers, same base',
        'Quiz · Unit 3 Exponents (5 pts)',
        '3.3 Dividing powers',
      ],
      'Unit 4 · Rational numbers',
      '4.1 Decimals and fractions',
    ),
    'Math 201' => (
      'Unit 4 · Factoring',
      [
        '4.1 Common factors',
        '4.1 Common factors',
        '4.2 Difference of squares',
        '4.3 Factoring quadratics',
        'Quiz · Unit 4 Factoring (5 pts)',
        '4.4 Factoring practice',
      ],
      'Unit 5 · Geometry',
      '5.1 Similar triangles',
    ),
    'Math 301' => (
      'Unit 1 · Linear functions',
      [
        '1.1 Coordinate planes',
        '1.1 Coordinate planes',
        '1.2 Slope and intercept',
        '1.2 Slope and intercept',
        'Quiz · Unit 1 Linear functions (5 pts)',
        '1.3 Graphing equations',
      ],
      'Unit 2 · Systems of equations',
      '2.1 Solving by substitution',
    ),
    _ => (
      'Unit 2 · Ratios',
      [
        '2.1 Equivalent ratios',
        '2.1 Equivalent ratios',
        '2.2 Proportional relationships',
        '2.2 Proportional relationships',
        'Quiz · Unit 2 Ratios (5 pts)',
        '2.3 Applying ratios',
      ],
      'Unit 3 · Percentages',
      '3.1 Percent change',
    ),
  };
  final students =
      course.studentCount ~/ course.classCount +
      (room < course.studentCount % course.classCount ? 1 : 0);
  final statuses = course.isDraft
      ? List.filled(6, CoursePeriodStatus.upcoming)
      : const [
          CoursePeriodStatus.taught,
          CoursePeriodStatus.taught,
          CoursePeriodStatus.rescheduled,
          CoursePeriodStatus.today,
          CoursePeriodStatus.quiz,
          CoursePeriodStatus.upcoming,
        ];
  final notes = course.isDraft
      ? List.filled(6, 'Draft schedule')
      : [
          'Done · ${students - 1}/$students checked in',
          'Done · $students/$students checked in',
          'Moved: school assembly on original slot',
          'IBL plan ready',
          'Quiz built · 10 items',
          'Plan drafted by AI',
        ];
  const days = [8, 10, 13, 15, 17, 20];
  const slots = [
    'P2 · 09:20',
    'P1 · 08:30',
    'P2 · 09:20',
    'P4 · 10:20',
    'P1 · 08:30',
    'P4 · 10:20',
  ];
  return [
    for (var index = 0; index < topics.length; index++)
      (
        date: DateTime.utc(2026, 7, days[index] + room * 7),
        slot: slots[index],
        topic: topics[index],
        unit: unit,
        status: statuses[index],
        notes: notes[index],
      ),
    for (var index = 0; index < 2; index++)
      (
        date: DateTime.utc(2026, 7, 22 + index * 2 + room * 7),
        slot: slots[index],
        topic: index == 0 ? nextTopic : 'Practice and review',
        unit: nextUnit,
        status: CoursePeriodStatus.upcoming,
        notes: 'Planned',
      ),
  ];
}
