import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/homework_check.dart';
import '../../../../domain/models/homework_submission.dart';
import '../../../core/theme/app_theme.dart';

const _green = Color(0xFF206D50);
const _ink = Color(0xFF202438);
const _paleGreen = Color(0xFFE4F1E9);
const _line = Color(0xFFE1E9E3);
const _warning = Color(0xFF993C24);

final _mathCommands = RegExp(r'\\(cdot|times|div)(?![A-Za-z])');
const _mathSymbols = {'cdot': '·', 'times': '×', 'div': '÷'};

String _displayMath(String work) => work.replaceAllMapped(
  _mathCommands,
  (command) => _mathSymbols[command[1]]!,
);

class HomeworkProgressView extends StatefulWidget {
  const HomeworkProgressView({
    super.key,
    required this.report,
    required this.onBack,
  });

  final HomeworkSubmissionReport report;
  final VoidCallback onBack;

  @override
  State<HomeworkProgressView> createState() => _HomeworkProgressViewState();
}

class _HomeworkProgressViewState extends State<HomeworkProgressView> {
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: _ProgressLayout(report: widget.report, onBack: widget.onBack),
  );
}

class _ProgressLayout extends StatelessWidget {
  const _ProgressLayout({required this.report, required this.onBack});

  final HomeworkSubmissionReport report;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final wrong = report.questions
        .where(
          (question) => question.status == HomeworkReviewStatus.needsRevision,
        )
        .length;
    final tabs = DefaultTabController.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final roomy = wide && constraints.maxHeight >= 680;
        final inset = roomy ? 48.0 : (wide ? 28.0 : 16.0);
        final next = _NextStep(
          wrong: wrong,
          pending: report.pending,
          onReview: report.mistakes.isEmpty ? null : () => tabs.animateTo(1),
        );
        final main = Column(
          spacing: roomy ? 18 : 12,
          children: [
            _Scores(report: report, wrong: wrong),
            Expanded(
              child: _ResultTabs(report: report, next: wide ? null : next),
            ),
          ],
        );
        return Column(
          children: [
            _ProgressHeader(inset: inset, roomy: roomy, onBack: onBack),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.75, -0.96),
                    radius: 0.46,
                    colors: [Color(0xFFBFEACC), AppColors.canvas],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: inset,
                    vertical: roomy ? 32 : 14,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 20,
                          children: [
                            Expanded(flex: 21, child: main),
                            Expanded(
                              flex: 10,
                              child: SingleChildScrollView(
                                primary: false,
                                child: next,
                              ),
                            ),
                          ],
                        )
                      : main,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.inset,
    required this.roomy,
    required this.onBack,
  });

  final double inset;
  final bool roomy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.header,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: roomy ? 140 : 68),
      child: Padding(
        padding: EdgeInsets.only(left: inset - (roomy ? 44 : 8), right: inset),
        child: Row(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Back to homework',
              iconSize: 22,
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left, color: _ink),
            ),
            Expanded(
              child: Text(
                'My progress · Unit 3',
                style: TextStyle(
                  color: _ink,
                  fontSize: roomy ? 30 : 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (roomy)
              const _StatusChip(
                'Math 101 · HW 3.1',
                AppColors.canvas,
                AppColors.mutedText,
              ),
          ],
        ),
      ),
    ),
  );
}

class _ResultTabs extends StatelessWidget {
  const _ResultTabs({required this.report, this.next});

  final HomeworkSubmissionReport report;
  final Widget? next;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Material(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TabBar(
            labelColor: _green,
            unselectedLabelColor: AppColors.mutedText,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            dividerColor: _line,
            indicatorColor: _green,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: EdgeInsets.symmetric(horizontal: 6),
            tabs: [
              Tab(
                height: 44,
                child: Text('Your answer', textAlign: TextAlign.center),
              ),
              Tab(
                height: 44,
                child: Text('Mistakes to watch', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: TabBarView(
          children: [
            ListView(
              key: const PageStorageKey('homework-question-results'),
              primary: false,
              children: [
                _TabContent(
                  child: ListTileTheme.merge(
                    horizontalTitleGap: 8,
                    minLeadingWidth: 24,
                    child: Column(
                      children: [
                        for (final question in report.questions)
                          _QuestionProgress(
                            question: question,
                            compact: next != null,
                          ),
                      ],
                    ),
                  ),
                ),
                if (next case final nextStep?) ...[
                  const SizedBox(height: 12),
                  nextStep,
                ],
              ],
            ),
            ListView(
              key: const PageStorageKey('homework-mistakes'),
              primary: false,
              children: [
                _TabContent(child: _MistakesPanel(mistakes: report.mistakes)),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: child,
    ),
  );
}

class _Scores extends StatelessWidget {
  const _Scores({required this.report, required this.wrong});

  final HomeworkSubmissionReport report;
  final int wrong;

  @override
  Widget build(BuildContext context) {
    final total = report.questions.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: compact ? 8 : 14,
          children: [
            Expanded(
              child: _ScoreCard(
                compact: compact,
                icon: Icons.track_changes_outlined,
                title: compact ? 'Score' : 'AI review score',
                value: '${report.points} / ${report.maximum} pts',
                detail: report.pending > 0
                    ? (compact ? 'Pending' : 'Awaiting review')
                    : (compact ? 'Reviewed' : 'Formative feedback'),
              ),
            ),
            Expanded(
              child: _ScoreCard(
                compact: compact,
                icon: Icons.task_alt,
                title: 'Homework',
                value: '$total / $total',
                detail: compact ? 'Submitted' : 'Questions submitted',
              ),
            ),
            Expanded(
              child: _ScoreCard(
                compact: compact,
                icon: Icons.fact_check_outlined,
                title: compact ? 'To revisit' : 'Needs attention',
                value: '$wrong',
                detail: '${report.pending} pending',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.compact,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Panel(
      padding: EdgeInsets.all(compact ? 10 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 5,
            children: [
              if (!compact) Icon(icon, color: _green, size: 16),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 18 : 24,
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _QuestionProgress extends StatelessWidget {
  const _QuestionProgress({required this.question, required this.compact});

  final HomeworkSubmittedQuestion question;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, foreground, background) = switch (question.status) {
      HomeworkReviewStatus.correct => (
        'Correct',
        _green,
        const Color(0xFFE6F2EA),
      ),
      HomeworkReviewStatus.needsRevision => (
        'Revisit',
        _warning,
        const Color(0xFFFFE8E2),
      ),
      HomeworkReviewStatus.unreadable => (
        'Pending',
        AppColors.mutedText,
        AppColors.canvas,
      ),
    };
    final points = question.points;
    final maxPoints = question.maximum;
    final progress = points == null || maxPoints <= 0
        ? 0.0
        : (points / maxPoints).clamp(0.0, 1.0);
    final score = points == null ? null : '$points / $maxPoints';
    return ExpansionTile(
      key: PageStorageKey('homework-result-${question.position}'),
      dense: true,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 34, right: 6, bottom: 12),
      leading: Text(
        'Q${question.position}',
        style: const TextStyle(color: _green, fontWeight: FontWeight.w600),
      ),
      title: Text(
        question.prompt,
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          color: AppColors.primary,
          backgroundColor: _paleGreen,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      trailing: _StatusChip(
        compact || score == null ? label : '$label · $score',
        background,
        foreground,
      ),
      children: [
        if (compact && score != null)
          Align(alignment: Alignment.centerLeft, child: Text('$score pts')),
        if (question.work.trim().isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recognized work',
              style: text.labelSmall?.copyWith(color: AppColors.mutedText),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              _displayMath(question.work),
              // Keep the text's scroll offset separate from the tile's expanded state.
              key: const PageStorageKey('recognized-work'),
              style: text.bodyMedium?.copyWith(color: _ink),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Align(alignment: Alignment.centerLeft, child: Text(question.message)),
      ],
    );
  }
}

class _MistakesPanel extends StatelessWidget {
  const _MistakesPanel({required this.mistakes});

  final List<HomeworkMistake> mistakes;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<HomeworkMistake>>{};
    for (final issue in mistakes) {
      (groups[issue.kind] ??= []).add(issue);
    }
    if (groups.isEmpty) {
      return const Text('No mistakes were identified in the reviewed answers.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final group in groups.values) _MistakeGroup(issues: group),
      ],
    );
  }
}

class _MistakeGroup extends StatelessWidget {
  const _MistakeGroup({required this.issues});

  final List<HomeworkMistake> issues;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final questions = issues
        .map((issue) => 'Q${issue.position}')
        .toSet()
        .join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFCF8F5),
        border: Border.all(color: _warning),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFFFE4D8),
                  child: Icon(Icons.replay, color: _warning, size: 16),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        issues.first.observation,
                        style: text.titleSmall?.copyWith(color: _ink),
                      ),
                      Text(
                        questions,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            for (final issue in issues)
              if (issue.work.isNotEmpty)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: text.bodySmall,
                      children: [
                        TextSpan(
                          text: issues.length == 1
                              ? 'Your work  '
                              : 'Q${issue.position} · Your work  ',
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                        TextSpan(
                          text: _displayMath(issue.work),
                          style: const TextStyle(
                            color: _warning,
                            backgroundColor: Color(0xFFFFE0E0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                const Icon(Icons.auto_awesome, color: _green, size: 16),
                Expanded(child: Text(issues.first.hint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.wrong,
    required this.pending,
    required this.onReview,
  });

  final int wrong;
  final int pending;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Panel(
      color: const Color(0xFFF3F9EF),
      borderColor: AppColors.mint,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              const Icon(Icons.track_changes_outlined, color: _green, size: 18),
              Text('Next step', style: text.titleMedium?.copyWith(color: _ink)),
            ],
          ),
          if (wrong > 0)
            Text(
              wrong == 1
                  ? 'Use the hint to revisit the highlighted step.'
                  : 'Use the hints to revisit the highlighted steps in $wrong answers.',
              style: text.bodySmall?.copyWith(color: AppColors.mutedText),
            )
          else if (pending == 0)
            const Text('All submitted answers were marked correct.'),
          if (pending > 0)
            Text(
              pending == 1
                  ? 'One answer could not be read confidently and is pending.'
                  : '$pending answers could not be read confidently and are pending.',
            ),
          if (onReview != null)
            FilledButton.icon(
              onPressed: onReview,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Review mistakes'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF101713),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(label, style: TextStyle(fontSize: 12, color: foreground)),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.color = Colors.white,
    this.borderColor,
    required this.padding,
  });

  final Widget child;
  final Color color;
  final Color? borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      border: borderColor == null ? null : Border.all(color: borderColor!),
      borderRadius: BorderRadius.circular(16),
    ),
    padding: padding,
    child: child,
  );
}
