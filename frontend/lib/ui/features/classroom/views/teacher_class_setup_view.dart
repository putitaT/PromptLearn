import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/services/class_recording_service.dart';
import '../../../core/layout/app_page_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../models/teacher_class_preview.dart';
import 'teacher_class_ended_view.dart';
import 'teacher_teaching_view.dart';

const _text = Color(0xFF202438);
const _green = Color(0xFF1E6C50);
const _greenTint = Color(0xFFE3F1E9);
const _lightGreen = Color(0xFFF2F9ED);
const _line = Color(0xFFE2E9E5);
const _black = Color(0xFF0B100D);
const _cardPadding = 24.0;
const _cardGap = 22.0;
const _controlsFlex = 57;
const _planFlex = 43;

extension on RecordingSource {
  String get title => switch (this) {
    RecordingSource.slides => 'Slides in PromptLearn',
    RecordingSource.screen => 'Whole screen',
  };

  String get description => switch (this) {
    RecordingSource.slides => TeacherClassPreview.slides,
    RecordingSource.screen => 'Keep recording as you switch apps',
  };

  String get icon => switch (this) {
    RecordingSource.slides => 'slides',
    RecordingSource.screen => 'screen',
  };
}

enum _ClassOption {
  recording(
    'Record this class',
    'Save the screen and microphone audio as a clip on this device',
    'rec',
  ),
  checkIn(
    'Location check-in',
    'Students can check in within 50 m of Room 204 · closes 15 min after start',
    'pin',
  ),
  live(
    'Live stream',
    'For students on leave or learning remotely · 2 on leave today',
    'live',
  ),
  participation(
    'Track participation',
    'Counts questions and answers to summarize for you after class',
    'chart',
  );

  const _ClassOption(this.title, this.description, this.icon);

  final String title;
  final String description;
  final String icon;
}

class TeacherClassSetupView extends StatefulWidget {
  const TeacherClassSetupView({
    super.key,
    required this.onBack,
    required this.recordingService,
    required this.onNavigationLockChanged,
  });

  final VoidCallback onBack;
  final ClassRecordingService recordingService;
  final ValueChanged<bool> onNavigationLockChanged;

  @override
  State<TeacherClassSetupView> createState() => _TeacherClassSetupViewState();
}

class _TeacherClassSetupViewState extends State<TeacherClassSetupView> {
  var _source = RecordingSource.slides;
  final _options = {
    _ClassOption.recording,
    _ClassOption.checkIn,
    _ClassOption.participation,
  };
  StreamSubscription<RecordingStatus>? _recordingSubscription;
  RecordingStatus _recording = const RecordingStatus();
  RecordingClip? _lastClip;
  RecordingClip? _reviewClip;
  String? _reviewNotice;
  bool _teaching = false;
  bool _starting = false;
  bool _ending = false;
  bool _confirmingEnd = false;

  @override
  void initState() {
    super.initState();
    _recordingSubscription = widget.recordingService.updates.listen(
      _onRecordingStatus,
      onError: (Object _) {
        if (mounted && _starting) {
          _finishWithError('Screen recording is unavailable. Try again.');
        }
      },
    );
    if (widget.recordingService.isSupported) unawaited(_loadLastClip());
  }

  Future<void> _loadLastClip() async {
    try {
      final clips = await widget.recordingService.savedClips();
      if (!mounted || clips.isEmpty || _lastClip != null) return;
      setState(() => _lastClip = clips.first);
    } on PlatformException {
      // A failed lookup does not block teaching or reviewing a new recording.
    } on MissingPluginException {
      // No local clips are available without the native recorder.
    }
  }

  @override
  void dispose() {
    _recordingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startClass() async {
    if (_starting || _teaching) return;
    if (!_options.contains(_ClassOption.recording)) {
      widget.onNavigationLockChanged(true);
      setState(() => _teaching = true);
      return;
    }
    if (!widget.recordingService.isSupported) {
      _message(
        'Screen recording is available on Android. Turn recording off to teach here.',
      );
      return;
    }

    widget.onNavigationLockChanged(true);
    setState(() => _starting = true);
    try {
      await widget.recordingService.start(_source);
    } on PlatformException catch (error) {
      if (mounted && _starting) {
        _finishWithError(error.message ?? 'Screen recording could not start.');
      }
    } on MissingPluginException {
      if (mounted && _starting) {
        _finishWithError('Screen recording is unavailable.');
      }
    }
  }

  void _onRecordingStatus(RecordingStatus status) {
    if (!mounted) return;
    if (status.inProgress) {
      widget.onNavigationLockChanged(true);
      setState(() {
        _recording = status;
        _source = status.source ?? _source;
        _starting = status.phase == RecordingPhase.starting;
        _teaching = !_starting;
      });
      return;
    }
    if (!_starting && !_recording.inProgress) return;

    if (status.clip case final clip?) {
      final notice =
          status.message ??
          (status.interrupted
              ? 'Android stopped screen sharing. The clip so far was kept.'
              : null);
      _openReview(clip, notice: notice);
    } else if (status.phase == RecordingPhase.failed) {
      _finishWithError(status.message ?? 'No recording was saved.');
    }
  }

  void _openReview(RecordingClip clip, {String? notice}) {
    widget.onNavigationLockChanged(false);
    setState(() {
      _recording = const RecordingStatus();
      _starting = false;
      _teaching = false;
      _ending = false;
      _lastClip = clip;
      _reviewClip = clip;
      _reviewNotice = notice;
    });
  }

  Future<void> _endClass() async {
    if (_ending) return;
    if (!_recording.inProgress) {
      _leaveClass();
      return;
    }

    setState(() => _ending = true);
    try {
      await widget.recordingService.stop();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _ending = false);
      _message(error.message ?? 'Could not stop recording. Try again.');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _ending = false);
      _message('Could not reach the recording service.');
    }
  }

  Future<void> _confirmEndClass() async {
    if (_ending || _confirmingEnd) return;
    _confirmingEnd = true;
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this class?'),
        content: Text(
          _recording.inProgress
              ? 'The recording will stop and the clip will be saved on this device.'
              : 'You will return to Teacher Home.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep teaching'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End class'),
          ),
        ],
      ),
    );
    _confirmingEnd = false;
    if (mounted && end == true && _reviewClip == null) await _endClass();
  }

  void _leaveClass() {
    widget.onNavigationLockChanged(false);
    widget.onBack();
  }

  void _finishWithError(String message) {
    widget.onNavigationLockChanged(false);
    setState(() {
      _recording = const RecordingStatus();
      _starting = false;
      _teaching = false;
      _ending = false;
    });
    _message(message);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLessonPlan() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(TeacherClassPreview.lessonTitle),
      content: const SizedBox(
        width: 440,
        child: SingleChildScrollView(child: _PeriodPlan()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _showDeviceTest() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Test mic & screen'),
      content: Text(
        'Selected source: ${_source.title}. Android asks for access to the '
        'microphone and screen when recording starts. Choose Whole screen to '
        'include other apps. For single-app sharing, select PromptLearn if offered.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void _setOption(_ClassOption option, bool enabled) {
    setState(() {
      if (enabled) {
        _options.add(option);
      } else {
        _options.remove(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_reviewClip case final clip?) {
      return TeacherClassEndedView(
        key: ValueKey(clip.path),
        clip: clip,
        notice: _reviewNotice,
        onBack: widget.onBack,
      );
    }

    if (_teaching) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_confirmEndClass());
        },
        child: TeacherTeachingView(
          source: _source,
          recording: _recording,
          ending: _ending,
          checkIn: _options.contains(_ClassOption.checkIn),
          liveRequested: _options.contains(_ClassOption.live),
          participation: _options.contains(_ClassOption.participation),
          onBack: _confirmEndClass,
          onEnd: _endClass,
        ),
      );
    }

    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(letterSpacingFactor: 0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= 900 ? 48.0 : 16.0;
          final typography = Theme.of(context).textTheme;
          return AppPageLayout(
            header: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: SizedBox(
                  height: 100,
                  child: Row(
                    spacing: 12,
                    children: [
                      IconButton(
                        tooltip: 'Back to Teacher Home',
                        onPressed: _starting ? null : widget.onBack,
                        icon: const Icon(Icons.chevron_left, color: _black),
                      ),
                      Expanded(
                        child: Text(
                          TeacherClassPreview.period,
                          style: typography.titleLarge?.copyWith(color: _text),
                        ),
                      ),
                      if (_lastClip case final clip?)
                        TextButton.icon(
                          onPressed: _starting ? null : () => _openReview(clip),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('Last recording'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.75, -0.64),
                  radius: 0.38,
                  colors: [Color(0xFFCCEFDA), AppColors.canvas],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, 32, inset, 36),
                child: LayoutBuilder(
                  builder: (context, bodyConstraints) {
                    final width = bodyConstraints.maxWidth;
                    final alongside = width >= 840;
                    final controlsWidth = alongside
                        ? (width - _cardGap) *
                              _controlsFlex /
                              (_controlsFlex + _planFlex)
                        : width;
                    final controls = _ClassCard(
                      child: _buildControls(
                        context,
                        controlsWidth - 2 * _cardPadding,
                      ),
                    );
                    const plan = _ClassCard(child: _PeriodPlan());
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: _cardGap,
                      children: [
                        _ClassCard(
                          child: _LessonOverview(onOpenPlan: _showLessonPlan),
                        ),
                        if (alongside)
                          IntrinsicHeight(
                            child: Row(
                              spacing: _cardGap,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: _controlsFlex, child: controls),
                                const Expanded(flex: _planFlex, child: plan),
                              ],
                            ),
                          )
                        else ...[
                          controls,
                          plan,
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls(BuildContext context, double width) {
    final textTheme = Theme.of(context).textTheme;
    final startLabel = _starting
        ? 'Starting recording…'
        : _options.contains(_ClassOption.recording)
        ? 'Start teaching & recording'
        : 'Start teaching';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionTitle('Before you start'),
        const SizedBox(height: 20),
        Text(
          'What should PromptLearn record?',
          style: textTheme.labelLarge?.copyWith(color: _text),
        ),
        const SizedBox(height: 12),
        _AdaptivePair(
          horizontal: width >= 435,
          first: _SourceTile(
            source: RecordingSource.slides,
            selected: _source == RecordingSource.slides,
            onTap: () => setState(() => _source = RecordingSource.slides),
          ),
          second: _SourceTile(
            source: RecordingSource.screen,
            selected: _source == RecordingSource.screen,
            onTap: () => setState(() => _source = RecordingSource.screen),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: _line),
        const SizedBox(height: 12),
        for (final option in _ClassOption.values)
          _OptionRow(
            option: option,
            enabled: _options.contains(option),
            onChanged: (enabled) => _setOption(option, enabled),
          ),
        const SizedBox(height: 34),
        _AdaptivePair(
          horizontal: width >= 505,
          gap: 24,
          first: FilledButton.icon(
            onPressed: _starting ? null : _startClass,
            style: _buttonStyle(background: _black, foreground: Colors.white),
            icon: const _ClassIcon('start', color: Colors.white),
            label: Text(startLabel),
          ),
          second: FilledButton.icon(
            onPressed: _starting ? null : _showDeviceTest,
            style: _buttonStyle(background: _line, foreground: _text),
            icon: const _ClassIcon('mic', color: _text),
            label: const Text('Test mic & screen'),
          ),
        ),
      ],
    );
  }
}

ButtonStyle _buttonStyle({
  required Color background,
  required Color foreground,
}) => FilledButton.styleFrom(
  backgroundColor: background,
  foregroundColor: foreground,
  minimumSize: const Size(0, 56),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.all(_cardPadding), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontSize: 20, color: _text),
  );
}

class _ClassIcon extends StatelessWidget {
  const _ClassIcon(this.name, {required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/classroom/$name.svg',
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

class _LessonOverview extends StatelessWidget {
  const _LessonOverview({required this.onOpenPlan});

  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Pill(
                  TeacherClassPreview.date,
                  background: AppColors.lime,
                  color: _text,
                ),
                _Pill(TeacherClassPreview.schedule),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              TeacherClassPreview.lessonTitle,
              style: theme.titleLarge?.copyWith(color: _text),
            ),
            const SizedBox(height: 22),
            Text(
              TeacherClassPreview.details,
              style: theme.bodyMedium?.copyWith(color: AppColors.mutedText),
            ),
          ],
        );
        final button = OutlinedButton.icon(
          onPressed: onOpenPlan,
          icon: const _ClassIcon('doc', color: _text),
          label: const Text('Open lesson plan'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _text,
            side: const BorderSide(color: _line),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (constraints.maxWidth >= 690) {
          return Row(
            spacing: 24,
            children: [
              Expanded(child: summary),
              button,
            ],
          );
        }
        return Column(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [summary, button],
        );
      },
    );
  }
}

class _AdaptivePair extends StatelessWidget {
  const _AdaptivePair({
    required this.horizontal,
    required this.first,
    required this.second,
    this.gap = 10,
  });

  final bool horizontal;
  final double gap;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return Row(
        spacing: gap,
        children: [
          Expanded(child: first),
          Expanded(child: second),
        ],
      );
    }
    return Column(
      spacing: gap,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [first, second],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final RecordingSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? AppColors.primary : _line,
        width: selected ? 2 : 1,
      ),
    );
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? _lightGreen : Colors.white,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ClassIcon(
                      source.icon,
                      color: selected ? _green : AppColors.mutedText,
                    ),
                    if (selected)
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.check_circle,
                          color: _green,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                Text(
                  source.title,
                  style: typography.titleMedium?.copyWith(color: _text),
                ),
                Text(
                  source.description,
                  style: typography.bodySmall?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.enabled,
    required this.onChanged,
  });

  final _ClassOption option;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          spacing: 14,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? _greenTint : AppColors.canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _ClassIcon(
                option.icon,
                color: enabled ? _green : AppColors.mutedText,
              ),
            ),
            Expanded(
              child: Column(
                spacing: 3,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: typography.titleMedium?.copyWith(color: _text),
                  ),
                  Text(
                    option.description,
                    style: typography.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.875,
              alignment: AlignmentDirectional.centerEnd,
              transformHitTests: false,
              child: Switch(
                value: enabled,
                onChanged: onChanged,
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                activeTrackColor: _green,
                inactiveTrackColor: const Color(0xFFD1DAD5),
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
    this.label, {
    this.background = AppColors.canvas,
    this.color = AppColors.mutedText,
    this.icon,
  });

  final String label;
  final Color background;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (icon case final symbol?) Icon(symbol, size: 13, color: color),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodPlan extends StatelessWidget {
  const _PeriodPlan();

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    const steps = TeacherClassPreview.steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SectionTitle('This period’s plan'),
            _Pill(
              'IBL · 50 min',
              background: _greenTint,
              color: _green,
              icon: Icons.auto_awesome,
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < steps.length; index++)
          _TimelineStep(
            step: steps[index],
            index: index,
            last: index == steps.length - 1,
          ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _lightGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 14,
              children: [
                const _ClassIcon('doc', color: _green),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        'Homework to assign at the end',
                        style: typography.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                      Text(
                        TeacherClassPreview.homework,
                        style: typography.labelLarge?.copyWith(color: _text),
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

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.step,
    required this.index,
    required this.last,
  });

  final LessonStep step;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final first = index == 0;
    return IntrinsicHeight(
      child: Row(
        spacing: 14,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Stack(
              children: [
                Positioned(
                  top: first ? 12 : 0,
                  bottom: last ? null : 0,
                  height: last ? 12 : null,
                  left: 11,
                  width: 2,
                  child: const ColoredBox(color: _line),
                ),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: first ? _green : _greenTint,
                  child: Text(
                    '${index + 1}',
                    style: typography.labelSmall?.copyWith(
                      color: first ? Colors.white : _green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        step.title,
                        style: typography.titleMedium?.copyWith(color: _text),
                      ),
                      Text(
                        '${step.startMinute}–${step.endMinute} min',
                        style: typography.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    step.instructions,
                    style: typography.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
