import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recording_state.dart';
import '../providers/recording_provider.dart';

class RecordingControls extends StatelessWidget {
  const RecordingControls({super.key});

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.lastError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.lastError!,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: provider.clearError,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            switch (state.mode) {
              RecordingMode.audio => _AudioControls(
                  state: state,
                  provider: provider,
                  formatDuration: _formatDuration,
                ),
              RecordingMode.photo => _PhotoControls(provider: provider),
              RecordingMode.video => _VideoControls(
                  state: state,
                  provider: provider,
                  formatDuration: _formatDuration,
                ),
              RecordingMode.text => _TextControls(provider: provider),
            },
          ],
        );
      },
    );
  }
}

class _AudioControls extends StatelessWidget {
  final RecordingState state;
  final RecordingProvider provider;
  final String Function(Duration) formatDuration;

  const _AudioControls({
    required this.state,
    required this.provider,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = state.isRecording;
    final isPaused = state.status == RecordingStatus.paused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Elapsed time
        if (isRecording || isPaused) ...[
          Text(
            formatDuration(state.elapsed ?? Duration.zero),
            style: theme.textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          // Pulsing recording indicator
          _RecordingDot(isActive: isRecording),
          const SizedBox(height: 24),
        ],

        if (!isRecording && !isPaused) ...[
          // Waveform placeholder
          Icon(
            Icons.graphic_eq,
            size: 80,
            color: theme.colorScheme.primary.withAlpha(60),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap to record audio',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRecording || isPaused) ...[
              // Pause / Resume
              FilledButton.tonalIcon(
                onPressed: isPaused
                    ? () => provider.resumeRecording()
                    : () => provider.pauseRecording(),
                icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(isPaused ? 'Resume' : 'Pause'),
              ),
              const SizedBox(width: 16),
              // Stop
              FilledButton.icon(
                onPressed: () => provider.stopRecording(),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ] else ...[
              // Large record button
              SizedBox(
                width: 80,
                height: 80,
                child: FilledButton(
                  onPressed: () => provider.startRecording(),
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: const Icon(Icons.mic, size: 36),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PhotoControls extends StatelessWidget {
  final RecordingProvider provider;

  const _PhotoControls({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Camera preview placeholder
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.camera_alt,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Tap to capture photo',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 72,
          height: 72,
          child: FilledButton(
            onPressed: () => provider.capturePhoto(),
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.camera, size: 32),
          ),
        ),
      ],
    );
  }
}

class _VideoControls extends StatelessWidget {
  final RecordingState state;
  final RecordingProvider provider;
  final String Function(Duration) formatDuration;

  const _VideoControls({
    required this.state,
    required this.provider,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = state.isRecording;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Camera preview placeholder
        Container(
          width: 240,
          height: 180,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.videocam,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
              ),
              if (isRecording)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _RecordingDot(isActive: true),
                      const SizedBox(width: 4),
                      Text(
                        formatDuration(state.elapsed ?? Duration.zero),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (!isRecording)
          Text(
            'Tap to record video',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: 72,
          height: 72,
          child: FilledButton(
            onPressed: isRecording
                ? () => provider.stopRecording()
                : () => provider.startRecording(),
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor:
                  isRecording ? theme.colorScheme.error : theme.colorScheme.primary,
              foregroundColor:
                  isRecording ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
            ),
            child: Icon(
              isRecording ? Icons.stop : Icons.videocam,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextControls extends StatelessWidget {
  final RecordingProvider provider;

  const _TextControls({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.edit_note,
          size: 80,
          color: theme.colorScheme.primary.withAlpha(60),
        ),
        const SizedBox(height: 16),
        Text(
          'Use the note button to create a text entry',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Small pulsing red dot indicating active recording.
class _RecordingDot extends StatefulWidget {
  final bool isActive;

  const _RecordingDot({required this.isActive});

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _RecordingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: const Icon(Icons.circle, size: 12, color: Colors.red),
        );
      },
    );
  }
}
