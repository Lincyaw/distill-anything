import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/event.dart';
import 'event_storage_service.dart';

/// Service for monitoring and managing local storage usage.
///
/// Tracks how much disk space events consume and provides cleanup utilities
/// for files that have been verified as uploaded to the server.
class StorageManagerService {
  final EventStorageService _eventStorage;

  /// Whether automatic cleanup of verified events is enabled.
  bool autoCleanup = false;

  /// Number of days to retain local files after verified upload.
  int retentionDays = 30;

  StorageManagerService({EventStorageService? eventStorage})
      : _eventStorage = eventStorage ?? EventStorageService();

  /// Get total local storage used by the app in bytes.
  ///
  /// Recursively scans the application documents directory.
  Future<int> getUsedStorageBytes() async {
    final dir = await getApplicationDocumentsDirectory();
    return await _calculateDirectorySize(dir);
  }

  /// Get available device storage in bytes.
  ///
  /// TODO: On Android, `Process.run('df', ...)` may not work.
  /// Use a platform channel with Android's `StatFs` for accurate results.
  /// This implementation works on desktop platforms and is best-effort on mobile.
  Future<int> getAvailableStorageBytes() async {
    final dir = await getApplicationDocumentsDirectory();
    return _getAvailableSpace(dir.path);
  }

  /// Get the storage directory path for event files.
  Future<String> getStorageDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Get a summary of storage usage.
  Future<Map<String, int>> getStorageSummary() async {
    final used = await getUsedStorageBytes();
    final dbTotal = await _eventStorage.getTotalStorageBytes();
    final eventCount = await _eventStorage.getEventCount();
    return {
      'used_bytes': used,
      'db_reported_bytes': dbTotal,
      'event_count': eventCount,
    };
  }

  /// Delete the payload file for a given event.
  Future<void> deleteEventFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clean up local files for verified events older than the retention period.
  ///
  /// Only deletes files for events whose upload has been verified on the server.
  /// Returns the number of files cleaned up.
  Future<int> cleanupVerifiedEvents() async {
    if (!autoCleanup) return 0;

    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final events = await _eventStorage.getAllEvents();
    int cleaned = 0;

    for (final event in events) {
      if (event.uploadStatus == UploadStatus.verified &&
          event.timestamp.isBefore(cutoff) &&
          event.payloadPath != null) {
        final file = File(event.payloadPath!);
        if (await file.exists()) {
          await file.delete();
          cleaned++;
        }
        // Clear the payload path and file size since the file is deleted.
        await _eventStorage.updateEvent(
          event.copyWith(payloadPath: null, fileSizeBytes: 0),
        );
      }
    }
    return cleaned;
  }

  /// Check if storage is critically low (< 100 MB available).
  Future<bool> isStorageLow() async {
    try {
      final available = await getAvailableStorageBytes();
      return available < 100 * 1024 * 1024; // 100 MB threshold
    } catch (_) {
      return false;
    }
  }

  /// Recursively calculate the total size of all files in a directory.
  /// Uses async I/O to avoid blocking the UI thread.
  Future<int> _calculateDirectorySize(Directory dir) async {
    int size = 0;
    if (!await dir.exists()) return size;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  /// Get available space on the filesystem containing [path].
  ///
  /// Uses `df` which works on Linux/macOS/desktop. On Android this may not
  /// be available — a platform channel using `android.os.StatFs` is the
  /// correct long-term solution.
  // TODO: Replace with platform channel for Android using StatFs.
  Future<int> _getAvailableSpace(String path) async {
    try {
      final result = await Process.run('df', ['-B1', path]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length > 3) {
            return int.tryParse(parts[3]) ?? 0;
          }
        }
      }
    } catch (_) {
      // df not available (e.g. on Android) — fall back to 0.
    }
    return 0;
  }
}
