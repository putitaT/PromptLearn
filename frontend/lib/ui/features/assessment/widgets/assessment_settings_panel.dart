import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/assessment_draft.dart';
import '../../../core/theme/app_theme.dart';

const _green = Color(0xFF1E6C50);
const _line = Color(0xFFE6ECE8);

class AssessmentSettingsPanel extends StatelessWidget {
  const AssessmentSettingsPanel({
    super.key,
    required this.draft,
    required this.totals,
    required this.onChanged,
  });

  final AssessmentDraft draft;
  final String totals;
  final ValueChanged<AssessmentDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final homework = draft.kind == AssessmentKind.homework;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text(
          'Settings',
          style: typography.titleMedium?.copyWith(fontSize: 20, height: 1.3),
        ),
        Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assessment type',
              style: typography.labelLarge?.copyWith(
                fontSize: 13,
                color: AppColors.mutedText,
              ),
            ),
            _AssessmentTypePicker(
              selected: draft.kind,
              onSelected: (kind) => onChanged(draft.copyWith(kind: kind)),
            ),
          ],
        ),
        Column(
          spacing: 8,
          children: [
            const _SettingRow(
              icon: Icons.people_outline,
              label: 'Classes',
              value: Text('M.1/1 · M.1/2 · M.1/3', textAlign: TextAlign.end),
            ),
            const _SettingRow(
              icon: Icons.calendar_today_outlined,
              label: 'When',
              value: Text('Not scheduled', textAlign: TextAlign.end),
            ),
            _SettingRow(
              icon: Icons.schedule,
              label: 'Time limit',
              value: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: draft.timeLimitMinutes,
                  isDense: true,
                  iconSize: 17,
                  items: [
                    for (final minutes in {
                      0,
                      15,
                      30,
                      45,
                      60,
                      draft.timeLimitMinutes,
                    })
                      DropdownMenuItem(
                        value: minutes,
                        child: Text(minutes == 0 ? 'No limit' : '$minutes min'),
                      ),
                  ],
                  onChanged: (minutes) {
                    if (minutes != null) {
                      onChanged(draft.copyWith(timeLimitMinutes: minutes));
                    }
                  },
                  style: typography.labelLarge?.copyWith(fontSize: 13),
                ),
              ),
            ),
            _SettingRow(
              icon: Icons.star_border,
              label: 'Points',
              value: Text(totals, textAlign: TextAlign.end),
            ),
          ],
        ),
        const Divider(color: _line, height: 1),
        Column(
          spacing: 10,
          children: [
            _AssessmentSwitch(
              title: 'Require shown work',
              description: 'Ask students to show their solution steps.',
              value: draft.requireShownWork,
              onChanged: (enabled) =>
                  onChanged(draft.copyWith(requireShownWork: enabled)),
            ),
            _AssessmentSwitch(
              title: 'Accept photos of paper work',
              description: 'Accept a photo of handwritten work.',
              value: draft.acceptPhotos,
              onChanged: (enabled) =>
                  onChanged(draft.copyWith(acceptPhotos: enabled)),
            ),
            _AssessmentSwitch(
              title: 'AI Tutor hints',
              description: 'Available for homework.',
              value: homework && draft.homeworkHints,
              onChanged: homework
                  ? (enabled) =>
                        onChanged(draft.copyWith(homeworkHints: enabled))
                  : null,
            ),
            _AssessmentSwitch(
              title: 'Shuffle question order',
              value: draft.shuffleQuestions,
              onChanged: (enabled) =>
                  onChanged(draft.copyWith(shuffleQuestions: enabled)),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssessmentTypePicker extends StatelessWidget {
  const _AssessmentTypePicker({
    required this.selected,
    required this.onSelected,
  });

  final AssessmentKind selected;
  final ValueChanged<AssessmentKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          spacing: 4,
          children: [
            for (final kind in AssessmentKind.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: selected == kind,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected == kind
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: selected == kind
                          ? const [
                              BoxShadow(
                                color: Color(0x11000000),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => onSelected(kind),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 36),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Wrap(
                                spacing: 6,
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (selected == kind)
                                    const Icon(
                                      Icons.check,
                                      size: 15,
                                      color: _green,
                                    ),
                                  Text(
                                    kind == AssessmentKind.quiz
                                        ? 'Quiz'
                                        : 'Homework',
                                    style: typography.titleMedium?.copyWith(
                                      color: selected == kind
                                          ? null
                                          : AppColors.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return Row(
      spacing: 9,
      children: [
        Icon(icon, size: 18, color: AppColors.mutedText),
        Text(
          label,
          style: typography.bodySmall?.copyWith(
            fontSize: 13,
            color: AppColors.mutedText,
          ),
        ),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DefaultTextStyle.merge(
              style: typography.labelLarge?.copyWith(
                fontSize: 13,
                height: 18 / 13,
              ),
              child: value,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssessmentSwitch extends StatelessWidget {
  const _AssessmentSwitch({
    required this.title,
    this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                spacing: 2,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: typography.titleMedium),
                  if (description case final text?)
                    Text(
                      text,
                      style: typography.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            widthFactor: 0.8,
            child: Transform.scale(
              scale: 0.8,
              alignment: AlignmentDirectional.centerEnd,
              transformHitTests: false,
              child: Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? _green
                      : const Color(0xFFD1DAD5),
                ),
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
