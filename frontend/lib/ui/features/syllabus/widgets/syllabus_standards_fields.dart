import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models/syllabus_sources.dart';
import '../view_models/syllabus_editor_view_model.dart';

const _ink = Color(0xFF202438);
const _green = Color(0xFF22704F);
const _line = Color(0xFFE6ECE8);
const _pillFill = Color(0xFFEEF3EF);

class SyllabusStandardsFields extends StatelessWidget {
  const SyllabusStandardsFields({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    final obec = draft.standardsSource == StandardsSource.obec;
    final selectedCount = draft.selectedIndicators.length;
    final additional = draft.additionalIndicators;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _CardTitle('Learning standards'),
            if (obec)
              const _Pill(
                'Basic Education Core Curriculum B.E. 2551 (rev. 2560)',
              ),
          ],
        ),
        Semantics(
          label: 'Standards source',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _pillFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final source in StandardsSource.values)
                    Semantics(
                      selected: draft.standardsSource == source,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: draft.standardsSource == source
                              ? const Color(0xFFFFFFFF)
                              : null,
                          foregroundColor: draft.standardsSource == source
                              ? _ink
                              : AppColors.mutedText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => draft.setStandardsSource(source),
                        child: Text(
                          source == StandardsSource.obec
                              ? 'OBEC indicators'
                              : 'Custom',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (obec) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF6FBF7),
              border: Border.all(color: _green, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Text(
                    selectedCount == 1
                        ? '1 indicator selected'
                        : '$selectedCount indicators selected',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    draft.indicators.isEmpty
                        ? 'Sample indicators are available for Mathayom 1. Use Custom to add indicators for this grade.'
                        : 'Review the recommended indicators and adjust your selection.',
                    style: const TextStyle(
                      color: Color(0xFF648C7B),
                      fontSize: 13,
                    ),
                  ),
                  for (final indicator in draft.recommendedIndicators)
                    _IndicatorTile(indicator: indicator, draft: draft),
                ],
              ),
            ),
          ),
          if (additional.isNotEmpty)
            _Disclosure(
              label: 'Additional indicators',
              children: [
                for (final indicator in additional)
                  _IndicatorTile(indicator: indicator, draft: draft),
              ],
            ),
        ] else ...[
          for (final (index, indicator) in draft.customIndicators.indexed)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: const Color(0xFFF6FBF7),
              title: Text(indicator),
              trailing: IconButton(
                tooltip: 'Remove custom indicator ${index + 1}',
                onPressed: () => draft.removeCustomIndicator(index),
                icon: const Icon(Icons.close),
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add custom indicator'),
            onPressed: () => _addCustom(context),
          ),
        ],
      ],
    );
  }

  Future<void> _addCustom(BuildContext context) async {
    final form = GlobalKey<FormState>();
    var input = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add custom indicator'),
        scrollable: true,
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Code and description',
            ),
            onChanged: (value) => input = value.trim(),
            validator: (_) {
              if (input.isEmpty) return 'Enter an indicator.';
              if (draft.customIndicators.contains(input)) {
                return 'This indicator is already listed.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.of(context).pop(input);
              }
            },
            child: const Text('Add indicator'),
          ),
        ],
      ),
    );
    if (value != null && context.mounted) draft.addCustomIndicator(value);
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({required this.indicator, required this.draft});

  final SyllabusIndicator indicator;
  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    final selected = draft.selectedIndicators.any(
      (item) => item.code == indicator.code,
    );
    final book = draft.textbook;
    final matches = book == null
        ? <String>[]
        : [
            for (final chapter in indicator.chapters)
              'Ch $chapter ${book.chapters[chapter - 1]}',
          ];
    return Material(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(14),
      child: CheckboxListTile(
        key: ValueKey(indicator.code),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        activeColor: const Color(0xFF4ABE7A),
        checkColor: const Color(0xFFFFFFFF),
        value: selected,
        onChanged: (value) =>
            draft.toggleIndicator(indicator.code, value ?? false),
        title: Text(
          '${indicator.code} — ${indicator.description}',
          style: const TextStyle(fontSize: 14, color: _ink),
        ),
        subtitle: matches.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Pill(
                    'Matched: ${matches.join(' · ')}',
                    fill: const Color(0xFFE4FFE0),
                    color: _green,
                  ),
                ),
              )
            : indicator.chapters.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Pill('Semester 2 course'),
                ),
              )
            : null,
      ),
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      side: const BorderSide(color: _line, width: 2),
      borderRadius: BorderRadius.circular(12),
    );
    return ExpansionTile(
      shape: shape,
      collapsedShape: shape,
      title: Text(label, style: const TextStyle(fontSize: 14, color: _ink)),
      children: children,
    );
  }
}

class SyllabusTextbookFields extends StatelessWidget {
  const SyllabusTextbookFields({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    final book = draft.textbook;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        const Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [_CardTitle('Textbook'), _Pill('Optional')],
        ),
        if (book != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              spacing: 14,
              children: [
                Container(
                  width: 48,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F9D6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.menu_book_outlined, color: _green),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        'PDF · ${book.pages} pages · ${book.chapters.length} chapters',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: _line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: draft.textbooks.isEmpty ? null : () => _pickBook(context),
          icon: const Icon(Icons.menu_book_outlined, size: 16),
          label: const Text('Choose a textbook'),
        ),
        Text(
          draft.textbooks.isEmpty
              ? 'No sample textbooks are available for this grade.'
              : 'Choose a sample textbook from the list.',
          style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
        ),
        if (book != null)
          for (final (index, title) in book.chapters.indexed)
            Row(
              spacing: 8,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    'Ch ${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
      ],
    );
  }

  Future<void> _pickBook(BuildContext context) async {
    final options = draft.textbooks;
    final index = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a textbook'),
        children: [
          for (final (index, book) in options.indexed)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(index),
              child: Text(book.title),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(-1),
            child: const Text('No textbook'),
          ),
        ],
      ),
    );
    if (index != null && context.mounted) {
      draft.selectTextbook(index < 0 ? null : options[index]);
    }
  }
}

class SyllabusMatchSummary extends StatelessWidget {
  const SyllabusMatchSummary({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    final matched = draft.selectedIndicators
        .where((indicator) => indicator.chapters.isNotEmpty)
        .toList();
    final chapters = {for (final indicator in matched) ...indicator.chapters};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        border: Border.all(color: const Color(0xFFD1D4F2), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              SvgPicture.asset(
                'assets/syllabus/match-sparkle.svg',
                width: 16,
                height: 16,
                excludeFromSemantics: true,
              ),
              Expanded(
                child: Text(
                  '${chapters.length} chapters matched to ${matched.length} indicators',
                  style: const TextStyle(
                    color: Color(0xFF181F75),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'Review these sample chapter matches and adjust your indicator selection.',
            style: TextStyle(color: _ink, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontSize: 17, color: _ink),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(
    this.label, {
    this.fill = _pillFill,
    this.color = AppColors.mutedText,
  });
  final String label;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(label, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}
