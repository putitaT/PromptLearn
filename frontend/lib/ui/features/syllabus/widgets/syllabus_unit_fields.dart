import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models/syllabus_unit_draft.dart';
import '../view_models/syllabus_editor_view_model.dart';
import 'syllabus_unit_colors.dart';

const _line = Color(0xFFE6ECE8);
const _ink = Color(0xFF202438);
const _white = Color(0xFFFFFFFF);
const _buffer = Color(0xFFC9C8C1);

typedef _Details = ({String title, int periods, String? reference});

class SyllabusUnitFields extends StatefulWidget {
  const SyllabusUnitFields({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  State<SyllabusUnitFields> createState() => _SyllabusUnitFieldsState();
}

class _SyllabusUnitFieldsState extends State<SyllabusUnitFields> {
  late int? _expandedUnit = widget.draft.units
      .where((unit) => unit.reference == 'ค 1.1 ม.1/2')
      .firstOrNull
      ?.id;
  EdgeDraggingAutoScroller? _dragScroller;

  @override
  void dispose() {
    _dragScroller?.stopAutoScroll();
    super.dispose();
  }

  void _startDrag() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      _dragScroller = EdgeDraggingAutoScroller(scrollable, velocityScalar: 18);
    }
  }

  void _updateDrag(DragUpdateDetails details) {
    final scroller = _dragScroller;
    if (scroller == null) return;
    scroller.startAutoScrollIfNecessary(
      Rect.fromCenter(center: details.globalPosition, width: 1, height: 56),
    );
  }

  void _endDrag(DraggableDetails details) {
    _dragScroller?.stopAutoScroll();
    _dragScroller = null;
  }

  Future<void> _editUnit([SyllabusUnitDraft? unit]) async {
    final draft = widget.draft;
    final result = await showDialog<_Details>(
      context: context,
      builder: (context) => _DetailsDialog(
        heading: unit == null ? 'Add unit' : 'Edit unit',
        title: unit?.title ?? '',
        periods: unit?.periods ?? 2,
        reference: unit?.reference,
        references: draft.unitReferences,
        onRemove: unit == null ? null : () => draft.removeUnit(unit.id),
      ),
    );
    if (!mounted || result == null) return;
    if (unit == null) {
      draft.addUnit(result.title, result.reference!, result.periods);
      setState(() => _expandedUnit = draft.units.last.id);
    } else {
      draft.replaceUnit(
        unit.copyWith(
          title: result.title,
          reference: result.reference,
          periods: result.periods,
        ),
      );
    }
  }

  Future<void> _editLesson(SyllabusUnitDraft unit, [int? index]) async {
    final lessons = [...unit.lessons];
    final lesson = index == null ? null : lessons[index];
    final result = await showDialog<_Details>(
      context: context,
      builder: (context) => _DetailsDialog(
        heading: lesson == null ? 'Add lesson' : 'Edit lesson',
        title: lesson?.title ?? '',
        periods: lesson?.periods ?? 2,
        onRemove: index == null
            ? null
            : () {
                lessons.removeAt(index);
                widget.draft.replaceUnit(unit.copyWith(lessons: lessons));
              },
      ),
    );
    if (!mounted || result == null) return;
    final replacement = (title: result.title, periods: result.periods);
    if (index == null) {
      lessons.add(replacement);
    } else {
      lessons[index] = replacement;
    }
    widget.draft.replaceUnit(unit.copyWith(lessons: lessons));
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final units = draft.units;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final (index, unit) in units.indexed)
          DragTarget<int>(
            key: ValueKey(unit.id),
            onWillAcceptWithDetails: (details) => details.data != unit.id,
            onAcceptWithDetails: (details) {
              final from = units.indexWhere((item) => item.id == details.data);
              if (from >= 0) draft.reorderUnit(from, index);
            },
            builder: (context, candidates, _) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _UnitCard(
                unit: unit,
                index: index,
                expanded: _expandedUnit == unit.id,
                highlighted: candidates.isNotEmpty,
                dragHandle: Tooltip(
                  message: 'Drag to reorder unit ${index + 1}',
                  triggerMode: TooltipTriggerMode.manual,
                  child: LongPressDraggable<int>(
                    data: unit.id,
                    axis: Axis.vertical,
                    maxSimultaneousDrags: 1,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    onDragStarted: _startDrag,
                    onDragUpdate: _updateDrag,
                    onDragEnd: _endDrag,
                    feedback: Transform.translate(
                      offset: const Offset(18, -18),
                      child: Material(
                        borderRadius: BorderRadius.circular(10),
                        elevation: 4,
                        color:
                            syllabusUnitColors[unit.colorIndex %
                                    syllabusUnitColors.length]
                                .fill,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            unit.title,
                            style: const TextStyle(color: _ink),
                          ),
                        ),
                      ),
                    ),
                    child: const SizedBox.square(
                      dimension: 44,
                      child: ColoredBox(
                        color: Colors.transparent,
                        child: Icon(
                          Icons.drag_indicator,
                          color: Color(0xFF59615E),
                        ),
                      ),
                    ),
                  ),
                ),
                onToggle: () => setState(() {
                  _expandedUnit = _expandedUnit == unit.id ? null : unit.id;
                }),
                onEdit: () => _editUnit(unit),
                onPeriodsChanged: (value) =>
                    draft.replaceUnit(unit.copyWith(periods: value)),
                onAddLesson: () => _editLesson(unit),
                onEditLesson: (index) => _editLesson(unit, index),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: _AddButton(label: 'Add unit', onPressed: _editUnit),
        ),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.index,
    required this.expanded,
    required this.highlighted,
    required this.dragHandle,
    required this.onToggle,
    required this.onEdit,
    required this.onPeriodsChanged,
    required this.onAddLesson,
    required this.onEditLesson,
  });

  final SyllabusUnitDraft unit;
  final int index;
  final bool expanded;
  final bool highlighted;
  final Widget dragHandle;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final ValueChanged<int> onPeriodsChanged;
  final VoidCallback onAddLesson;
  final ValueChanged<int> onEditLesson;

  @override
  Widget build(BuildContext context) {
    final number = index + 1;
    final tone =
        syllabusUnitColors[unit.colorIndex % syllabusUnitColors.length];
    final border = Border.all(
      color: expanded ? tone.accent : _line,
      width: expanded ? 2 : 1,
    );
    final lessons = unit.lessons;
    return Container(
      key: ValueKey('unit-card-${unit.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? tone.fill : _white,
        border: border,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              void toggleAndReveal() {
                onToggle();
                if (expanded) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  Scrollable.ensureVisible(
                    context,
                    alignmentPolicy:
                        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
                    duration: const Duration(milliseconds: 160),
                  );
                });
              }

              final title = Row(
                spacing: 8,
                children: [
                  dragHandle,
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: tone.fill,
                    foregroundColor: _ink,
                    child: Text('$number'),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: toggleAndReveal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              unit.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            Text(
                              '${unit.reference} · ${lessons.length} ${lessons.length == 1 ? 'lesson' : 'lessons'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
              final controls = Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  const Text(
                    'Periods',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                  ),
                  SizedBox(
                    width: 64,
                    child: Semantics(
                      label: 'Periods for unit $number',
                      child: _UnitPeriodField(
                        periods: unit.periods,
                        onChanged: onPeriodsChanged,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        '${expanded ? 'Hide' : 'Show'} lessons in unit $number',
                    onPressed: toggleAndReveal,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: _ink,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 490) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 6,
                  children: [
                    title,
                    Align(alignment: Alignment.centerRight, child: controls),
                  ],
                );
              }
              return Row(
                spacing: 12,
                children: [
                  Expanded(child: title),
                  controls,
                ],
              );
            },
          ),
          if (expanded) ...[
            const Divider(color: _line, height: 1),
            for (final (lessonIndex, lesson) in lessons.indexed)
              InkWell(
                onTap: () => onEditLesson(lessonIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Text(
                          lesson.title == 'Review + Quiz'
                              ? lesson.title
                              : '$number.${lessonIndex + 1} ${lesson.title}',
                          style: const TextStyle(fontSize: 13, color: _ink),
                        ),
                      ),
                      Text(
                        _periodLabel(lesson.periods),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (unit.lessonPeriods != unit.periods)
              Text(
                '${unit.lessonPeriods} of ${unit.periods} unit periods assigned to lessons',
                style: const TextStyle(fontSize: 12, color: Color(0xFF963F14)),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AddButton(label: 'Add lesson', onPressed: onAddLesson),
                TextButton(onPressed: onEdit, child: const Text('Edit unit')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UnitPeriodField extends StatefulWidget {
  const _UnitPeriodField({required this.periods, required this.onChanged});

  final int periods;
  final ValueChanged<int> onChanged;

  @override
  State<_UnitPeriodField> createState() => _UnitPeriodFieldState();
}

class _UnitPeriodFieldState extends State<_UnitPeriodField> {
  late final _controller = TextEditingController(
    text: widget.periods == 0 ? '' : '${widget.periods}',
  );

  @override
  void didUpdateWidget(covariant _UnitPeriodField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.periods != oldWidget.periods &&
        (int.tryParse(_controller.text) ?? 0) != widget.periods) {
      _controller.text = widget.periods == 0 ? '' : '${widget.periods}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    decoration: const InputDecoration(
      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    ),
    textAlign: TextAlign.center,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(3),
    ],
    onChanged: (value) => widget.onChanged(int.tryParse(value) ?? 0),
  );
}

class SyllabusPeriodBudget extends StatelessWidget {
  const SyllabusPeriodBudget({super.key, required this.draft});

  final SyllabusEditorViewModel draft;

  @override
  Widget build(BuildContext context) {
    final units = draft.units;
    final available = draft.teachingTime.available;
    final planned = draft.plannedPeriods;
    final buffer = draft.orientationPeriods;
    final remaining = available - planned - buffer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text(
          'Period budget',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontSize: 17, color: _ink),
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$planned',
              key: const ValueKey('planned-unit-periods'),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            Text(
              'of $available periods planned',
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ],
        ),
        ClipRRect(
          key: const ValueKey('period-budget-bar'),
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                if (planned == 0 && available == 0)
                  const Expanded(child: ColoredBox(color: _line)),
                for (final unit in units)
                  if (unit.periods > 0)
                    Expanded(
                      flex: unit.periods,
                      child: ColoredBox(
                        color:
                            syllabusUnitColors[unit.colorIndex %
                                    syllabusUnitColors.length]
                                .accent,
                      ),
                    ),
                if (buffer > 0)
                  Expanded(
                    flex: buffer,
                    child: const ColoredBox(color: _buffer),
                  ),
                if (remaining > 0)
                  Expanded(
                    flex: remaining,
                    child: const ColoredBox(color: _line),
                  ),
              ],
            ),
          ),
        ),
        for (final (index, unit) in units.indexed)
          _BudgetLine(
            title: 'Unit ${index + 1} · ${unit.title}',
            periods: unit.periods,
            color:
                syllabusUnitColors[unit.colorIndex % syllabusUnitColors.length]
                    .accent,
          ),
        _BudgetLine(
          title: 'Orientation & buffer',
          periods: buffer,
          color: _buffer,
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: remaining < 0
                ? const Color(0xFFFFF3EA)
                : const Color(0xFFE7F3EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            spacing: 8,
            children: [
              Icon(
                remaining < 0 ? Icons.warning_amber_rounded : Icons.check,
                size: 16,
                color: remaining < 0
                    ? const Color(0xFF963F14)
                    : const Color(0xFF22704F),
              ),
              Expanded(
                child: Text(
                  remaining < 0
                      ? '${_periodLabel(-remaining)} over your timetable'
                      : 'Fits your timetable with ${_periodLabel(remaining)} to spare',
                  style: const TextStyle(fontSize: 13, color: _ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine({
    required this.title,
    required this.periods,
    required this.color,
  });

  final String title;
  final int periods;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Text(title, style: const TextStyle(color: _ink, fontSize: 13)),
        ),
        Text(
          '$periods',
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      side: const BorderSide(color: _line),
      backgroundColor: _white,
      foregroundColor: _ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.add, size: 18),
    label: Text(label),
  );
}

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({
    required this.heading,
    required this.title,
    required this.periods,
    this.reference,
    this.references = const [],
    this.onRemove,
  });

  final String heading;
  final String title;
  final int periods;
  final String? reference;
  final List<String> references;
  final VoidCallback? onRemove;

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  final _form = GlobalKey<FormState>();
  late String _title = widget.title;
  late int _periods = widget.periods;
  late String? _reference = widget.references.contains(widget.reference)
      ? widget.reference
      : widget.references.firstOrNull;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.heading),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            TextFormField(
              initialValue: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (value) => _title = value.trim(),
              validator: (_) => _title.isEmpty ? 'Enter a title.' : null,
            ),
            TextFormField(
              initialValue: '$_periods',
              decoration: const InputDecoration(labelText: 'Periods'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: (value) => _periods = int.tryParse(value) ?? 0,
              validator: (_) =>
                  _periods < 1 ? 'Enter at least one period.' : null,
            ),
            if (widget.references.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _reference,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Indicator'),
                items: [
                  for (final reference in widget.references)
                    DropdownMenuItem(
                      value: reference,
                      child: Text(reference, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => _reference = value,
              ),
          ],
        ),
      ),
      actions: [
        if (widget.onRemove case final remove?)
          TextButton(
            onPressed: () {
              remove();
              Navigator.of(context).pop();
            },
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(
                context,
              ).pop((title: _title, periods: _periods, reference: _reference));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

String _periodLabel(int count) => '$count ${count == 1 ? 'period' : 'periods'}';
