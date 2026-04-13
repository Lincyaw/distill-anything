import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service for recording video using the device camera.
class VideoCaptureService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  bool _isRecording = false;

  /// Initialize the camera for video recording.
  Future<void> init() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw StateError('No cameras available on this device');
    }
    await _initController(_cameras[_currentCameraIndex]);
  }

  Future<void> _initController(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    await _controller!.initialize();
    _isInitialized = true;
  }

  /// Get the camera controller for preview display.
  Future<CameraController> getCameraController() async {
    if (!_isInitialized || _controller == null) {
      await init();
    }
    return _controller!;
  }

  /// Start recording video.
  Future<void> startVideoRecording() async {
    if (_controller == null || !_isInitialized) {
      throw StateError('Camera not initialized. Call init() first.');
    }
    if (_isRecording) {
      throw StateError('Already recording video');
    }

    await _controller!.startVideoRecording();
    _isRecording = true;
  }

  /// Stop recording and return the final file path.
  Future<String> stopVideoRecording() async {
    if (_controller == null || !_isRecording) {
      throw StateError('Not currently recording video');
    }

    final xFile = await _controller!.stopVideoRecording();
    _isRecording = false;

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final destPath = p.join(dir.path, 'video_$timestamp.mp4');

    try {
      await File(xFile.path).rename(destPath);
    } on FileSystemException {
      await File(xFile.path).copy(destPath);
      try {
        await File(xFile.path).delete();
      } catch (_) {}
    }

    return destPath;
  }

  /// Whether video is currently being recorded.
  bool get isRecording => _isRecording;

  /// Switch between front and rear cameras.
  Future<void> switchCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_currentCameraIndex]);
  }

  /// Dispose of camera resources.
  Future<void> dispose() async {
    if (_isRecording) {
      try {
        await _controller?.stopVideoRecording();
      } catch (_) {
        // Ignore errors during dispose
      }
    }
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isRecording = false;
  }
}
