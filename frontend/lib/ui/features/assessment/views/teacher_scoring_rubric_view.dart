import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/assessment_draft.dart';
import '../../../../domain/models/assessment_rubric.dart';
import '../../../../domain/repositories/assessment_rubric_generator.dart';
import '../../../core/layout/app_page_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/assessment_rubric_controller.dart';
import '../widgets/assessment_question_editor.dart';
import '../widgets/rubric_score_table.dart';

const _ink = Color(0xFF202438);
const _green = Color(0xFF1E6C50);
const _tint = Color(0xFFE3F1E9);
const _pale = Color(0xFFF2F9ED);
const _line = Color(0xFFE2E9E5);
const _yellow = Color(0xFFFFF2CF);
const _yellowInk = Color(0xFF715011);
const _red = Color(0xFF9A3D1E);
const _redTint = Color(0xFFFFE3D6);

class TeacherScoringRubricView extends StatefulWidget {
  const TeacherScoringRubricView({
    super.key,
    required this.controller,
    required this.onBack,
  });

  final AssessmentRubricController controller;
  final VoidCallback onBack;

  @override
  State<TeacherScoringRubricView> createState() =>
      _TeacherScoringRubricViewState();
}

class _TeacherScoringRubricViewState extends State<TeacherScoringRubricView> {
  final _request = TextEditingController();
  late final _changes = Listenable.merge([
    widget.controller,
    widget.controller.draft,
  ]);
  int _selected = 0;
  int _editorVersion = 0;
  int _requestVersion = 0;
  bool _revising = false;
  String? _sentRequest;
  String? _revisionError;
  QuestionRubric? _proposal;

  AssessmentDraft get _draft => widget.controller.draft.draft;

  @override
  void dispose() {
    _request.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_selected == index) return;
    setState(() {
      _selected = index;
      _resetRevision();
    });
  }

  void _resetRevision() {
    _requestVersion++;
    _revising = false;
    _request.clear();
    _sentRequest = null;
    _revisionError = null;
    _proposal = null;
  }

  void _edit(QuestionRubric Function(QuestionRubric) edit) {
    widget.controller.update(
      _selected,
      (current) => edit(current).copyWith(approved: false),
    );
  }

  void _manual(AssessmentQuestion question) {
    final half = rubricScore(question.points / 2);
    _edit(
      (_) => QuestionRubric(
        criteria: question.kind == AssessmentQuestionKind.showWork
            ? [
                RubricCriterion(name: 'Method', fullScore: half),
                RubricCriterion(name: 'Answer', fullScore: half),
              ]
            : const [],
      ),
    );
  }

  Future<void> _askAI(AssessmentQuestion question, String instruction) async {
    final request = instruction.trim();
    if (request.isEmpty || _revising) return;
    final version = ++_requestVersion;
    setState(() {
      _revising = true;
      _sentRequest = request;
      _revisionError = null;
      _proposal = null;
      _request.clear();
    });
    try {
      final result = await widget.controller.revise(question, request);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _proposal = result;
        _revising = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _revisionError = error is RubricGenerationFailure
            ? error.message
            : 'Could not draft a revision. Try again.';
        _revising = false;
      });
    }
  }

  void _applyProposal() {
    final proposal = _proposal;
    if (proposal == null) return;
    _edit((_) => proposal);
    setState(() {
      _proposal = null;
      _sentRequest = null;
      _editorVersion++;
    });
  }

  Future<void> _removeQuestion(AssessmentQuestion question) async {
    final index = _selected;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove question ${index + 1}?'),
        content: const Text(
          'This removes the question and its rubric from the assessment draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove question'),
          ),
        ],
      ),
    );

    if (!mounted ||
        remove != true ||
        index >= _draft.questions.length ||
        !_draft.questions[index].sameContentAs(question)) {
      return;
    }
    widget.controller.remove(index);
    setState(() {
      _selected = _draft.questions.isEmpty
          ? 0
          : index.clamp(0, _draft.questions.length - 1);
      _editorVersion++;
      _resetRevision();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
          letterSpacingFactor: 0,
        ),
      ),
      child: ListenableBuilder(
        listenable: _changes,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final inset = switch (constraints.maxWidth) {
              >= 1130 => 48.0,
              >= 900 => 42.0,
              _ => 16.0,
            };
            final width = constraints.maxWidth - inset * 2;
            final full = width >= 1080 && constraints.maxHeight >= 840;
            final headerHeight = full ? 142.0 : 100.0;
            final vertical = full ? 32.0 : 24.0;
            final wide =
                width >= 875 &&
                MediaQuery.textScalerOf(context).scale(14) <= 17;
            return AppPageLayout(
              header: _header(context, inset, wide, headerHeight, full),
              body: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.76, -0.57),
                    radius: 0.65,
                    colors: [Color(0xFFD1F1DE), AppColors.canvas],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    vertical,
                    inset,
                    vertical + 4,
                  ),
                  child: _body(
                    context,
                    wide: wide,
                    minHeight: wide
                        ? (constraints.maxHeight -
                                  headerHeight -
                                  vertical * 2 -
                                  4)
                              .clamp(0.0, double.infinity)
                        : 0,
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
    BuildContext context,
    double inset,
    bool wide,
    double height,
    bool full,
  ) {
    final text = Theme.of(context).textTheme;
    final kind = _draft.kind == AssessmentKind.quiz ? 'Quiz U3' : 'Homework';
    final title = Row(
      spacing: 8,
      children: [
        IconButton(
          onPressed: widget.onBack,
          tooltip: 'Back from scoring rubric',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            'Scoring rubric · $kind',
            style: text.titleLarge?.copyWith(
              fontSize: full ? 30 : 26,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onBack,
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: _line),
            minimumSize: const Size(0, 48),
            shape: shape,
          ),
          icon: const Icon(Icons.chevron_left, size: 19),
          label: const Text('Back to questions'),
        ),
        Tooltip(
          message: 'Publishing will be available when class assignments are connected',
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.send_outlined, size: 17),
            label: const Text('Publish to 3 classes'),
            style: FilledButton.styleFrom(
              disabledForegroundColor: const Color(0xFFD7DED9),
              disabledBackgroundColor: const Color(0xFF0B0F0C),
              minimumSize: const Size(0, 48),
              shape: shape,
            ),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset, vertical: 8),
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

  Widget _body(
    BuildContext context, {
    required bool wide,
    required double minHeight,
  }) {
    final questions = _draft.questions;
    if (questions.isEmpty) {
      return const _RubricSurface(
        child: Text('No questions left. Go back to add a question.'),
      );
    }
    final question = questions[_selected];
    final rubric = question.rubric;
    final sidebar = _RubricSurface(
      minHeight: minHeight,
      padding: wide ? 14 : 16,
      child: _questionList(context, questions, wide),
    );
    final main = _RubricSurface(
      minHeight: minHeight,
      child: KeyedSubtree(
        key: ValueKey((_selected, _editorVersion)),
        child: _question(context, question, rubric),
      ),
    );
    final ai = _RubricSurface(
      minHeight: minHeight,
      background: _pale,
      border: AppColors.mint,
      child: _assistant(context, question, rubric),
    );
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 20,
            children: [
              Expanded(flex: 20, child: sidebar),
              Expanded(flex: 50, child: main),
              Expanded(flex: 30, child: ai),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [sidebar, main, ai],
          );
  }

  Widget _questionList(
    BuildContext context,
    List<AssessmentQuestion> questions,
    bool wide,
  ) {
    final text = Theme.of(context).textTheme;
    final count = questions.length;
    final tiles = [
      for (var index = 0; index < count; index++)
        _QuestionNavigationTile(
          index: index,
          question: questions[index],
          selected: index == _selected,
          pending: widget.controller.isDrafting(questions[index]),
          onTap: () => _select(index),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            '$count ${count == 1 ? 'question' : 'questions'} · ${_draft.totalPoints} pts',
            style: text.labelLarge?.copyWith(color: AppColors.mutedText),
          ),
        ),
        if (wide)
          ...tiles
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                for (final tile in tiles) SizedBox(width: 162, child: tile),
              ],
            ),
          ),
      ],
    );
  }

  Widget _question(
    BuildContext context,
    AssessmentQuestion question,
    QuestionRubric? rubric,
  ) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Q${_selected + 1}',
              style: text.labelLarge?.copyWith(color: _green),
            ),
            _RubricPill(question.kind.label),
            _RubricPill(
              '${question.points} pt',
              foreground: _green,
              background: _tint,
            ),
            if (rubric?.approved ?? false)
              const _RubricPill(
                'Approved',
                foreground: _green,
                background: _tint,
              ),
          ],
        ),
        Text(
          question.prompt,
          style: text.titleMedium?.copyWith(fontSize: 20, height: 1.35),
        ),
        if (rubric == null)
          _NoRubric(
            pending: widget.controller.isDrafting(question),
            error: widget.controller.errorFor(question),
            canUseAI: widget.controller.canUseAI,
            onRetry: () => widget.controller.request(question),
            onManual: () => _manual(question),
          )
        else ...[
          if (rubric.flagged)
            _OutOfScopeNotice(
              reason: rubric.alignmentReason,
              onRemove: () => _removeQuestion(question),
              onKeep: () =>
                  _edit((current) => current.copyWith(keptByTeacher: true)),
            )
          else if (rubric.alignment == RubricAlignment.unclear)
            Text(
              rubric.alignmentReason,
              style: text.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
          _AnswerEditor(question: question, rubric: rubric, onEdit: _edit),
          if (question.kind == AssessmentQuestionKind.showWork) ...[
            if (rubric.criteria.isEmpty)
              OutlinedButton(
                onPressed: () {
                  final half = rubricScore(question.points / 2);
                  _edit(
                    (current) => current.copyWith(
                      criteria: [
                        RubricCriterion(name: 'Method', fullScore: half),
                        RubricCriterion(name: 'Answer', fullScore: half),
                      ],
                    ),
                  );
                },
                child: const Text('Add scoring criteria'),
              )
            else
              RubricScoreTable(
                rubric: rubric,
                points: question.points,
                onChanged: (index, edit) {
                  _edit((current) {
                    final rows = [...current.criteria];
                    rows[index] = edit(rows[index]);
                    return current.copyWith(criteria: rows);
                  });
                },
              ),
          ],
          if (rubric.mistakes.isNotEmpty)
            _LikelyMistakes(mistakes: rubric.mistakes),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: rubric.approved || !_canApprove(question, rubric)
                  ? null
                  : () => widget.controller.update(
                      _selected,
                      (current) => current.copyWith(approved: true),
                    ),
              icon: const Icon(Icons.check, size: 17),
              label: Text(
                rubric.approved ? 'Answer approved' : 'Approve answer',
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _canApprove(AssessmentQuestion question, QuestionRubric rubric) {
    if (rubric.flagged) return false;
    return switch (question.kind) {
      AssessmentQuestionKind.multipleChoice ||
      AssessmentQuestionKind.trueFalse => rubric.correctOption != null,
      AssessmentQuestionKind.shortAnswer => rubric.answer.trim().isNotEmpty,
      AssessmentQuestionKind.showWork =>
        rubric.answer.trim().isNotEmpty &&
            rubric.matchesQuestionPoints(question.points),
    };
  }

  Widget _assistant(
    BuildContext context,
    AssessmentQuestion question,
    QuestionRubric? rubric,
  ) {
    final text = Theme.of(context).textTheme;
    final canAsk = rubric != null && widget.controller.canUseAI && !_revising;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 8,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.lime,
                  radius: 15,
                  child: Icon(Icons.auto_awesome, size: 17, color: _green),
                ),
                Expanded(
                  child: Text(
                    'Design with AI',
                    style: text.titleMedium?.copyWith(fontSize: 18),
                  ),
                ),
              ],
            ),
            if (rubric != null && rubric.note.isNotEmpty)
              _MessageBubble(rubric.note)
            else
              Text(
                widget.controller.canUseAI
                    ? 'AI suggestions will appear here.'
                    : 'Set up the backend to draft and refine answers with AI.',
                style: text.bodySmall?.copyWith(color: AppColors.mutedText),
              ),
            if (_sentRequest case final message?)
              _MessageBubble(message, fromTeacher: true),
            if (_revising) const LinearProgressIndicator(),
            if (_revisionError case final message?)
              Text(
                message,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (_proposal case final proposal?) ...[
              _MessageBubble(
                proposal.note.isEmpty
                    ? 'A revised answer is ready to review.'
                    : proposal.note,
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _applyProposal,
                    child: const Text('Apply AI revision'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _proposal = null),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            if (question.kind == AssessmentQuestionKind.showWork &&
                widget.controller.canUseAI)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: canAsk
                      ? () => _askAI(question, 'Make partial credit stricter.')
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.mint),
                  ),
                  child: Text(
                    'Make partial credit stricter',
                    style: text.labelMedium,
                  ),
                ),
              ),
            TextField(
              controller: _request,
              enabled: canAsk,
              textInputAction: TextInputAction.send,
              onSubmitted: (request) => _askAI(question, request),
              decoration: InputDecoration(
                hintText: 'Ask AI to edit rubric',
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: _line),
                ),
                suffixIcon: IconButton(
                  tooltip: 'Ask AI',
                  onPressed: canAsk
                      ? () => _askAI(question, _request.text)
                      : null,
                  icon: const Icon(
                    Icons.send_outlined,
                    size: 19,
                    color: _green,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnswerEditor extends StatelessWidget {
  const _AnswerEditor({
    required this.question,
    required this.rubric,
    required this.onEdit,
  });

  final AssessmentQuestion question;
  final QuestionRubric rubric;
  final void Function(QuestionRubric Function(QuestionRubric)) onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final options = switch (question.kind) {
      AssessmentQuestionKind.multipleChoice => question.options,
      AssessmentQuestionKind.trueFalse => const ['True', 'False'],
      _ => const <String>[],
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              options.isEmpty ? 'Model answer' : 'Choose the correct answer',
              style: text.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
            if (options.isEmpty)
              TextFormField(
                initialValue: rubric.answer,
                maxLines: null,
                style: text.titleMedium,
                decoration: const InputDecoration(
                  hintText: 'Enter model answer',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _green),
                  ),
                ),
                onChanged: (value) =>
                    onEdit((current) => current.copyWith(answer: value)),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var index = 0; index < options.length; index++)
                    ChoiceChip(
                      label: Text(options[index]),
                      selected: rubric.correctOption == index,
                      selectedColor: _tint,
                      onSelected: (_) => onEdit(
                        (current) => current.copyWith(
                          correctOption: index,
                          answer: current.correctOption == index
                              ? current.answer
                              : options[index],
                        ),
                      ),
                    ),
                ],
              ),
              if (rubric.answer.trim().isNotEmpty)
                Text(
                  rubric.answer,
                  style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoRubric extends StatelessWidget {
  const _NoRubric({
    required this.pending,
    required this.error,
    required this.canUseAI,
    required this.onRetry,
    required this.onManual,
  });

  final bool pending;
  final String? error;
  final bool canUseAI;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          LinearProgressIndicator(),
          Text('AI is drafting an answer…'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(error ?? 'No answer has been drafted yet.'),
        Wrap(
          spacing: 8,
          children: [
            if (canUseAI)
              OutlinedButton(
                onPressed: onRetry,
                child: Text(error == null ? 'Draft with AI' : 'Retry AI'),
              ),
            FilledButton(
              onPressed: onManual,
              child: const Text('Enter answer manually'),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutOfScopeNotice extends StatelessWidget {
  const _OutOfScopeNotice({
    required this.reason,
    required this.onRemove,
    required this.onKeep,
  });

  final String reason;
  final VoidCallback onRemove;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _yellow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          spacing: 6,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Outside this lesson',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: _yellowInk),
            ),
            Text(reason, style: const TextStyle(color: _yellowInk)),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onRemove,
                  child: const Text('Remove question'),
                ),
                TextButton(
                  onPressed: onKeep,
                  child: const Text('Keep question'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LikelyMistakes extends StatelessWidget {
  const _LikelyMistakes({required this.mistakes});

  final List<RubricMistake> mistakes;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Row(
        spacing: 8,
        children: [
          const Icon(Icons.outlined_flag, color: _red, size: 18),
          Expanded(
            child: Text(
              'Likely mistakes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final mistake in mistakes)
            _RubricPill(
              '${mistake.example} · ${mistake.reason}',
              foreground: _red,
              background: _redTint,
            ),
        ],
      ),
    ],
  );
}

class _QuestionNavigationTile extends StatelessWidget {
  const _QuestionNavigationTile({
    required this.index,
    required this.question,
    required this.selected,
    required this.pending,
    required this.onTap,
  });

  final int index;
  final AssessmentQuestion question;
  final bool selected;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rubric = question.rubric;
    final flagged = rubric?.flagged ?? false;
    final status = switch ((flagged, pending, rubric)) {
      (true, _, _) => 'Outside this lesson',
      (_, true, _) => 'Drafting…',
      (_, _, QuestionRubric(approved: true)) => 'Approved',
      (_, _, QuestionRubric()) => 'Needs review',
      _ => 'No answer yet',
    };
    final text = Theme.of(context).textTheme;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected
            ? (flagged ? const Color(0xFFC98C1A) : AppColors.primary)
            : Colors.transparent,
        width: selected ? 1.5 : 1,
      ),
    );
    return Semantics(
      label: 'Select question ${index + 1}',
      selected: selected,
      button: true,
      child: Material(
        shape: border,
        color: flagged ? _yellow : (selected ? _pale : Colors.white),
        child: InkWell(
          customBorder: border,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              spacing: 8,
              children: [
                Text(
                  'Q${index + 1}',
                  style: text.labelLarge?.copyWith(color: _green),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(question.kind.label, style: text.titleMedium),
                      Text(
                        status,
                        style: text.bodySmall?.copyWith(
                          color: flagged ? _yellowInk : AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (flagged)
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: _yellowInk,
                  )
                else if (rubric?.approved ?? false)
                  const Icon(Icons.check, size: 17, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RubricSurface extends StatelessWidget {
  const _RubricSurface({
    required this.child,
    this.minHeight = 0,
    this.padding = 18,
    this.background = Colors.white,
    this.border,
  });

  final Widget child;
  final double minHeight;
  final double padding;
  final Color background;
  final Color? border;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: border == null ? BorderSide.none : BorderSide(color: border!),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

class _RubricPill extends StatelessWidget {
  const _RubricPill(
    this.label, {
    this.foreground = AppColors.mutedText,
    this.background = AppColors.canvas,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble(this.message, {this.fromTeacher = false});

  final String message;
  final bool fromTeacher;

  @override
  Widget build(BuildContext context) => Align(
    alignment: fromTeacher
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: fromTeacher ? _green : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: fromTeacher ? Colors.white : _ink,
            height: 1.4,
          ),
        ),
      ),
    ),
  );
}
