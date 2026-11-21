import '../models/assessment_draft.dart';

abstract interface class AssessmentDraftRepository {
  Future<AssessmentDraft?> load();
  Future<void> save(AssessmentDraft draft);
}
