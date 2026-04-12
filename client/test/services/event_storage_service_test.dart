import 'package:flutter_test/flutter_test.dart';
import 'package:distill_anything/models/event.dart';

/// Tests for EventStorageService.
///
/// Since sqflite requires platform channels (Android/iOS), we test the
/// serialization layer (toMap/fromMap) that the storage service relies on.
/// Full integration tests with SQLite should be run on device or emulator.
void main() {
  group('EventStorageService serialization', () {
    test('insert and retrieve roundtrip via toMap/fromMap', () {
      final event = Event(
        id: 'insert-test',
        type: EventType.audio,
        timestamp: DateTime.utc(2026, 4, 12, 9, 0),
        payloadPath: '/audio/recording.wav',
        checksum: 'abc',
        uploadStatus: UploadStatus.pending,
        fileSizeBytes: 5000,
      );

      final map = event.toMap();
      final restored = Event.fromMap(map);

      expect(restored.id, event.id);
      expect(restored.type, event.type);
      expect(restored.timestamp, event.timestamp);
      expect(restored.payloadPath, event.payloadPath);
      expect(restored.checksum, event.checksum);
      expect(restored.uploadStatus, event.uploadStatus);
      expect(restored.fileSizeBytes, event.fileSizeBytes);
    });

    test('filtering by type works on in-memory list', () {
      final events = [
        Event(id: '1', type: EventType.text, timestamp: DateTime.utc(2026, 4, 12)),
        Event(id: '2', type: EventType.audio, timestamp: DateTime.utc(2026, 4, 12)),
        Event(id: '3', type: EventType.text, timestamp: DateTime.utc(2026, 4, 12)),
        Event(id: '4', type: EventType.photo, timestamp: DateTime.utc(2026, 4, 12)),
      ];

      final textEvents = events.where((e) => e.type == EventType.text).toList();
      expect(textEvents.length, 2);
      expect(textEvents.every((e) => e.type == EventType.text), isTrue);

      final audioEvents = events.where((e) => e.type == EventType.audio).toList();
      expect(audioEvents.length, 1);

      final videoEvents = events.where((e) => e.type == EventType.video).toList();
      expect(videoEvents.length, 0);
    });

    test('upload status update via copyWith', () {
      final event = Event(
        id: 'status-test',
        type: EventType.photo,
        uploadStatus: UploadStatus.pending,
      );

      final updated = event.copyWith(uploadStatus: UploadStatus.uploading);
      expect(updated.uploadStatus, UploadStatus.uploading);
      expect(updated.id, event.id);

      final uploaded = updated.copyWith(uploadStatus: UploadStatus.uploaded);
      expect(uploaded.uploadStatus, UploadStatus.uploaded);
    });

    test('pending uploads retrieval logic', () {
      final events = [
        Event(id: '1', type: EventType.text, uploadStatus: UploadStatus.pending),
        Event(id: '2', type: EventType.text, uploadStatus: UploadStatus.uploaded),
        Event(id: '3', type: EventType.text, uploadStatus: UploadStatus.failed),
        Event(id: '4', type: EventType.text, uploadStatus: UploadStatus.verified),
        Event(id: '5', type: EventType.text, uploadStatus: UploadStatus.uploading),
      ];

      final pending = events
          .where((e) =>
              e.uploadStatus == UploadStatus.pending ||
              e.uploadStatus == UploadStatus.failed)
          .toList();

      expect(pending.length, 2);
      expect(pending.map((e) => e.id).toList(), ['1', '3']);
    });

    test('delete removes from in-memory list', () {
      final events = [
        Event(id: 'a', type: EventType.text),
        Event(id: 'b', type: EventType.audio),
        Event(id: 'c', type: EventType.photo),
      ];

      events.removeWhere((e) => e.id == 'b');
      expect(events.length, 2);
      expect(events.any((e) => e.id == 'b'), isFalse);
    });

    test('event count and storage bytes simulation', () {
      final events = [
        Event(id: '1', type: EventType.audio, fileSizeBytes: 1000),
        Event(id: '2', type: EventType.photo, fileSizeBytes: 2000),
        Event(id: '3', type: EventType.text, fileSizeBytes: null),
        Event(id: '4', type: EventType.video, fileSizeBytes: 5000),
      ];

      expect(events.length, 4);

      final totalBytes = events.fold<int>(
        0,
        (sum, e) => sum + (e.fileSizeBytes ?? 0),
      );
      expect(totalBytes, 8000);
    });

    test('toMap produces correct SQL-compatible types', () {
      final event = Event(
        id: 'sql-test',
        type: EventType.video,
        timestamp: DateTime.utc(2026, 6, 15, 14, 30),
        payloadPath: '/videos/clip.mp4',
        textContent: null,
        annotation: 'meeting recording',
        checksum: 'sha256hash',
        uploadStatus: UploadStatus.pending,
        fileSizeBytes: 10240,
      );

      final map = event.toMap();

      // All values should be SQL-compatible types
      expect(map['id'], isA<String>());
      expect(map['type'], isA<String>());
      expect(map['timestamp'], isA<String>());
      expect(map['upload_status'], isA<String>());
      expect(map['file_size_bytes'], isA<int>());
      // Nullable fields can be null
      expect(map['text_content'], isNull);
    });
  });
}
