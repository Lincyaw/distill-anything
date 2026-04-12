import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/event.dart';
import '../models/server_config.dart';
import 'event_storage_service.dart';

/// Service for uploading events to the LAN server.
///
/// Uses multipart HTTP uploads with retry logic and checksum verification.
class UploadService {
  final Dio _dio;
  final EventStorageService _storage;
  ServerConfig _config;
  bool _isUploading = false;

  UploadService({
    ServerConfig? config,
    EventStorageService? storage,
    Dio? dio,
  })  : _config = config ?? const ServerConfig(),
        _storage = storage ?? EventStorageService(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 300),
              sendTimeout: const Duration(seconds: 300),
            ));

  void updateConfig(ServerConfig config) {
    _config = config;
  }

  bool get isUploading => _isUploading;

  /// Test server connectivity.
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('${_config.baseUrl}/api/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Prepare metadata map from an event.
  static Map<String, dynamic> buildMetadata(Event event) {
    return {
      'id': event.id,
      'type': event.type.name,
      'timestamp': event.timestamp.toIso8601String(),
      'text_content': event.textContent,
      'annotation': event.annotation,
      'checksum': event.checksum,
      'file_size_bytes': event.fileSizeBytes,
    };
  }

  /// Upload a single event to the server.
  Future<bool> uploadEvent(Event event) async {
    try {
      await _storage.updateUploadStatus(event.id, UploadStatus.uploading);

      final metadata = buildMetadata(event);

      final formData = FormData.fromMap({
        'metadata': jsonEncode(metadata),
      });

      if (event.payloadPath != null && event.payloadPath!.isNotEmpty) {
        final file = File(event.payloadPath!);
        if (await file.exists()) {
          formData.files.add(MapEntry(
            'file',
            await MultipartFile.fromFile(
              file.path,
              filename: file.uri.pathSegments.last,
            ),
          ));
        }
      }

      final response = await _dio.post(
        '${_config.baseUrl}/api/events',
        data: formData,
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        final serverChecksum = responseData['server_checksum'] as String?;

        if (event.checksum != null && serverChecksum != null) {
          if (event.checksum == serverChecksum) {
            await _storage.updateUploadStatus(event.id, UploadStatus.verified);
          } else {
            await _storage.updateUploadStatus(event.id, UploadStatus.failed);
            return false;
          }
        } else {
          await _storage.updateUploadStatus(event.id, UploadStatus.uploaded);
        }
        return true;
      } else {
        await _storage.updateUploadStatus(event.id, UploadStatus.failed);
        return false;
      }
    } catch (e) {
      await _storage.updateUploadStatus(event.id, UploadStatus.failed);
      return false;
    }
  }

  /// Upload all pending events.
  Future<Map<String, bool>> uploadAllPending() async {
    if (_isUploading) return {};
    _isUploading = true;

    final results = <String, bool>{};
    try {
      final pendingEvents = await _storage.getPendingUploads();
      for (final event in pendingEvents) {
        results[event.id] = await uploadEvent(event);
      }
    } finally {
      _isUploading = false;
    }
    return results;
  }

  /// Retry failed uploads with exponential backoff.
  Future<void> retryFailed({int maxRetries = 3}) async {
    final pending = await _storage.getPendingUploads();
    final failed =
        pending.where((e) => e.uploadStatus == UploadStatus.failed).toList();

    for (final event in failed) {
      for (var attempt = 0; attempt < maxRetries; attempt++) {
        final success = await uploadEvent(event);
        if (success) break;
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
  }

  void dispose() {
    _dio.close();
  }
}
