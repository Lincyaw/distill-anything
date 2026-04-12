import 'package:flutter/material.dart';

class StorageIndicator extends StatelessWidget {
  const StorageIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder usage ratio — StorageManagerService methods are not yet
    // implemented, so we display a static indicator.
    const double usageRatio = 0.0;

    final Color barColor;
    if (usageRatio < 0.6) {
      barColor = Colors.green;
    } else if (usageRatio < 0.85) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                '${(usageRatio * 100).toStringAsFixed(0)}% used',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: usageRatio,
            color: barColor,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}
