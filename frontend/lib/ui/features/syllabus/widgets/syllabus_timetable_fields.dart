import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../view_models/syllabus_editor_view_model.dart';

const _line = Color(0xFFE6ECE8);
const _classColors = [
  (fill: Color(0xFFE5F9D6), border: Color(0xFF4ABE7A), text: Color(0xFF017932)),
  (fill: Color(0xFFE2F3F2), border: Color(0xFF0F6E6E), text: Color(0xFF0F6E6E)),
  (fill: Color(0xFFF2EAF9), border: Color(0xFF7A3FA8), text: Color(0xFF7A3FA8)),
  (fill: Color(0xFFFFF3EA), border: Color(0xFFC87239), text: Color(0xFF963F14)),
];

class SyllabusTimetableFields extends StatelessWidget {
  const SyllabusTimetableFields({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  Future<void> _addClass(BuildContext context) async {
    final room = await showDialog<TeachingClass>(
      context: context,
      builder: (context) => _AddTeachingClassDialog(draft: draft),
    );
    if (room != null && context.mounted) draft.addClass(room);
  }

  @override
  Widget build(BuildContext context) {
    final classes = draft.classes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              'Classes & weekly timetable',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 17),
            ),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Timetable import is unavailable in this preview. You can assign periods in the grid.',
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF3EA),
                foregroundColor: const Color(0xFF963F14),
                side: const BorderSide(color: Color(0xFFFFD7C2)),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('Import school timetable'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var index = 0; index < classes.length; index++)
              _ClassChoice(
                room: classes[index],
                index: index,
                selected: draft.selectedClass == index,
                onSelected: () => draft.selectClass(index),
              ),
            OutlinedButton.icon(
              onPressed: () => _addClass(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF202438),
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add class'),
            ),
          ],
        ),
        const Text(
          'Tap a slot to assign it to the selected class. Tap it again to clear it.',
          style: TextStyle(fontSize: 13, color: AppColors.mutedText),
        ),
        _TimetableGrid(draft: draft, classes: classes),
      ],
    );
  }
}

class _ClassChoice extends StatelessWidget {
  const _ClassChoice({
    required this.room,
    required this.index,
    required this.selected,
    required this.onSelected,
  });

  final TeachingClass room;
  final int index;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final tone = _classColors[index % _classColors.length];
    return ChoiceChip(
      label: Text('${room.name} · ${room.students} students'),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(color: tone.text, fontWeight: FontWeight.w600),
      backgroundColor: tone.fill,
      selectedColor: tone.fill,
      side: BorderSide(color: tone.border, width: selected ? 2.5 : 1),
      shape: const StadiumBorder(),
      onSelected: (_) => onSelected(),
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({required this.draft, required this.classes});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  final SyllabusEditorViewModel draft;
  final List<TeachingClass> classes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(512.0, constraints.maxWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              spacing: 4,
              children: [
                Row(
                  spacing: 4,
                  children: [
                    const SizedBox(width: 56),
                    for (var period = 1; period <= 8; period++)
                      Expanded(
                        child: Text(
                          'P$period',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                  ],
                ),
                for (var day = 1; day <= _weekdays.length; day++)
                  Row(
                    spacing: 4,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          _weekdays[day - 1],
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      for (var period = 1; period <= 8; period++)
                        Expanded(
                          child: _cell((
                            weekday: day,
                            period: period,
                          ), label: '${_weekdays[day - 1]} period $period'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(WeeklyPeriod period, {required String label}) {
    final index = draft.classFor(period);
    final room = index == null ? null : classes[index];
    final tone = index == null
        ? null
        : _classColors[index % _classColors.length];
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: tone?.border ?? _line,
        width: index == null ? 1 : 1.5,
      ),
    );
    return Semantics(
      label: '$label, ${room?.name ?? 'free'}',
      button: true,
      child: Material(
        color: tone?.fill ?? const Color(0xFFFFFFFF),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('slot-${period.weekday}-${period.period}'),
          onTap: () => draft.togglePeriod(period),
          customBorder: shape,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            alignment: Alignment.center,
            child: room == null
                ? null
                : ExcludeSemantics(
                    child: Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: tone!.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AddTeachingClassDialog extends StatefulWidget {
  const _AddTeachingClassDialog({required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  State<_AddTeachingClassDialog> createState() =>
      _AddTeachingClassDialogState();
}

class _AddTeachingClassDialogState extends State<_AddTeachingClassDialog> {
  final _form = GlobalKey<FormState>();
  String _name = '';
  String _students = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add class'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            TextFormField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Class name'),
              onChanged: (value) => _name = value.trim(),
              validator: (_) {
                if (_name.isEmpty) return 'Enter a class name.';
                if (widget.draft.hasClass(_name)) {
                  return 'This class is already listed.';
                }
                return null;
              },
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Number of students',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _students = value.trim(),
              validator: (_) {
                final count = int.tryParse(_students);
                return count == null || count <= 0
                    ? 'Enter a positive whole number.'
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context)
                .pop((name: _name, students: int.parse(_students)));
          },
          child: const Text('Add class'),
        ),
      ],
    );
  }
}
