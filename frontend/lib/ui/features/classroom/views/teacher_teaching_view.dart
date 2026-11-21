import 'dart:async';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/services/class_recording_service.dart';
import '../../../core/layout/app_page_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../models/teacher_class_preview.dart';

const _ink = Color(0xFF202438);
const _green = Color(0xFF1E6C50);
const _tint = Color(0xFFE3F1E9);
const _line = Color(0xFFE2E9E5);
const _danger = Color(0xFFC42C1A);
const _dangerTint = Color(0xFFFCE6E3);
const _lightGreen = Color(0xFFF2F9ED);

class TeacherTeachingView extends StatefulWidget {
  const TeacherTeachingView({
    super.key,
    required this.source,
    required this.recording,
    required this.ending,
    required this.checkIn,
    required this.liveRequested,
    required this.participation,
    required this.onBack,
    required this.onEnd,
  });

  final RecordingSource source;
  final RecordingStatus recording;
  final bool ending;
  final bool checkIn;
  final bool liveRequested;
  final bool participation;
  final VoidCallback onBack;
  final VoidCallback onEnd;

  @override
  State<TeacherTeachingView> createState() => _TeacherTeachingViewState();
}

class _TeacherTeachingViewState extends State<TeacherTeachingView> {
  int _slide = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saving =
        widget.ending || widget.recording.phase == RecordingPhase.saving;
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(letterSpacingFactor: 0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= 900 ? 48.0 : 16.0;
          final compact = constraints.maxWidth - inset * 2 < 780;
          final status = switch (widget.recording.phase) {
            RecordingPhase.recording => _RecordingClock(
              elapsed: widget.recording.elapsed,
            ),
            RecordingPhase.saving => const _Badge(
              'Saving recording…',
              background: _dangerTint,
              color: _danger,
            ),
            _ => const _Badge('Recording off'),
          };
          final stop = FilledButton.icon(
            onPressed: saving ? null : widget.onEnd,
            style: FilledButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Stop & end class'),
          );
          final title = Row(
            spacing: 6,
            children: [
              IconButton(
                tooltip: 'Back from teaching',
                onPressed: saving ? null : widget.onBack,
                icon: const Icon(Icons.chevron_left, color: _ink),
              ),
              Expanded(
                child: Text(
                  'Teaching · ${TeacherClassPreview.classroom}',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: _ink),
                ),
              ),
            ],
          );
          final presentation = _Presentation(
            source: widget.source,
            phase: widget.recording.phase,
            liveRequested: widget.liveRequested,
            slide: _slide,
            onPrevious: _slide == 0 ? null : () => setState(() => _slide--),
            onNext: _slide == _slides.length - 1
                ? null
                : () => setState(() => _slide++),
          );
          final sidebar = Column(
            spacing: 18,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CheckIn(enabled: widget.checkIn),
              _StudentQuestions(enabled: widget.participation),
            ],
          );
          return AppPageLayout(
            header: ColoredBox(
              color: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 100),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: inset,
                    vertical: compact ? 4 : 12,
                  ),
                  child: compact
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            title,
                            Wrap(
                              spacing: 8,
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [status, stop],
                            ),
                          ],
                        )
                      : Row(
                          spacing: 10,
                          children: [
                            Expanded(child: title),
                            status,
                            stop,
                          ],
                        ),
                ),
              ),
            ),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.75, -0.64),
                  radius: 0.5,
                  colors: [Color(0xFFCCEFDA), AppColors.canvas],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, 24, inset, 32),
                child: compact
                    ? Column(
                        spacing: 20,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [presentation, sidebar],
                      )
                    : Row(
                        spacing: 22,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 64, child: presentation),
                          Expanded(flex: 36, child: sidebar),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecordingClock extends StatefulWidget {
  const _RecordingClock({required this.elapsed});

  final Duration elapsed;

  @override
  State<_RecordingClock> createState() => _RecordingClockState();
}

class _RecordingClockState extends State<_RecordingClock> {
  final _clock = Stopwatch()..start();
  late final Timer _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void didUpdateWidget(covariant _RecordingClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.elapsed != widget.elapsed) _clock.reset();
  }

  @override
  void dispose() {
    _refresh.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.elapsed + _clock.elapsed;
    String pad(int value) => value.toString().padLeft(2, '0');
    final label =
        '${pad(elapsed.inHours)}:${pad(elapsed.inMinutes % 60)}:${pad(elapsed.inSeconds % 60)}';
    return _Badge('● REC  $label', background: _dangerTint, color: _danger);
  }
}

class _Presentation extends StatelessWidget {
  const _Presentation({
    required this.source,
    required this.phase,
    required this.liveRequested,
    required this.slide,
    required this.onPrevious,
    required this.onNext,
  });

  final RecordingSource source;
  final RecordingPhase phase;
  final bool liveRequested;
  final int slide;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final item = _slides[slide];
    final typography = Theme.of(context).textTheme;
    final description = phase == RecordingPhase.recording
        ? switch (source) {
            RecordingSource.slides => 'Recording: Slides in PromptLearn',
            RecordingSource.screen => 'Recording: Whole screen',
          }
        : 'Slides in PromptLearn';
    return _TeachingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$description · slide ${slide + 1} / ${_slides.length}',
                style: typography.titleMedium?.copyWith(color: _ink),
              ),
              _Badge(
                liveRequested ? 'Live stream unavailable' : 'Live stream: off',
              ),
            ],
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 280),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                Text(
                  item.title,
                  style: typography.titleLarge?.copyWith(color: _ink),
                ),
                _Badge(
                  item.formula,
                  background: AppColors.lime,
                  color: _ink,
                  large: true,
                ),
                Text(
                  item.example,
                  style: typography.titleMedium?.copyWith(color: _ink),
                ),
                Text(
                  item.takeaway,
                  style: typography.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Row(
            spacing: 6,
            children: [
              Expanded(
                child: Text('Slide note', style: typography.titleMedium),
              ),
              IconButton.outlined(
                tooltip: 'Previous slide',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton.outlined(
                tooltip: 'Next slide',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            item.note,
            style: typography.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _CheckIn extends StatelessWidget {
  const _CheckIn({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return _TeachingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const _PanelHeading(
            'Check-in',
            asset: 'pin',
            trailing: _Badge('Sample'),
          ),
          if (enabled) ...[
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '29',
                  style: typography.titleLarge?.copyWith(
                    fontSize: 32,
                    color: _ink,
                  ),
                ),
                Text(
                  '/ 32 students',
                  style: typography.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
            LinearProgressIndicator(
              value: 29 / 32,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: _tint,
              borderRadius: BorderRadius.circular(4),
            ),
            const Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Badge('Present 29', background: _tint, color: _green),
                _Badge('On leave 2'),
                _Badge(
                  'Not checked in 1',
                  background: Color(0xFFFFE3D6),
                  color: Color(0xFF8C3814),
                ),
              ],
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  spacing: 10,
                  children: [
                    const CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.mint,
                      child: Text('P'),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phum Jaidee',
                            style: typography.titleMedium?.copyWith(
                              color: _ink,
                            ),
                          ),
                          Text(
                            'Out of range · 120 m',
                            style: typography.bodySmall?.copyWith(
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const Text('Location check-in is off.'),
        ],
      ),
    );
  }
}

class _StudentQuestions extends StatelessWidget {
  const _StudentQuestions({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return _TeachingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          _PanelHeading(
            'Student questions',
            icon: Icons.pan_tool_outlined,
            trailing: enabled
                ? const _Badge(
                    '3 examples',
                    background: AppColors.lime,
                    color: _ink,
                  )
                : null,
          ),
          if (enabled)
            for (final (name, time, question, grouped) in _questions)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: grouped ? _lightGreen : Colors.white,
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  spacing: 6,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: typography.labelLarge?.copyWith(color: _ink),
                        ),
                        Text(
                          time,
                          style: typography.bodySmall?.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                        if (grouped)
                          const _Badge(
                            'Asked by 4',
                            background: AppColors.lime,
                            color: _ink,
                          ),
                      ],
                    ),
                    Text(
                      question,
                      style: typography.bodyMedium?.copyWith(color: _ink),
                    ),
                  ],
                ),
              )
          else
            const Text('Participation tracking is off.'),
        ],
      ),
    );
  }
}

class _TeachingCard extends StatelessWidget {
  const _TeachingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading(this.label, {this.icon, this.asset, this.trailing});

  final String label;
  final IconData? icon;
  final String? asset;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (asset case final name?)
            SvgPicture.asset(
              'assets/classroom/$name.svg',
              colorFilter: const ColorFilter.mode(_green, BlendMode.srcIn),
              excludeFromSemantics: true,
            )
          else
            Icon(icon, color: _green, size: 18),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 18, color: _ink),
            ),
          ),
        ],
      ),
      ?trailing,
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge(
    this.text, {
    this.background = AppColors.canvas,
    this.color = AppColors.mutedText,
    this.large = false,
  });

  final String text;
  final Color background;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 16 : 10,
          vertical: large ? 10 : 5,
        ),
        child: Text(
          text,
          style: (large ? typography.titleLarge : typography.labelSmall)
              ?.copyWith(color: color),
        ),
      ),
    );
  }
}

const _questions = [
  ('Fah', '18:02', 'Why isn’t 2³ × 2² equal to 4⁵?', true),
  ('Non', '21:30', 'Does this rule work if the bases are different?', false),
  ('Baitoey', '22:58', 'What happens if the exponent is 0?', false),
];

typedef _Slide = ({
  String title,
  String formula,
  String example,
  String takeaway,
  String note,
});

const _slides = <_Slide>[
  (
    title: 'Warm-up · What is a power?',
    formula: '2³',
    example: '2 × 2 × 2 = 8',
    takeaway: 'The exponent counts the factors.',
    note: 'Ask each group to name the base and exponent.',
  ),
  (
    title: 'Read the notation',
    formula: 'aⁿ',
    example: 'In 3⁴, 3 is the base and 4 is the exponent.',
    takeaway: 'Say the base first.',
    note: 'Invite one student to read the expression aloud.',
  ),
  (
    title: 'Expand the first factor',
    formula: '2³ = 2·2·2',
    example: 'Write three copies of 2.',
    takeaway: 'Keep the base unchanged.',
    note: 'Have students write the expansion independently.',
  ),
  (
    title: 'Expand the second factor',
    formula: '2² = 2·2',
    example: 'Write two more copies of 2.',
    takeaway: 'Both powers have the same base.',
    note: 'Ask students to compare the two products.',
  ),
  (
    title: 'Look for a pattern',
    formula: '2³ × 2²',
    example: '(2·2·2) × (2·2)',
    takeaway: 'Count all the factors of 2.',
    note: 'Let groups explain the pattern before stating the rule.',
  ),
  (
    title: 'The rule · Multiplying powers with the same base',
    formula: 'aᵐ × aⁿ = aᵐ⁺ⁿ',
    example: '2³ × 2² = (2·2·2) × (2·2) = 2⁵ = 32',
    takeaway: 'Same base → add the exponents.',
    note: 'Group 3 found this pattern themselves.',
  ),
  (
    title: 'Example · Base 3',
    formula: '3² × 3⁴ = 3⁶',
    example: '2 + 4 = 6',
    takeaway: 'The base stays 3.',
    note: 'Have a volunteer explain why the base does not change.',
  ),
  (
    title: 'Example · A variable base',
    formula: 'x⁴ × x³ = x⁷',
    example: '4 + 3 = 7',
    takeaway: 'The same rule works for a variable base.',
    note: 'Ask students to write a second example with x.',
  ),
  (
    title: 'What if the bases differ?',
    formula: '2³ × 3²',
    example: '8 × 9 = 72',
    takeaway: 'The same-base rule does not apply here.',
    note: 'Compare this expression with 2³ × 2².',
  ),
  (
    title: 'Try it · Base 5',
    formula: '5² × 5³',
    example: 'Write the result as one power.',
    takeaway: 'Show how you combined the exponents.',
    note: 'Give one minute for individual work.',
  ),
  (
    title: 'Try it · Three factors',
    formula: 'y² × y × y³',
    example: 'Remember that y = y¹.',
    takeaway: 'Add all three exponents.',
    note: 'Have students compare solutions with a partner.',
  ),
  (
    title: 'Check a common mistake',
    formula: '2³ × 2² = 2⁵',
    example: 'We add 3 and 2, not multiply them.',
    takeaway: 'Use an expansion to verify the rule.',
    note: 'Ask students to point out the mistaken step in 2⁶.',
  ),
  (
    title: 'Exit ticket',
    formula: 'm⁴ × m²',
    example: 'Simplify and explain in one sentence.',
    takeaway: 'State the condition on the bases.',
    note: 'Collect two responses before ending class.',
  ),
  (
    title: 'Homework · HW 3.2',
    formula: 'Same base → add exponents',
    example: 'Complete eight practice questions.',
    takeaway: 'Show your work for each question.',
    note: 'Remind students that HW 3.2 is due Friday.',
  ),
];
