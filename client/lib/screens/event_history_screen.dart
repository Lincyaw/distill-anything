import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
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
      case EventType.text:
        _showTextDetail(context, event);
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

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Audio Playback'),
          content: _AudioPlayerWidget(path: path),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showTextDetail(BuildContext context, Event event) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${event.type.name[0].toUpperCase()}${event.type.name.substring(1)} Event'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('ID', event.id),
              _detailRow('Time', dateFormat.format(event.timestamp)),
              _detailRow('Type', event.type.name),
              _detailRow('Status', event.uploadStatus.name),
              if (event.textContent != null)
                _detailRow('Content', event.textContent!),
              if (event.annotation != null)
                _detailRow('Annotation', event.annotation!),
              if (event.payloadPath != null)
                _detailRow('File', event.payloadPath!),
              if (event.fileSizeBytes != null)
                _detailRow('Size', _formatFileSize(event.fileSizeBytes!)),
              if (event.checksum != null)
                _detailRow('Checksum', '${event.checksum!.substring(0, 16)}...'),
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event History'),
        actions: [
          Consumer<EventProvider>(
            builder: (context, provider, _) {
              return PopupMenuButton<EventType?>(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter by type',
                onSelected: (type) => provider.setFilter(type),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: null,
                    child: Text('All'),
                  ),
                  const PopupMenuItem(
                    value: EventType.audio,
                    child: ListTile(
                      leading: Icon(Icons.mic),
                      title: Text('Audio'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: EventType.photo,
                    child: ListTile(
                      leading: Icon(Icons.photo_camera),
                      title: Text('Photo'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: EventType.video,
                    child: ListTile(
                      leading: Icon(Icons.videocam),
                      title: Text('Video'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: EventType.text,
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

  const _AudioPlayerWidget({required this.path});

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
    _player = AudioPlayer();
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
    _player.dispose();
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
