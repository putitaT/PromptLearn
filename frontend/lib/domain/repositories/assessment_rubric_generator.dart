import '../models/assessment_draft.dart';
import '../models/assessment_rubric.dart';

abstract interface class AssessmentRubricGenerator {
  Future<QuestionRubric> generate({
    required AssessmentQuestion question,
    required String lessonTitle,
    required List<String> lessonSteps,
    String? teacherRequest,
  });
}

class RubricGenerationFailure implements Exception {
  const RubricGenerationFailure(this.message);

  final String message;
}
