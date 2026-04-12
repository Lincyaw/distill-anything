import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/server_config.dart';
import '../services/upload_service.dart';

/// Manages the upload queue and upload state.
class UploadProvider extends ChangeNotifier {
  final UploadService _uploadService;

  bool _isUploading = false;
  int _uploadedCount = 0;
  int _failedCount = 0;
  int _totalInQueue = 0;
  String? _lastError;
  Map<String, bool> _lastUploadResult = {};
  Timer? _autoUploadTimer;

  UploadProvider({UploadService? uploadService})
      : _uploadService = uploadService ?? UploadService();

  bool get isUploading => _isUploading;
  int get uploadedCount => _uploadedCount;
  int get failedCount => _failedCount;
  int get totalInQueue => _totalInQueue;
  String? get lastError => _lastError;
  Map<String, bool> get lastUploadResult => _lastUploadResult;

  double get progress =>
      _totalInQueue > 0 ? _uploadedCount / _totalInQueue : 0.0;

  /// Update the server configuration used by the upload service.
  void updateConfig(ServerConfig config) {
    _uploadService.updateConfig(config);
  }

  /// Test server connectivity.
  Future<bool> testConnection() async {
    return _uploadService.testConnection();
  }

  /// Upload all pending events to the server.
  Future<void> uploadAll() async {
    if (_isUploading) return;

    _isUploading = true;
    _uploadedCount = 0;
    _failedCount = 0;
    _lastError = null;
    notifyListeners();

    try {
      final results = await _uploadService.uploadAllPending();
      _lastUploadResult = results;
      _totalInQueue = results.length;
      _uploadedCount = results.values.where((v) => v).length;
      _failedCount = results.values.where((v) => !v).length;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Upload a single event.
  Future<bool> uploadOne(Event event) async {
    _isUploading = true;
    _lastError = null;
    notifyListeners();

    try {
      final success = await _uploadService.uploadEvent(event);
      if (!success) {
        _lastError = 'Upload failed for event ${event.id}';
      }
      return success;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Retry all failed uploads with exponential backoff.
  Future<void> retryFailed({int maxRetries = 3}) async {
    if (_isUploading) return;

    _isUploading = true;
    _lastError = null;
    notifyListeners();

    try {
      await _uploadService.retryFailed(maxRetries: maxRetries);
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Start periodic auto-upload at the given interval.
  void startAutoUpload({Duration interval = const Duration(minutes: 5)}) {
    stopAutoUpload();
    _autoUploadTimer = Timer.periodic(interval, (_) => uploadAll());
  }

  /// Stop periodic auto-upload.
  void stopAutoUpload() {
    _autoUploadTimer?.cancel();
    _autoUploadTimer = null;
  }

  /// Cancel ongoing uploads.
  void cancelUpload() {
    _isUploading = false;
    _lastError = 'Upload cancelled by user';
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoUpload();
    _uploadService.dispose();
    super.dispose();
  }
}
