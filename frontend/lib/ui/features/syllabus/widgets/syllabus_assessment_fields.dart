import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../view_models/syllabus_editor_view_model.dart';

const _ink = Color(0xFF202438);
const _line = Color(0xFFE6ECE8);
const _green = Color(0xFF2B6B1F);
const _colors = [
  Color(0xFF4ABE7A),
  Color(0xFF0F6E6E),
  Color(0xFF7A3FA8),
  Color(0xFFA1294F),
  Color(0xFF202438),
];

class SyllabusAssessmentFields extends StatefulWidget {
  const SyllabusAssessmentFields({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  State<SyllabusAssessmentFields> createState() =>
      _SyllabusAssessmentFieldsState();
}

class _SyllabusAssessmentFieldsState extends State<SyllabusAssessmentFields> {
  static const _presets = [20, 30, 40, 50];

  late final _controllers = {
    for (final category in AssessmentCategory.values)
      category: TextEditingController(
        text: '${widget.draft.pointsFor(category)}',
      ),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _applySplit(int points) {
    FocusScope.of(context).unfocus();
    widget.draft.setAssessmentSplit(points);
    for (final entry in _controllers.entries) {
      entry.value.text = '${widget.draft.pointsFor(entry.key)}';
    }
  }

  String _description(AssessmentCategory category) {
    final count = widget.draft.units.length;
    final quizPoints = widget.draft.pointsFor(AssessmentCategory.quizzes);
    return switch (category) {
      AssessmentCategory.quizzes
          when count > 0 && quizPoints > 0 && quizPoints % count == 0 =>
        '$count ${count == 1 ? 'quiz' : 'quizzes'} × ${quizPoints ~/ count} points',
      AssessmentCategory.quizzes => 'Quiz dates are set in Schedule',
      AssessmentCategory.coursework => 'Formative · weekly',
      AssessmentCategory.participation =>
        'Attendance via app + in-class questions',
      AssessmentCategory.midterm =>
        '${_unitsLabel((count + 1) ~/ 2)} · exam week',
      AssessmentCategory.finalExam => '${_unitsLabel(count)} · exam week',
    };
  }

  String _unitsLabel(int count) => count == 1 ? 'Unit 1' : 'Units 1–$count';

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final total = draft.assessmentTotal;
    final valid = total == 100;
    final preset = valid && _presets.contains(draft.finalPoints)
        ? draft.finalPoints
        : -1;
    final totalColor = valid ? _green : const Color(0xFF963F14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Score split',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 17, color: _ink),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'During Term : Final',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedText),
                ),
                SizedBox(
                  width: 116,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(preset),
                    initialValue: preset,
                    isExpanded: true,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF195D40),
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: _line,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      if (preset == -1)
                        DropdownMenuItem(
                          value: -1,
                          enabled: false,
                          child: Text(
                            '${draft.duringTermPoints} : ${draft.finalPoints}',
                          ),
                        ),
                      for (final points in _presets)
                        DropdownMenuItem(
                          value: points,
                          child: Text('${100 - points} : $points'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null && value >= 0) _applySplit(value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            key: const ValueKey('assessment-score-bar'),
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                for (final category in AssessmentCategory.values)
                  if (draft.pointsFor(category) > 0)
                    Expanded(
                      flex: draft.pointsFor(category),
                      child: ColoredBox(
                        color: category == AssessmentCategory.quizzes
                            ? const Color(0xFF0B0F0C)
                            : _colors[category.index],
                        child: LayoutBuilder(
                          builder: (context, constraints) => Center(
                            child: constraints.maxWidth >= 28
                                ? Text(
                                    '${draft.pointsFor(category)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                if (total < 100)
                  Expanded(
                    flex: 100 - total,
                    child: const ColoredBox(color: _line),
                  ),
              ],
            ),
          ),
        ),
        Column(
          children: [
            for (final category in AssessmentCategory.values)
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _line)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    spacing: 12,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colors[category.index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              category.label,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _description(category),
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Semantics(
                          label: '${category.label} points',
                          child: TextFormField(
                            key: ValueKey('assessment-${category.name}'),
                            controller: _controllers[category],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 10,
                              ),
                            ),
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onChanged: (value) => draft.setAssessmentPoints(
                              category,
                              int.tryParse(value) ?? 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: valid ? const Color(0xFFE7F3EC) : const Color(0xFFFFF3EA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            spacing: 8,
            children: [
              Icon(
                valid ? Icons.check : Icons.warning_amber_rounded,
                color: totalColor,
                size: 18,
              ),
              const Expanded(child: Text('Total')),
              Text(
                '$total / 100',
                style: TextStyle(
                  color: totalColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
