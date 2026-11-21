import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/course_syllabus.dart';
import '../../domain/repositories/course_syllabus_repository.dart';

class ApiCourseSyllabusRepository implements CourseSyllabusRepository {
  const ApiCourseSyllabusRepository(this.baseUrl, this.client);

  final Uri baseUrl;
  final http.Client client;
  static const _timeout = Duration(seconds: 70);
  static const _json = {'Content-Type': 'application/json'};

  @override
  Future<List<CurriculumRow>> loadCurriculum(int grade) async {
    final uri = baseUrl
        .resolve('/v1/curriculum/math')
        .replace(queryParameters: {'grade': '$grade', 'course_type': 'core'});
    final catalog = _read(await client.get(uri).timeout(_timeout), 200);
    return [
      for (final group in catalog['groups'] as List)
        for (final row in group['rows'] as List)
          CurriculumRow.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<CourseSyllabusDraft> generate(
    CourseSyllabusSelection selection,
  ) async {
    final response = await _post('/v1/syllabi/draft', selection.toJson());
    return CourseSyllabusDraft.fromJson(selection, _read(response, 200));
  }

  @override
  Future<String> save(CourseSyllabusDraft draft) async {
    final response = await _post('/v1/syllabi', draft.toEditJson());
    final id = _read(response, 201)['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('The saved syllabus has no draft ID.');
    }
    return id;
  }

  Future<http.Response> _post(String path, Map<String, Object> body) {
    return client
        .post(baseUrl.resolve(path), headers: _json, body: jsonEncode(body))
        .timeout(_timeout);
  }

  Map<String, dynamic> _read(http.Response response, int expectedStatus) {
    if (response.statusCode != expectedStatus) {
      throw http.ClientException(
        'Syllabus API returned ${response.statusCode}.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
