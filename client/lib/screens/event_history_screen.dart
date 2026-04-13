import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import '../widgets/event_list_item.dart';

class EventHistoryScreen extends StatefulWidget {
  const EventHistoryScreen({super.key});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
    });
  }

  void _showEventPreview(BuildContext context, Event event) {
    switch (event.type) {
      case EventType.photo:
        _showPhotoPreview(context, event);
        break;
      case EventType.audio:
        _showAudioPreview(context, event);
        break;
      case EventType.video:
        _showVideoPreview(context, event);
        break;
      case EventType.text:
        _showTextPreview(context, event);
        break;
    }
  }

  void _showPhotoPreview(BuildContext context, Event event) {
    final path = event.payloadPath;
    if (path == null || !File(path).existsSync()) {
      _showMissingFileDialog(context, 'Photo file not found');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(File(path)),
              ),
            ),
            Positioned(
              top: 16,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioPreview(BuildContext context, Event event) {
    final path = event.payloadPath;
    if (path == null || !File(path).existsSync()) {
      _showMissingFileDialog(context, 'Audio file not found');
      return;
    }

    final player = AudioPlayer();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Audio Playback'),
          content: _AudioPlayerWidget(path: path, player: player),
          actions: [
            TextButton(
              onPressed: () {
                player.stop();
                Navigator.pop(ctx);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    ).then((_) => player.dispose());
  }

  void _showVideoPreview(BuildContext context, Event event) {
    final path = event.payloadPath;
    if (path == null || !File(path).existsSync()) {
      _showMissingFileDialog(context, 'Video file not found');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: _VideoPlayerWidget(
          path: path,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showTextPreview(BuildContext context, Event event) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final content = event.textContent ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.text_snippet, color: Colors.amber.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateFormat.format(event.timestamp),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) ...[
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    content,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ] else
                const Text('(No text content)',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              if (event.annotation != null) ...[
                const SizedBox(height: 12),
                _detailRow('Annotation', event.annotation!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMissingFileDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File Not Found'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event History'),
        actions: [
          Consumer<EventProvider>(
            builder: (context, provider, _) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter by type',
                onSelected: (value) {
                  if (value == 'all') {
                    provider.setFilter(null);
                  } else {
                    provider.setFilter(EventType.values.byName(value));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('All'),
                  ),
                  const PopupMenuItem(
                    value: 'audio',
                    child: ListTile(
                      leading: Icon(Icons.mic),
                      title: Text('Audio'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'photo',
                    child: ListTile(
                      leading: Icon(Icons.photo_camera),
                      title: Text('Photo'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'video',
                    child: ListTile(
                      leading: Icon(Icons.videocam),
                      title: Text('Video'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'text',
                    child: ListTile(
                      leading: Icon(Icons.text_snippet),
                      title: Text('Text'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<EventProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = provider.events;

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.filterType != null
                        ? 'No ${provider.filterType!.name} events yet.'
                        : 'No events recorded yet.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadEvents(),
            child: ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final event = events[index];
                return EventListItem(
                  event: event,
                  onTap: () => _showEventPreview(context, event),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String path;
  final AudioPlayer player;

  const _AudioPlayerWidget({required this.path, required this.player});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late final AudioPlayer _player;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = widget.player;
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setFilePath(widget.path);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _player.stop();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 120,
        child: Center(child: Text('Failed to load audio:\n$_error')),
      );
    }

    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final processingState = playerState?.processingState;
              final playing = playerState?.playing ?? false;

              if (processingState == ProcessingState.loading ||
                  processingState == ProcessingState.buffering) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                );
              }

              return IconButton(
                iconSize: 56,
                icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                onPressed: () {
                  if (playing) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
                },
              );
            },
          ),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  final max = duration.inMilliseconds.toDouble();
                  final value = position.inMilliseconds.toDouble().clamp(0.0, max);

                  return Column(
                    children: [
                      Slider(
                        max: max > 0 ? max : 1.0,
                        value: value,
                        onChanged: (newValue) {
                          _player.seek(Duration(milliseconds: newValue.toInt()));
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position)),
                            Text(_formatDuration(duration)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String path;
  final VoidCallback onClose;

  const _VideoPlayerWidget({required this.path, required this.onClose});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _controller.initialize().then((_) {
      setState(() => _isInitialized = true);
      _controller.play();
    }).catchError((e) {
      setState(() => _error = e.toString());
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (_error != null)
          Center(
            child: Text('Failed to load video:\n$_error',
                style: const TextStyle(color: Colors.white)),
          )
        else if (!_isInitialized)
          const Center(child: CircularProgressIndicator())
        else
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
        // Close button
        Positioned(
          top: 16,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            onPressed: widget.onClose,
          ),
        ),
        // Controls overlay
        if (_isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Column(
              children: [
                // Play/pause
                IconButton(
                  iconSize: 56,
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      if (_controller.value.position >=
                          _controller.value.duration) {
                        await _controller.seekTo(Duration.zero);
                      }
                      _controller.play();
                    }
                  },
                ),
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(_controller.value.position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          max: _controller.value.duration.inMilliseconds
                              .toDouble()
                              .clamp(1.0, double.infinity),
                          value: _controller.value.position.inMilliseconds
                              .toDouble()
                              .clamp(0.0, _controller.value.duration.inMilliseconds.toDouble()),
                          onChanged: (v) {
                            _controller.seekTo(Duration(milliseconds: v.toInt()));
                          },
                        ),
                      ),
                      Text(
                        _formatDuration(_controller.value.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
