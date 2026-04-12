import 'dart:async';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Service for managing audio recording sessions.
///
/// Uses the `record` package for audio capture with AAC codec.
class AudioRecordingService {
  AudioRecorder? _recorder;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentPath;
  DateTime? _recordingStartTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _lastPauseTime;

  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  Timer? _durationTimer;

  /// Initialize the recorder and check permissions.
  Future<void> init() async {
    _recorder = AudioRecorder();

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw StateError('Microphone permission not granted');
    }
  }

  /// Start recording audio. Returns the file path.
  Future<String> startRecording() async {
    if (_recorder == null) {
      await init();
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(dir.path, 'audio_$timestamp.m4a');

    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    _currentPath = filePath;
    _isRecording = true;
    _isPaused = false;
    _recordingStartTime = DateTime.now();
    _pausedDuration = Duration.zero;
    _lastPauseTime = null;

    _startDurationTimer();

    return filePath;
  }

  /// Stop recording and return the final file path.
  Future<String> stopRecording() async {
    if (_recorder == null || !_isRecording) {
      throw StateError('Not currently recording');
    }

    final path = await _recorder!.stop();
    _isRecording = false;
    _isPaused = false;
    _stopDurationTimer();

    final result = path ?? _currentPath!;
    _currentPath = null;
    _recordingStartTime = null;
    _pausedDuration = Duration.zero;
    _lastPauseTime = null;

    return result;
  }

  /// Pause the current recording session.
  Future<void> pauseRecording() async {
    if (_recorder == null || !_isRecording || _isPaused) return;
    await _recorder!.pause();
    _isPaused = true;
    _lastPauseTime = DateTime.now();
  }

  /// Resume a paused recording session.
  Future<void> resumeRecording() async {
    if (_recorder == null || !_isRecording || !_isPaused) return;
    await _recorder!.resume();
    if (_lastPauseTime != null) {
      _pausedDuration += DateTime.now().difference(_lastPauseTime!);
      _lastPauseTime = null;
    }
    _isPaused = false;
  }

  /// Whether the recorder is currently active (recording or paused).
  bool get isRecording => _isRecording;

  /// Stream of elapsed recording duration (excluding paused time).
  Stream<Duration> get durationStream => _durationController.stream;

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recordingStartTime == null) return;
      final now = DateTime.now();
      var elapsed = now.difference(_recordingStartTime!);
      elapsed -= _pausedDuration;
      if (_isPaused && _lastPauseTime != null) {
        elapsed -= now.difference(_lastPauseTime!);
      }
      if (!_durationController.isClosed) {
        _durationController.add(elapsed);
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  /// Dispose of recorder resources.
  Future<void> dispose() async {
    _stopDurationTimer();
    if (_isRecording) {
      await _recorder?.stop();
    }
    _recorder?.dispose();
    _recorder = null;
    _isRecording = false;
    await _durationController.close();
  }
}
