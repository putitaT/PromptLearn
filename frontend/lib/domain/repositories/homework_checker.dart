import '../models/homework_check.dart';
import '../models/homework_submission.dart';

abstract interface class HomeworkChecker {
  Future<HomeworkFeedback> check(HomeworkCheckRequest request);
}

abstract interface class HomeworkSubmitter {
  Future<HomeworkSubmissionReport> submit(
    String assignmentId,
    List<String> reviewIds,
  );
}
