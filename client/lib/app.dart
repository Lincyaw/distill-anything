import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/recording_provider.dart';
import 'providers/event_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/upload_provider.dart';
import 'services/event_storage_service.dart';
import 'screens/home_screen.dart';

class DistillAnythingApp extends StatelessWidget {
  const DistillAnythingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final eventStorage = EventStorageService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final provider = EventProvider(storage: eventStorage);
          provider.loadEvents();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = SettingsProvider();
          provider.loadSettings();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = RecordingProvider();
          provider.eventStorageService = eventStorage;
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => UploadProvider()),
      ],
      child: MaterialApp(
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
        home: const HomeScreen(),
      ),
    );
  }
}
