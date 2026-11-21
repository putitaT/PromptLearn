import 'dart:convert';

import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

bool get androidHttpInspectionEnabled =>
    kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

http.Client createApiHttpClient() {
  final client = http.Client();
  return androidHttpInspectionEnabled ? _InspectedHttpClient(client) : client;
}

Future<http.Response> sendHomeworkReview(
  http.Client client,
  http.Request request, {
  required Map<String, String> requestPreview,
}) async {
  if (!androidHttpInspectionEnabled) {
    return http.Response.fromStream(await client.send(request));
  }

  final inspection = _HomeworkInspectionTransport(client, request);
  final preview =
      http.Request(
          request.method,
          request.url.replace(userInfo: '', query: '', fragment: ''),
        )
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(requestPreview);
  try {
    await ChuckerHttpClient(inspection).send(preview);
  } on Exception {
    if (!inspection.sent) {
      return http.Response.fromStream(await client.send(request));
    }
    if (inspection.response == null) rethrow;
    debugPrint('Chucker could not save the homework review preview.');
  }
  return inspection.response!;
}

// Chucker records the shortened request and the review JSON. The checker
// receives the original response.
class _HomeworkInspectionTransport extends http.BaseClient {
  _HomeworkInspectionTransport(this._client, this._request);

  final http.Client _client;
  final http.Request _request;
  http.Response? response;
  bool sent = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest preview) async {
    sent = true;
    final actual = await http.Response.fromStream(await _client.send(_request));
    response = actual;
    final body = utf8.encode(jsonEncode(_reviewPreview(actual.bodyBytes)));
    return http.StreamedResponse(
      http.ByteStream.fromBytes(body),
      actual.statusCode,
      request: preview,
      headers: const {'content-type': 'application/json'},
      contentLength: body.length,
    );
  }

  Map<String, dynamic> _reviewPreview(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is Map<String, dynamic>) {
        return {
          for (final key in [
            'review_id',
            'assignment_id',
            'item_id',
            'status',
            'message',
            'issues',
            'code',
          ])
            if (json.containsKey(key)) key: json[key],
        };
      }
    } on FormatException {
      // Some network errors have a non-JSON response body.
    }
    return {'message': 'No review JSON in this response.'};
  }
}

class _InspectedHttpClient extends http.BaseClient {
  _InspectedHttpClient(this._transport);

  final http.Client _transport;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Chucker tracks timing on the interceptor instance. Isolate it per request
    // while reusing the same socket pool for concurrent requests.
    return ChuckerHttpClient(_transport).send(request);
  }

  @override
  void close() => _transport.close();
}
