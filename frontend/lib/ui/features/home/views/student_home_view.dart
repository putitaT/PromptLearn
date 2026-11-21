import 'package:material_ui/material_ui.dart';

import '../../../core/layout/app_page_layout.dart';
import '../widgets/home_header.dart';
import '../widgets/student_coursework.dart';
import '../widgets/student_timetable.dart';

class StudentHomeView extends StatefulWidget {
  const StudentHomeView({
    super.key,
    required this.displayName,
    required this.now,
    required this.onOpenHomework,
  });

  final String displayName;
  final DateTime now;
  final VoidCallback onOpenHomework;

  @override
  State<StudentHomeView> createState() => _StudentHomeViewState();
}

class _StudentHomeViewState extends State<StudentHomeView> {
  late int _weekday = widget.now.weekday.clamp(
    DateTime.monday,
    DateTime.friday,
  );

  @override
  Widget build(BuildContext context) {
    return AppPageLayout(
      header: HomeHeader(displayName: widget.displayName, now: widget.now),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 880;
          final timetable = StudentTimetable(
            now: widget.now,
            weekday: _weekday,
            onDaySelected: (day) => setState(() => _weekday = day),
          );
          final coursework = StudentCoursework(
            now: widget.now,
            onOpenHomework: widget.onOpenHomework,
          );
          return Stack(
            children: [
              Positioned(
                top: -135,
                left: -90,
                width: 700,
                height: 380,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xffbcf8cf),
                        Color(0x70d9f8d3),
                        Color(0x00dbf8d5),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 42 : 16),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 407, child: timetable),
                          SizedBox(
                            width: constraints.maxWidth >= 1100 ? 50 : 24,
                          ),
                          Expanded(flex: 651, child: coursework),
                        ],
                      )
                    : Column(
                        children: [
                          timetable,
                          const SizedBox(height: 28),
                          coursework,
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
