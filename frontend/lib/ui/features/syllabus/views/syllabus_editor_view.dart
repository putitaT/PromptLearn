import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models/syllabus_sources.dart';
import '../view_models/syllabus_editor_view_model.dart';
import '../widgets/syllabus_assessment_fields.dart';
import '../widgets/syllabus_course_fields.dart';
import '../widgets/syllabus_review_fields.dart';
import '../widgets/syllabus_schedule_fields.dart';
import '../widgets/syllabus_standards_fields.dart';
import '../widgets/syllabus_timetable_fields.dart';
import '../widgets/syllabus_unit_fields.dart';

const _ink = Color(0xFF202438);
const _line = Color(0xFFE6ECE8);
const _white = Color(0xFFFFFFFF);
const _green = Color(0xFF017932);
const _border = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(10)),
  borderSide: BorderSide(color: _line),
);

class SyllabusEditorView extends StatefulWidget {
  const SyllabusEditorView({
    super.key,
    required this.draft,
    this.reviewNavigation,
  });

  final SyllabusEditorViewModel draft;
  final Widget? reviewNavigation;

  @override
  State<SyllabusEditorView> createState() => _SyllabusEditorViewState();
}

class _SyllabusEditorViewState extends State<SyllabusEditorView> {
  final _form = GlobalKey<FormState>();

  int _step = 0;

  void _changeStep(int step) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _step = step);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      _changeStep(_step - 1);
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _continue() {
    final draft = widget.draft;
    if (_step == 0) {
      final validFields = _form.currentState!.validate();
      final error = validFields
          ? draft.timetableError
          : 'Check the highlighted course fields.';
      if (error == null) {
        _changeStep(1);
        return;
      }
      _showMessage(error);
      return;
    }
    if (_step == 1) {
      if (!draft.hasStandards) {
        _showMessage('Select or add at least one indicator.');
        return;
      }
      draft.prepareUnits();
      _changeStep(2);
      return;
    }
    if (_step == 2) {
      final error = draft.unitsError;
      if (error == null) {
        _changeStep(3);
      } else {
        _showMessage(error);
      }
      return;
    }
    if (_step == 3) {
      final error = draft.assessmentError;
      if (error == null) {
        draft.prepareSchedule();
        _changeStep(4);
      } else {
        _showMessage(error);
      }
      return;
    }
    if (_step == 4) {
      final error = draft.scheduleError;
      if (error == null) {
        _changeStep(5);
      } else {
        _showMessage(error);
      }
    }
  }

  void _saveDraft() {
    _showMessage('Draft kept for this session.');
    Navigator.of(context).pop();
  }

  void _publish() {
    _showMessage(
      'Publishing this draft is unavailable until the backend supports its schedule and review settings.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<void>(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step != 0) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1410),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 1000 && constraints.maxHeight >= 560;
              final inset = wide ? 48.0 : 16.0;
              final navigation = wide && _step == 5
                  ? widget.reviewNavigation
                  : null;
              final panel = Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  navigation != null
                      ? 0
                      : wide
                      ? 22
                      : 8,
                  wide ? 22 : 8,
                  wide ? 22 : 8,
                  wide ? 22 : 8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(wide ? 44 : 22),
                  child: ColoredBox(
                    color: const Color(0xFFF8F8F8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _EditorHeader(
                          wide: wide,
                          inset: inset,
                          onBack: _goHome,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              const Positioned(
                                top: -72,
                                left: -120,
                                width: 620,
                                height: 420,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        Color(0xD99BECB4),
                                        Color(0x59C9F5D5),
                                        Color(0x00FFFFFF),
                                      ],
                                      stops: [0, 0.55, 1],
                                    ),
                                  ),
                                ),
                              ),
                              SingleChildScrollView(
                                key: ValueKey(_step),
                                padding: EdgeInsets.fromLTRB(
                                  inset,
                                  wide ? 32 : 18,
                                  inset,
                                  28,
                                ),
                                child: Theme(
                                  data: theme.copyWith(
                                    inputDecorationTheme:
                                        const InputDecorationThemeData(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 13,
                                          ),
                                          border: _border,
                                          enabledBorder: _border,
                                        ),
                                  ),
                                  child: Form(
                                    key: _form,
                                    child: ListenableBuilder(
                                      listenable: widget.draft,
                                      builder: (context, _) => switch (_step) {
                                        0 => _BasicsSection(
                                          draft: widget.draft,
                                        ),
                                        1 => _StandardsSection(
                                          draft: widget.draft,
                                        ),
                                        2 => _UnitsSection(draft: widget.draft),
                                        3 => _AssessmentSection(
                                          draft: widget.draft,
                                        ),
                                        4 => _ScheduleSection(
                                          draft: widget.draft,
                                        ),
                                        _ => _ReviewSection(
                                          draft: widget.draft,
                                        ),
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_step == 5)
                          _ReviewFooter(
                            draft: widget.draft,
                            inset: inset,
                            onBack: _back,
                            onSave: _saveDraft,
                            onPublish: _publish,
                          )
                        else
                          _EditorFooter(
                            inset: inset,
                            wide: wide,
                            onContinue: _continue,
                            backLabel: _step == 0 ? 'Cancel' : 'Back',
                            onBack: _back,
                          ),
                      ],
                    ),
                  ),
                ),
              );
              if (navigation == null) return panel;
              return Row(
                children: [
                  SizedBox(width: 112, child: navigation),
                  Expanded(child: panel),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.wide,
    required this.inset,
    required this.onBack,
  });

  final bool wide;
  final double inset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      constraints: BoxConstraints(minHeight: wide ? 142 : 78),
      padding: EdgeInsets.symmetric(horizontal: wide ? inset : 8, vertical: 10),
      child: Row(
        spacing: 12,
        children: [
          IconButton(
            tooltip: 'Back to teacher home',
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new, size: wide ? 27 : 20),
          ),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Create Syllabus',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _heading(context, wide ? 32 : 23),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3EA),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Text(
                      'Draft syllabus',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: const Color(0xFF963F14)),
                    ),
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

class _BasicsSection extends StatelessWidget {
  const _BasicsSection({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 22,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              'New course: basics & timetable',
              style: _heading(context, 24),
            ),
            const Text(
              'Tell us what you teach and when. Your weekly slots decide how many periods the syllabus can use.',
              style: TextStyle(fontSize: 15, color: AppColors.mutedText),
            ),
          ],
        ),
        const _CourseSetupSteps(step: 0),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _SectionCard(child: SyllabusCourseFields(draft: draft)),
                _SectionCard(child: SyllabusTimetableFields(draft: draft)),
              ],
            );
            final summary = _SectionCard(child: _TeachingTime(draft: draft));
            if (constraints.maxWidth >= 930) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Expanded(flex: 2, child: fields),
                  Expanded(child: summary),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [fields, summary],
            );
          },
        ),
      ],
    );
  }
}

class _StandardsSection extends StatelessWidget {
  const _StandardsSection({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 22,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text('Standards & sources', style: _heading(context, 24)),
            const Text(
              'Pick the end-of-grade indicators this course must cover, and the textbook you teach from. They become the backbone of every unit.',
              style: TextStyle(fontSize: 15, color: AppColors.mutedText),
            ),
          ],
        ),
        const _CourseSetupSteps(step: 1),
        LayoutBuilder(
          builder: (context, constraints) {
            final standards = _SectionCard(
              child: SyllabusStandardsFields(draft: draft),
            );
            final sources = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                if (draft.standardsSource == StandardsSource.obec &&
                    draft.textbook != null &&
                    draft.selectedIndicators.any(
                      (indicator) => indicator.chapters.isNotEmpty,
                    ))
                  SyllabusMatchSummary(draft: draft),
                _SectionCard(child: SyllabusTextbookFields(draft: draft)),
              ],
            );
            if (constraints.maxWidth >= 930) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Expanded(flex: 2, child: standards),
                  Expanded(child: sources),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [standards, sources],
            );
          },
        ),
      ],
    );
  }
}

class _UnitsSection extends StatelessWidget {
  const _UnitsSection({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 22,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text('Units & periods', style: _heading(context, 24)),
            const Text(
              'Order your units and decide how many periods each one gets. Open a unit to split it into lessons for the teaching schedule.',
              style: TextStyle(fontSize: 15, color: AppColors.mutedText),
            ),
          ],
        ),
        const _CourseSetupSteps(step: 2),
        LayoutBuilder(
          builder: (context, constraints) {
            final units = SyllabusUnitFields(draft: draft);
            final budget = _SectionCard(
              child: SyllabusPeriodBudget(draft: draft),
            );
            if (constraints.maxWidth >= 930) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Expanded(flex: 2, child: units),
                  Expanded(child: budget),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [units, budget],
            );
          },
        ),
      ],
    );
  }
}

class _AssessmentSection extends StatelessWidget {
  const _AssessmentSection({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 22,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text('Assessment', style: _heading(context, 24)),
          const Text(
            'Set how the 100 points in this course are earned. Set quiz dates in Schedule. Students will see this breakdown on their syllabus.',
            style: TextStyle(fontSize: 15, color: AppColors.mutedText),
          ),
        ],
      ),
      const _CourseSetupSteps(step: 3),
      _SectionCard(child: SyllabusAssessmentFields(draft: draft)),
    ],
  );
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 22,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text('Teaching schedule', style: _heading(context, 24)),
          const Text(
            'Lessons are placed on teaching dates. Press and hold a period card, then drop it onto another slot to move it and shift the periods between them.',
            style: TextStyle(fontSize: 15, color: AppColors.mutedText),
          ),
        ],
      ),
      const _CourseSetupSteps(step: 4),
      SyllabusScheduleFields(draft: draft),
    ],
  );
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 22,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text('Review & publish', style: _heading(context, 24)),
            const Text(
              'Review the syllabus and schedule your classes will see before publishing.',
              style: TextStyle(fontSize: 15, color: AppColors.mutedText),
            ),
          ],
        ),
        const _CourseSetupSteps(step: 5),
        SyllabusReviewTotals(draft: draft),
        LayoutBuilder(
          builder: (context, constraints) {
            final plans = _SectionCard(
              child: SyllabusLearningPlanOptions(draft: draft),
            );
            final preview = _SectionCard(
              child: SyllabusStudentPreviewOptions(draft: draft),
            );
            if (constraints.maxWidth >= 930) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Expanded(
                    flex: 2,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 409),
                      child: plans,
                    ),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 409),
                      child: preview,
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [plans, preview],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewFooter extends StatelessWidget {
  const _ReviewFooter({
    required this.draft,
    required this.inset,
    required this.onBack,
    required this.onSave,
    required this.onPublish,
  });

  final SyllabusEditorViewModel draft;
  final double inset;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final classes = draft.classes;
    final recipients = classes.length == 1
        ? classes.first.name
        : classes.length <= 3
        ? '${classes.first.name}–${classes.last.name}'
        : '${classes.length} classes';
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: _ink,
              side: const BorderSide(color: _line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Back'),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: _ink,
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onSave,
                child: const Text('Save as draft'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B0F0C),
                  foregroundColor: _white,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: onPublish,
                icon: const Icon(Icons.check, size: 18),
                label: Text('Publish to $recipients'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseSetupSteps extends StatelessWidget {
  const _CourseSetupSteps({required this.step});

  final int step;

  static const _labels = [
    'Basics & timetable',
    'Standards & sources',
    'Units & periods',
    'Assessment',
    'Schedule',
    'Review & publish',
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final steps = [
              for (final (index, label) in _labels.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (index.compareTo(step)) {
                            < 0 => const Color(0xFF22704F),
                            0 => const Color(0xFF4ABE7A),
                            _ => _white,
                          },
                          border: index <= step
                              ? null
                              : Border.all(color: const Color(0xFFC9D3CC)),
                        ),
                        child: index < step
                            ? const Icon(Icons.check, size: 14, color: _white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: index == step
                                      ? _white
                                      : AppColors.mutedText,
                                ),
                              ),
                      ),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            color: index <= step ? _ink : AppColors.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ];
            return Semantics(
              label: 'Course setup steps. Step ${step + 1} of 6.',
              child: wide
                  ? Row(
                      spacing: 12,
                      children: [
                        for (final step in steps) Expanded(child: step),
                      ],
                    )
                  : Wrap(spacing: 18, children: steps),
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
}

class _TeachingTime extends StatelessWidget {
  const _TeachingTime({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    final time = draft.teachingTime;
    final dates = DateFormat('EEE d MMM', 'en_US');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text('Teaching time available', style: _heading(context, 17)),
        _SummaryRow(label: 'Teaching weeks', value: '${time.weeks}'),
        _SummaryRow(
          label: 'Periods per week (per class)',
          value: time.periodsPerWeek,
        ),
        _SummaryRow(
          label: 'Holidays & school events on your slots',
          value: time.excluded == 0 ? '0' : '−${time.excluded}',
        ),
        const Divider(height: 1, color: _line),
        _SummaryRow(
          label: 'Teaching periods',
          value: '${time.available}',
          highlight: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                const Text(
                  'FROM SCHOOL CALENDAR · SAMPLE',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                ),
                for (final event in draft.schoolEvents)
                  Text(
                    '${dates.format(event.date)} · ${event.name}',
                    style: const TextStyle(fontSize: 13, color: _ink),
                  ),
                if (draft.schoolEvents.isEmpty)
                  const Text(
                    'No sample events in this date range.',
                    style: TextStyle(fontSize: 13, color: AppColors.mutedText),
                  ),
                const Text(
                  'Midterm and final exams run in school exam weeks, outside these periods.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.mutedText),
          ),
        ),
        Text(
          value,
          key: highlight ? const ValueKey('available-teaching-periods') : null,
          style: highlight
              ? _heading(context, 30).copyWith(color: _green)
              : const TextStyle(fontSize: 14, color: _ink),
        ),
      ],
    );
  }
}

class _EditorFooter extends StatelessWidget {
  const _EditorFooter({
    required this.inset,
    required this.wide,
    required this.onContinue,
    required this.backLabel,
    required this.onBack,
  });

  final double inset;
  final bool wide;
  final VoidCallback onContinue;
  final String backLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: inset,
          vertical: wide ? 16 : 8,
        ),
        child: Row(
          spacing: 12,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _line),
                foregroundColor: _ink,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onBack,
              child: Text(backLabel),
            ),
            const Expanded(
              child: Text(
                'Draft saved for this session',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 13, color: AppColors.mutedText),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B0F0C),
                foregroundColor: _white,
                minimumSize: const Size(0, 48),
                padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 12),
              ),
              onPressed: onContinue,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 16),
              label: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _heading(BuildContext context, double size) {
  return Theme.of(context).textTheme.titleLarge!
      .copyWith(color: _ink, fontSize: size, height: 1.22);
}
