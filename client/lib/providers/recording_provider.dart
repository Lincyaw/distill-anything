import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/recording_state.dart';
import '../services/audio_recording_service.dart';
import '../services/foreground_service.dart';
import '../services/photo_capture_service.dart';
import '../services/schedule_service.dart';
import '../services/video_capture_service.dart';
import '../services/checksum_service.dart';

/// Manages recording state across the app.
///
/// Orchestrates all recording services and creates events
/// when recording completes.
class RecordingProvider extends ChangeNotifier {
  RecordingState _state = const RecordingState();

  // Lazy-initialized services
  AudioRecordingService? _audioService;
  PhotoCaptureService? _photoService;
  VideoCaptureService? _videoService;
  ScheduleService? _scheduleService;
  final ForegroundServiceManager _foregroundService = ForegroundServiceManager();
  final ChecksumService _checksumService = ChecksumService();

  // Callback to notify EventProvider when a new event is created.
  // Set by the app before use — avoids double-writing to DB.
  Future<void> Function(Event)? onEventCreated;

  StreamSubscription<Duration>? _durationSub;

  RecordingState get state => _state;

  // -- Service accessors (lazy init) --

  AudioRecordingService get _audio {
    _audioService ??= AudioRecordingService();
    return _audioService!;
  }

  PhotoCaptureService get _photo {
    _photoService ??= PhotoCaptureService();
    return _photoService!;
  }

  VideoCaptureService get _video {
    _videoService ??= VideoCaptureService();
    return _videoService!;
  }

  ScheduleService get _schedule {
    _scheduleService ??= ScheduleService();
    return _scheduleService!;
  }

  /// Switch the recording mode (audio, photo, video, text).
  void setMode(RecordingMode mode) {
    if (_state.isRecording) return; // Don't switch while recording
    _state = _state.copyWith(mode: mode);
    notifyListeners();
  }

  /// Error message from the last failed operation, if any.
  String? _lastError;
  String? get lastError => _lastError;

  /// Clear the last error.
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Start a recording session in the current mode.
  /// Throws are caught internally — check [lastError] for failures.
  Future<void> startRecording() async {
    _lastError = null;
    try {
      switch (_state.mode) {
        case RecordingMode.audio:
          await _startAudioRecording();
          break;
        case RecordingMode.video:
          await _startVideoRecording();
          break;
        case RecordingMode.photo:
          await capturePhoto();
          return;
        case RecordingMode.text:
          return;
      }

      _state = _state.copyWith(
        status: RecordingStatus.recording,
        startTime: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> _startAudioRecording() async {
    await _audio.init();
    await _audio.startRecording();
    await _foregroundService.startForegroundService(
      title: 'Audio Recording',
      body: 'Recording audio...',
    );

    _durationSub?.cancel();
    _durationSub = _audio.durationStream.listen((elapsed) {
      _state = _state.copyWith(elapsed: elapsed);
      notifyListeners();
      _foregroundService.updateNotification(
        title: 'Audio Recording',
        body: 'Elapsed: ${_formatDuration(elapsed)}',
      );
    });
  }

  Timer? _videoTimer;
  DateTime? _videoStartTime;

  Future<void> _startVideoRecording() async {
    await _video.init();
    await _video.startVideoRecording();
    await _foregroundService.startForegroundService(
      title: 'Video Recording',
      body: 'Recording video...',
    );

    _videoStartTime = DateTime.now();
    _videoTimer?.cancel();
    _videoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_videoStartTime == null) return;
      final elapsed = DateTime.now().difference(_videoStartTime!);
      _state = _state.copyWith(elapsed: elapsed);
      notifyListeners();
      _foregroundService.updateNotification(
        title: 'Video Recording',
        body: 'Elapsed: ${_formatDuration(elapsed)}',
      );
    });
  }

  /// Pause the current recording.
  Future<void> pauseRecording() async {
    if (_state.mode == RecordingMode.audio) {
      await _audio.pauseRecording();
    }
    _state = _state.copyWith(status: RecordingStatus.paused);
    notifyListeners();
  }

  /// Resume a paused recording.
  Future<void> resumeRecording() async {
    if (_state.mode == RecordingMode.audio) {
      await _audio.resumeRecording();
    }
    _state = _state.copyWith(status: RecordingStatus.recording);
    notifyListeners();
  }

  /// Stop the current recording and create an event.
  Future<Event?> stopRecording() async {
    Event? event;

    switch (_state.mode) {
      case RecordingMode.audio:
        event = await _stopAudioRecording();
        break;
      case RecordingMode.video:
        event = await _stopVideoRecording();
        break;
      default:
        break;
    }

    await _foregroundService.stopForegroundService();
    _durationSub?.cancel();
    _durationSub = null;
    _videoTimer?.cancel();
    _videoTimer = null;
    _videoStartTime = null;

    _state = const RecordingState(); // Reset to idle
    notifyListeners();

    if (event != null) {
      await onEventCreated?.call(event);
    }

    return event;
  }

  Future<Event> _stopAudioRecording() async {
    final path = await _audio.stopRecording();
    return _buildFileEvent(path, EventType.audio);
  }

  Future<Event> _stopVideoRecording() async {
    final path = await _video.stopVideoRecording();
    return _buildFileEvent(path, EventType.video);
  }

  /// Capture a photo and create an event.
  Future<Event?> capturePhoto({String? annotation}) async {
    await _photo.init();
    final path = await _photo.capturePhoto(annotation: annotation);
    final event = await _buildFileEvent(path, EventType.photo, annotation: annotation);
    await onEventCreated?.call(event);
    return event;
  }

  /// Create a text event.
  Future<Event?> createTextEvent(String content, {String? annotation}) async {
    final event = Event(
      type: EventType.text,
      textContent: content,
      annotation: annotation,
    );
    await onEventCreated?.call(event);
    return event;
  }

  Future<Event> _buildFileEvent(
    String path,
    EventType type, {
    String? annotation,
  }) async {
    final file = File(path);
    final results = await (file.length(), _checksumService.computeSha256(path)).wait;
    return Event(
      type: type,
      payloadPath: path,
      annotation: annotation,
      checksum: results.$2,
      fileSizeBytes: results.$1,
    );
  }

  /// Schedule a future recording session.
  Future<void> scheduleRecording({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await _schedule.init();
    _schedule.onRecordingStart = () => startRecording();
    _schedule.onRecordingStop = () => stopRecording();

    await _schedule.scheduleRecording(
      startTime: startTime,
      endTime: endTime,
    );

    _state = _state.copyWith(
      status: RecordingStatus.scheduled,
      scheduledStart: startTime,
      scheduledEnd: endTime,
    );
    notifyListeners();
  }

  /// Cancel a scheduled recording.
  Future<void> cancelSchedule() async {
    await _schedule.cancelSchedule();
    _state = const RecordingState();
    notifyListeners();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _videoTimer?.cancel();
    _audioService?.dispose();
    _photoService?.dispose();
    _videoService?.dispose();
    _scheduleService?.dispose();
    _foregroundService.stopForegroundService();
    super.dispose();
  }
}
