import 'dart:io';

import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service for capturing photos using the device camera.
class PhotoCaptureService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitialized = false;

  /// Initialize the camera for photo capture.
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
      enableAudio: false,
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

  /// Capture a photo, save to app directory, return the file path.
  Future<String> capturePhoto({String? annotation}) async {
    if (_controller == null || !_isInitialized) {
      throw StateError('Camera not initialized. Call init() first.');
    }

    final xFile = await _controller!.takePicture();

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final destPath = p.join(dir.path, 'photo_$timestamp.jpg');

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

  /// Switch between front and rear cameras.
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_currentCameraIndex]);
  }

  /// Dispose of camera resources.
  Future<void> dispose() async {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
