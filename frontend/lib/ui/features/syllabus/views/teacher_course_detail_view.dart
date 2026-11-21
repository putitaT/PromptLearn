import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../models/course_detail_preview.dart';
import '../models/syllabus_preview.dart';

const _ink = Color(0xFF202438);
const _line = Color(0xFFE6ECE8);

enum _CourseTab {
  info('Course Info', Icons.description_outlined),
  schedule('Teaching Schedule', Icons.calendar_today_outlined),
  assessment('Assessment', Icons.assignment_outlined);

  const _CourseTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class TeacherCourseDetailView extends StatefulWidget {
  const TeacherCourseDetailView({
    super.key,
    required this.course,
    this.navigation,
  });

  final SyllabusPreview course;
  final Widget? navigation;

  @override
  State<TeacherCourseDetailView> createState() =>
      _TeacherCourseDetailViewState();
}

class _TeacherCourseDetailViewState extends State<TeacherCourseDetailView> {
  static const _pageSize = 6;
  final _search = TextEditingController();
  final _dates = DateFormat('EEE d MMM yyyy', 'en_US');
  _CourseTab _tab = _CourseTab.schedule;
  int _room = 0;
  String _unit = 'All units';
  String _status = 'All';
  String _query = '';
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(VoidCallback change) => setState(() {
    change();
    _page = 0;
  });

  Future<void> _share(BuildContext context) async {
    final room = coursePreviewClasses(widget.course)[_room];
    final schedule = coursePreviewPeriods(widget.course, _room)
        .map(
          (item) =>
              '${_dates.format(item.date)} · ${item.slot} · ${item.topic}',
        )
        .join('\n');
    final target = context.findRenderObject()! as RenderBox;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${widget.course.title} · $room\nSample teaching schedule\n\n$schedule',
          sharePositionOrigin: target.localToGlobal(Offset.zero) & target.size,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share the schedule. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = coursePreviewPeriods(widget.course, _room);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0A1410),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 1000 && constraints.maxHeight >= 560;
            final nav = wide ? widget.navigation : null;
            final inset = wide ? 48.0 : 16.0;
            final edge = wide ? 22.0 : 8.0;
            final panel = Padding(
              padding: EdgeInsets.fromLTRB(
                nav == null ? edge : 0,
                edge,
                edge,
                edge,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(wide ? 44 : 22),
                child: ColoredBox(
                  color: const Color(0xFFF8F8F8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: Colors.white,
                        constraints: BoxConstraints(minHeight: wide ? 142 : 72),
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? inset : 8,
                          vertical: 10,
                        ),
                        child: Row(
                          spacing: wide ? 12 : 4,
                          children: [
                            IconButton(
                              tooltip: 'Back from course details',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                size: wide ? 26 : 18,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.course.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: wide ? 32 : 22,
                                  color: _ink,
                                ),
                              ),
                            ),
                            Builder(
                              builder: (context) => wide
                                  ? OutlinedButton.icon(
                                      style: _buttonStyle(),
                                      onPressed: () => _share(context),
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Share with students'),
                                    )
                                  : IconButton(
                                      tooltip: 'Share with students',
                                      onPressed: () => _share(context),
                                      icon: const Icon(Icons.share_outlined),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            const Positioned(
                              top: -72,
                              left: -120,
                              width: 620,
                              height: 420,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0xD99BECB4),
                                      Color(0x59C9F5D5),
                                      Color(0x00FFFFFF),
                                    ],
                                    stops: [0, 0.55, 1],
                                  ),
                                ),
                              ),
                            ),
                            SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                inset,
                                wide ? 32 : 16,
                                inset,
                                36,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 22,
                                children: [
                                  _CourseTabs(
                                    selected: _tab,
                                    onSelect: (tab) =>
                                        setState(() => _tab = tab),
                                  ),
                                  switch (_tab) {
                                    _CourseTab.schedule => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      spacing: 22,
                                      children: [
                                        _summary(rows),
                                        _schedule(rows),
                                      ],
                                    ),
                                    _CourseTab.info => _courseInfo(rows),
                                    _CourseTab.assessment => _assessments(rows),
                                  },
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (nav == null) return panel;
            return Row(
              children: [
                SizedBox(width: 112, child: nav),
                Expanded(child: panel),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summary(List<CoursePeriodPreview> rows) {
    final course = widget.course;
    final quiz = rows
        .where((item) => item.status == CoursePeriodStatus.quiz)
        .firstOrNull;
    final taught = course.taughtPeriods;
    final metrics = [
      ('Taught', '$taught / ${course.periods} periods'),
      ('Current unit', rows.first.unit),
      (
        'Next scored event',
        quiz == null ? 'None scheduled' : 'Quiz · ${_dates.format(quiz.date)}',
      ),
      ('Pace', course.isDraft ? 'Draft' : 'On track'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final columns = constraints.maxWidth >= 800
            ? 4
            : constraints.maxWidth >= 270
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (index, metric) in metrics.indexed)
              SizedBox(
                width: width,
                child: _Panel(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 76),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 5,
                      children: [
                        Text(
                          metric.$1,
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          metric.$2,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontSize: 16, color: _ink),
                        ),
                        if (index == 0)
                          LinearProgressIndicator(
                            value: taught / course.periods,
                            color: AppColors.accent,
                            backgroundColor: _line,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        if (index == 3 && !course.isDraft)
                          const Text(
                            '1 period rescheduled',
                            style: TextStyle(
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
      },
    );
  }

  Widget _schedule(List<CoursePeriodPreview> rows) {
    final units = ['All units', ...rows.map((row) => row.unit).toSet()];
    final query = _query.trim().toLowerCase();
    final filtered = rows
        .where(
          (row) =>
              (_unit == 'All units' || row.unit == _unit) &&
              (_status == 'All' || _status == row.status.label) &&
              '${row.topic} ${row.unit} ${row.notes} ${_dates.format(row.date)}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final pageCount = (filtered.length / _pageSize).ceil();
    final pageRows = filtered.skip(_page * _pageSize).take(_pageSize);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 12,
                runSpacing: 10,
                children: [
                  _Filter(
                    label: 'Class',
                    width: 136,
                    value: _room,
                    values: [
                      for (final (index, room) in coursePreviewClasses(
                        widget.course,
                      ).indexed)
                        (index, room),
                    ],
                    onChanged: (room) => _filter(() => _room = room!),
                  ),
                  _Filter(
                    label: 'Unit',
                    width: 178,
                    value: _unit,
                    values: [for (final unit in units) (unit, unit)],
                    onChanged: (unit) => _filter(() => _unit = unit!),
                  ),
                  _Filter<String>(
                    label: 'Status',
                    width: 146,
                    value: _status,
                    values: [
                      ('All', 'All'),
                      for (final status in CoursePeriodStatus.values)
                        (status.label, status.label),
                    ],
                    onChanged: (status) => _filter(() => _status = status!),
                  ),
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 190,
                    child: TextField(
                      controller: _search,
                      decoration: _inputDecoration.copyWith(
                        hintText: 'Search topics',
                        prefixIcon: const Icon(Icons.search, size: 18),
                      ),
                      onChanged: (value) => _filter(() => _query = value),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B0F0C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _filter(() => _query = _search.text);
                    },
                    child: const Text('Search'),
                  ),
                ],
              ),
            ],
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No periods match these filters.'),
            )
          else ...[
            _ScheduleTable(rows: pageRows, dates: _dates, onPlan: _showPlan),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 6,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page == 0 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left),
                ),
                for (var index = 0; index < pageCount; index++)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(40, 44),
                      padding: EdgeInsets.zero,
                      foregroundColor: _ink,
                      side: BorderSide(
                        color: _page == index ? AppColors.accent : _line,
                      ),
                    ),
                    onPressed: () => setState(() => _page = index),
                    child: Text('${index + 1}'),
                  ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page + 1 >= pageCount
                      ? null
                      : () => setState(() => _page++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPlan(CoursePeriodPreview row) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row.topic),
        content: Text(
          '${_dates.format(row.date)} · ${row.slot}\n${row.unit}\n\n${row.notes}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _courseInfo(List<CoursePeriodPreview> rows) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          widget.course.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('Grade ${widget.course.grade} · ${widget.course.periods} periods'),
        Text(
          '${widget.course.classCount} classes · ${widget.course.studentCount} students',
        ),
        Text(widget.course.status),
        const Divider(color: _line),
        for (final unit in rows.map((row) => row.unit).toSet()) Text(unit),
      ],
    ),
  );

  Widget _assessments(List<CoursePeriodPreview> rows) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text('Scored events', style: Theme.of(context).textTheme.titleLarge),
        if (widget.course.isDraft)
          const Text('No scored events have been scheduled for this draft.'),
        for (final row in rows.where(
          (item) => item.status == CoursePeriodStatus.quiz,
        ))
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              title: Text(row.topic),
              subtitle: Text('${_dates.format(row.date)} · ${row.slot}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPlan(row),
            ),
          ),
      ],
    ),
  );
}

const _inputDecoration = InputDecoration(
  isDense: true,
  fillColor: Colors.white,
  filled: true,
  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: _line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: _line),
  ),
);

ButtonStyle _buttonStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size(0, 44),
  foregroundColor: _ink,
  side: const BorderSide(color: _line),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

class _Filter<T> extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.width,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final double width;
  final T value;
  final List<(T, String)> values;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: _inputDecoration,
          items: [
            for (final (value, label) in values)
              DropdownMenuItem(
                value: value,
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _CourseTabs extends StatelessWidget {
  const _CourseTabs({required this.selected, required this.onSelect});
  final _CourseTab selected;
  final ValueChanged<_CourseTab> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      spacing: 24,
      children: [
        for (final tab in _CourseTab.values)
          Semantics(
            selected: tab == selected,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: tab == selected ? _ink : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: tab == selected ? _ink : AppColors.mutedText,
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: () => onSelect(tab),
                icon: Icon(tab.icon, size: 20),
                label: Text(tab.label),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({
    required this.rows,
    required this.dates,
    required this.onPlan,
  });
  final Iterable<CoursePeriodPreview> rows;
  final DateFormat dates;
  final ValueChanged<CoursePeriodPreview> onPlan;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: constraints.maxWidth < 850 ? 850 : constraints.maxWidth,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.45),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(2.2),
            3: FlexColumnWidth(1.45),
            4: FlexColumnWidth(1.15),
            5: FlexColumnWidth(1.85),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F6EF)),
              children: [
                for (final label in [
                  'Date',
                  'Period',
                  'Topic',
                  'Unit',
                  'Status',
                  'Notes',
                ])
                  _cell(
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            for (final row in rows)
              TableRow(
                decoration: BoxDecoration(
                  color: row.status == CoursePeriodStatus.today
                      ? const Color(0xFFF5F9FF)
                      : Colors.white,
                  border: const Border(top: BorderSide(color: _line)),
                ),
                children: [
                  _cell(Text(dates.format(row.date))),
                  _cell(Text(row.slot)),
                  _cell(
                    Text(
                      row.topic,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _cell(Text(row.unit)),
                  _cell(_StatusBadge(status: row.status)),
                  _cell(
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Text(
                            row.notes,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ),
                        IconButton.outlined(
                          tooltip: 'Edit plan',
                          style: IconButton.styleFrom(
                            foregroundColor: _ink,
                            minimumSize: const Size.square(44),
                            side: const BorderSide(color: _line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => onPlan(row),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    child: child,
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final CoursePeriodStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, accent) = switch (status) {
      CoursePeriodStatus.today => (
        const Color(0xFFEBF3FE),
        const Color(0xFF1276FF),
      ),
      CoursePeriodStatus.upcoming => (
        const Color(0xFFF2F1FF),
        const Color(0xFF4F47B5),
      ),
      CoursePeriodStatus.rescheduled => (
        const Color(0xFFFFEDEF),
        const Color(0xFFF4552E),
      ),
      CoursePeriodStatus.quiz => (
        const Color(0xFFFFEFD8),
        const Color(0xFFFF9D10),
      ),
      CoursePeriodStatus.taught => (
        const Color(0xFFFDFEFF),
        const Color(0xFF546270),
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(22)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A65776C),
          blurRadius: 40,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}
