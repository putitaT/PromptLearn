import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/assessment_draft.dart';
import '../../../../domain/repositories/assessment_draft_repository.dart';

enum DraftSaveState { loading, newDraft, saving, saved, loadFailed, saveFailed }

class AssessmentDraftController extends ChangeNotifier {
  AssessmentDraftController(this._repository) {
    unawaited(load());
  }

  final AssessmentDraftRepository _repository;
  var _draft = const AssessmentDraft();
  var _state = DraftSaveState.loading;
  var _revision = 0;
  var _disposed = false;
  Future<void> _writes = Future.value();

  AssessmentDraft get draft => _draft;
  DraftSaveState get state => _state;

  Future<void> load() async {
    _state = DraftSaveState.loading;
    _notify();
    try {
      final stored = await _repository.load();
      _draft = stored ?? const AssessmentDraft();
      _state = stored == null ? DraftSaveState.newDraft : DraftSaveState.saved;
    } catch (_) {
      _state = DraftSaveState.loadFailed;
    }
    _notify();
  }

  void update(AssessmentDraft draft) {
    _draft = draft;
    _state = DraftSaveState.saving;
    final revision = ++_revision;
    _notify();

    _writes = _writes.then((_) async {
      // A newer snapshot already contains all intermediate edits.
      if (revision != _revision) return;
      var result = DraftSaveState.saved;
      try {
        await _repository.save(draft);
      } catch (_) {
        result = DraftSaveState.saveFailed;
      }
      if (revision == _revision) {
        _state = result;
        _notify();
      }
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
