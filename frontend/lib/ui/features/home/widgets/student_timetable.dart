import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

class StudentTimetable extends StatelessWidget {
  const StudentTimetable({
    super.key,
    required this.now,
    required this.weekday,
    required this.onDaySelected,
  });

  final DateTime now;
  final int weekday;
  final ValueChanged<int> onDaySelected;

  // Sample timetable until the student's schedule is connected.
  static const subjects = [
    'Mathematics',
    'Science',
    'CSS101 Basic Programming',
    'English',
    'Science',
  ];
  static const periods = [
    ('09:00', '10:00', 'Review the previous lesson.'),
    (
      '10:00',
      '11:30',
      'Work through examples together and practice with a partner.',
    ),
    ('11:30', '12:00', 'Lunch Break'),
    ('12:00', '13:00', 'Guided practice'),
    ('13:00', '14:00', 'Independent exercises'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var day = 1; day <= 5; day++)
              Flexible(child: _dayButton(context, day)),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 26, 20, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              for (final (start, end, description) in periods)
                _period(context, start, end, description),
              Row(
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      '14:00',
                      style: theme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(height: 1)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayButton(BuildContext context, int day) {
    final theme = Theme.of(context).textTheme;
    final selected = weekday == day;
    final date = DateTime(now.year, now.month, now.day - now.weekday + day);
    final label = DateFormat.E('en_US').format(date);
    return Semantics(
      selected: selected,
      button: true,
      label: DateFormat.yMMMMEEEEd('en_US').format(date),
      excludeSemantics: true,
      onTap: () => onDaySelected(day),
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: .55),
        shape: const StadiumBorder(side: BorderSide(color: Colors.white)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onDaySelected(day),
          child: Container(
            width: selected ? 74 : 62,
            constraints: BoxConstraints(minHeight: selected ? 92 : 76),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.labelSmall?.copyWith(
                    color: selected ? AppColors.primary : AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xff007932)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(selected ? 8 : 2),
                    child: Text(
                      '${date.day}',
                      style: theme.titleMedium?.copyWith(
                        fontSize: 18,
                        color: selected ? Colors.white : AppColors.mutedText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _period(
    BuildContext context,
    String start,
    String end,
    String description,
  ) {
    final theme = Theme.of(context).textTheme;
    final isBreak = start == '11:30';
    final time = DateFormat.Hm('en_US').format(now);
    final active =
        weekday == now.weekday &&
        time.compareTo(start) >= 0 &&
        time.compareTo(end) < 0;
    final foreground = active ? Colors.white : const Color(0xff175c35);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            start,
            style: theme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              const Divider(height: 1, color: Color(0xffc9d5e7)),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: isBreak
                      ? 43
                      : start == '10:00'
                      ? 120
                      : 76,
                ),
                margin: const EdgeInsets.symmetric(vertical: 7),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : isBreak
                      ? AppColors.header
                      : const Color(0xffdfffcc),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          isBreak ? description : subjects[weekday - 1],
                          style: theme.titleSmall?.copyWith(
                            color: foreground,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$start – $end',
                          style: theme.bodySmall?.copyWith(
                            color: foreground,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    if (!isBreak)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          description,
                          style: theme.bodySmall?.copyWith(color: foreground),
                        ),
                      ),
                    if (active)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const ShapeDecoration(
                            shape: StadiumBorder(),
                            color: Colors.white,
                          ),
                          child: Text(
                            '● Now',
                            style: theme.labelSmall?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
