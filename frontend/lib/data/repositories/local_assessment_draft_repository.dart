import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/assessment_draft.dart';
import '../../domain/repositories/assessment_draft_repository.dart';

class LocalAssessmentDraftRepository implements AssessmentDraftRepository {
  const LocalAssessmentDraftRepository();

  static const _draftKey = 'promptlearn.assessments.math101.unit3.draft';

  @override
  Future<AssessmentDraft?> load() async {
    final raw = await SharedPreferencesAsync().getString(_draftKey);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map<String, Object?>) {
      throw const FormatException('Invalid assessment draft.');
    }
    return AssessmentDraft.fromJson(data);
  }

  @override
  Future<void> save(AssessmentDraft draft) =>
      SharedPreferencesAsync().setString(_draftKey, jsonEncode(draft.toJson()));
}
