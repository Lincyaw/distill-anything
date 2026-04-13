import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';
import '../services/upload_service.dart';

/// Manages server connection settings with persistence via shared_preferences.
class SettingsProvider extends ChangeNotifier {
  final UploadService _uploadService;
  ServerConfig _config = const ServerConfig();

  SettingsProvider({UploadService? uploadService})
      : _uploadService = uploadService ?? UploadService();

  ServerConfig get config => _config;
  bool get isConnected => _config.isConnected;
  DateTime? get lastChecked => _config.lastChecked;

  /// Update the server host address.
  void setHost(String host) {
    _config = _config.copyWith(host: host);
    _uploadService.updateConfig(_config);
    notifyListeners();
  }

  /// Update the server port.
  void setPort(int port) {
    _config = _config.copyWith(port: port);
    _uploadService.updateConfig(_config);
    notifyListeners();
  }

  /// Save settings to shared_preferences.
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_host', _config.host);
    await prefs.setInt('server_port', _config.port);
    notifyListeners();
  }

  /// Load settings from shared_preferences.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('server_host') ?? '192.168.1.100';
    final port = prefs.getInt('server_port') ?? 8000;
    _config = ServerConfig(host: host, port: port);
    _uploadService.updateConfig(_config);
    notifyListeners();
  }

  /// Test the connection to the configured server.
  Future<bool> testConnection() async {
    final connected = await _uploadService.testConnection();
    _config = _config.copyWith(
      isConnected: connected,
      lastChecked: DateTime.now(),
    );
    notifyListeners();
    return connected;
  }

  @override
  void dispose() {
    _uploadService.dispose();
    super.dispose();
  }
}
