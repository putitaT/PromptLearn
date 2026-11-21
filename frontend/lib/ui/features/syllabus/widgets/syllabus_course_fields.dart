import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../view_models/syllabus_editor_view_model.dart';

class SyllabusCourseFields extends StatelessWidget {
  const SyllabusCourseFields({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  Future<void> _pickDate(BuildContext context, {required bool first}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: first ? draft.firstDay : draft.lastDay,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && context.mounted) {
      draft.setTeachingDay(selected, first: first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = draft.academicYear;
    final dates = DateFormat('EEE d MMM yyyy', 'en_US');
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 600;
        final half = width >= 380 ? (width - 16) / 2 : width;
        final quarter = wide ? (width - 48) / 4 : half;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 18,
          children: [
            Text(
              'Course',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 17),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: wide ? (width - 48) / 2 : half,
                  child: _Field(
                    label: 'Course name',
                    child: TextFormField(
                      initialValue: draft.courseName,
                      decoration: const InputDecoration(),
                      onChanged: draft.setCourseName,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a course name.'
                          : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: quarter,
                  child: _Field(
                    label: 'Subject code',
                    child: TextFormField(
                      initialValue: draft.courseCode,
                      decoration: const InputDecoration(),
                      onChanged: draft.setCourseCode,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: quarter,
                  child: _Field(
                    label: 'Grade',
                    child: _Select(
                      value: draft.grade,
                      values: const [1, 2, 3, 4, 5, 6],
                      label: (grade) => 'Mathayom $grade',
                      onChanged: draft.setGrade,
                    ),
                  ),
                ),
                SizedBox(
                  width: quarter,
                  child: _Field(
                    label: 'Credits',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        TextFormField(
                          initialValue: draft.credits,
                          decoration: const InputDecoration(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: draft.setCredits,
                          validator: (value) {
                            final credits = double.tryParse(value ?? '');
                            return credits == null ||
                                    !credits.isFinite ||
                                    credits <= 0
                                ? 'Enter valid credits.'
                                : null;
                          },
                        ),
                        const Text(
                          '1.5 credits = 3 periods / week',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6A7870),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: quarter,
                  child: _Field(
                    label: 'Academic year',
                    child: _Select(
                      value: year,
                      values: List.generate(11, (index) => 2023 + index),
                      label: (year) => '$year',
                      onChanged: draft.setAcademicYear,
                    ),
                  ),
                ),
                SizedBox(
                  width: quarter,
                  child: _Field(
                    label: 'Semester',
                    child: _Select(
                      value: draft.semester,
                      values: const [1, 2],
                      label: (semester) => '$semester',
                      onChanged: draft.setSemester,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                for (final first in [true, false])
                  SizedBox(
                    width: half,
                    child: _Field(
                      label: first ? 'First teaching day' : 'Last teaching day',
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          foregroundColor: const Color(0xFF202438),
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          side: const BorderSide(color: Color(0xFFE6ECE8)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _pickDate(context, first: first),
                        child: Text(
                          dates.format(first ? draft.firstDay : draft.lastDay),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (draft.dateError case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          ExcludeSemantics(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          child,
        ],
      ),
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final List<int> values;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey(value),
      initialValue: value,
      decoration: const InputDecoration(),
      isExpanded: true,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
      items: [
        for (final item in values)
          DropdownMenuItem(
            value: item,
            child: Text(label(item), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
