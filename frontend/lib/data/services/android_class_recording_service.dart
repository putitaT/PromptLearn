import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/services/class_recording_service.dart';

class AndroidClassRecordingService implements ClassRecordingService {
  const AndroidClassRecordingService();

  static const _methods = MethodChannel('promptlearn/class_recording');
  static const _events = EventChannel('promptlearn/class_recording/events');

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<RecordingStatus> get updates => isSupported
      ? _events.receiveBroadcastStream().map(_status)
      : const Stream.empty();

  @override
  Future<RecordingStatus> status() async {
    if (!isSupported) return const RecordingStatus();
    return _status(await _methods.invokeMethod<Object>('status'));
  }

  @override
  Future<void> start(RecordingSource source) =>
      _methods.invokeMethod<void>('start', source.name);

  @override
  Future<void> stop() => _methods.invokeMethod<void>('stop');

  @override
  Future<List<RecordingClip>> savedClips() async {
    if (!isSupported) return [];
    final clips = await _methods.invokeListMethod<Object>('savedClips') ?? [];
    return clips.map(_clip).toList(growable: false);
  }

  static RecordingStatus _status(Object? value) {
    final map = value as Map<Object?, Object?>;
    final source = map['source'] as String?;
    return RecordingStatus(
      phase: RecordingPhase.values.byName(map['phase'] as String),
      source: source == null ? null : RecordingSource.values.byName(source),
      elapsed: Duration(milliseconds: (map['elapsedMs'] as int?) ?? 0),
      clip: map['clip'] == null ? null : _clip(map['clip']),
      interrupted: map['interrupted'] == true,
      message: map['message'] as String?,
    );
  }

  static RecordingClip _clip(Object? value) {
    final map = value as Map<Object?, Object?>;
    final savedAt = map['savedAtMs'] as int?;
    return RecordingClip(
      savedAt: savedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(savedAt),
      path: map['path'] as String,
      name: map['name'] as String,
      sizeBytes: map['sizeBytes'] as int,
    );
  }
}
