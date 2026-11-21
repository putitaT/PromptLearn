import '../../domain/models/homework_check.dart';
import '../../domain/repositories/homework_checker.dart';

class MockHomeworkChecker implements HomeworkChecker {
  const MockHomeworkChecker();

  @override
  Future<HomeworkFeedback> check(HomeworkCheckRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return const HomeworkFeedback('Snapshot received.', isDemo: true);
  }
}
