import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/assessment_rubric.dart';
import '../../../core/theme/app_theme.dart';

const _green = Color(0xFF1E6C50);
const _line = Color(0xFFE2E9E5);

typedef CriterionEdit = void Function(
  int index,
  RubricCriterion Function(RubricCriterion) edit,
);

class RubricScoreTable extends StatelessWidget {
  const RubricScoreTable({
    super.key,
    required this.rubric,
    required this.points,
    required this.onChanged,
  });

  final QuestionRubric rubric;
  final int points;
  final CriterionEdit onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final matches = rubric.matchesQuestionPoints(points);
    final table = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        border: TableBorder.all(color: _line),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        columnWidths: const {
          0: FlexColumnWidth(1.34),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
          3: FlexColumnWidth(0.92),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF2F9ED)),
            children: [
              for (final title in ['Criterion', 'Full', 'Partial', 'None'])
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    title,
                    style: text.labelLarge?.copyWith(color: _green),
                  ),
                ),
            ],
          ),
          for (var index = 0; index < rubric.criteria.length; index++)
            _criterionRow(context, rubric.criteria[index], index),
          TableRow(
            decoration: const BoxDecoration(color: AppColors.canvas),
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Total', style: text.labelLarge),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${rubricScore(rubric.fullPoints)} pt',
                  style: text.labelLarge?.copyWith(color: _green),
                ),
              ),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 380
              ? table
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 380, child: table),
                ),
        ),
        if (!matches)
          Text(
            'Enter valid scores. Full credit must add up to $points pt, and partial credit must stay within full credit.',
            style: text.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }

  TableRow _criterionRow(BuildContext context, RubricCriterion row, int index) {
    final text = Theme.of(context).textTheme;
    final name = text.labelLarge;
    final score = name?.copyWith(color: _green);
    final detail = text.bodySmall?.copyWith(
      color: AppColors.mutedText,
      height: 1.35,
    );

    return TableRow(
      children: [
        _TableCell(
          children: [
            _RubricInput(
              label: 'Criterion ${index + 1} name',
              hint: 'Criterion',
              value: row.name,
              style: name,
              onChanged: (value) =>
                  onChanged(index, (current) => current.copyWith(name: value)),
            ),
            _RubricInput(
              label: 'Criterion ${index + 1} description',
              hint: 'Description',
              value: row.description,
              style: detail,
              onChanged: (value) => onChanged(
                index,
                (current) => current.copyWith(description: value),
              ),
            ),
          ],
        ),
        _TableCell(
          children: [
            _RubricInput(
              label: 'Criterion ${index + 1} full points',
              hint: 'Points',
              value: row.fullScore,
              style: score,
              numeric: true,
              onChanged: (value) => onChanged(
                index,
                (current) => current.copyWith(fullScore: value),
              ),
            ),
            _RubricInput(
              label: 'Criterion ${index + 1} full description',
              hint: 'Full credit',
              value: row.fullDescription,
              style: detail,
              onChanged: (value) => onChanged(
                index,
                (current) => current.copyWith(fullDescription: value),
              ),
            ),
          ],
        ),
        _TableCell(
          children: [
            _RubricInput(
              label: 'Criterion ${index + 1} partial points',
              hint: '—',
              value: row.partialScore,
              style: score,
              numeric: true,
              onChanged: (value) => onChanged(
                index,
                (current) => current.copyWith(partialScore: value),
              ),
            ),
            _RubricInput(
              label: 'Criterion ${index + 1} partial description',
              hint: 'Partial credit',
              value: row.partialDescription,
              style: detail,
              onChanged: (value) => onChanged(
                index,
                (current) => current.copyWith(partialDescription: value),
              ),
            ),
          ],
        ),
        _TableCell(
          children: [
            Text('0', style: score),
            _RubricInput(
              label: 'Criterion ${index + 1} no credit description',
              hint: 'No credit',
              value: row.noneDescription,
              style: detail,
              onChanged: (value) => onChanged(
                index,
                (current) => current.copyWith(noneDescription: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    child: Column(
      spacing: 4,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _RubricInput extends StatelessWidget {
  const _RubricInput({
    required this.label,
    required this.hint,
    required this.value,
    required this.style,
    required this.onChanged,
    this.numeric = false,
  });

  final String label;
  final String hint;
  final String value;
  final TextStyle? style;
  final ValueChanged<String> onChanged;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: TextFormField(
      key: ValueKey(label),
      initialValue: value,
      style: style,
      maxLines: numeric ? 1 : null,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.multiline,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 3),
        border: InputBorder.none,
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _green),
        ),
      ),
      onChanged: onChanged,
    ),
  );
}
