import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/recording_provider.dart';
import 'providers/event_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/upload_provider.dart';
import 'services/event_storage_service.dart';
import 'services/upload_service.dart';
import 'screens/home_screen.dart';

class DistillAnythingApp extends StatefulWidget {
  const DistillAnythingApp({super.key});

  @override
  State<DistillAnythingApp> createState() => _DistillAnythingAppState();
}

class _DistillAnythingAppState extends State<DistillAnythingApp> {
  late final EventStorageService _eventStorage;
  late final UploadService _uploadService;
  late final EventProvider _eventProvider;
  late final SettingsProvider _settingsProvider;
  late final RecordingProvider _recordingProvider;
  late final UploadProvider _uploadProvider;

  @override
  void initState() {
    super.initState();
    _eventStorage = EventStorageService();
    _uploadService = UploadService(storage: _eventStorage);
    _eventProvider = EventProvider(storage: _eventStorage);
    _settingsProvider = SettingsProvider(uploadService: _uploadService);
    _recordingProvider = RecordingProvider();
    _uploadProvider = UploadProvider(uploadService: _uploadService);

    // Wire event creation: add to local DB and trigger immediate upload.
    _recordingProvider.onEventCreated = (event) async {
      await _eventProvider.addEvent(event);
      await _uploadProvider.uploadOne(event);
    };

    _eventProvider.loadEvents();
    _settingsProvider.loadSettings().then((_) {
      _uploadProvider.updateConfig(_settingsProvider.config);
      _uploadProvider.startAutoUpload(
        interval: const Duration(seconds: 30),
      );
      // Upload any pending events from previous sessions on startup.
      _uploadProvider.uploadAll();
    });
  }

  @override
  void dispose() {
    _uploadProvider.stopAutoUpload();
    _uploadProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _eventProvider),
        ChangeNotifierProvider.value(value: _settingsProvider),
        ChangeNotifierProvider.value(value: _recordingProvider),
        ChangeNotifierProvider.value(value: _uploadProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Distill Anything',
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: settings.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
