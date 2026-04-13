import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../models/recording_state.dart';
import '../providers/event_provider.dart';
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
                  provider: provider,
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

  Future<void> _stopWithAnnotation(BuildContext context) async {
    final event = await provider.stopRecording();
    if (!context.mounted || event == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Audio saved'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Add label',
          onPressed: () => _showAnnotationSheet(context, event),
        ),
      ),
    );
  }

  void _showAnnotationSheet(BuildContext context, Event event) {
    if (!context.mounted) return;
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Label for this recording',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    final updated = event.copyWith(annotation: text);
                    context.read<EventProvider>().updateEvent(updated);
                  }
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

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
                onPressed: () => _stopWithAnnotation(context),
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

  Future<void> _takePhoto(BuildContext context) async {
    final xFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (xFile != null && context.mounted) {
      await context
          .read<RecordingProvider>()
          .createEventFromFile(xFile.path, EventType.photo);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.camera_alt,
          size: 80,
          color: theme.colorScheme.primary.withAlpha(60),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to take a photo',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 80,
          height: 80,
          child: FilledButton(
            onPressed: () => _takePhoto(context),
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.camera_alt, size: 36),
          ),
        ),
      ],
    );
  }
}

class _VideoControls extends StatelessWidget {
  final RecordingProvider provider;

  const _VideoControls({
    required this.provider,
  });

  Future<void> _recordVideo(BuildContext context) async {
    final xFile = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (xFile != null && context.mounted) {
      await context
          .read<RecordingProvider>()
          .createEventFromFile(xFile.path, EventType.video);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.videocam,
          size: 80,
          color: theme.colorScheme.primary.withAlpha(60),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to record video',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 80,
          height: 80,
          child: FilledButton(
            onPressed: () => _recordVideo(context),
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Icon(Icons.videocam, size: 36),
          ),
        ),
      ],
    );
  }
}

class _TextControls extends StatefulWidget {
  final RecordingProvider provider;

  const _TextControls({required this.provider});

  @override
  State<_TextControls> createState() => _TextControlsState();
}

class _TextControlsState extends State<_TextControls> {
  final _textController = TextEditingController();
  final _annotationController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    _annotationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final annotation = _annotationController.text.trim();
    await widget.provider.createTextEvent(
      text,
      annotation: annotation.isEmpty ? null : annotation,
    );

    if (mounted) {
      _textController.clear();
      _annotationController.clear();
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _annotationController,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              hintText: 'Write your note here...',
              border: OutlineInputBorder(),
            ),
            maxLines: 10,
            minLines: 5,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
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
