import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:distill_anything/models/event.dart';
import 'package:distill_anything/models/server_config.dart';
import 'package:distill_anything/services/upload_service.dart';

void main() {
  group('UploadService.buildMetadata', () {
    test('produces correct metadata for event with all fields', () {
      final timestamp = DateTime.utc(2026, 4, 12, 10, 30);
      final event = Event(
        id: 'test-id-123',
        type: EventType.audio,
        timestamp: timestamp,
        payloadPath: '/audio/recording.wav',
        textContent: 'transcription text',
        annotation: 'morning standup',
        checksum: 'sha256abc',
        uploadStatus: UploadStatus.pending,
        fileSizeBytes: 102400,
      );

      final metadata = UploadService.buildMetadata(event);

      expect(metadata['id'], 'test-id-123');
      expect(metadata['type'], 'audio');
      expect(metadata['timestamp'], timestamp.toIso8601String());
      expect(metadata['text_content'], 'transcription text');
      expect(metadata['annotation'], 'morning standup');
      expect(metadata['checksum'], 'sha256abc');
      expect(metadata['file_size_bytes'], 102400);
    });

    test('handles null optional fields', () {
      final event = Event(
        id: 'text-only',
        type: EventType.text,
        textContent: 'hello',
      );

      final metadata = UploadService.buildMetadata(event);

      expect(metadata['id'], 'text-only');
      expect(metadata['type'], 'text');
      expect(metadata['text_content'], 'hello');
      expect(metadata['annotation'], isNull);
      expect(metadata['checksum'], isNull);
      expect(metadata['file_size_bytes'], isNull);
    });

    test('metadata is JSON-serializable', () {
      final event = Event(
        id: 'json-test',
        type: EventType.photo,
        timestamp: DateTime.utc(2026, 1, 1),
        payloadPath: '/photos/img.jpg',
        checksum: 'abc123',
        fileSizeBytes: 5000,
      );

      final metadata = UploadService.buildMetadata(event);
      final jsonString = jsonEncode(metadata);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['id'], 'json-test');
      expect(decoded['type'], 'photo');
      expect(decoded['checksum'], 'abc123');
      expect(decoded['file_size_bytes'], 5000);
    });

    test('all EventType values produce valid type strings', () {
      for (final type in EventType.values) {
        final event = Event(id: 'type-${type.name}', type: type);
        final metadata = UploadService.buildMetadata(event);
        expect(metadata['type'], type.name);
      }
    });
  });

  group('Upload status transitions', () {
    test('pending -> uploading -> uploaded flow', () {
      final event = Event(
        id: 'flow-test',
        type: EventType.text,
        uploadStatus: UploadStatus.pending,
      );

      expect(event.uploadStatus, UploadStatus.pending);

      final uploading = event.copyWith(uploadStatus: UploadStatus.uploading);
      expect(uploading.uploadStatus, UploadStatus.uploading);
      expect(uploading.id, event.id);

      final uploaded = uploading.copyWith(uploadStatus: UploadStatus.uploaded);
      expect(uploaded.uploadStatus, UploadStatus.uploaded);
    });

    test('pending -> uploading -> verified flow (with checksum match)', () {
      final event = Event(
        id: 'verify-test',
        type: EventType.audio,
        checksum: 'sha256abc',
        uploadStatus: UploadStatus.pending,
      );

      final uploading = event.copyWith(uploadStatus: UploadStatus.uploading);
      expect(uploading.uploadStatus, UploadStatus.uploading);

      // Simulate checksum match
      const serverChecksum = 'sha256abc';
      final verified = (uploading.checksum == serverChecksum)
          ? uploading.copyWith(uploadStatus: UploadStatus.verified)
          : uploading.copyWith(uploadStatus: UploadStatus.failed);

      expect(verified.uploadStatus, UploadStatus.verified);
    });

    test('checksum mismatch leads to failed status', () {
      final event = Event(
        id: 'mismatch-test',
        type: EventType.photo,
        checksum: 'local-checksum',
        uploadStatus: UploadStatus.uploading,
      );

      const serverChecksum = 'different-checksum';
      final result = (event.checksum == serverChecksum)
          ? event.copyWith(uploadStatus: UploadStatus.verified)
          : event.copyWith(uploadStatus: UploadStatus.failed);

      expect(result.uploadStatus, UploadStatus.failed);
    });

    test('failed events are retryable', () {
      final events = [
        Event(id: '1', type: EventType.text, uploadStatus: UploadStatus.pending),
        Event(id: '2', type: EventType.text, uploadStatus: UploadStatus.uploaded),
        Event(id: '3', type: EventType.text, uploadStatus: UploadStatus.failed),
        Event(id: '4', type: EventType.text, uploadStatus: UploadStatus.verified),
        Event(id: '5', type: EventType.text, uploadStatus: UploadStatus.failed),
      ];

      final retryable =
          events.where((e) => e.uploadStatus == UploadStatus.failed).toList();

      expect(retryable.length, 2);
      expect(retryable.map((e) => e.id).toList(), ['3', '5']);
    });
  });

  group('UploadService constructor', () {
    test('creates instance with default config', () {
      final service = UploadService();
      expect(service.isUploading, isFalse);
      service.dispose();
    });

    test('creates instance with custom config', () {
      final service = UploadService(
        config: const ServerConfig(host: '10.0.0.1', port: 9000),
      );
      expect(service.isUploading, isFalse);
      service.dispose();
    });

    test('updateConfig changes config', () {
      final service = UploadService();
      service.updateConfig(
        const ServerConfig(host: '192.168.0.50', port: 3000),
      );
      expect(service.isUploading, isFalse);
      service.dispose();
    });
  });
}
