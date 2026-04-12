enum RecordingMode { audio, photo, video, text }

enum RecordingStatus { idle, recording, paused, scheduled }

class RecordingState {
  final RecordingMode mode;
  final RecordingStatus status;
  final DateTime? startTime;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final Duration? elapsed;

  const RecordingState({
    this.mode = RecordingMode.audio,
    this.status = RecordingStatus.idle,
    this.startTime,
    this.scheduledStart,
    this.scheduledEnd,
    this.elapsed,
  });

  RecordingState copyWith({
    RecordingMode? mode,
    RecordingStatus? status,
    DateTime? startTime,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    Duration? elapsed,
  }) {
    return RecordingState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      elapsed: elapsed ?? this.elapsed,
    );
  }

  bool get isRecording => status == RecordingStatus.recording;
  bool get isScheduled => status == RecordingStatus.scheduled;
}
