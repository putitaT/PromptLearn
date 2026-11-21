import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../domain/models/homework_check.dart';
import '../../domain/models/homework_submission.dart';
import '../../domain/repositories/homework_checker.dart';
import '../services/api_http_client.dart';

class ApiHomeworkChecker implements HomeworkChecker, HomeworkSubmitter {
  const ApiHomeworkChecker(this.baseUrl, this.client);

  final Uri baseUrl;
  final http.Client client;

  @override
  Future<HomeworkFeedback> check(HomeworkCheckRequest request) async {
    final assignment = Uri.encodeComponent(request.assignmentId);
    final item = Uri.encodeComponent(request.question.id);
    const mimePrefix = 'data:image/png;base64,';
    const language = 'en';
    final image = base64Encode(request.paperPng);
    final reviewRequest =
        http.Request(
            'POST',
            baseUrl.resolve('/v1/assignments/$assignment/items/$item/reviews'),
          )
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'image_data_url': '$mimePrefix$image',
            'language': language,
          });
    final response = await sendHomeworkReview(
      client,
      reviewRequest,
      requestPreview: {
        // The first 24 Base64 characters of a PNG contain header bytes only.
        'image_data_url':
            '$mimePrefix${image.substring(0, math.min(24, image.length))}...',
        'language': language,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Homework review failed (${response.statusCode}).',
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic> ||
        json['assignment_id'] != request.assignmentId ||
        json['item_id'] != request.question.id ||
        json['message'] is! String ||
        json['issues'] is! List ||
        json['review_id'] is! String) {
      throw const FormatException('Invalid homework review response.');
    }
    final status = HomeworkReviewStatus.fromApi(json['status']);
    final issues = (json['issues'] as List)
        .map(_parseIssue)
        .toList(growable: false);
    if (issues.length > 3 ||
        (status == HomeworkReviewStatus.needsRevision) != issues.isNotEmpty) {
      throw const FormatException('Homework findings do not match the status.');
    }
    return HomeworkFeedback(
      json['message'] as String,
      status: status,
      reviewId: json['review_id'] as String,
      issues: issues,
    );
  }

  @override
  Future<HomeworkSubmissionReport> submit(
    String assignmentId,
    List<String> reviewIds,
  ) async {
    final assignment = Uri.encodeComponent(assignmentId);
    final response = await client
        .post(
          baseUrl.resolve('/v1/assignments/$assignment/submissions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'review_ids': reviewIds}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 201) {
      throw http.ClientException(
        'Homework submission failed (${response.statusCode}).',
      );
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (data['assignment_id'] != assignmentId) {
      throw const FormatException(
        'Homework result is for a different assignment.',
      );
    }
    return HomeworkSubmissionReport.fromJson(data);
  }

  HomeworkIssue _parseIssue(dynamic issue) {
    if (issue is! Map<String, dynamic> ||
        issue['box'] is! Map<String, dynamic> ||
        issue['hint'] is! String ||
        issue['observation'] is! String) {
      throw const FormatException('Invalid homework issue.');
    }
    final box = issue['box'] as Map<String, dynamic>;
    double coordinate(String name) {
      final value = box[name];
      if (value is! num) {
        throw const FormatException('Invalid paper coordinate.');
      }
      return value.toDouble();
    }

    final region = PaperRegion(
      coordinate('x'),
      coordinate('y'),
      coordinate('width'),
      coordinate('height'),
    );
    if (!region.isValid) {
      throw const FormatException('Issue is outside the paper.');
    }
    return HomeworkIssue(
      region: region,
      observation: issue['observation'] as String,
      hint: issue['hint'] as String,
    );
  }
}
