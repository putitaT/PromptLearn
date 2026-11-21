import 'dart:ui';

import '../../../../domain/models/homework_check.dart';
import '../../../../domain/models/homework_submission.dart';

enum PaperTool { pen, highlighter, eraser }

class PaperStroke {
  const PaperStroke(this.tool, this.points);

  final PaperTool tool;
  final List<Offset> points;
}

class PaperContent {
  const PaperContent({this.strokes = const []});

  final List<PaperStroke> strokes;

  bool get hasWork => strokes.isNotEmpty;

  /// Removes entire strokes touched by this segment of the eraser gesture.
  PaperContent eraseBetween(Offset start, Offset end) {
    final keptStrokes = strokes.where((stroke) {
      var previous = stroke.points.first;
      for (final point in stroke.points) {
        if (_eraserHitsSegment(start, end, previous, point)) return false;
        previous = point;
      }
      return true;
    }).toList();
    if (keptStrokes.length == strokes.length) return this;
    return PaperContent(strokes: keptStrokes);
  }
}

const paperEraserRadius = 0.014;

class HomeworkDraft {
  PaperContent _content = const PaperContent();
  final List<PaperContent> _undoHistory = [];
  final List<PaperContent> _redoHistory = [];

  PaperContent get content => _content;
  bool get canUndo => _undoHistory.isNotEmpty;
  bool get canRedo => _redoHistory.isNotEmpty;

  void addInk(PaperTool tool, List<Offset> points) {
    assert(tool != PaperTool.eraser);
    if (points.isEmpty) return;
    commit(
      PaperContent(
        strokes: [
          ...content.strokes,
          PaperStroke(tool, List.unmodifiable(points)),
        ],
      ),
    );
  }

  void commit(PaperContent next) {
    if (identical(next, _content)) return;
    _rememberForUndo();
    _redoHistory.clear();
    _content = next;
  }

  void undo() {
    if (!canUndo) return;
    _redoHistory.add(_content);
    _content = _undoHistory.removeLast();
  }

  void redo() {
    if (!canRedo) return;
    _rememberForUndo();
    _content = _redoHistory.removeLast();
  }

  void _rememberForUndo() {
    if (_undoHistory.length == 24) _undoHistory.removeAt(0);
    _undoHistory.add(_content);
  }
}

bool _eraserHitsSegment(Offset a, Offset b, Offset c, Offset d) {
  const limit = paperEraserRadius * paperEraserRadius;
  if (_distanceToSegmentSquared(c, a, b) <= limit ||
      _distanceToSegmentSquared(d, a, b) <= limit ||
      _distanceToSegmentSquared(a, c, d) <= limit ||
      _distanceToSegmentSquared(b, c, d) <= limit) {
    return true;
  }

  double side(Offset start, Offset end, Offset point) {
    final axis = end - start;
    final relative = point - start;
    return axis.dx * relative.dy - axis.dy * relative.dx;
  }

  return side(a, b, c) * side(a, b, d) < 0 && side(c, d, a) * side(c, d, b) < 0;
}

double _distanceToSegmentSquared(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  final delta = point - start;
  if (lengthSquared == 0) return delta.distanceSquared;
  final fraction =
      ((delta.dx * segment.dx + delta.dy * segment.dy) / lengthSquared).clamp(
        0.0,
        1.0,
      );
  return (delta - segment * fraction).distanceSquared;
}

class HomeworkNotebook {
  static const assignmentId = 'hw-3-1';
  static const questions = [
    HomeworkQuestion('q1', 'Simplify x² · x³.'),
    HomeworkQuestion('q2', 'Simplify (a³)².'),
    HomeworkQuestion('q3', 'Simplify y⁶ ÷ y², where y ≠ 0.'),
    HomeworkQuestion('q5', 'Solve for x: x + 7 = 22.'),
  ];

  int activeIndex = 0;
  bool automatic = false;
  final _drafts = <int, HomeworkDraft>{};
  List<PaperContent>? _submittedWork;
  HomeworkSubmissionReport? _report;

  HomeworkDraft get draft =>
      _drafts.putIfAbsent(activeIndex, HomeworkDraft.new);

  bool hasWorkAt(int index) => _drafts[index]?.content.hasWork ?? false;

  bool get submitted {
    final submitted = _submittedWork;
    if (submitted == null) return false;
    for (var index = 0; index < questions.length; index++) {
      if (_drafts[index]?.content != submitted[index]) return false;
    }
    return true;
  }

  bool get canSubmit =>
      !submitted && Iterable<int>.generate(questions.length).every(hasWorkAt);

  List<PaperContent> get answerPapers => [
    for (var index = 0; index < questions.length; index++)
      _drafts[index]!.content,
  ];

  HomeworkSubmissionReport? get submittedReport => submitted ? _report : null;

  void recordSubmission(
    List<PaperContent> papers,
    HomeworkSubmissionReport? report,
  ) {
    _submittedWork = papers;
    _report = report;
  }

  bool submit() {
    if (!canSubmit) return false;
    recordSubmission(answerPapers, null);
    return true;
  }
}
