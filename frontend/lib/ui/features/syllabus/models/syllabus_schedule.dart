typedef SchedulePeriod = ({
  String id,
  String title,
  int? colorIndex,
  int quizPoints,
});

typedef ScheduleSlot = ({
  DateTime date,
  int periodNumber,
  String? holiday,
  int? position,
  SchedulePeriod? lesson,
});

String scheduleCalendarFile({
  required String course,
  required String room,
  required Iterable<ScheduleSlot> slots,
  required DateTime generatedAt,
}) {
  String digits(int value) => value.toString().padLeft(2, '0');
  String date(DateTime day) =>
      '${day.year}${digits(day.month)}${digits(day.day)}';
  final stamp = generatedAt.toUtc();
  final timestamp =
      '${date(stamp)}T${digits(stamp.hour)}${digits(stamp.minute)}${digits(stamp.second)}Z';

  String escape(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');

  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//PromptLearn//Teaching Schedule//EN',
    for (final slot in slots)
      if (slot.lesson case final lesson?) ...[
        'BEGIN:VEVENT',
        'UID:${Uri.encodeComponent(course)}-${Uri.encodeComponent(room)}-${lesson.id}@promptlearn',
        'DTSTAMP:$timestamp',
        'DTSTART;VALUE=DATE:${date(slot.date)}',
        'SUMMARY:${escape('P${slot.periodNumber} · $course · ${lesson.title}')}',
        'DESCRIPTION:${escape(lesson.quizPoints > 0 ? '$room · Quiz worth ${lesson.quizPoints} points' : room)}',
        'END:VEVENT',
      ],
    'END:VCALENDAR',
    '',
  ];
  return lines.join('\r\n');
}
