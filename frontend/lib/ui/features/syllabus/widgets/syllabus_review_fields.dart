import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../view_models/syllabus_editor_view_model.dart';

const _ink = Color(0xFF202438);
const _line = Color(0xFFE6ECE8);
const _green = Color(0xFF22704F);

class SyllabusReviewTotals extends StatelessWidget {
  const SyllabusReviewTotals({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    final units = draft.units;
    final lessons = units.fold(0, (total, unit) => total + unit.lessons.length);
    final scored = draft
        .scheduleFor(0)
        .where((slot) => (slot.lesson?.quizPoints ?? 0) > 0)
        .length;
    final metrics = [
      (draft.schedulePeriodCount, 'teaching periods'),
      (units.length, 'units · $lessons lessons'),
      (scored, 'scored events'),
      (draft.classes.length, 'classes'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700
            ? 4
            : constraints.maxWidth >= 270
            ? 2
            : 1;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (value, label) in metrics)
              Container(
                width: width,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: _ink),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class SyllabusLearningPlanOptions extends StatelessWidget {
  const SyllabusLearningPlanOptions({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  Future<void> _writeNotes(BuildContext context) async {
    var value = draft.teachingNotes;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your teaching notes'),
        scrollable: true,
        content: TextFormField(
          initialValue: value,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Teaching notes'),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(value.trim()),
            child: const Text('Save notes'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) draft.setTeachingNotes(result);
  }

  @override
  Widget build(BuildContext context) {
    final selected = draft.teachingApproaches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _Title('Next: learning plans for each period'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 13,
                    color: Color(0xFF963F14),
                  ),
                  Text(
                    'AI-assisted',
                    style: TextStyle(fontSize: 12, color: Color(0xFF963F14)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Text(
          'Select one or more teaching approaches for future lesson plans. Each plan can include a warm-up, timed activities, an exercise, an exit ticket and homework.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final columns = constraints.maxWidth >= 600
                ? 4
                : constraints.maxWidth >= 280
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            final cards = [
              for (final approach in TeachingApproach.values)
                SizedBox(
                  width: width,
                  child: _ApproachCard(
                    approach: approach,
                    selected: selected.contains(approach),
                    compact: columns != 4,
                    onChanged: (value) =>
                        draft.setTeachingApproach(approach, value ?? false),
                  ),
                ),
            ];
            if (columns == 4) {
              return IntrinsicHeight(
                child: Row(
                  spacing: gap,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cards,
                ),
              );
            }
            return Wrap(spacing: gap, runSpacing: gap, children: cards);
          },
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF3EA),
                foregroundColor: const Color(0xFF963F14),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFFFD7C2)),
              ),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(
                'Generate ${draft.schedulePeriodCount} learning plans',
              ),
              onPressed: selected.isEmpty
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Teaching approaches are saved in the draft. Learning-plan generation is not connected yet.',
                        ),
                      ),
                    ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: _line),
              ),
              onPressed: () => _writeNotes(context),
              child: const Text('Write my own'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ApproachCard extends StatelessWidget {
  const _ApproachCard({
    required this.approach,
    required this.selected,
    required this.compact,
    required this.onChanged,
  });

  final TeachingApproach approach;
  final bool selected;
  final bool compact;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE5F9D6) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.accent : _line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 105 : 172),
        child: Align(
          alignment: Alignment.topLeft,
          heightFactor: 1,
          child: ListTileTheme(
            horizontalTitleGap: 0,
            textColor: _ink,
            child: CheckboxListTile(
              key: ValueKey(approach),
              value: selected,
              activeColor: _green,
              checkColor: Colors.white,
              controlAffinity: ListTileControlAffinity.leading,
              titleAlignment: ListTileTitleAlignment.top,
              contentPadding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
              title: Text(
                approach.label,
                style: const TextStyle(
                  fontSize: 14,
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: compact ? 6 : 26),
                child: Text(
                  approach.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class SyllabusStudentPreviewOptions extends StatelessWidget {
  const SyllabusStudentPreviewOptions({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    final selected = draft.studentDetails;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const _Title('What students will see'),
        for (final detail in StudentSyllabusDetail.values)
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              checkColor: Colors.white,
              value: selected.contains(detail),
              onChanged: (value) =>
                  draft.setStudentDetail(detail, value ?? false),
              title: Text(
                detail == StudentSyllabusDetail.scores
                    ? '${detail.label} (${draft.duringTermPoints} : ${draft.finalPoints})'
                    : detail.label,
              ),
            ),
          ),
        TextButton.icon(
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: _ink,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 48),
          ),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Preview as a student'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => _StudentPreview(draft: draft),
          ),
        ),
      ],
    );
  }
}

class _StudentPreview extends StatefulWidget {
  const _StudentPreview({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  State<_StudentPreview> createState() => _StudentPreviewState();
}

class _StudentPreviewState extends State<_StudentPreview> {
  int _room = 0;

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final details = draft.studentDetails;
    final dates = DateFormat('EEE d MMM', 'en_US');
    final slots = draft.scheduleFor(_room);
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 720),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              Row(
                children: [
                  Expanded(child: _Title(draft.courseName)),
                  IconButton(
                    tooltip: 'Close student preview',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (index, room) in draft.classes.indexed)
                    ChoiceChip(
                      label: Text(room.name),
                      selected: _room == index,
                      onSelected: (_) => setState(() => _room = index),
                    ),
                ],
              ),
              if (details.isEmpty)
                const Text(
                  'Select syllabus details to include in the student preview.',
                ),
              if (details.contains(StudentSyllabusDetail.scores)) ...[
                const _Title('Score breakdown'),
                for (final category in AssessmentCategory.values)
                  Text(
                    '${category.label} · ${draft.pointsFor(category)} points',
                  ),
              ],
              if (details.contains(StudentSyllabusDetail.indicators)) ...[
                const _Title('Indicator codes'),
                for (final reference in draft.unitReferences) Text(reference),
              ],
              if (details.contains(StudentSyllabusDetail.notes)) ...[
                const _Title('Teaching notes'),
                Text(
                  draft.teachingNotes.isEmpty
                      ? 'No teaching notes yet.'
                      : draft.teachingNotes,
                ),
              ],
              if (details.contains(StudentSyllabusDetail.assessmentDates)) ...[
                const _Title('Quiz and exam dates'),
                for (final slot in slots)
                  if ((slot.lesson?.quizPoints ?? 0) > 0)
                    Text(
                      '${dates.format(slot.date)} · P${slot.periodNumber} · ${slot.lesson!.title} · ${slot.lesson!.quizPoints} points',
                    ),
                const Text('Exam dates follow the school calendar.'),
              ],
              if (details.contains(StudentSyllabusDetail.topics)) ...[
                const _Title('Unit & lesson topics by date'),
                for (final slot in slots)
                  if (slot.lesson case final lesson?)
                    Text(
                      '${dates.format(slot.date)} · P${slot.periodNumber} · ${lesson.title}',
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontSize: 17, color: _ink),
  );
}
