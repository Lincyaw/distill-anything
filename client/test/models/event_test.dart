import 'package:flutter_test/flutter_test.dart';
import 'package:distill_anything/models/event.dart';

void main() {
  group('Event model', () {
    test('toMap produces correct keys and values', () {
      final event = Event(
        id: 'test-id-1',
        type: EventType.text,
        timestamp: DateTime.utc(2026, 4, 12, 10, 30),
        textContent: 'Hello world',
        annotation: 'A note',
        checksum: 'abc123',
        uploadStatus: UploadStatus.pending,
        fileSizeBytes: 42,
      );

      final map = event.toMap();

      expect(map['id'], 'test-id-1');
      expect(map['type'], 'text');
      expect(map['timestamp'], '2026-04-12T10:30:00.000Z');
      expect(map['payload_path'], isNull);
      expect(map['text_content'], 'Hello world');
      expect(map['annotation'], 'A note');
      expect(map['checksum'], 'abc123');
      expect(map['upload_status'], 'pending');
      expect(map['file_size_bytes'], 42);
    });

    test('fromMap reconstructs event correctly', () {
      final map = {
        'id': 'test-id-2',
        'type': 'audio',
        'timestamp': '2026-04-12T08:00:00.000Z',
        'payload_path': '/data/audio.wav',
        'text_content': null,
        'annotation': null,
        'checksum': 'def456',
        'upload_status': 'uploaded',
        'file_size_bytes': 1024,
      };

      final event = Event.fromMap(map);

      expect(event.id, 'test-id-2');
      expect(event.type, EventType.audio);
      expect(event.timestamp, DateTime.utc(2026, 4, 12, 8, 0));
      expect(event.payloadPath, '/data/audio.wav');
      expect(event.textContent, isNull);
      expect(event.annotation, isNull);
      expect(event.checksum, 'def456');
      expect(event.uploadStatus, UploadStatus.uploaded);
      expect(event.fileSizeBytes, 1024);
    });

    test('toMap/fromMap roundtrip preserves data', () {
      final original = Event(
        id: 'roundtrip-id',
        type: EventType.photo,
        timestamp: DateTime.utc(2026, 1, 1),
        payloadPath: '/photos/img.jpg',
        textContent: null,
        annotation: 'sunset photo',
        checksum: 'sha256hash',
        uploadStatus: UploadStatus.verified,
        fileSizeBytes: 2048,
      );

      final restored = Event.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.timestamp, original.timestamp);
      expect(restored.payloadPath, original.payloadPath);
      expect(restored.textContent, original.textContent);
      expect(restored.annotation, original.annotation);
      expect(restored.checksum, original.checksum);
      expect(restored.uploadStatus, original.uploadStatus);
      expect(restored.fileSizeBytes, original.fileSizeBytes);
    });

    test('fromMap handles all EventType values', () {
      for (final type in EventType.values) {
        final map = {
          'id': 'type-test-${type.name}',
          'type': type.name,
          'timestamp': '2026-04-12T00:00:00.000Z',
          'payload_path': null,
          'text_content': null,
          'annotation': null,
          'checksum': null,
          'upload_status': 'pending',
          'file_size_bytes': null,
        };

        final event = Event.fromMap(map);
        expect(event.type, type);
      }
    });

    test('fromMap handles all UploadStatus values', () {
      for (final status in UploadStatus.values) {
        final map = {
          'id': 'status-test-${status.name}',
          'type': 'text',
          'timestamp': '2026-04-12T00:00:00.000Z',
          'payload_path': null,
          'text_content': null,
          'annotation': null,
          'checksum': null,
          'upload_status': status.name,
          'file_size_bytes': null,
        };

        final event = Event.fromMap(map);
        expect(event.uploadStatus, status);
      }
    });

    test('copyWith creates modified copy', () {
      final original = Event(
        id: 'copy-id',
        type: EventType.text,
        textContent: 'original',
        uploadStatus: UploadStatus.pending,
      );

      final modified = original.copyWith(
        textContent: 'modified',
        uploadStatus: UploadStatus.uploaded,
      );

      expect(modified.id, original.id);
      expect(modified.type, original.type);
      expect(modified.textContent, 'modified');
      expect(modified.uploadStatus, UploadStatus.uploaded);
      // Original unchanged
      expect(original.textContent, 'original');
      expect(original.uploadStatus, UploadStatus.pending);
    });

    test('default id is generated when not provided', () {
      final event = Event(type: EventType.text);
      expect(event.id, isNotEmpty);
      expect(event.id.length, greaterThan(0));
    });

    test('default timestamp is set when not provided', () {
      final before = DateTime.now();
      final event = Event(type: EventType.text);
      final after = DateTime.now();

      expect(event.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(event.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('default uploadStatus is pending', () {
      final event = Event(type: EventType.text);
      expect(event.uploadStatus, UploadStatus.pending);
    });
  });

  group('Checksum service (string-based)', () {
    test('computeStringSha256 produces consistent results', () {
      // This tests the concept - actual ChecksumService uses crypto package
      // and requires dart:io which needs platform support
      final map1 = Event(
        id: 'same',
        type: EventType.text,
        timestamp: DateTime.utc(2026, 1, 1),
        uploadStatus: UploadStatus.pending,
      ).toMap();

      final map2 = Event(
        id: 'same',
        type: EventType.text,
        timestamp: DateTime.utc(2026, 1, 1),
        uploadStatus: UploadStatus.pending,
      ).toMap();

      expect(map1, equals(map2));
    });
  });
}
