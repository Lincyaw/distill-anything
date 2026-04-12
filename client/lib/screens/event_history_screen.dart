import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    // Load events when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
    });
  }

  void _showEventDetail(BuildContext context, Event event) {
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
          // Filter dropdown
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
                  onTap: () => _showEventDetail(context, event),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
