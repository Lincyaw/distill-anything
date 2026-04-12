import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages the Android foreground service for long-running recording.
///
/// Keeps the app alive during extended audio/video recording sessions
/// by displaying a persistent notification.
class ForegroundServiceManager {
  bool _isRunning = false;

  /// Initialize the foreground task configuration.
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'distill_recording',
        channelName: 'Recording Service',
        channelDescription: 'Keeps the app running during recording sessions.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service with a persistent notification.
  Future<void> startForegroundService({
    String title = 'Recording in progress',
    String body = 'Distill Anything is recording...',
  }) async {
    _initForegroundTask();

    final result =
        await FlutterForegroundTask.startService(
          notificationTitle: title,
          notificationText: body,
          callback: _foregroundTaskCallback,
        );

    _isRunning = result is ServiceRequestSuccess;
  }

  /// Update the foreground notification content.
  Future<void> updateNotification({
    required String title,
    required String body,
  }) async {
    if (!_isRunning) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
    );
  }

  /// Stop the foreground service.
  Future<void> stopForegroundService() async {
    if (!_isRunning) return;
    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }

  /// Check if the foreground service is currently running.
  bool get isRunning => _isRunning;
}

/// Top-level callback for the foreground task.
/// Must be a top-level or static function.
@pragma('vm:entry-point')
void _foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_RecordingTaskHandler());
}

/// Task handler that runs inside the foreground service isolate.
class _RecordingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Service started — recording logic runs in the main isolate.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: we use eventAction nothing().
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Service stopping — cleanup if needed.
  }
}
