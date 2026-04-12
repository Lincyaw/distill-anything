import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Schedule configuration stored in the database.
class ScheduleConfig {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String mode;
  final bool recurring;
  final bool active;

  ScheduleConfig({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.mode,
    this.recurring = false,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'mode': mode,
      'recurring': recurring ? 1 : 0,
      'active': active ? 1 : 0,
    };
  }

  factory ScheduleConfig.fromMap(Map<String, dynamic> map) {
    return ScheduleConfig(
      id: map['id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      mode: map['mode'] as String,
      recurring: (map['recurring'] as int) == 1,
      active: (map['active'] as int) == 1,
    );
  }
}

/// State emitted by the schedule stream.
enum ScheduleState { idle, waiting, recording, completed, cancelled }

/// Service for scheduling alarm-style recording sessions.
///
/// Uses Timer-based scheduling since the app runs as a foreground service.
/// Stores schedule configs in SQLite.
class ScheduleService {
  Database? _db;
  Timer? _startTimer;
  Timer? _stopTimer;
  ScheduleConfig? _currentSchedule;

  final StreamController<ScheduleState> _stateController =
      StreamController<ScheduleState>.broadcast();

  /// Callback invoked when a scheduled recording should start.
  /// Set this from the provider to wire up actual recording.
  void Function()? onRecordingStart;

  /// Callback invoked when a scheduled recording should stop.
  void Function()? onRecordingStop;

  /// Stream of schedule state changes.
  Stream<ScheduleState> get scheduleStream => _stateController.stream;

  /// Current schedule state.
  ScheduleState _state = ScheduleState.idle;
  ScheduleState get state => _state;

  /// Initialize the schedule database.
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'schedules.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE schedules (
            id TEXT PRIMARY KEY,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            mode TEXT NOT NULL,
            recurring INTEGER NOT NULL DEFAULT 0,
            active INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    );
  }

  /// Schedule a recording session between [startTime] and [endTime].
  Future<void> scheduleRecording({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await cancelSchedule();

    final config = ScheduleConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime,
      mode: 'audio',
    );

    if (_db != null) {
      await _db!.insert('schedules', config.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    _currentSchedule = config;
    _setupTimers(config);

    _state = ScheduleState.waiting;
    _stateController.add(ScheduleState.waiting);
  }

  void _setupTimers(ScheduleConfig config) {
    final now = DateTime.now();

    final startDelay = config.startTime.difference(now);
    if (startDelay.isNegative) {
      // Start time already passed — start immediately if end time is future
      if (config.endTime.isAfter(now)) {
        _triggerStart();
        final stopDelay = config.endTime.difference(now);
        _stopTimer = Timer(stopDelay, _triggerStop);
      }
      return;
    }

    _startTimer = Timer(startDelay, () {
      _triggerStart();
      final recordingDuration = config.endTime.difference(config.startTime);
      _stopTimer = Timer(recordingDuration, _triggerStop);
    });
  }

  void _triggerStart() {
    _state = ScheduleState.recording;
    _stateController.add(ScheduleState.recording);
    onRecordingStart?.call();
  }

  void _triggerStop() {
    _state = ScheduleState.completed;
    _stateController.add(ScheduleState.completed);
    onRecordingStop?.call();

    // Clean up the current schedule
    if (_currentSchedule != null && _db != null) {
      _db!.delete('schedules',
          where: 'id = ?', whereArgs: [_currentSchedule!.id]);
    }
    _currentSchedule = null;

    // Reset to idle after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      _state = ScheduleState.idle;
      if (!_stateController.isClosed) {
        _stateController.add(ScheduleState.idle);
      }
    });
  }

  /// Cancel the current schedule.
  Future<void> cancelSchedule() async {
    _startTimer?.cancel();
    _startTimer = null;
    _stopTimer?.cancel();
    _stopTimer = null;

    if (_currentSchedule != null && _db != null) {
      await _db!.delete('schedules',
          where: 'id = ?', whereArgs: [_currentSchedule!.id]);
    }
    _currentSchedule = null;

    _state = ScheduleState.cancelled;
    _stateController.add(ScheduleState.cancelled);

    _state = ScheduleState.idle;
    _stateController.add(ScheduleState.idle);
  }

  /// Get all active schedules from the database.
  Future<List<ScheduleConfig>> getActiveSchedules() async {
    if (_db == null) return [];
    final maps =
        await _db!.query('schedules', where: 'active = ?', whereArgs: [1]);
    return maps.map((m) => ScheduleConfig.fromMap(m)).toList();
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    _startTimer?.cancel();
    _stopTimer?.cancel();
    await _stateController.close();
    await _db?.close();
  }
}
