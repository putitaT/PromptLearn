import '../models/course_syllabus.dart';

abstract interface class CourseSyllabusRepository {
  Future<List<CurriculumRow>> loadCurriculum(int grade);
  Future<CourseSyllabusDraft> generate(CourseSyllabusSelection selection);
  Future<String> save(CourseSyllabusDraft draft);
}
