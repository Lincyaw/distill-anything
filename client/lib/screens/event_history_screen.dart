import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import '../providers/upload_provider.dart';
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

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

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
            // Top bar with close + info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  color: Colors.black38,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dateFormat.format(event.timestamp),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                            if (event.fileSizeBytes != null)
                              Text(
                                _formatFileSize(event.fileSizeBytes!),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.indigo.withAlpha(30),
                      child: const Icon(Icons.mic, color: Colors.indigo),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Audio Recording',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            dateFormat.format(event.timestamp),
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (event.fileSizeBytes != null)
                      Text(
                        _formatFileSize(event.fileSizeBytes!),
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _AudioPlayerWidget(path: path),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

          // Build a list of display items: date headers + events.
          final List<_ListItem> items = [];
          String? lastDateLabel;
          final dateFmt = DateFormat('yyyy-MM-dd, EEEE');
          for (final event in events) {
            final dateLabel = dateFmt.format(event.timestamp);
            if (dateLabel != lastDateLabel) {
              items.add(_DateHeaderItem(dateLabel));
              lastDateLabel = dateLabel;
            }
            items.add(_EventItem(event));
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadEvents(),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                if (item is _DateHeaderItem) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(120),
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  );
                }
                final event = (item as _EventItem).event;
                return Dismissible(
                  key: ValueKey(event.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child:
                        const Icon(Icons.delete, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Event'),
                        content: const Text(
                            'Are you sure you want to delete this event? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    provider.deleteEvent(event.id);
                  },
                  child: EventListItem(
                    event: event,
                    onTap: () => _showEventPreview(context, event),
                    onRetry: event.uploadStatus == UploadStatus.failed
                        ? () async {
                            await context.read<UploadProvider>().uploadOne(event);
                            if (context.mounted) {
                              // Reload from DB to get the actual status set by UploadService
                              await context.read<EventProvider>().loadEvents();
                            }
                          }
                        : null,
                  ),
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
    _player.stop();
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
      // Don't auto-play — show first frame, let user tap to play
    }).catchError((e) {
      setState(() => _error = e.toString());
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

  void _togglePlayPause() async {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        await _controller.seekTo(Duration.zero);
      }
      _controller.play();
    }
    setState(() {});
  }

  void _onTapVideo() {
    _togglePlayPause();
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
          GestureDetector(
            onTap: _onTapVideo,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    // Play icon overlay when paused
                    if (!_controller.value.isPlaying)
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 56),
                      ),
                  ],
                ),
              ),
            ),
          ),
        // Close button
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: widget.onClose,
              ),
            ),
          ),
        ),
        // Controls overlay
        if (_isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final maxMs =
                      value.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
                  final posMs =
                      value.position.inMilliseconds.toDouble().clamp(0.0, maxMs);
                  return Container(
                    color: Colors.black38,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(value.position),
                          style:
                              const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            max: maxMs,
                            value: posMs,
                            onChanged: (v) {
                              _controller
                                  .seekTo(Duration(milliseconds: v.toInt()));
                            },
                          ),
                        ),
                        Text(
                          _formatDuration(value.duration),
                          style:
                              const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

// Helper types for mixed date-header + event list.
sealed class _ListItem {}

class _DateHeaderItem extends _ListItem {
  final String label;
  _DateHeaderItem(this.label);
}

class _EventItem extends _ListItem {
  final Event event;
  _EventItem(this.event);
}
