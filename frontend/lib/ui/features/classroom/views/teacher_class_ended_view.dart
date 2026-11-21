import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/services/class_recording_service.dart';
import '../../../core/layout/app_page_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../models/teacher_class_preview.dart';
import '../widgets/local_class_clip_player.dart';

const _ink = Color(0xFF202438);
const _green = Color(0xFF1E6C50);
const _tint = Color(0xFFE3F1E9);
const _line = Color(0xFFE2E9E5);

class TeacherClassEndedView extends StatefulWidget {
  const TeacherClassEndedView({
    super.key,
    required this.clip,
    required this.onBack,
    this.notice,
  });

  final RecordingClip clip;
  final VoidCallback onBack;
  final String? notice;

  @override
  State<TeacherClassEndedView> createState() => _TeacherClassEndedViewState();
}

class _TeacherClassEndedViewState extends State<TeacherClassEndedView> {
  final _playerKey = GlobalKey();
  Duration? _duration;
  final Set<int> _selected = {0, 1, 2};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(letterSpacingFactor: 0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= 900 ? 48.0 : 16.0;
          final wide = constraints.maxWidth - inset * 2 >= 810;
          final player = _ReplayCard(child: _buildClip(context));
          final details = Column(
            spacing: 18,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReplayCard(
                child: _ReplayStatus(sizeBytes: widget.clip.sizeBytes),
              ),
              _ReplayCard(child: _buildSharingOptions(context)),
            ],
          );

          return AppPageLayout(
            header: _buildHeader(context, inset: inset, wide: wide),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.75, -0.64),
                  radius: 0.48,
                  colors: [Color(0xFFCCEFDA), AppColors.canvas],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, 24, inset, 32),
                child: wide
                    ? Row(
                        spacing: 22,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 61, child: player),
                          Expanded(flex: 39, child: details),
                        ],
                      )
                    : Column(
                        spacing: 18,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [player, details],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required double inset,
    required bool wide,
  }) {
    final title = Row(
      spacing: 6,
      children: [
        IconButton(
          tooltip: 'Back to Teacher Home',
          onPressed: widget.onBack,
          icon: const Icon(Icons.chevron_left, color: _ink),
        ),
        Expanded(
          child: Text(
            'Class ended · ${TeacherClassPreview.classroom}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: _ink),
          ),
        ),
      ],
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        _StatusPill(
          _duration == null
              ? 'Recorded'
              : 'Recorded ${formatClipTime(_duration!)}',
          background: _tint,
          color: _green,
          icon: Icons.check,
        ),
        Tooltip(
          message: 'Publishing will be available once the backend is connected',
          child: FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: const Color(0xFF273430),
              disabledForegroundColor: Colors.white70,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.send_outlined, size: 17),
            label: const Text('Publish Lesson & Assignment'),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inset,
            vertical: wide ? 10 : 4,
          ),
          child: wide
              ? Row(
                  spacing: 12,
                  children: [
                    Expanded(child: title),
                    actions,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, actions],
                ),
        ),
      ),
    );
  }

  Widget _buildClip(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final savedAt = widget.clip.savedAt;
    final details = [
      if (savedAt != null)
        DateFormat('EEE d MMM yyyy', 'en_US').format(savedAt),
      'P4',
      TeacherClassPreview.lessonTitle,
    ].join(' · ');
    return Column(
      spacing: 14,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  const _ReplayHeading('Class clip'),
                  Text(
                    details,
                    style: typography.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Clip editing is coming soon',
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.content_cut, size: 17),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
        if (widget.notice case final notice?)
          Text(
            notice,
            style: typography.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        LocalClassClipPlayer(
          key: _playerKey,
          path: widget.clip.path,
          onDuration: (duration) => setState(() => _duration = duration),
        ),
        const Divider(height: 1, color: _line),
        const _ReplayHeading('Transcript & chapters'),
        Text(
          'Timestamps will appear here after the clip is uploaded and processed.',
          style: typography.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
  }

  Widget _buildSharingOptions(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ReplayHeading('What to send students'),
            _StatusPill('M.1/1 · 32 students', icon: Icons.group_outlined),
          ],
        ),
        for (var index = 0; index < _sharingOptions.length; index++)
          CheckboxListTile(
            value: _selected.contains(index),
            onChanged: (checked) => setState(() {
              if (checked == true) {
                _selected.add(index);
              } else {
                _selected.remove(index);
              }
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            activeColor: _green,
            checkColor: Colors.white,
            title: Text(
              _sharingOptions[index].$1,
              style: typography.titleMedium?.copyWith(color: _ink),
            ),
            subtitle: _sharingOptions[index].$2.isEmpty
                ? null
                : Text(
                    _sharingOptions[index].$2,
                    style: typography.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F9ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              spacing: 12,
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.lime,
                  child: Icon(Icons.trending_up, color: _green, size: 18),
                ),
                Expanded(
                  child: Column(
                    spacing: 3,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teaching summary',
                        style: typography.titleMedium?.copyWith(color: _ink),
                      ),
                      Text(
                        'Available after replay processing.',
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
      ],
    );
  }
}

const _sharingOptions = [
  ('Clip with transcript and chapters', 'Students can jump to a timestamp.'),
  ('Homework HW 3.2 · 8 questions', 'Attach the assignment for this period.'),
  ('Let students ask AI Tutor about the clip', ''),
  ('Also share the clip with parents', ''),
];

class _ReplayStatus extends StatelessWidget {
  const _ReplayStatus({required this.sizeBytes});

  final int sizeBytes;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final size = sizeBytes >= 1024 * 1024
        ? '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(sizeBytes / 1024).ceil()} KB';
    final steps = [
      ('Upload clip', 'Saved on this device · $size'),
      ('Transcribe audio', 'Waiting for upload'),
      ('Create chapters', 'Waiting for transcript'),
      ('Link exercises to timestamps', 'Waiting for transcript'),
      ('Auto-edit clip', 'Coming soon'),
    ];
    return Column(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ReplayHeading('Preparing the replay'),
        for (var index = 0; index < steps.length; index++)
          Row(
            spacing: 12,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: index == 0 ? _tint : AppColors.canvas,
                child: Icon(
                  index == 0 ? Icons.cloud_upload_outlined : Icons.schedule,
                  size: 15,
                  color: index == 0 ? _green : AppColors.mutedText,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      steps[index].$1,
                      style: typography.titleMedium?.copyWith(color: _ink),
                    ),
                    Text(
                      steps[index].$2,
                      style: typography.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ReplayHeading extends StatelessWidget {
  const _ReplayHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontSize: 18, color: _ink),
  );
}

class _ReplayCard extends StatelessWidget {
  const _ReplayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(
    this.label, {
    this.background = AppColors.canvas,
    this.color = AppColors.mutedText,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: background,
      shape: const StadiumBorder(),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(icon, color: color, size: 14),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}
