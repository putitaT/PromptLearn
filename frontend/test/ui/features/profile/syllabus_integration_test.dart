import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:promptlearn/app/prompt_learn_app.dart';
import 'package:promptlearn/data/repositories/api_course_syllabus_repository.dart';
import 'package:promptlearn/domain/models/user_role.dart';
import 'package:promptlearn/domain/repositories/role_repository.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await inter.load();
  });

  testWidgets(
    'Teacher Profile generates and saves a selected semester from Go API data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const export = MethodChannel('promptlearn/syllabus_export');
      final messenger = tester.binding.defaultBinaryMessenger;
      final exports = <MethodCall>[];
      messenger.setMockMethodCallHandler(export, (call) async {
        exports.add(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(export, null));
      const first = 'core/2/1.2/1';
      const second = 'core/2/1.2/2';
      Map<String, Object> row(String id, String title) => {
        'id': id,
        'title': title,
        'outcomes': [
          {'code': 'ค 1.2 ม.2/1', 'text': 'Explain mathematical reasoning.'},
        ],
      };
      final requests = <String>[];
      final grades = <String?>[];
      http.Response jsonResponse(Map<String, Object> body) =>
          http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      final client = MockClient((request) async {
        final path = request.url.path;
        requests.add('${request.method} $path');
        if (path == '/v1/curriculum/math') {
          expect(request.url.queryParameters['course_type'], 'core');
          grades.add(request.url.queryParameters['grade']);
          return jsonResponse({
            'groups': [
              {
                'rows': request.url.queryParameters['grade'] == '2'
                    ? [
                        row(first, 'Polynomial operations'),
                        row(second, 'Factoring polynomials'),
                      ]
                    : [row('core/1/1.1/1', 'Rational numbers')],
              },
            ],
          });
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (path == '/v1/syllabi/draft') {
          expect(body['grade'], 2);
          expect(body['term'], 2);
          expect(body['reference_ids'], [first, second]);
          return jsonResponse({
            'description': 'Work with polynomials in a one-semester course.',
            'references': [
              {'row': row(first, 'Polynomial operations')},
              {'row': row(second, 'Factoring polynomials')},
            ],
            'units': [
              {
                'title': 'Operations',
                'reference_ids': [first],
                'sessions': [
                  for (var i = 1; i <= 30; i++)
                    {'number': i, 'title': 'Polynomial operations $i'},
                ],
                'assessments': [],
              },
              {
                'title': 'Factoring',
                'reference_ids': [second],
                'sessions': [
                  for (var i = 31; i <= 54; i++)
                    {'number': i, 'title': 'Factoring practice $i'},
                ],
                'assessments': [
                  {
                    'session': 31,
                    'category': 'Unit Quizzes',
                    'title': 'Factoring quiz',
                    'points': 30,
                  },
                ],
              },
            ],
            'document_html': '<h1>Mathematics</h1>',
          });
        }
        expect(path, '/v1/syllabi');
        expect(body['course']['term'], 2);
        expect(body['plan']['units'][1]['assessments'][0]['session'], 1);
        return http.Response('{"id":"saved-draft"}', 201);
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        PromptLearnApp(
          roleRepository: _TeacherRoleRepository(),
          syllabusRepository: ApiCourseSyllabusRepository(
            Uri.parse('http://127.0.0.1:8080'),
            client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test syllabus integration'));
      await tester.pumpAndSettle();
      final selectors = find.byType(DropdownButtonFormField<int>);
      await tester.tap(selectors.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ม.2').last);
      await tester.pumpAndSettle();
      expect(grades, ['1', '2']);
      expect(find.text('Polynomial operations'), findsOneWidget);
      await tester.tap(selectors.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semester 2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Polynomial operations'));
      await tester.tap(find.text('Factoring polynomials'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate draft'));
      await tester.pumpAndSettle();
      expect(find.text('Syllabus draft'), findsOneWidget);
      expect(
        find.text('Work with polynomials in a one-semester course.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Download HTML'));
      await tester.pumpAndSettle();
      expect(exports.single.method, 'saveHtml');
      expect(
        exports.single.arguments['fileName'],
        'PromptLearn-M2-Semester-2.html',
      );
      expect(exports.single.arguments['contents'], isA<Uint8List>());
      expect(
        utf8.decode(exports.single.arguments['contents'] as Uint8List),
        '<h1>Mathematics</h1>',
      );
      expect(find.text('Saved HTML to your device.'), findsOneWidget);
      expect(requests, [
        'GET /v1/curriculum/math',
        'GET /v1/curriculum/math',
        'POST /v1/syllabi/draft',
      ]);

      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.text('Draft saved · saved-draft'), findsOneWidget);
      expect(find.text('Saved to backend'), findsOneWidget);
      expect(requests, [
        'GET /v1/curriculum/math',
        'GET /v1/curriculum/math',
        'POST /v1/syllabi/draft',
        'POST /v1/syllabi',
      ]);
    },
  );
}

class _TeacherRoleRepository implements RoleRepository {
  @override
  Future<UserRole?> load() async => UserRole.teacher;

  @override
  Future<void> save(UserRole role) async {}

  @override
  Future<void> clear() async {}
}
