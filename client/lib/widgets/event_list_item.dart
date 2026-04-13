import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';

class EventListItem extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const EventListItem({super.key, required this.event, this.onTap, this.onRetry});

  IconData get _typeIcon {
    switch (event.type) {
      case EventType.audio:
        return Icons.mic;
      case EventType.photo:
        return Icons.photo_camera;
      case EventType.video:
        return Icons.videocam;
      case EventType.text:
        return Icons.text_snippet;
    }
  }

  Color get _typeColor {
    switch (event.type) {
      case EventType.audio:
        return Colors.indigo;
      case EventType.photo:
        return Colors.teal;
      case EventType.video:
        return Colors.deepOrange;
      case EventType.text:
        return Colors.amber.shade700;
    }
  }

  IconData get _statusIcon {
    switch (event.uploadStatus) {
      case UploadStatus.pending:
        return Icons.schedule;
      case UploadStatus.uploading:
        return Icons.sync;
      case UploadStatus.uploaded:
        return Icons.check_circle_outline;
      case UploadStatus.verified:
        return Icons.verified;
      case UploadStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _statusColor(BuildContext context) {
    switch (event.uploadStatus) {
      case UploadStatus.pending:
        return Colors.grey;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.uploaded:
        return Colors.orange;
      case UploadStatus.verified:
        return Colors.green;
      case UploadStatus.failed:
        return Colors.red;
    }
  }

  String get _subtitle {
    switch (event.type) {
      case EventType.audio:
        final size = _fileSizeLabel;
        return size != null ? 'Audio recording  $size' : 'Audio recording';
      case EventType.photo:
        final size = _fileSizeLabel;
        return size != null ? 'Photo  $size' : 'Photo';
      case EventType.video:
        final size = _fileSizeLabel;
        return size != null ? 'Video  $size' : 'Video';
      case EventType.text:
        final preview = event.textContent ?? '';
        return preview.length > 60 ? '${preview.substring(0, 60)}...' : preview;
    }
  }

  String? get _fileSizeLabel {
    final bytes = event.fileSizeBytes;
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Build a thumbnail widget for photo events.
  Widget _buildLeading() {
    if (event.type == EventType.photo && event.payloadPath != null) {
      final file = File(event.payloadPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            cacheWidth: 96, // decode at 2x for sharpness
            errorBuilder: (_, __, ___) => _buildIconLeading(),
          ),
        );
      }
    }
    return _buildIconLeading();
  }

  Widget _buildIconLeading() {
    return CircleAvatar(
      backgroundColor: _typeColor.withAlpha(30),
      child: Icon(_typeIcon, color: _typeColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('yyyy-MM-dd');

    return ListTile(
      leading: _buildLeading(),
      title: Text(
        timeFormat.format(event.timestamp),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_subtitle),
          Text(
            dateFormat.format(event.timestamp),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      trailing: event.uploadStatus == UploadStatus.failed
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon, size: 20, color: Colors.red),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Colors.red),
                  tooltip: 'Retry upload',
                  onPressed: onRetry,
                ),
              ],
            )
          : Icon(
              _statusIcon,
              size: 20,
              color: _statusColor(context),
            ),
      onTap: onTap,
    );
  }
}
