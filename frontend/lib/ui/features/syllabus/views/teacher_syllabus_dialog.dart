import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models/syllabus_preview.dart';
import '../widgets/syllabus_dashed_border.dart';

const _ink = Color(0xFF202438);
const _white = Color(0xFFFFFFFF);
const _mint = Color(0xFFE5F9D6);
const _createGreen = Color(0xFF017932);

class TeacherSyllabusDialog extends StatelessWidget {
  const TeacherSyllabusDialog({
    super.key,
    required this.syllabi,
    required this.onCreateSyllabus,
    required this.onOpenCourse,
  });

  final List<SyllabusPreview> syllabi;
  final VoidCallback onCreateSyllabus;
  final ValueChanged<SyllabusPreview> onOpenCourse;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 976, maxHeight: 891),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: _white,
      surfaceTintColor: _white,
      shadowColor: const Color(0x1A65776C),
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(38)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          final inset = wide ? 32.0 : 16.0;
          final topInset = wide ? 32.0 : 12.0;
          final gap = wide ? 22.0 : 14.0;
          final contentWidth = math.max(0.0, constraints.maxWidth - inset * 2);
          final columns = contentWidth >= 760
              ? 3
              : contentWidth >= 480
              ? 2
              : 1;
          final cardWidth = (contentWidth - gap * (columns - 1)) / columns;

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    topInset,
                    inset,
                    wide ? 18 : 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'My Syllabus',
                            style: _style(
                              context,
                              24,
                              weight: FontWeight.w700,
                              color: const Color(0xFF000000),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close syllabus',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(inset, 8, inset, 20),
                    child: Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final syllabus in syllabi)
                          SizedBox(
                            width: cardWidth,
                            child: _SyllabusCard(
                              syllabus: syllabus,
                              onTap: () => onOpenCourse(syllabus),
                            ),
                          ),
                        SizedBox(
                          width: cardWidth,
                          child: _CreateSyllabusCard(
                            onPressed: onCreateSyllabus,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SyllabusCard extends StatelessWidget {
  const _SyllabusCard({required this.syllabus, required this.onTap});

  final SyllabusPreview syllabus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final draft = syllabus.isDraft;

    return Container(
      constraints: const BoxConstraints(minHeight: 300),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A65776C),
            blurRadius: 40,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 140),
                color: syllabus.coverColor,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    child: Text(
                      syllabus.status,
                      style: _style(
                        context,
                        12,
                        weight: FontWeight.w600,
                        color: draft
                            ? const Color(0xFF1A1F60)
                            : const Color(0xFF22704F),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: 10,
                      children: [
                        Flexible(
                          child: Text(
                            syllabus.title,
                            style: _style(context, 20, weight: FontWeight.w700),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${syllabus.periods} periods',
                            textAlign: TextAlign.end,
                            style: _style(context, 18, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: draft
                            ? const Color(0xFFF2F3FF)
                            : const Color(0xFFE7F3EC),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          '${syllabus.grade}th Grade',
                          style: _style(
                            context,
                            13,
                            weight: FontWeight.w600,
                            height: 20 / 13,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${syllabus.classCount} classes · ${syllabus.studentCount} students',
                      style: _style(context, 13, color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateSyllabusCard extends StatelessWidget {
  const _CreateSyllabusCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const SyllabusDashedBorder(),
      child: Material(
        color: const Color(0xFFF7FCF9),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: _mint,
                  child: Icon(Icons.add, size: 26, color: _createGreen),
                ),
                Text(
                  'Create syllabus',
                  textAlign: TextAlign.center,
                  style: _style(
                    context,
                    17,
                    weight: FontWeight.w700,
                    color: _createGreen,
                  ),
                ),
                Text(
                  'Units, periods, scores and a teaching schedule in 6 steps',
                  textAlign: TextAlign.center,
                  style: _style(context, 14, color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _style(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _ink,
  double height = 1.25,
}) {
  return Theme.of(context).textTheme.bodyMedium!.copyWith(
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    height: height,
  );
}
