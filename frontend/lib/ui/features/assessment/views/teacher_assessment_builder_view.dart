import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/assessment_draft.dart';
import '../../../core/layout/app_page_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/assessment_draft_controller.dart';
import '../widgets/assessment_question_editor.dart';
import '../widgets/assessment_settings_panel.dart';
import '../widgets/assessment_student_preview.dart';

const _ink = Color(0xFF202438);
const _green = Color(0xFF1E6C50);
const _tint = Color(0xFFE3F1E9);
const _line = Color(0xFFE6ECE8);
const _panelGap = 22.0;
const _settingsFlex = 31;
const _questionsFlex = 69;

enum _QuestionAction { edit, duplicate, moveUp, moveDown, remove }

class TeacherAssessmentBuilderView extends StatefulWidget {
  const TeacherAssessmentBuilderView({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onNext,
  });

  final AssessmentDraftController controller;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<TeacherAssessmentBuilderView> createState() =>
      _TeacherAssessmentBuilderViewState();
}

class _TeacherAssessmentBuilderViewState
    extends State<TeacherAssessmentBuilderView> {
  AssessmentDraft get _draft => widget.controller.draft;

  Future<void> _editQuestion([int? index]) async {
    final edited = await showAssessmentQuestionEditor(
      context,
      initial: index == null ? null : _draft.questions[index],
    );
    if (edited == null || !mounted) return;
    final questions = [..._draft.questions];
    if (index == null) {
      questions.add(edited);
    } else {
      final original = questions[index];
      if (original.sameContentAs(edited)) return;
      questions[index] = edited;
    }
    widget.controller.update(_draft.copyWith(questions: questions));
  }

  Future<void> _questionAction(int index, _QuestionAction action) async {
    final questions = [..._draft.questions];
    switch (action) {
      case _QuestionAction.edit:
        return _editQuestion(index);
      case _QuestionAction.duplicate:
        final original = questions[index];
        questions.insert(
          index + 1,
          original.withRubric(original.rubric?.copyWith(approved: false)),
        );
      case _QuestionAction.moveUp:
        questions.insert(index - 1, questions.removeAt(index));
      case _QuestionAction.moveDown:
        questions.insert(index + 1, questions.removeAt(index));
      case _QuestionAction.remove:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete question ${index + 1}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete question'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
        questions.removeAt(index);
    }
    widget.controller.update(_draft.copyWith(questions: questions));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final assessmentText = text.copyWith(
      titleMedium: text.titleMedium?.copyWith(fontSize: 14, height: 20 / 14),
      bodyMedium: text.bodyMedium?.copyWith(height: 23 / 15),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, height: 1.5),
      labelLarge: text.labelLarge?.copyWith(fontSize: 14, height: 20 / 14),
      labelSmall: text.labelSmall?.copyWith(fontSize: 12, height: 17 / 12),
    );
    return Theme(
      data: theme.copyWith(
        textTheme: assessmentText.apply(
          bodyColor: _ink,
          displayColor: _ink,
          letterSpacingFactor: 0,
        ),
      ),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final inset = switch (constraints.maxWidth) {
              >= 1130 => 48.0,
              >= 900 => 42.0,
              _ => 16.0,
            };
            final width = constraints.maxWidth - 2 * inset;
            final wide = width >= 830;
            final fullSize = width >= 1080 && constraints.maxHeight >= 840;
            final headerHeight = fullSize ? 142.0 : 100.0;
            final headerInline =
                wide && MediaQuery.textScalerOf(context).scale(15) <= 18;
            final top = fullSize ? 32.0 : 24.0;
            final bottom = fullSize ? 36.0 : 24.0;
            return AppPageLayout(
              header: _header(
                context,
                inset: inset,
                inline: headerInline,
                minHeight: headerHeight,
                fullSize: fullSize,
              ),
              body: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.79, -0.5),
                    radius: 0.49,
                    colors: [
                      Color(0xFFD0F0DC),
                      Color(0xFFEAF7EE),
                      AppColors.canvas,
                    ],
                    stops: [0, 0.58, 1],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(inset, top, inset, bottom),
                  child: _body(
                    context,
                    width: width,
                    wide: wide,
                    minHeight: headerInline
                        ? (constraints.maxHeight - headerHeight - top - bottom)
                              .clamp(0.0, double.infinity)
                        : 0,
                    panelPadding: fullSize ? 22 : 18,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required double inset,
    required bool inline,
    required double minHeight,
    required bool fullSize,
  }) {
    final typography = Theme.of(context).textTheme;
    final kind = _draft.kind == AssessmentKind.quiz ? 'Quiz U3' : 'Homework';
    final state = widget.controller.state;
    final saveStatus = switch (state) {
      DraftSaveState.loading => 'Loading draft…',
      DraftSaveState.newDraft => 'Draft',
      DraftSaveState.saving => 'Saving draft…',
      DraftSaveState.saved => 'Draft · auto-saved',
      DraftSaveState.loadFailed => 'Draft unavailable',
      DraftSaveState.saveFailed => 'Draft not saved',
    };
    final title = Row(
      spacing: 8,
      children: [
        IconButton(
          tooltip: 'Back to Teacher Home',
          onPressed: widget.onBack,
          icon: const Icon(Icons.chevron_left, color: _ink),
        ),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Assessment',
                    style: typography.titleLarge?.copyWith(
                      fontSize: fullSize ? 30 : 26,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    '$kind · Exponents',
                    style: typography.titleMedium?.copyWith(
                      color: AppColors.mutedText,
                      fontSize: fullSize ? 17 : 15,
                    ),
                  ),
                ],
              ),
              _Label(
                saveStatus,
                fontSize: 13,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              if (state == DraftSaveState.saveFailed)
                TextButton(
                  onPressed: () => widget.controller.update(_draft),
                  child: const Text('Retry save'),
                ),
            ],
          ),
        ),
      ],
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final buttonText = typography.labelLarge?.copyWith(
      fontSize: fullSize ? 15 : 14,
    );
    final actions = Wrap(
      spacing: fullSize ? 14 : 10,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _draft.questions.isEmpty
              ? null
              : () => showAssessmentStudentPreview(context, _draft),
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: _line),
            minimumSize: Size(fullSize ? 196 : 0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: controlShape,
            textStyle: buttonText,
          ),
          icon: const Icon(Icons.visibility_outlined, size: 19),
          label: const Text('Preview as student'),
        ),
        FilledButton.icon(
          onPressed: _draft.questions.isEmpty ? null : widget.onNext,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0B0F0C),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF273430),
            disabledForegroundColor: const Color(0xFFD7DED9),
            minimumSize: Size(fullSize ? 215 : 0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: controlShape,
            textStyle: buttonText,
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('Next: Scoring rubric'),
        ),
      ],
    );
    return ColoredBox(
      color: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset, vertical: 8),
          child: inline
              ? Row(
                  spacing: 12,
                  children: [
                    Expanded(child: title),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [title, actions],
                ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context, {
    required double width,
    required bool wide,
    required double minHeight,
    required double panelPadding,
  }) {
    final state = widget.controller.state;
    if (state == DraftSaveState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state == DraftSaveState.loadFailed) {
      return _AssessmentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not load the assessment draft.'),
            TextButton(
              onPressed: widget.controller.load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final count = _draft.questions.length;
    final points = _draft.totalPoints;
    final totals =
        '$count ${count == 1 ? 'question' : 'questions'} · $points ${points == 1 ? 'pt' : 'pts'}';
    final settings = _AssessmentCard(
      padding: panelPadding,
      child: AssessmentSettingsPanel(
        draft: _draft,
        totals: totals,
        onChanged: widget.controller.update,
      ),
    );
    final questionWidth = wide
        ? (width - _panelGap) *
              _questionsFlex /
              (_settingsFlex + _questionsFlex)
        : width;
    final questions = _AssessmentCard(
      padding: panelPadding,
      child: _questions(
        context,
        totals,
        horizontal: questionWidth - 2 * panelPadding >= 510,
      ),
    );
    return wide
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: IntrinsicHeight(
              child: Row(
                spacing: _panelGap,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: _settingsFlex, child: settings),
                  Expanded(flex: _questionsFlex, child: questions),
                ],
              ),
            ),
          )
        : Column(
            spacing: 16,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [questions, settings],
          );
  }

  Widget _questions(
    BuildContext context,
    String totals, {
    required bool horizontal,
  }) {
    final typography = Theme.of(context).textTheme;
    final actions = [
      _QuestionSource(
        title: 'Write in app',
        description: 'Short answer, choice, show work',
        icon: Icons.edit_outlined,
        onTap: _editQuestion,
      ),
      const _QuestionSource(
        title: 'Snap a photo',
        description: 'Photo import coming soon',
        icon: Icons.camera_alt_outlined,
      ),
      const _QuestionSource(
        title: 'Generate with AI',
        description: 'AI generation coming soon',
        icon: Icons.auto_awesome_outlined,
        highlighted: true,
      ),
    ];
    return Column(
      spacing: 14,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Questions',
                  style: typography.titleMedium?.copyWith(
                    fontSize: 20,
                    height: 1.3,
                  ),
                ),
                _Label(totals, background: _tint, foreground: _green),
              ],
            ),
            Text(
              'Unit 3 · 3.1–3.2',
              style: typography.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
        if (horizontal)
          IntrinsicHeight(
            child: Row(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final action in actions) Expanded(child: action)],
            ),
          )
        else
          Column(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        if (_draft.questions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'No questions yet. Use Write in app to add your first question.',
              style: typography.bodyMedium?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ),
        for (var index = 0; index < _draft.questions.length; index++)
          _QuestionCard(
            question: _draft.questions[index],
            index: index,
            isLast: index == _draft.questions.length - 1,
            horizontalOptions: horizontal,
            onAction: (action) => _questionAction(index, action),
          ),
      ],
    );
  }
}

class _QuestionSource extends StatelessWidget {
  const _QuestionSource({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return CustomPaint(
      foregroundPainter: highlighted ? null : const _SourceOutline(),
      child: Material(
        color: highlighted ? const Color(0xFFF4FBEF) : Colors.white,
        shape: RoundedRectangleBorder(
          side: highlighted
              ? const BorderSide(color: AppColors.mint)
              : BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                spacing: 10,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: highlighted
                        ? AppColors.lime
                        : AppColors.canvas,
                    child: Icon(
                      icon,
                      size: 17,
                      color: highlighted ? _green : _ink,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: typography.titleMedium),
                        Text(
                          description,
                          style: typography.bodySmall?.copyWith(
                            fontSize: 11,
                            height: 15 / 11,
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
        ),
      ),
    );
  }
}

class _SourceOutline extends CustomPainter {
  const _SourceOutline();

  @override
  void paint(Canvas canvas, Size size) {
    final border = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      const Radius.circular(14),
    );
    final outline = (Path()..addRRect(border)).computeMetrics().single;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = _line;
    for (var offset = 0.0; offset < outline.length; offset += 10) {
      canvas.drawPath(outline.extractPath(offset, offset + 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SourceOutline oldDelegate) => false;
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.isLast,
    required this.horizontalOptions,
    required this.onAction,
  });

  final AssessmentQuestion question;
  final int index;
  final bool isLast;
  final bool horizontalOptions;
  final ValueChanged<_QuestionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 14),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Q${index + 1}',
                        style: typography.labelLarge?.copyWith(color: _green),
                      ),
                      _Label(question.kind.label),
                    ],
                  ),
                ),
                Text('${question.points} pt', style: typography.labelSmall),
                SizedBox(
                  width: 40,
                  height: 32,
                  child: PopupMenuButton<_QuestionAction>(
                    padding: EdgeInsets.zero,
                    iconSize: 19,
                    tooltip: 'Question ${index + 1} actions',
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.mutedText,
                    ),
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _QuestionAction.edit,
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: _QuestionAction.duplicate,
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(
                        value: _QuestionAction.moveUp,
                        enabled: index > 0,
                        child: const Text('Move up'),
                      ),
                      PopupMenuItem(
                        value: _QuestionAction.moveDown,
                        enabled: !isLast,
                        child: const Text('Move down'),
                      ),
                      const PopupMenuItem(
                        value: _QuestionAction.remove,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(question.prompt, style: typography.bodyMedium),
            if (question.options.isNotEmpty)
              _ChoiceOptions(
                options: question.options,
                horizontal: horizontalOptions,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceOptions extends StatelessWidget {
  const _ChoiceOptions({required this.options, required this.horizontal});

  final List<String> options;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tiles = [
      for (var index = 0; index < options.length; index++)
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: text.labelSmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
                Flexible(child: Text(options[index], style: text.bodyMedium)),
              ],
            ),
          ),
        ),
    ];
    return horizontal
        ? IntrinsicHeight(
            child: Row(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final tile in tiles) Expanded(child: tile)],
            ),
          )
        : Wrap(spacing: 8, runSpacing: 6, children: tiles);
  }
}

class _Label extends StatelessWidget {
  const _Label(
    this.text, {
    this.background = AppColors.canvas,
    this.foreground = AppColors.mutedText,
    this.fontSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final String text;
  final Color background;
  final Color foreground;
  final double? fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: background,
      shape: const StadiumBorder(),
    ),
    child: Padding(
      padding: padding,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontSize: fontSize),
      ),
    ),
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.child, this.padding = 20});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}
