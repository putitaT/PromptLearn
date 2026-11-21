import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/syllabus_schedule.dart';
import '../models/syllabus_sources.dart';
import '../models/syllabus_unit_draft.dart';

typedef WeeklyPeriod = ({int weekday, int period});
typedef TeachingClass = ({String name, int students});
typedef SchoolEvent = ({DateTime date, String name});

enum AssessmentCategory {
  quizzes('Unit quizzes', 25),
  coursework('Homework & classwork', 15),
  participation('Participation & check-in', 10),
  midterm('Midterm exam', 20),
  finalExam('Final exam', 30);

  const AssessmentCategory(this.label, this.defaultPoints);

  final String label;
  final int defaultPoints;
}

enum TeachingApproach {
  inquiry(
    'Inquiry-based (IBL)',
    'Students explore a problem before the rule is named.',
  ),
  fiveE('5E model', 'Engage · Explore · Explain · Elaborate · Evaluate'),
  cpa('CPA', 'Objects, then pictures, then symbols. Good for number topics.'),
  flipped('Flipped', 'Short video at home, practice in class.');

  const TeachingApproach(this.label, this.description);

  final String label;
  final String description;
}

enum StudentSyllabusDetail {
  topics('Unit & lesson topics by date'),
  assessmentDates('Quiz and exam dates'),
  scores('Score breakdown'),
  indicators('Indicator codes'),
  notes('Your teaching notes');

  const StudentSyllabusDetail(this.label);

  final String label;
}

class SyllabusEditorViewModel extends ChangeNotifier {
  static final _schoolEvents = <SchoolEvent>[
    (date: DateTime.utc(2026, 6, 3), name: 'Queen’s Birthday'),
    (date: DateTime.utc(2026, 8, 12), name: 'Mother’s Day'),
    (date: DateTime.utc(2026, 9, 4), name: 'Sports Day'),
  ];

  String _courseName = 'Mathematics 1 (Basic)';
  String _courseCode = 'ค21101';
  String _credits = '1.5';
  int _grade = 1;
  int _academicYear = 2026;
  int _semester = 1;
  DateTime _firstDay = DateTime.utc(2026, 5, 18);
  DateTime _lastDay = DateTime.utc(2026, 9, 25);
  final _classes = <TeachingClass>[
    (name: 'M.1/1', students: 32),
    (name: 'M.1/2', students: 32),
    (name: 'M.1/3', students: 32),
  ];
  final _assignments = <WeeklyPeriod, int>{
    (weekday: 1, period: 2): 0,
    (weekday: 3, period: 4): 0,
    (weekday: 5, period: 1): 0,
    (weekday: 1, period: 3): 1,
    (weekday: 3, period: 5): 1,
    (weekday: 4, period: 2): 1,
    (weekday: 2, period: 6): 2,
    (weekday: 3, period: 7): 2,
    (weekday: 5, period: 5): 2,
  };
  StandardsSource _standardsSource = StandardsSource.obec;
  final _selectedIndicatorsBySemester = {
    1: {
      for (final indicator in mathayomOneIndicators)
        if (indicator.chapters.isNotEmpty) indicator.code,
    },
    2: {
      for (final indicator in mathayomOneIndicators)
        if (indicator.chapters.isEmpty) indicator.code,
    },
  };
  Set<String> get _selectedIndicators =>
      _selectedIndicatorsBySemester[semester]!;
  final _customIndicators = <int, List<String>>{};
  SyllabusTextbook? _mathayomOneTextbook = mathayomOneTextbooks.first;

  StandardsSource get standardsSource => _standardsSource;
  List<SyllabusIndicator> get indicators =>
      grade == 1 ? mathayomOneIndicators : const [];
  bool _isRecommended(SyllabusIndicator indicator) =>
      indicator.chapters.isNotEmpty == (semester == 1);

  List<SyllabusIndicator> get recommendedIndicators =>
      indicators.where(_isRecommended).toList();
  List<SyllabusIndicator> get additionalIndicators =>
      indicators.where((indicator) => !_isRecommended(indicator)).toList();

  List<SyllabusIndicator> get selectedIndicators => [
    for (final indicator in indicators)
      if (_selectedIndicators.contains(indicator.code)) indicator,
  ];
  List<String> get customIndicators =>
      List.unmodifiable(_customIndicators[grade] ?? const <String>[]);
  List<SyllabusTextbook> get textbooks =>
      grade == 1 ? mathayomOneTextbooks : const [];
  SyllabusTextbook? get textbook => grade == 1 ? _mathayomOneTextbook : null;
  bool get hasStandards => switch (_standardsSource) {
    StandardsSource.obec => selectedIndicators.isNotEmpty,
    StandardsSource.custom => customIndicators.isNotEmpty,
  };

  void setStandardsSource(StandardsSource value) {
    _standardsSource = value;
    notifyListeners();
  }

  void toggleIndicator(String code, bool selected) {
    if (selected) {
      _selectedIndicators.add(code);
    } else {
      _selectedIndicators.remove(code);
    }
    notifyListeners();
  }

  void addCustomIndicator(String value) {
    (_customIndicators[grade] ??= []).add(value);
    notifyListeners();
  }

  void removeCustomIndicator(int index) {
    _customIndicators[grade]!.removeAt(index);
    notifyListeners();
  }

  void selectTextbook(SyllabusTextbook? value) {
    _mathayomOneTextbook = value;
    notifyListeners();
  }

  final _units = <SyllabusUnitDraft>[];
  int _nextUnitId = 1;
  bool _unitsPrepared = false;

  List<SyllabusUnitDraft> get units => List.unmodifiable(_units);
  List<String> get unitReferences => switch (_standardsSource) {
    StandardsSource.obec =>
      selectedIndicators.map((indicator) => indicator.code).toList(),
    StandardsSource.custom => customIndicators,
  };
  int get plannedPeriods =>
      _units.fold(0, (total, unit) => total + unit.periods);
  int get orientationPeriods =>
      (teachingTime.available - plannedPeriods).clamp(0, 2);

  void prepareUnits() {
    if (_unitsPrepared) return;
    _unitsPrepared = true;
    final book = textbook;
    if (_standardsSource == StandardsSource.obec && book != null) {
      final selected = selectedIndicators;
      for (final (index, title) in book.chapters.indexed) {
        for (final indicator in selected) {
          if (!indicator.chapters.contains(index + 1)) continue;
          final lessons = sampleChapterLessons[index];
          _units.add(
            SyllabusUnitDraft(
              id: _nextUnitId++,
              colorIndex: index,
              title: title,
              reference: indicator.code,
              periods: lessons.fold(
                0,
                (total, lesson) => total + lesson.periods,
              ),
              lessons: lessons,
            ),
          );
        }
      }
    }
    final covered = _units.map((unit) => unit.reference).toSet();
    for (final reference in unitReferences) {
      if (covered.contains(reference)) continue;
      final title = _standardsSource == StandardsSource.obec
          ? selectedIndicators
                .firstWhere((indicator) => indicator.code == reference)
                .description
          : reference;
      _units.add(
        _newUnit(title, reference, 1, lessons: [(title: title, periods: 1)]),
      );
    }
    notifyListeners();
  }

  SyllabusUnitDraft _newUnit(
    String title,
    String reference,
    int periods, {
    List<SyllabusLessonDraft> lessons = const [],
  }) {
    final id = _nextUnitId++;
    return SyllabusUnitDraft(
      id: id,
      colorIndex: id - 1,
      title: title,
      reference: reference,
      periods: periods,
      lessons: lessons,
    );
  }

  void addUnit(String title, String reference, int periods) {
    _units.add(_newUnit(title, reference, periods));
    notifyListeners();
  }

  void replaceUnit(SyllabusUnitDraft unit) {
    final index = _units.indexWhere((item) => item.id == unit.id);
    if (index == -1) return;
    _units[index] = unit;
    notifyListeners();
  }

  void removeUnit(int id) {
    _units.removeWhere((unit) => unit.id == id);
    notifyListeners();
  }

  void reorderUnit(int oldIndex, int newIndex) {
    _units.insert(newIndex, _units.removeAt(oldIndex));
    notifyListeners();
  }

  String? get unitsError {
    if (_units.isEmpty) return 'Add at least one unit.';
    final references = unitReferences.toSet();
    for (final unit in _units) {
      if (!references.contains(unit.reference)) {
        return 'Choose a current indicator for ${unit.title}.';
      }
      if (unit.periods <= 0 ||
          unit.lessons.isEmpty ||
          unit.lessonPeriods != unit.periods) {
        return 'Match the lesson periods to the unit periods for ${unit.title}.';
      }
    }
    if (!references.every(
      (reference) => _units.any((unit) => unit.reference == reference),
    )) {
      return 'Assign every selected indicator to a unit.';
    }
    if (plannedPeriods > teachingTime.available) {
      return 'The plan is over the available teaching periods.';
    }
    return null;
  }

  final _assessmentPoints = {
    for (final category in AssessmentCategory.values)
      category: category.defaultPoints,
  };

  int pointsFor(AssessmentCategory category) => _assessmentPoints[category]!;
  int get assessmentTotal =>
      _assessmentPoints.values.fold(0, (sum, points) => sum + points);
  int get finalPoints => pointsFor(AssessmentCategory.finalExam);
  int get duringTermPoints => assessmentTotal - finalPoints;
  String? get assessmentError => assessmentTotal == 100
      ? null
      : 'Set assessment scores to a total of 100 points.';

  void setAssessmentPoints(AssessmentCategory category, int points) {
    _assessmentPoints[category] = points;
    notifyListeners();
  }

  void setAssessmentSplit(int finalPoints) {
    final termCategories = AssessmentCategory.values
        .where((category) => category != AssessmentCategory.finalExam)
        .toList();
    final currentTotal = duringTermPoints;
    final scores = [
      for (final category in termCategories)
        currentTotal == 0 ? category.defaultPoints : pointsFor(category),
    ];
    final denominator = scores.fold(0, (sum, score) => sum + score);
    final termBudget = 100 - finalPoints;
    final shares = scores
        .map((score) => score * termBudget ~/ denominator)
        .toList();
    final indices = List.generate(scores.length, (index) => index)
      ..sort((a, b) {
        final first = scores[a] * termBudget % denominator;
        final second = scores[b] * termBudget % denominator;
        return first == second ? a.compareTo(b) : second.compareTo(first);
      });
    final remainder =
        termBudget - shares.fold<int>(0, (sum, share) => sum + share);
    for (final index in indices.take(remainder)) {
      shares[index]++;
    }
    for (final (index, category) in termCategories.indexed) {
      _assessmentPoints[category] = shares[index];
    }
    _assessmentPoints[AssessmentCategory.finalExam] = finalPoints;
    notifyListeners();
  }

  final _classSchedules = <int, List<String?>>{};
  var _schedulePeriods = <SchedulePeriod>[];

  void prepareSchedule() {
    final periods = _buildSchedulePeriods();
    if (!listEquals(
      _schedulePeriods.map((period) => period.id).toList(),
      periods.map((period) => period.id).toList(),
    )) {
      _classSchedules.clear();
    }
    _schedulePeriods = periods;
    notifyListeners();
  }

  List<SchedulePeriod> _buildSchedulePeriods() {
    final result = <SchedulePeriod>[];
    if (orientationPeriods > 0) {
      result.add((
        id: 'orientation',
        title: 'Orientation',
        colorIndex: null,
        quizPoints: 0,
      ));
    }
    final quizBudget = pointsFor(AssessmentCategory.quizzes);
    for (final (unitIndex, unit) in _units.indexed) {
      var periodNumber = 0;
      for (final lesson in unit.lessons) {
        for (var i = 0; i < lesson.periods; i++) {
          periodNumber++;
          final isLast = periodNumber == unit.periods;
          final points = !isLast || quizBudget == 0
              ? 0
              : quizBudget ~/ _units.length +
                    (unitIndex < quizBudget % _units.length ? 1 : 0);
          result.add((
            id: 'unit-${unit.id}-$periodNumber',
            title: lesson.periods == 1
                ? lesson.title
                : '${lesson.title} · ${i + 1}',
            colorIndex: unit.colorIndex,
            quizPoints: points,
          ));
        }
      }
    }
    if (orientationPeriods == 2) {
      result.add((
        id: 'buffer',
        title: 'Buffer',
        colorIndex: null,
        quizPoints: 0,
      ));
    }
    return result;
  }

  List<WeeklyPeriod> weeklyPeriodsFor(int classIndex) =>
      [
        for (final entry in _assignments.entries)
          if (entry.value == classIndex) entry.key,
      ]..sort(
        (a, b) => a.weekday == b.weekday
            ? a.period.compareTo(b.period)
            : a.weekday.compareTo(b.weekday),
      );

  List<ScheduleSlot> scheduleFor(int classIndex) {
    final periods = {for (final period in _schedulePeriods) period.id: period};
    final order = _orderFor(classIndex);
    final weekly = weeklyPeriodsFor(classIndex);
    final events = {for (final event in schoolEvents) event.date: event.name};
    var slot = 0;
    final result = <ScheduleSlot>[];
    for (
      var date = _firstDay;
      !date.isAfter(_lastDay);
      date = date.add(const Duration(days: 1))
    ) {
      for (final period in weekly) {
        if (period.weekday != date.weekday) continue;
        final event = events[date];
        final position = event == null ? slot++ : null;
        result.add((
          date: date,
          periodNumber: period.period,
          holiday: event,
          position: position,
          lesson: position == null || position >= order.length
              ? null
              : periods[order[position]],
        ));
      }
    }
    return result;
  }

  List<String?> _orderFor(int classIndex) => [
    ...(_classSchedules[classIndex] ??
        _schedulePeriods.map((period) => period.id)),
  ];

  int get schedulePeriodCount => _schedulePeriods.length;

  void moveSchedulePeriod(int classIndex, int from, int to) {
    if (from == to) return;
    final order = _orderFor(classIndex);
    if (from >= order.length || order[from] == null) return;
    while (order.length <= to) {
      order.add(null);
    }
    order.insert(to, order.removeAt(from));
    _classSchedules[classIndex] = order;
    notifyListeners();
  }

  void regenerateSchedule(int classIndex) {
    _classSchedules.remove(classIndex);
    notifyListeners();
  }

  void applyScheduleToAllClasses(int sourceClass) {
    final order = _orderFor(sourceClass).whereType<String>().toList();
    for (var index = 0; index < _classes.length; index++) {
      if (index != sourceClass) _classSchedules[index] = [...order];
    }
    notifyListeners();
  }

  String? get scheduleError {
    for (var index = 0; index < _classes.length; index++) {
      final placed = scheduleFor(index)
          .where((slot) => slot.lesson != null)
          .length;
      if (placed != schedulePeriodCount) {
        return 'Place every planned period for ${_classes[index].name}.';
      }
    }
    return null;
  }

  final _teachingApproaches = {TeachingApproach.inquiry};
  final _studentDetails = {
    StudentSyllabusDetail.topics,
    StudentSyllabusDetail.assessmentDates,
    StudentSyllabusDetail.scores,
  };
  String _teachingNotes = '';

  Set<TeachingApproach> get teachingApproaches =>
      Set.unmodifiable(_teachingApproaches);
  Set<StudentSyllabusDetail> get studentDetails =>
      Set.unmodifiable(_studentDetails);
  String get teachingNotes => _teachingNotes;

  void setTeachingApproach(TeachingApproach approach, bool selected) {
    if (selected) {
      _teachingApproaches.add(approach);
    } else {
      _teachingApproaches.remove(approach);
    }
    notifyListeners();
  }

  void setStudentDetail(StudentSyllabusDetail detail, bool selected) {
    if (selected) {
      _studentDetails.add(detail);
    } else {
      _studentDetails.remove(detail);
    }
    notifyListeners();
  }

  void setTeachingNotes(String notes) {
    _teachingNotes = notes;
    notifyListeners();
  }

  int _selectedClass = 0;

  String get courseName => _courseName;

  void setCourseName(String value) => _courseName = value;

  String get courseCode => _courseCode;

  void setCourseCode(String value) => _courseCode = value;

  String get credits => _credits;

  void setCredits(String value) => _credits = value;

  int get grade => _grade;
  int get academicYear => _academicYear;
  int get semester => _semester;
  DateTime get firstDay => _firstDay;
  DateTime get lastDay => _lastDay;
  List<TeachingClass> get classes => List.unmodifiable(_classes);
  int get selectedClass => _selectedClass;
  int? classFor(WeeklyPeriod period) => _assignments[period];

  void setGrade(int value) {
    _grade = value;
    notifyListeners();
  }

  void setAcademicYear(int value) {
    _academicYear = value;
    notifyListeners();
  }

  void setSemester(int value) {
    _semester = value;
    notifyListeners();
  }

  void setTeachingDay(DateTime value, {required bool first}) {
    final day = DateTime.utc(value.year, value.month, value.day);
    if (first) {
      _firstDay = day;
    } else {
      _lastDay = day;
    }
    notifyListeners();
  }

  void selectClass(int index) {
    _selectedClass = index;
    notifyListeners();
  }

  bool hasClass(String name) => _classes.any(
    (room) => room.name.toLowerCase() == name.trim().toLowerCase(),
  );

  void addClass(TeachingClass room) {
    _classes.add(room);
    _selectedClass = _classes.length - 1;
    notifyListeners();
  }

  void togglePeriod(WeeklyPeriod period) {
    if (_assignments[period] == _selectedClass) {
      _assignments.remove(period);
    } else {
      _assignments[period] = _selectedClass;
    }
    notifyListeners();
  }

  List<SchoolEvent> get schoolEvents => [
    for (final event in _schoolEvents)
      if (!event.date.isBefore(_firstDay) && !event.date.isAfter(_lastDay))
        event,
  ];

  String? get dateError {
    final length = _lastDay.difference(_firstDay).inDays;
    if (length < 0) return 'Last teaching day must be on or after the first.';
    if (length >= 365) return 'Choose a teaching range shorter than a year.';
    return null;
  }

  ({int weeks, String periodsPerWeek, int excluded, int available})
  get teachingTime {
    final weeklySlots = List.filled(_classes.length, 0);
    for (final index in _assignments.values) {
      weeklySlots[index]++;
    }
    final minWeekly = weeklySlots.reduce(math.min);
    final maxWeekly = weeklySlots.reduce(math.max);
    final weekly = minWeekly == maxWeekly
        ? '$minWeekly'
        : '$minWeekly–$maxWeekly';
    if (dateError != null) {
      return (weeks: 0, periodsPerWeek: weekly, excluded: 0, available: 0);
    }

    final events = schoolEvents.map((event) => event.date).toSet();
    final available = List.filled(_classes.length, 0);
    final excluded = List.filled(_classes.length, 0);
    final weeks = <DateTime>{};
    for (
      var date = _firstDay;
      !date.isAfter(_lastDay);
      date = date.add(const Duration(days: 1))
    ) {
      weeks.add(date.subtract(Duration(days: date.weekday - 1)));
      for (final entry in _assignments.entries) {
        if (entry.key.weekday != date.weekday) continue;
        final counts = events.contains(date) ? excluded : available;
        counts[entry.value]++;
      }
    }
    final leastAvailable = available.reduce(math.min);
    return (
      weeks: weeks.length,
      periodsPerWeek: weekly,
      excluded: excluded[available.indexOf(leastAvailable)],
      available: leastAvailable,
    );
  }

  String? get timetableError {
    if (dateError case final error?) return error;
    for (var index = 0; index < _classes.length; index++) {
      if (!_assignments.containsValue(index)) {
        return 'Assign at least one weekly period to ${_classes[index].name}.';
      }
    }
    if (teachingTime.available == 0) {
      return 'Choose teaching dates that include a period for every class.';
    }
    return null;
  }
}
