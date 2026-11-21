import 'package:flutter/widgets.dart';

class SyllabusPreview {
  const SyllabusPreview({
    required this.title,
    required this.grade,
    required this.periods,
    required this.classCount,
    required this.studentCount,
    this.draftStep,
    this.taughtPeriods = 0,
  });

  final String title;
  final int grade;
  final int periods;
  final int classCount;
  final int studentCount;
  final int? draftStep;
  final int taughtPeriods;

  bool get isDraft => draftStep != null;

  String get status => isDraft ? 'Draft · step $draftStep of 6' : 'Published';

  String get homeSummary {
    final level = 'M.${grade - 6}';
    return isDraft
        ? '$level · $status'
        : '$level · $classCount classes · $periods periods';
  }

  Color get coverColor => switch (grade) {
    7 => const Color(0xFFE5F9D6),
    8 => const Color(0xFFDDF0E2),
    _ => const Color(0xFFF2F3FF),
  };
}

const teacherSyllabusPreviews = [
  SyllabusPreview(
    title: 'Math 101',
    taughtPeriods: 24,
    grade: 7,
    periods: 54,
    classCount: 3,
    studentCount: 94,
  ),
  SyllabusPreview(
    title: 'Math 201',
    taughtPeriods: 43,
    grade: 8,
    periods: 48,
    classCount: 2,
    studentCount: 62,
  ),
  SyllabusPreview(
    title: 'Math 301',
    grade: 9,
    periods: 36,
    classCount: 2,
    studentCount: 59,
    draftStep: 3,
  ),
  SyllabusPreview(
    title: 'Math 102',
    taughtPeriods: 2,
    grade: 7,
    periods: 42,
    classCount: 3,
    studentCount: 90,
  ),
];
