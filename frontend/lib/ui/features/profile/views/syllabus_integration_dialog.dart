import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/course_syllabus.dart';
import '../../../../domain/repositories/course_syllabus_repository.dart';

class SyllabusIntegrationDialog extends StatefulWidget {
  const SyllabusIntegrationDialog({super.key, required this.repository});

  final CourseSyllabusRepository? repository;

  @override
  State<SyllabusIntegrationDialog> createState() =>
      _SyllabusIntegrationDialogState();
}

class _SyllabusIntegrationDialogState extends State<SyllabusIntegrationDialog> {
  static const _exportChannel = MethodChannel('promptlearn/syllabus_export');
  static const _exampleReferences = {
    'core/1/1.1/1',
    'core/1/2.2/1',
    'core/1/2.2/2',
  };

  int _grade = 1;
  int _term = 1;
  int _loadRequest = 0;
  List<CurriculumRow>? _rows;
  final _selected = <String>{};
  bool _curriculumFailed = false;
  bool _busy = false;
  bool _exporting = false;
  String? _error;
  String? _exportMessage;
  CourseSyllabusDraft? _draft;
  String? _savedId;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _loadCurriculum(_grade);
  }

  Future<void> _loadCurriculum(int grade) async {
    final request = ++_loadRequest;
    setState(() {
      _grade = grade;
      _rows = null;
      _selected.clear();
      _curriculumFailed = false;
      _error = null;
    });
    try {
      final rows = await widget.repository!.loadCurriculum(grade);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _rows = rows;
        _selectExample();
      });
    } catch (_) {
      if (mounted && request == _loadRequest) {
        setState(() => _curriculumFailed = true);
      }
    }
  }

  void _selectExample() {
    _selected.clear();
    final rows = _rows;
    if (_grade == 1 && _term == 1 && rows != null) {
      _selected.addAll(
        rows.map((row) => row.id).where(_exampleReferences.contains),
      );
    }
  }

  Future<void> _generate() async {
    final selection = CourseSyllabusSelection(
      grade: _grade,
      term: _term,
      references: [
        for (final row in _rows!)
          if (_selected.contains(row.id)) row.id,
      ],
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.repository!.generate(selection);
      if (mounted) setState(() => _draft = draft);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not generate the draft. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(CourseSyllabusDraft draft) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.repository!.save(draft);
      if (mounted) setState(() => _savedId = id);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the draft. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canDownload =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _exportDocument(CourseSyllabusDraft draft) async {
    setState(() {
      _exporting = true;
      _exportMessage = null;
      _error = null;
    });
    try {
      if (_canDownload) {
        final selection = draft.selection;
        final fileName =
            'PromptLearn-M${selection.grade}-Semester-${selection.term}.html';
        final saved = await _exportChannel.invokeMethod<bool>('saveHtml', {
          'fileName': fileName,
          'contents': utf8.encode(draft.documentHtml),
        });
        if (mounted && saved == true) {
          setState(() => _exportMessage = 'Saved HTML to your device.');
        }
      } else {
        await Clipboard.setData(ClipboardData(text: draft.documentHtml));
        if (mounted) setState(() => _exportMessage = 'Syllabus HTML copied.');
      }
    } on Exception {
      if (mounted) setState(() => _error = 'Could not export the syllabus.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final error = _error;
    final savedId = _savedId;
    final exportMessage = _exportMessage;
    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(draft == null ? 'Create syllabus' : 'Syllabus draft'),
          if (exportMessage != null)
            Text(exportMessage, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          key: ValueKey(draft == null),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              if (savedId != null) SelectableText('Draft saved · $savedId'),
              if (error != null)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (widget.repository == null)
                const Text('Configure the backend URL to create a syllabus.')
              else if (draft == null)
                ..._selectionFields()
              else
                _DraftPreview(draft: draft),
              if (_busy)
                LinearProgressIndicator(
                  semanticsLabel: draft == null
                      ? 'Generating draft'
                      : 'Saving draft',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (draft != null) ...[
          TextButton(
            onPressed: _busy || _exporting
                ? null
                : () => setState(() {
                    _draft = null;
                    _savedId = null;
                    _error = null;
                    _exportMessage = null;
                  }),
            child: const Text('Edit selection'),
          ),
          OutlinedButton(
            onPressed: _busy || _exporting || savedId != null
                ? null
                : () => _save(draft),
            child: Text(
              savedId != null
                  ? 'Saved to backend'
                  : _busy
                  ? 'Saving…'
                  : 'Save draft',
            ),
          ),
          FilledButton.icon(
            onPressed: _busy || _exporting
                ? null
                : () => _exportDocument(draft),
            icon: Icon(_canDownload ? Icons.download : Icons.copy),
            label: Text(
              _exporting
                  ? 'Exporting…'
                  : _canDownload
                  ? 'Download HTML'
                  : 'Copy HTML',
            ),
          ),
        ] else if (widget.repository != null)
          FilledButton(
            onPressed: !_busy && _selected.isNotEmpty ? _generate : null,
            child: Text(_busy ? 'Generating…' : 'Generate draft'),
          ),
      ],
    );
  }

  List<Widget> _selectionFields() {
    final rows = _rows;
    return [
      const Text(
        'Core Mathematics · ${CourseSyllabusSelection.periods} periods · '
        '${CourseSyllabusSelection.minutes} minutes per period',
      ),
      Row(
        spacing: 12,
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _grade,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Grade'),
              items: [
                for (var grade = 1; grade <= 6; grade++)
                  DropdownMenuItem(value: grade, child: Text('ม.$grade')),
              ],
              onChanged: _busy
                  ? null
                  : (grade) {
                      if (grade != null && grade != _grade) {
                        _loadCurriculum(grade);
                      }
                    },
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _term,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Semester'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Semester 1')),
                DropdownMenuItem(value: 2, child: Text('Semester 2')),
              ],
              onChanged: _busy
                  ? null
                  : (term) {
                      if (term == null || term == _term) return;
                      setState(() {
                        _term = term;
                        _error = null;
                        _selectExample();
                      });
                    },
            ),
          ),
        ],
      ),
      const Text('Choose the curriculum topics covered this semester.'),
      if (_curriculumFailed)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => _loadCurriculum(_grade),
            child: const Text('Could not load the curriculum. Retry'),
          ),
        )
      else if (rows == null)
        const LinearProgressIndicator(semanticsLabel: 'Loading curriculum')
      else if (rows.isEmpty)
        const Text('No curriculum topics were returned for this grade.')
      else
        for (final row in rows)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _selected.contains(row.id),
            title: Text(row.title),
            subtitle: Text(row.outcomes.join('\n')),
            onChanged: _busy
                ? null
                : (selected) => setState(() {
                    if (selected == true) {
                      _selected.add(row.id);
                    } else {
                      _selected.remove(row.id);
                    }
                  }),
          ),
    ];
  }
}

class _DraftPreview extends StatelessWidget {
  const _DraftPreview({required this.draft});

  final CourseSyllabusDraft draft;

  @override
  Widget build(BuildContext context) {
    final selection = draft.selection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(
          selection.courseName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          'Semester ${selection.term} · ${CourseSyllabusSelection.periods} periods',
        ),
        Text(draft.description),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Learning outcomes'),
          children: [
            for (final reference in draft.references)
              ListTile(
                title: Text(reference.title),
                subtitle: Text(reference.outcomes.join('\n')),
              ),
          ],
        ),
        Text('Assessment', style: Theme.of(context).textTheme.titleMedium),
        Text(
          CourseSyllabusSelection.weights.entries
              .map((weight) => '${weight.key} ${weight.value}%')
              .join(' · '),
        ),
        Text(
          'Units and periods',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final unit in draft.units)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(unit.title),
            subtitle: Text('${unit.periods.length} periods'),
            children: [
              for (final period in unit.periods)
                ListTile(
                  dense: true,
                  title: Text('${period.number}. ${period.title}'),
                ),
              for (final assessment in unit.assessments)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(assessment.title),
                  subtitle: Text(
                    '${assessment.category} · Period ${assessment.period} · ${assessment.points} points',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
