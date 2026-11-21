import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef ReplayJson = Map<String, dynamic>;

class ReplayApiException implements Exception {
  const ReplayApiException(this.message);

  final String message;

  static String messageFor(Object? error) => error is ReplayApiException
      ? error.message
      : 'เชื่อมต่อเดโมไม่สำเร็จ ลองใหม่อีกครั้ง';
}

abstract final class ReplayApi {
  static Future<ReplayJson> published() => _request('GET', '/api/demo/replay');

  static Future<web.Blob> preview(
    String recordingId,
    web.AbortSignal signal,
  ) async {
    final path =
        '/api/demo/recordings/${Uri.encodeComponent(recordingId)}/preview';
    final headers = web.Headers()..set('X-Demo-Role', 'teacher');
    final response = await web.window
        .fetch(
          path.toJS,
          web.RequestInit(headers: headers, signal: signal, cache: 'no-store'),
        )
        .toDart;
    if (!response.ok) {
      throw const ReplayApiException('เปิดพรีวิวคลิปไม่ได้ ลองใหม่อีกครั้ง');
    }
    return response.blob().toDart;
  }

  static Future<String> upload(
    web.File video,
    void Function(double?) onProgress,
  ) async {
    final form = web.FormData()..append('video', video, video.name);
    final result = await _request(
      'POST',
      '/api/demo/recordings',
      body: form,
      onProgress: onProgress,
    );
    return result['recordingId'] as String;
  }

  static Future<void> publish(String recordingId) async {
    await _request(
      'PUT',
      '/api/demo/publication',
      body: jsonEncode({'recordingId': recordingId}).toJS,
      json: true,
    );
  }

  static Future<ReplayJson> _request(
    String method,
    String path, {
    JSAny? body,
    bool json = false,
    void Function(double?)? onProgress,
  }) {
    final result = Completer<ReplayJson>();
    final request = web.XMLHttpRequest()
      ..open(method, path)
      ..timeout = onProgress == null ? 90000 : 250000;
    if (method != 'GET') request.setRequestHeader('X-Demo-Role', 'teacher');
    if (json) request.setRequestHeader('Content-Type', 'application/json');
    if (onProgress != null) {
      request.upload.onprogress = ((web.ProgressEvent event) {
        onProgress(
          event.lengthComputable && event.total > 0
              ? (event.loaded / event.total).clamp(0, 1).toDouble()
              : null,
        );
      }).toJS;
    }

    void failed(web.Event _) {
      result.completeError(
        const ReplayApiException('เชื่อมต่อเดโมไม่สำเร็จ ลองใหม่อีกครั้ง'),
      );
    }

    request
      ..onerror = failed.toJS
      ..ontimeout = failed.toJS
      ..onload = ((web.Event _) {
        try {
          final status = request.status;
          final payload = jsonDecode(request.responseText) as ReplayJson;
          if (status < 200 || status >= 300) {
            throw ReplayApiException(
              payload['message'] as String? ?? 'จัดการคลิปไม่สำเร็จ',
            );
          }
          result.complete(payload);
        } on FormatException {
          result.completeError(
            const ReplayApiException(
              'เปิดเดโมผ่านเว็บที่ Go backend ให้บริการ',
            ),
          );
        } catch (error, stack) {
          result.completeError(error, stack);
        }
      }).toJS;
    request.send(body);
    return result.future;
  }
}
