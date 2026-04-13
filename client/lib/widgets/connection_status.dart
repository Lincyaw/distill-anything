import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';

class ConnectionStatus extends StatelessWidget {
  const ConnectionStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, EventProvider>(
      builder: (context, settings, events, _) {
        final isTesting = settings.isTesting;
        final connected = settings.config.isConnected;
        final pending = events.pendingUploadCount;
        final failed = events.failedUploadCount;

        String label;
        Color dotColor;
        if (isTesting) {
          label = 'Connecting...';
          dotColor = Colors.grey;
        } else if (connected) {
          label = 'Connected';
          dotColor = Colors.green;
        } else {
          label = 'Offline';
          dotColor = Colors.red;
        }

        String badge = '';
        if (failed > 0) {
          badge = ' \u00b7 $failed\u2717';
        } else if (pending > 0) {
          badge = ' \u00b7 $pending\u2191';
        }
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: dotColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '$label$badge',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
