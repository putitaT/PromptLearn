import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../classroom/models/teacher_class_preview.dart';
import '../../syllabus/models/syllabus_preview.dart';
import '../../syllabus/view_models/syllabus_editor_view_model.dart';
import '../../syllabus/views/syllabus_editor_view.dart';
import '../../syllabus/views/teacher_syllabus_dialog.dart';
import '../../syllabus/widgets/syllabus_dashed_border.dart';
import '../../syllabus/views/teacher_course_detail_view.dart';
import '../widgets/home_header.dart';

const _paper = Color(0xFFFFFFFF);
const _text = Color(0xFF202438);
const _highlight = Color(0xFFDFFFCC);
const _lavender = Color(0xFFF2F3FF);
const _line = Color(0xFFE6ECE8);
const _upcomingGreen = Color(0xFF4ABE7A);
const _actionLabelStyle = TextStyle(fontSize: 14);
const _dashboardGap = 20.0;
const _overviewFlex = 791;
const _todayFlex = 302;

class TeacherHomeView extends StatelessWidget {
  const TeacherHomeView({
    super.key,
    required this.displayName,
    required this.now,
    required this.onStartClass,
    required this.onOpenAssessment,
    this.reviewNavigation,
  });

  final String displayName;
  final DateTime now;
  final VoidCallback onStartClass;
  final VoidCallback onOpenAssessment;
  final Widget? reviewNavigation;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8F8F8),
      child: Column(
        children: [
          HomeHeader(displayName: displayName, now: now),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final inset = constraints.maxWidth >= 900 ? 42.0 : 16.0;
                final padding = EdgeInsets.fromLTRB(inset, 25, inset, 18);
                final width = constraints.maxWidth - padding.horizontal;
                final rowWidth = width - _dashboardGap;
                final lessonWidth =
                    rowWidth * _overviewFlex / (_overviewFlex + _todayFlex);
                final showTodayAlongside =
                    lessonWidth >= _NextClass.minimumSplitWidth &&
                    rowWidth - lessonWidth >= _Today.minimumColumnWidth;
                final compactHeight = constraints.maxHeight < 700;
                return SingleChildScrollView(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.8, -0.2),
                        radius: 0.75,
                        colors: [Color(0xFFDFF8D5), Color(0xFFF8F8F8)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned(
                          top: -40,
                          left: -48,
                          width: 460,
                          height: 500,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, -0.3),
                                colors: [Color(0x3B6FF9A8), Color(0x006FF9A8)],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: padding,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  (constraints.maxHeight - padding.vertical)
                                      .clamp(0.0, double.infinity),
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: _dashboardGap,
                                children: [
                                  _DashboardRow(
                                    horizontal: showTodayAlongside,
                                    flexes: const [_overviewFlex, _todayFlex],
                                    children: [
                                      _NextClass(
                                        width: showTodayAlongside
                                            ? lessonWidth
                                            : width,
                                        compactHeight: compactHeight,
                                        onStartClass: onStartClass,
                                        onOpenAssessment: onOpenAssessment,
                                      ),
                                      const _Today(),
                                    ],
                                  ),
                                  Expanded(
                                    child: _DashboardRow(
                                      horizontal: width >= 900,
                                      flexes: const [387, 387, 300],
                                      children: [
                                        const _Attention(),
                                        const _ClassPulse(),
                                        _Syllabi(
                                          reviewNavigation: reviewNavigation,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardRow extends StatelessWidget {
  const _DashboardRow({
    required this.horizontal,
    required this.flexes,
    required this.children,
  });

  final bool horizontal;
  final List<int> flexes;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _dashboardGap,
        children: children,
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _dashboardGap,
        children: [
          for (var index = 0; index < children.length; index++)
            Expanded(flex: flexes[index], child: children[index]),
        ],
      ),
    );
  }
}

Widget _card(Widget child, {double padding = 20}) {
  return Container(
    padding: EdgeInsets.all(padding),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(16),
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

TextStyle _style(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _text,
}) {
  return Theme.of(context).textTheme.bodyMedium!.copyWith(
    fontSize: math.max(10.0, (size * 0.9).roundToDouble()),
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    height: 1.35,
    color: color,
  );
}

Widget _heading(
  BuildContext context,
  String title,
  Widget trailing, {
  CrossAxisAlignment alignment = CrossAxisAlignment.center,
}) {
  return Row(
    crossAxisAlignment: alignment,
    children: [
      Expanded(
        child: Text(title, style: _style(context, 18, weight: FontWeight.w700)),
      ),
      const SizedBox(width: 8),
      trailing,
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill(
    this.label, {
    this.color = _highlight,
    this.icon,
    this.foreground = _text,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            if (icon != null) Icon(icon, size: 14, color: foreground),
            Flexible(
              child: Text(
                label,
                style: _style(
                  context,
                  12,
                  weight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDetails(BuildContext context, String title, Widget content) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _NextClass extends StatelessWidget {
  const _NextClass({
    required this.width,
    required this.compactHeight,
    required this.onStartClass,
    required this.onOpenAssessment,
  });

  static const _minimumOverviewWidth = 370.0;
  static const _minimumFlowWidth = 220.0;
  static const minimumSplitWidth = _minimumOverviewWidth + _minimumFlowWidth;

  final double width;
  final bool compactHeight;
  final VoidCallback onStartClass;
  final VoidCallback onOpenAssessment;

  @override
  Widget build(BuildContext context) {
    final split = width >= minimumSplitWidth;
    final flowWidth = split
        ? (width * 0.35).clamp(_minimumFlowWidth, 280.0)
        : 0.0;
    final overview = _LessonOverview(
      onStartClass: onStartClass,
      onOpenAssessment: onOpenAssessment,
      horizontalActions: width - flowWidth >= 417,
    );
    final flow = _LessonFlow(compact: compactHeight || !split);

    return _card(
      split
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: overview),
                  SizedBox(width: flowWidth, child: flow),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [overview, flow],
            ),
      padding: 0,
    );
  }
}

class _LessonOverview extends StatelessWidget {
  const _LessonOverview({
    required this.horizontalActions,
    required this.onStartClass,
    required this.onOpenAssessment,
  });

  final bool horizontalActions;
  final VoidCallback onStartClass;
  final VoidCallback onOpenAssessment;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _LessonButton(
        label: 'Start Class',
        iconAsset: 'assets/home/iconmind_art-class-outline-thin.svg',
        primary: true,
        onPressed: onStartClass,
      ),
      _LessonButton(
        label: 'Lesson Plan',
        iconAsset: 'assets/home/akar-icons_book-close.svg',
        onPressed: onOpenAssessment,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 15,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const _Pill('Next · in 15 min', icon: Icons.schedule),
                  Text(
                    'P4 · 10:20–11:10 · Room 204',
                    style: _style(context, 15),
                  ),
                ],
              ),
              Text(
                TeacherClassPreview.lessonTitle,
                style: _style(context, 26, weight: FontWeight.w700),
              ),
              Row(
                spacing: 8,
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 18,
                    color: AppColors.mutedText,
                  ),
                  Flexible(
                    child: Text(
                      'M.1/1 · 32 students · 2 on leave',
                      style: _style(context, 13, color: AppColors.mutedText),
                    ),
                  ),
                ],
              ),
              const Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _Pill('IBL plan ready', icon: Icons.check),
                  _Pill(
                    '14 slides',
                    icon: Icons.slideshow_outlined,
                    color: _lavender,
                  ),
                  _Pill(
                    '2 exercises need review',
                    icon: Icons.error_outline,
                    color: Color(0xFFFFF1D6),
                  ),
                ],
              ),
            ],
          ),
          horizontalActions
              ? Row(
                  spacing: 16,
                  children: [
                    for (final button in buttons) Expanded(child: button),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: buttons,
                ),
        ],
      ),
    );
  }
}

class _LessonButton extends StatelessWidget {
  const _LessonButton({
    required this.label,
    required this.iconAsset,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: primary ? const Color(0xFF000000) : _lavender,
        foregroundColor: primary ? _paper : _text,
        minimumSize: const Size(0, 57),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: SvgPicture.asset(
        iconAsset,
        width: 24,
        height: 24,
        excludeFromSemantics: true,
      ),
      label: Text(label, style: _actionLabelStyle),
    );
  }
}

class _LessonFlow extends StatelessWidget {
  const _LessonFlow({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 0 : 357),
      color: const Color(0xFFF0FFE8),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            'Lesson flow · 50 min',
            style: _style(
              context,
              13,
              weight: FontWeight.w600,
              color: _upcomingGreen,
            ),
          ),
          for (final step in TeacherClassPreview.steps)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Text(
                  '${step.startMinute}′',
                  style: _style(
                    context,
                    12,
                    weight: FontWeight.w700,
                    color: const Color(0xFF286140),
                  ),
                ),
                Expanded(
                  child: _EntryText(step.title, step.summary, titleSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EntryText extends StatelessWidget {
  const _EntryText(
    this.title,
    this.description, {
    this.titleSize = 14,
    this.descriptionTrailing,
  });

  final String title;
  final String description;
  final double titleSize;
  final Widget? descriptionTrailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(title, style: _style(context, titleSize, weight: FontWeight.w600)),
        if (description.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                description,
                style: _style(context, 12, color: AppColors.mutedText),
              ),
              ?descriptionTrailing,
            ],
          ),
      ],
    );
  }
}

class _Today extends StatelessWidget {
  const _Today();

  static const minimumColumnWidth = 250.0;

  static const _periods = [
    ('08:30', '3.2 Multiplying powers', 'M.1/2'),
    ('10:20', '3.2 Multiplying powers', 'M.1/1'),
    ('12:00', 'Lunch break', ''),
    ('13:00', '3.1 What an exponent means', 'M.1/3'),
    ('14:00', 'Math 201 · 4.3 Factoring', 'M.2/1'),
  ];

  @override
  Widget build(BuildContext context) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          _heading(
            context,
            'Today',
            Text(
              '4 periods',
              style: _style(context, 13, color: AppColors.mutedText),
            ),
          ),
          for (final (time, title, room) in _periods)
            Container(
              decoration: BoxDecoration(
                color: time == '10:20' ? _highlight : null,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                spacing: 10,
                children: [
                  Text(
                    time,
                    style: _style(context, 13, weight: FontWeight.w600),
                  ),
                  Expanded(
                    child: _EntryText(
                      title,
                      room,
                      titleSize: 13,
                      descriptionTrailing: time == '10:20'
                          ? const _UpcomingBadge()
                          : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UpcomingBadge extends StatelessWidget {
  const _UpcomingBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _upcomingGreen,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          'Upcoming',
          style: _style(context, 10, weight: FontWeight.w600, color: _paper),
        ),
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.warning_amber_rounded,
        Color(0xFFFFE4D8),
        Color(0xFF9A4500),
        'Review 4 quiz papers',
        'AI wasn’t sure how to score these answers.',
      ),
      (
        Icons.auto_awesome_outlined,
        Color(0xFFE1F4E9),
        Color(0xFF179661),
        'Approve 7 practice sets',
        'Made from each student’s mistakes.',
      ),
    ];
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _heading(
            context,
            'Needs your attention',
            const _Pill('2', color: AppColors.ink, foreground: _paper),
          ),
          for (final (icon, color, foreground, title, description) in items)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showDetails(context, title, Text(description)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    spacing: 12,
                    children: [
                      _TileIcon(icon, color: color, foreground: foreground),
                      Expanded(child: _EntryText(title, description)),
                      const Icon(Icons.chevron_right, color: AppColors.ink),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassPulse extends StatelessWidget {
  const _ClassPulse();

  static const _classes = [
    ('M.1/1', 94, 78, 'On track'),
    ('M.1/2', 97, 86, 'On track'),
    ('M.1/3', 88, 61, '1 behind'),
  ];

  @override
  Widget build(BuildContext context) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          _heading(
            context,
            'Class pulse',
            Text(
              'This week',
              style: _style(context, 13, color: AppColors.mutedText),
            ),
          ),
          for (final (room, attendance, homework, status) in _classes)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _line, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              room,
                              style: _style(
                                context,
                                15,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Math 101',
                              style: _style(
                                context,
                                12,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Pill(
                        status,
                        color: status == 'On track'
                            ? const Color(0xFFE7F3EC)
                            : _lavender,
                        icon: status == 'On track'
                            ? Icons.check
                            : Icons.schedule,
                        foreground: status == 'On track'
                            ? const Color(0xFF22704F)
                            : const Color(0xFF2B2A86),
                      ),
                    ],
                  ),
                  _Metric('Attendance', attendance, _upcomingGreen),
                  _Metric(
                    'Homework done',
                    homework,
                    status == 'On track'
                        ? _upcomingGreen
                        : const Color(0xFF2B2A86),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.percent, this.color);

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: _style(context, 12, color: AppColors.mutedText),
          ),
        ),
        Expanded(
          flex: 5,
          child: LinearProgressIndicator(
            value: percent / 100,
            color: color,
            backgroundColor: const Color(0xFFE7F3EC),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$percent%',
            textAlign: TextAlign.end,
            style: _style(context, 12, weight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon, {required this.color, required this.foreground});

  final IconData icon;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: foreground, size: 18),
    );
  }
}

class _Syllabi extends StatefulWidget {
  const _Syllabi({this.reviewNavigation});

  final Widget? reviewNavigation;

  @override
  State<_Syllabi> createState() => _SyllabiState();
}

class _SyllabiState extends State<_Syllabi> {
  final _draft = SyllabusEditorViewModel();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _showCreateSyllabus(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SyllabusEditorView(
          draft: _draft,
          reviewNavigation: widget.reviewNavigation,
        ),
      ),
    );
  }

  void _showCourse(BuildContext context, SyllabusPreview course) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => TeacherCourseDetailView(
          course: course,
          navigation: widget.reviewNavigation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 14,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(
                context,
                'My syllabus',
                TextButton(
                  style: TextButton.styleFrom(
                    alignment: Alignment.topCenter,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierColor: const Color(0x87101010),
                    builder: (context) => TeacherSyllabusDialog(
                      syllabi: teacherSyllabusPreviews,
                      onCreateSyllabus: () => _showCreateSyllabus(context),
                      onOpenCourse: (course) => _showCourse(context, course),
                    ),
                  ),
                  child: const Text('See all', style: _actionLabelStyle),
                ),
                alignment: CrossAxisAlignment.start,
              ),
              _courseList(context),
            ],
          ),
          CustomPaint(
            foregroundPainter: const SyllabusDashedBorder(
              color: Color(0xFFC9D3CD),
              radius: 12,
            ),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _text,
                minimumSize: const Size(0, 48),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showCreateSyllabus(context),
              icon: const Icon(Icons.add),
              label: const Text('Create syllabus', style: _actionLabelStyle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _courseList(BuildContext context) {
    return Column(
      spacing: 24,
      children: [
        for (final syllabus in teacherSyllabusPreviews.take(3))
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showCourse(context, syllabus),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: syllabus.coverColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              syllabus.title,
                              style: _style(
                                context,
                                14,
                                weight: FontWeight.w700,
                              ),
                            ),
                            if (syllabus.isDraft)
                              const _Pill(
                                'Draft',
                                color: _lavender,
                                foreground: Color(0xFF2B2A86),
                              ),
                          ],
                        ),
                        Text(
                          syllabus.title == 'Math 101'
                              ? 'M.1 · ${syllabus.classCount} classes · ${syllabus.taughtPeriods} / ${syllabus.periods} periods'
                              : syllabus.homeSummary,
                          style: _style(
                            context,
                            12,
                            color: AppColors.mutedText,
                          ),
                        ),
                        LinearProgressIndicator(
                          value: syllabus.taughtPeriods / syllabus.periods,
                          color: _upcomingGreen,
                          backgroundColor: const Color(0xFFE7F3EC),
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
