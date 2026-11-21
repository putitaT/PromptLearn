typedef SyllabusLessonDraft = ({String title, int periods});

class SyllabusUnitDraft {
  SyllabusUnitDraft({
    required this.id,
    required this.colorIndex,
    required this.title,
    required this.reference,
    required this.periods,
    required List<SyllabusLessonDraft> lessons,
  }) : lessons = List.unmodifiable(lessons);

  final int id;
  final int colorIndex;
  final String title;
  final String reference;
  final int periods;
  final List<SyllabusLessonDraft> lessons;

  int get lessonPeriods =>
      lessons.fold(0, (total, lesson) => total + lesson.periods);

  SyllabusUnitDraft copyWith({
    String? title,
    String? reference,
    int? periods,
    List<SyllabusLessonDraft>? lessons,
  }) => SyllabusUnitDraft(
    id: id,
    colorIndex: colorIndex,
    title: title ?? this.title,
    reference: reference ?? this.reference,
    periods: periods ?? this.periods,
    lessons: lessons ?? this.lessons,
  );
}

const sampleChapterLessons = <List<SyllabusLessonDraft>>[
  [
    (title: 'Positive and negative integers', periods: 2),
    (title: 'Comparing integers', periods: 2),
    (title: 'Adding and subtracting integers', periods: 3),
    (title: 'Multiplying and dividing integers', periods: 3),
    (title: 'Integer problem solving', periods: 2),
  ],
  [
    (title: 'Geometric tools and basic constructions', periods: 2),
    (title: 'Bisecting segments and angles', periods: 3),
    (title: 'Constructing perpendicular and parallel lines', periods: 3),
    (title: 'Construction practice', periods: 2),
  ],
  [
    (title: 'What an exponent means', periods: 2),
    (title: 'Multiplying powers, same base', periods: 2),
    (title: 'Dividing powers', periods: 2),
    (title: 'Scientific notation', periods: 2),
    (title: 'Review + Quiz', periods: 2),
  ],
  [
    (title: 'Comparing decimals and fractions', periods: 3),
    (title: 'Operations with decimals', periods: 3),
    (title: 'Operations with fractions', periods: 3),
    (title: 'Rational number problems', periods: 3),
  ],
  [
    (title: 'Plane and solid figures', periods: 2),
    (title: 'Views of solids', periods: 2),
    (title: 'Cross-sections of solids', periods: 2),
    (title: 'Visualizing and sketching figures', periods: 2),
  ],
];
