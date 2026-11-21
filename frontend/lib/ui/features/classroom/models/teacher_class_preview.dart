typedef LessonStep = ({
  int startMinute,
  int endMinute,
  String title,
  String summary,
  String instructions,
});

abstract final class TeacherClassPreview {
  static const classroom = 'M.1/1';
  static const period = '$classroom · Period 25';
  static const lessonTitle = '3.2 Multiplying powers with the same base';
  static const date = 'Today · Wed 15 Jul 2569';
  static const schedule = 'P4 · 10:20–11:10 · 50 min';
  static const details =
      'Math 101 · Unit 3 Exponents · Room 204 · 32 students (2 on leave)';
  static const slides = 'Math 101 · 3.2 · 14 slides';
  static const homework = 'HW 3.2 · 8 questions · 10 pts · due Fri 17 Jul 2569';
  static const steps = <LessonStep>[
    (
      startMinute: 0,
      endMinute: 5,
      title: 'Warm-up',
      summary: 'Guess 2³ × 2² in groups',
      instructions: 'Groups of 4 guess what 2³ × 2² equals and explain why',
    ),
    (
      startMinute: 5,
      endMinute: 20,
      title: 'Explore',
      summary: 'Find the exponent pattern',
      instructions: 'Each group expands the powers and looks for a pattern in the exponents',
    ),
    (
      startMinute: 20,
      endMinute: 30,
      title: 'State the rule',
      summary: 'aᵐ × aⁿ = aᵐ⁺ⁿ',
      instructions: 'Groups present, then the class agrees that aᵐ × aⁿ = aᵐ⁺ⁿ',
    ),
    (
      startMinute: 30,
      endMinute: 45,
      title: 'Practice',
      summary: '6 exercises',
      instructions: '6 in-class exercises · on PromptLearn',
    ),
    (
      startMinute: 45,
      endMinute: 50,
      title: 'Wrap-up',
      summary: 'Exit ticket · HW 3.2',
      instructions: '2-question exit ticket, then assign HW 3.2',
    ),
  ];
}
