import 'dart:typed_data';

class HomeworkQuestion {
  const HomeworkQuestion(this.id, this.prompt);

  final String id;
  final String prompt;
}

/// A box relative to the captured paper, with its origin at the top left.
class PaperRegion {
  const PaperRegion(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;

  bool get isValid =>
      [x, y, width, height].every((value) => value.isFinite) &&
      x >= 0 &&
      y >= 0 &&
      width > 0 &&
      height > 0 &&
      right <= 1.000001 &&
      bottom <= 1.000001;
}

class HomeworkCheckRequest {
  const HomeworkCheckRequest({
    required this.assignmentId,
    required this.question,
    required this.paperPng,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String assignmentId;
  final HomeworkQuestion question;
  final Uint8List paperPng;
  final int imageWidth;
  final int imageHeight;
}

enum HomeworkMarkStyle { circle, underline }

enum HomeworkReviewStatus {
  correct,
  needsRevision,
  unreadable;

  factory HomeworkReviewStatus.fromApi(Object? value) => switch (value) {
    'correct' => correct,
    'needs_revision' => needsRevision,
    'unreadable' => unreadable,
    _ => throw const FormatException('Unknown homework review status.'),
  };
}

class HomeworkIssue {
  const HomeworkIssue({
    required this.region,
    required this.observation,
    required this.hint,
  });

  final PaperRegion region;
  final String observation;
  final String hint;
}

class HomeworkFeedback {
  const HomeworkFeedback(
    this.hint, {
    this.region,
    this.markStyle = HomeworkMarkStyle.circle,
    this.isDemo = false,
    this.status,
    this.reviewId,
    this.issues = const [],
  });

  final String hint;
  final PaperRegion? region;
  final HomeworkMarkStyle markStyle;
  final bool isDemo;
  final HomeworkReviewStatus? status;
  final String? reviewId;
  final List<HomeworkIssue> issues;
}
