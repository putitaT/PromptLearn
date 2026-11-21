enum RecordingSource { slides, screen }

enum RecordingPhase { idle, starting, recording, saving, saved, failed }

class RecordingClip {
  const RecordingClip({
    required this.path,
    required this.name,
    required this.sizeBytes,
    this.savedAt,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final DateTime? savedAt;
}

class RecordingStatus {
  const RecordingStatus({
    this.phase = RecordingPhase.idle,
    this.source,
    this.elapsed = Duration.zero,
    this.clip,
    this.interrupted = false,
    this.message,
  });

  final RecordingPhase phase;
  final RecordingSource? source;
  final Duration elapsed;
  final RecordingClip? clip;
  final bool interrupted;
  final String? message;

  bool get inProgress => switch (phase) {
    RecordingPhase.starting ||
    RecordingPhase.recording ||
    RecordingPhase.saving => true,
    _ => false,
  };
}

abstract interface class ClassRecordingService {
  bool get isSupported;
  Stream<RecordingStatus> get updates;

  Future<RecordingStatus> status();
  Future<void> start(RecordingSource source);
  Future<void> stop();
  Future<List<RecordingClip>> savedClips();
}
