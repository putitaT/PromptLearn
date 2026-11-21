import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

const _mint = Color(0xffdfffcc);
const _green = Color(0xff007932);
const _homework = [
  (
    id: 'hw-3.1',
    subject: 'Math 101 : Mathematics',
    task: 'HW 3.1 · Exponent practice',
    days: 0,
    time: '23:59',
  ),
  (
    id: 'science',
    subject: 'Science',
    task: 'Lab report on force and motion',
    days: 1,
    time: '16:00',
  ),
  (
    id: 'english',
    subject: 'English',
    task: 'Reading exercise · Unit 5',
    days: 2,
    time: '16:00',
  ),
  (
    id: 'css101',
    subject: 'CSS101 Basic Programming',
    task: 'Practice with variables and loops',
    days: 4,
    time: '16:00',
  ),
];

class StudentCoursework extends StatelessWidget {
  const StudentCoursework({
    super.key,
    required this.now,
    required this.onOpenHomework,
  });

  final DateTime now;
  final VoidCallback onOpenHomework;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _UpcomingClass(),
        const SizedBox(height: 40),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '📚 All Homework',
              style: theme.titleLarge?.copyWith(fontSize: 24),
            ),
            _Pill(
              '${_homework.length} works',
              color: Colors.white,
              ink: _green,
              outlined: true,
            ),
          ],
        ),
        const SizedBox(height: 28),
        for (final item in _homework) ...[
          _HomeworkCard(
            subject: item.subject,
            task: item.task,
            onOpen: item.id == 'hw-3.1' ? onOpenHomework : null,
            due: switch (item.days) {
              0 => '• Today',
              1 => '• Tomorrow',
              _ => DateFormat(
                'd MMM yyyy',
                'en_US',
              ).format(DateTime(now.year, now.month, now.day + item.days)),
            },
            time: item.time,
            accent: switch (item.days) {
              0 => const Color(0xffec281e),
              1 => const Color(0xffe95405),
              _ => AppColors.accent,
            },
            urgent: item.days < 2,
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _UpcomingClass extends StatelessWidget {
  const _UpcomingClass();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return _Surface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 470;
          const badge = _Pill('Starts in 15 min');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UP NEXT',
                          style: theme.labelSmall?.copyWith(color: _green),
                        ),
                        Text(
                          'Mathematics',
                          style: theme.titleLarge?.copyWith(fontSize: 24),
                        ),
                        Text(
                          '10:30 – 11:30 AM  ·  Room 204',
                          style: theme.bodyMedium?.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact) badge,
                ],
              ),
              if (compact)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Align(alignment: Alignment.centerLeft, child: badge),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfff7fcf9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      children: [
                        Text('Homework', style: theme.titleMedium),
                        Text(
                          '1 of 2 submitted',
                          style: theme.bodySmall?.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _Submission(
                      title: 'Algebra · Practice problems',
                      submitted: true,
                    ),
                    const _Submission(
                      title: 'Geometry · Worksheet 4',
                      submitted: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _ClassActions(),
            ],
          );
        },
      ),
    );
  }
}

class _Submission extends StatelessWidget {
  const _Submission({required this.title, required this.submitted});

  final String title;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    final status = submitted ? 'Submitted' : 'Not submitted';
    final badge = _Pill(
      status,
      color: submitted ? const Color(0xffe7f3ec) : const Color(0xffffe5da),
      ink: submitted ? const Color(0xff22704f) : const Color(0xffa63a05),
      checked: submitted,
    );
    return InkWell(
      onTap: () => _showDetails(context, title, 'Mathematics · $status'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 42),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [Text(title), badge],
              ),
            ),
            const Icon(Icons.chevron_right, size: 21, color: _green),
          ],
        ),
      ),
    );
  }
}

class _ClassActions extends StatelessWidget {
  const _ClassActions();

  @override
  Widget build(BuildContext context) {
    final join = _button(
      context,
      'Join Class',
      'iconmind_art-class-outline-thin',
      Colors.black,
      Colors.white,
      'Mathematics meets in Room 204, 10:30 – 11:30 AM.',
    );
    final plan = _button(
      context,
      'Lesson Plan',
      'akar-icons_book-close',
      const Color(0xfff2f2fc),
      AppColors.ink,
      'Mathematics · Linear equations\n\nReview linear equations, solve practice problems, and discuss Worksheet 4.',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <
            340 * MediaQuery.textScalerOf(context).scale(1)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [join, const SizedBox(height: 8), plan],
          );
        }
        return Row(
          children: [
            Expanded(child: join),
            const SizedBox(width: 16),
            Expanded(child: plan),
          ],
        );
      },
    );
  }

  Widget _button(
    BuildContext context,
    String title,
    String asset,
    Color background,
    Color foreground,
    String details,
  ) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(0, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: SvgPicture.asset(
        'assets/student_home/$asset.svg',
        width: 26,
        excludeFromSemantics: true,
      ),
      label: Text(title),
      onPressed: () => _showDetails(context, title, details),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    required this.subject,
    required this.task,
    required this.due,
    required this.time,
    required this.accent,
    required this.urgent,
    this.onOpen,
  });

  final String subject, task, due, time;
  final Color accent;
  final bool urgent;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final subjectText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subject, style: theme.titleMedium?.copyWith(fontSize: 20)),
        Text(
          task,
          style: theme.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
    final deadline = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Pill(
          due,
          color: urgent ? accent : _mint,
          ink: urgent ? Colors.white : _green,
        ),
        const SizedBox(height: 3),
        Text(
          time,
          style: theme.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
    return _Surface(
      onTap:
          onOpen ??
          () => _showDetails(
            context,
            subject,
            '$task\n\nDue ${due.replaceFirst('• ', '')} · $time',
          ),
      child: Container(
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  subjectText,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: deadline),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: subjectText),
                const SizedBox(width: 12),
                deadline,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
    this.text, {
    this.color = _mint,
    this.ink = _green,
    this.outlined = false,
    this.checked = false,
  });

  final String text;
  final Color color, ink;
  final bool outlined, checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: ShapeDecoration(
        color: color,
        shape: StadiumBorder(
          side: outlined
              ? const BorderSide(color: AppColors.accent, width: 1.5)
              : BorderSide.none,
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: text),
            if (checked)
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.check_circle, size: 14, color: _green),
                ),
              ),
          ],
        ),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ink),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inset = Padding(padding: const EdgeInsets.all(20), child: child);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? inset : InkWell(onTap: onTap, child: inset),
    );
  }
}

void _showDetails(BuildContext context, String title, String details) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(details),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
