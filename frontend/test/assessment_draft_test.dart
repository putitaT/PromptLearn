import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:promptlearn/domain/models/assessment_draft.dart';

void main() {
  test(
    'Assessment drafts round-trip with the question order and all settings',
    () {
      const draft = AssessmentDraft(
        kind: AssessmentKind.homework,
        timeLimitMinutes: 30,
        requireShownWork: false,
        acceptPhotos: false,
        homeworkHints: true,
        shuffleQuestions: false,
        questions: [
          AssessmentQuestion(
            kind: AssessmentQuestionKind.showWork,
            prompt: 'จงแสดงวิธีทำ 2³ × 2²',
            points: 3,
          ),
          AssessmentQuestion(
            kind: AssessmentQuestionKind.multipleChoice,
            prompt: 'Which power is equivalent?',
            points: 2,
            options: ['2⁵', '2⁶'],
          ),
        ],
      );

      final raw =
          jsonDecode(jsonEncode(draft.toJson())) as Map<String, Object?>;
      final restored = AssessmentDraft.fromJson(raw);

      expect(restored.toJson(), draft.toJson());
      expect(restored.totalPoints, 5);
    },
  );

  test('A draft with no saved fields loads as an empty quiz', () {
    final restored = AssessmentDraft.fromJson({});

    expect(restored.toJson(), const AssessmentDraft().toJson());
    expect(restored.totalPoints, 0);
  });
}
