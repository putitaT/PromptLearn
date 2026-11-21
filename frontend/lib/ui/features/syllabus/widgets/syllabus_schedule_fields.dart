import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../models/syllabus_schedule.dart';
import '../view_models/syllabus_editor_view_model.dart';
import 'syllabus_unit_colors.dart';

const _ink = Color(0xFF202438);
const _line = Color(0xFFE6ECE8);
const _soft = Color(0xFFEEF3EF);
const _white = Color(0xFFFFFFFF);
const _orange = Color(0xFF963F14);

class SyllabusScheduleFields extends StatefulWidget {
  const SyllabusScheduleFields({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  State<SyllabusScheduleFields> createState() => _SyllabusScheduleFieldsState();
}

class _SyllabusScheduleFieldsState extends State<SyllabusScheduleFields> {
  int _classIndex = 0;
  final _keptQuizzes = <(int, String, DateTime)>{};
  EdgeDraggingAutoScroller? _verticalDragScroller;

  @override
  void dispose() {
    _verticalDragScroller?.stopAutoScroll();
    super.dispose();
  }

  void _startDrag() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      _verticalDragScroller = EdgeDraggingAutoScroller(
        scrollable,
        velocityScalar: 18,
      );
    }
  }

  void _updateDrag(DragUpdateDetails details) {
    _verticalDragScroller?.startAutoScrollIfNecessary(
      Rect.fromCenter(center: details.globalPosition, width: 1, height: 48),
    );
  }

  void _endDrag(DraggableDetails details) {
    _verticalDragScroller?.stopAutoScroll();
    _verticalDragScroller = null;
  }

  Future<void> _export(BuildContext context, List<ScheduleSlot> slots) async {
    final draft = widget.draft;
    final data = scheduleCalendarFile(
      course: draft.courseName,
      room: draft.classes[_classIndex].name,
      slots: slots,
      generatedAt: DateTime.now(),
    );
    final button = context.findRenderObject()! as RenderBox;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(data)),
              mimeType: 'text/calendar',
            ),
          ],
          fileNameOverrides: ['promptlearn-schedule.ics'],
          sharePositionOrigin: button.localToGlobal(Offset.zero) & button.size,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not export the calendar. Try again.'),
        ),
      );
    }
  }

  Future<void> _regenerate() async {
    final classIndex = _classIndex;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate schedule?'),
        content: Text(
          'Reset the period order for ${widget.draft.classes[classIndex].name} to the unit plan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    _keptQuizzes.removeWhere((entry) => entry.$1 == classIndex);
    widget.draft.regenerateSchedule(classIndex);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final classes = draft.classes;
    final slots = draft.scheduleFor(_classIndex);
    final weekly = draft.weeklyPeriodsFor(_classIndex);
    final first = draft.firstDay.subtract(
      Duration(days: draft.firstDay.weekday - 1),
    );
    final suggestedMidterm = first.add(
      Duration(days: draft.teachingTime.weeks ~/ 2 * 7),
    );
    final warning = slots.where((slot) {
      final days = suggestedMidterm.difference(slot.date).inDays;
      final lesson = slot.lesson;
      return lesson != null &&
          lesson.quizPoints > 0 &&
          days >= 1 &&
          days <= 2 &&
          !_keptQuizzes.contains((_classIndex, lesson.id, slot.date));
    }).firstOrNull;
    final others = [
      for (var index = 0; index < classes.length; index++)
        if (index != _classIndex) classes[index].name,
    ];
    final className = classes[_classIndex].name;
    final placed = slots.where((slot) => slot.lesson != null).length;
    final available = slots.where((slot) => slot.position != null).length;
    final planned = draft.schedulePeriodCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Class',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final (index, room) in classes.indexed)
                  ChoiceChip(
                    label: Text(room.name),
                    showCheckmark: false,
                    selectedColor: _white,
                    backgroundColor: _soft,
                    selected: _classIndex == index,
                    onSelected: (_) => setState(() => _classIndex = index),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: _regenerate,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Regenerate'),
                ),
                Builder(
                  builder: (context) => OutlinedButton.icon(
                    onPressed: placed == 0
                        ? null
                        : () => _export(context, slots),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Export .ics'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final (index, unit) in draft.units.indexed)
              _Legend(
                label: 'U${index + 1}',
                color:
                    syllabusUnitColors[unit.colorIndex %
                            syllabusUnitColors.length]
                        .accent,
              ),
            const _Legend(label: 'Scored', color: _ink, outlined: true),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final calendar = _Panel(
              child: _CalendarGrid(
                weekly: weekly,
                slots: slots,
                firstWeek: first,
                weeks: draft.teachingTime.weeks,
                onMove: (from, to) =>
                    draft.moveSchedulePeriod(_classIndex, from, to),
                onDragStarted: _startDrag,
                onDragUpdate: _updateDrag,
                onDragEnd: _endDrag,
              ),
            );
            final checks = _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Text(
                    'Checks',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 17, color: _ink),
                  ),
                  _Notice(
                    color: placed == planned
                        ? const Color(0xFFE7F3EC)
                        : const Color(0xFFFFF3EA),
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          placed == planned
                              ? Icons.check
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color: placed == planned
                              ? const Color(0xFF2B6B1F)
                              : _orange,
                        ),
                        Expanded(
                          child: Text(
                            placed == planned
                                ? 'All $planned periods placed · ${available - placed} left over'
                                : '$placed of $planned periods placed · ${planned - placed} unplaced',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (warning != null)
                    _Notice(
                      color: const Color(0xFFFFF3EA),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          Text(
                            'A quiz lands shortly before the suggested midterm week.',
                            style: const TextStyle(
                              color: _orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'EEE d MMM',
                              'en_US',
                            ).format(warning.date),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  final earlier =
                                      slots
                                          .where(
                                            (slot) =>
                                                slot.position != null &&
                                                !slot.date.isAfter(
                                                  warning.date.subtract(
                                                    const Duration(days: 7),
                                                  ),
                                                ),
                                          )
                                          .lastOrNull ??
                                      slots.firstWhere(
                                        (slot) => slot.position != null,
                                      );
                                  if (earlier.position == warning.position) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'There is no earlier teaching slot.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  draft.moveSchedulePeriod(
                                    _classIndex,
                                    warning.position!,
                                    earlier.position!,
                                  );
                                },
                                child: const Text('Move earlier'),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _keptQuizzes.add((
                                    _classIndex,
                                    warning.lesson!.id,
                                    warning.date,
                                  )),
                                ),
                                child: const Text('Keep'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (others.isNotEmpty)
                    _Notice(
                      color: const Color(0xFFF8F8F8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 8,
                        children: [
                          Text(
                            others.join(', '),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Copy the period order from $className to the other classes’ own teaching slots.',
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 13,
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              draft.applyScheduleToAllClasses(_classIndex);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Period order applied to all classes.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Apply to all classes'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
            if (constraints.maxWidth >= 930) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Expanded(flex: 2, child: calendar),
                  Expanded(child: checks),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [calendar, checks],
            );
          },
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.weekly,
    required this.slots,
    required this.firstWeek,
    required this.weeks,
    required this.onMove,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final List<WeeklyPeriod> weekly;
  final List<ScheduleSlot> slots;
  final DateTime firstWeek;
  final int weeks;
  final void Function(int, int) onMove;
  final VoidCallback onDragStarted;
  final DragUpdateCallback onDragUpdate;
  final ValueChanged<DraggableDetails> onDragEnd;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final dates = DateFormat('EEE d MMM', 'en_US');
    final byDate = {
      for (final slot in slots) (slot.date, slot.periodNumber): slot,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth,
          62 + weekly.length * 112.0,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              spacing: 8,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    const SizedBox(width: 54),
                    for (final period in weekly)
                      Expanded(
                        child: Text(
                          '${weekdays[period.weekday - 1]} P${period.period}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
                for (var week = 0; week < weeks; week++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      SizedBox(
                        width: 54,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Text(
                            'Week ${week + 1}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ),
                      for (final period in weekly)
                        Expanded(
                          child: _slot(
                            byDate[(
                              firstWeek.add(
                                Duration(days: week * 7 + period.weekday - 1),
                              ),
                              period.period,
                            )],
                            dates,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _slot(ScheduleSlot? slot, DateFormat dates) {
    if (slot == null) return const SizedBox(height: 70);
    final date = dates.format(slot.date);
    final position = slot.position;
    if (position == null) {
      return _PeriodCard(
        date: date,
        label: 'Holiday · ${slot.holiday}',
        color: const Color(0xFFECEBE6),
      );
    }
    final lesson = slot.lesson;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => position != details.data,
      onAcceptWithDetails: (details) => onMove(details.data, position),
      builder: (context, candidates, _) {
        final card = _PeriodCard(
          key: ValueKey('schedule-slot-$position'),
          date: date,
          label: lesson?.title ?? 'Open slot',
          quizPoints: lesson?.quizPoints ?? 0,
          color: lesson?.colorIndex == null
              ? _soft
              : syllabusUnitColors[lesson!.colorIndex! %
                        syllabusUnitColors.length]
                    .fill,
          highlighted: candidates.isNotEmpty,
        );
        if (lesson == null) return card;
        return LongPressDraggable<int>(
          data: position,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          maxSimultaneousDrags: 1,
          onDragStarted: onDragStarted,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          feedback: Transform.translate(
            offset: const Offset(14, -24),
            child: Material(
              elevation: 4,
              color: _white,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    lesson.title,
                    style: const TextStyle(color: _ink),
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: card,
        );
      },
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    super.key,
    required this.date,
    required this.label,
    required this.color,
    this.highlighted = false,
    this.quizPoints = 0,
  });

  final String date;
  final String label;
  final Color color;
  final bool highlighted;
  final int quizPoints;

  @override
  Widget build(BuildContext context) {
    final scored = quizPoints > 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: highlighted
              ? AppColors.accent
              : scored
              ? _ink
              : _line,
          width: highlighted || scored ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Text(
            date,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          Text(label, style: const TextStyle(color: _ink, fontSize: 13)),
          if (scored)
            Text(
              'Quiz · $quizPoints pts',
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A65776C),
          blurRadius: 40,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.label,
    required this.color,
    this.outlined = false,
  });
  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: outlined ? null : color,
          border: outlined ? Border.all(color: color, width: 2) : null,
          shape: BoxShape.circle,
        ),
      ),
      Text(label, style: const TextStyle(color: _ink, fontSize: 12)),
    ],
  );
}
