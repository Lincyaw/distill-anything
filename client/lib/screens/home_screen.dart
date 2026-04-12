import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recording_state.dart';
import '../providers/recording_provider.dart';
import '../widgets/recording_controls.dart';
import '../widgets/mode_switcher.dart';
import '../widgets/connection_status.dart';
import '../widgets/storage_indicator.dart';
import 'event_history_screen.dart';
import 'settings_screen.dart';
import 'text_input_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distill Anything'),
        actions: [
          const ConnectionStatus(),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Event History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EventHistoryScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const StorageIndicator(),
          const ModeSwitcher(),
          const Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: RecordingControls(),
              ),
            ),
          ),
          // Show quick-note FAB hint only in text mode
          Consumer<RecordingProvider>(
            builder: (context, provider, _) {
              if (provider.state.mode == RecordingMode.text) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Tap the button below to write a note',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      floatingActionButton: Consumer<RecordingProvider>(
        builder: (context, provider, _) {
          // Show FAB for quick text entry in all modes
          if (provider.state.isRecording) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TextInputScreen(),
              ),
            ),
            tooltip: 'Quick Note',
            child: const Icon(Icons.edit_note),
          );
        },
      ),
    );
  }
}
