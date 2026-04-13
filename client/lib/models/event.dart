import 'package:uuid/uuid.dart';

enum EventType { audio, photo, video, text }

enum UploadStatus { pending, uploading, uploaded, verified, failed }

class Event {
  final String id;
  final EventType type;
  final DateTime timestamp;
  final String? payloadPath;
  final String? textContent;
  final String? annotation;
  final String? checksum;
  final UploadStatus uploadStatus;
  final int? fileSizeBytes;

  Event({
    String? id,
    required this.type,
    DateTime? timestamp,
    this.payloadPath,
    this.textContent,
    this.annotation,
    this.checksum,
    this.uploadStatus = UploadStatus.pending,
    this.fileSizeBytes,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'payload_path': payloadPath,
      'text_content': textContent,
      'annotation': annotation,
      'checksum': checksum,
      'upload_status': uploadStatus.name,
      'file_size_bytes': fileSizeBytes,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      type: _parseEnum(EventType.values, map['type'] as String, EventType.text),
      timestamp: DateTime.parse(map['timestamp'] as String),
      payloadPath: map['payload_path'] as String?,
      textContent: map['text_content'] as String?,
      annotation: map['annotation'] as String?,
      checksum: map['checksum'] as String?,
      uploadStatus: _parseEnum(
          UploadStatus.values, map['upload_status'] as String, UploadStatus.pending),
      fileSizeBytes: map['file_size_bytes'] as int?,
    );
  }

  static T _parseEnum<T extends Enum>(List<T> values, String name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  Event copyWith({
    String? id,
    EventType? type,
    DateTime? timestamp,
    String? payloadPath,
    String? textContent,
    String? annotation,
    String? checksum,
    UploadStatus? uploadStatus,
    int? fileSizeBytes,
  }) {
    return Event(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      payloadPath: payloadPath ?? this.payloadPath,
      textContent: textContent ?? this.textContent,
      annotation: annotation ?? this.annotation,
      checksum: checksum ?? this.checksum,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}
