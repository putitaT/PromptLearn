import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/assessment_draft.dart';

Future<void> showAssessmentStudentPreview(
  BuildContext context,
  AssessmentDraft draft,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Student preview'),
    scrollable: true,
    content: SizedBox(
      width: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          for (var index = 0; index < draft.questions.length; index++)
            _PreviewQuestion(index: index, question: draft.questions[index]),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close preview'),
      ),
    ],
  ),
);

class _PreviewQuestion extends StatefulWidget {
  const _PreviewQuestion({required this.index, required this.question});

  final int index;
  final AssessmentQuestion question;

  @override
  State<_PreviewQuestion> createState() => _PreviewQuestionState();
}

class _PreviewQuestionState extends State<_PreviewQuestion> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final options = switch (question.kind) {
      AssessmentQuestionKind.trueFalse => const ['True', 'False'],
      AssessmentQuestionKind.multipleChoice => question.options,
      _ => const <String>[],
    };
    final showWork = question.kind == AssessmentQuestionKind.showWork;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          'Q${widget.index + 1} · ${question.points} pt',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text(question.prompt),
        if (options.isEmpty)
          TextField(
            minLines: showWork ? 3 : 1,
            maxLines: showWork ? 5 : 2,
            decoration: InputDecoration(
              labelText: showWork ? 'Show each step' : 'Your answer',
              border: const OutlineInputBorder(),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var index = 0; index < options.length; index++)
                ChoiceChip(
                  label: Text(options[index]),
                  selected: _selected == index,
                  onSelected: (selected) =>
                      setState(() => _selected = selected ? index : null),
                ),
            ],
          ),
      ],
    );
  }
}
