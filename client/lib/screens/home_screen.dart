import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recording_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/recording_controls.dart';
import '../widgets/mode_switcher.dart';
import '../widgets/connection_status.dart';
import '../models/recording_state.dart';
import 'event_history_screen.dart';
import 'settings_screen.dart';
import 'text_input_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _serverBannerDismissed = false;

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
          // Server setup banner for first-time users
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              if (settings.isConnected || _serverBannerDismissed) {
                return const SizedBox.shrink();
              }
              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Recording works offline. Set up a server to sync your data.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        ),
                        child: const Text('Set up'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setState(() => _serverBannerDismissed = true),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const ModeSwitcher(),
          const Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: RecordingControls(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<RecordingProvider>(
        builder: (context, provider, _) {
          // Hide FAB when recording or in text mode (inline input available)
          if (provider.state.isRecording ||
              provider.state.mode == RecordingMode.text) {
            return const SizedBox.shrink();
          }
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
