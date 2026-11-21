import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/assessment_draft.dart';
import '../../../core/theme/app_theme.dart';

extension AssessmentQuestionKindLabels on AssessmentQuestionKind {
  String get label => switch (this) {
    AssessmentQuestionKind.shortAnswer => 'Short answer',
    AssessmentQuestionKind.showWork => 'Show work',
    AssessmentQuestionKind.multipleChoice => 'Multiple choice',
    AssessmentQuestionKind.trueFalse => 'True or false',
  };

  IconData get icon => switch (this) {
    AssessmentQuestionKind.shortAnswer => Icons.short_text,
    AssessmentQuestionKind.showWork => Icons.edit_note,
    AssessmentQuestionKind.multipleChoice => Icons.checklist_rtl,
    AssessmentQuestionKind.trueFalse => Icons.compare_arrows,
  };
}

Future<AssessmentQuestion?> showAssessmentQuestionEditor(
  BuildContext context, {
  AssessmentQuestion? initial,
}) async {
  final kind =
      initial?.kind ??
      await showDialog<AssessmentQuestionKind>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose a question type'),
          children: [
            for (final type in AssessmentQuestionKind.values)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, type),
                child: Row(
                  spacing: 14,
                  children: [
                    Icon(type.icon, color: AppColors.primary),
                    Flexible(child: Text(type.label)),
                  ],
                ),
              ),
          ],
        ),
      );

  if (kind == null || !context.mounted) return null;
  return showDialog<AssessmentQuestion>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _QuestionEditor(kind: kind, initial: initial),
  );
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({required this.kind, required this.initial});

  final AssessmentQuestionKind kind;
  final AssessmentQuestion? initial;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  final _form = GlobalKey<FormState>();
  late final _prompt = TextEditingController(text: widget.initial?.prompt);
  late final _points = TextEditingController(
    text: (widget.initial?.points ?? 1).toString(),
  );
  late final _choices = widget.kind == AssessmentQuestionKind.multipleChoice
      ? List.generate(
          4,
          (index) => TextEditingController(
            text: index < (widget.initial?.options.length ?? 0)
                ? widget.initial!.options[index]
                : null,
          ),
        )
      : <TextEditingController>[];

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      AssessmentQuestion(
        kind: widget.kind,
        prompt: _prompt.text.trim(),
        points: int.parse(_points.text),
        options: List.unmodifiable(
          _choices
              .map((choice) => choice.text.trim())
              .where((choice) => choice.isNotEmpty),
        ),
      ),
    );
  }

  String? _validateChoice(int index, String? value) {
    final choice = value?.trim() ?? '';
    if (choice.isEmpty) return index < 2 ? 'Enter a choice.' : null;
    final duplicate = _choices.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.text.trim().toLowerCase() == choice.toLowerCase(),
    );
    return duplicate ? 'Choices must be different.' : null;
  }

  @override
  void dispose() {
    _prompt.dispose();
    _points.dispose();
    for (final choice in _choices) {
      choice.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStatement = widget.kind == AssessmentQuestionKind.trueFalse;
    return AlertDialog(
      title: Text(widget.kind.label),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              TextFormField(
                controller: _prompt,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: isStatement ? 'Statement' : 'Question',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? (isStatement ? 'Enter a statement.' : 'Enter a question.')
                    : null,
              ),
              TextFormField(
                controller: _points,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Points',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                    ? 'Enter a positive whole number.'
                    : null,
              ),
              for (var index = 0; index < _choices.length; index++)
                TextFormField(
                  controller: _choices[index],
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: 'Option ${String.fromCharCode(65 + index)}',
                    hintText: index >= 2 ? 'Optional' : null,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => _validateChoice(index, value),
                ),
              if (isStatement)
                const Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text('True')),
                    Chip(label: Text('False')),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save question')),
      ],
    );
  }
}
