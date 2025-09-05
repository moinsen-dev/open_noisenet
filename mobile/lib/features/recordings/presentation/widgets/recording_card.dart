import 'package:flutter/material.dart';

import '../../../../core/database/models/audio_recording.dart';

class RecordingCard extends StatelessWidget {
  final AudioRecording recording;
  final VoidCallback? onPlay;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo;

  const RecordingCard({
    super.key,
    required this.recording,
    this.onPlay,
    this.onDelete,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = recording.expiresDateTime.isBefore(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpired 
            ? Colors.grey 
            : Theme.of(context).colorScheme.primary,
          child: Icon(
            _getRecordingIcon(),
            color: Colors.white,
          ),
        ),
        title: Text(
          'Recording ${recording.id.substring(0, 8)}...',
          style: TextStyle(
            color: isExpired ? Colors.grey : null,
            decoration: isExpired ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${recording.durationSeconds}s • ${recording.format.toUpperCase()}',
              style: TextStyle(
                color: isExpired ? Colors.grey : null,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDateTime(recording.createdDateTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            if (isExpired) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.warning,
                    size: 12,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Expired',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(action),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'play',
              enabled: !isExpired && onPlay != null,
              child: const Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text('Play'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'info',
              enabled: onInfo != null,
              child: const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('Info'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              enabled: onDelete != null,
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _getRecordingIcon() {
    if (recording.eventId != null) {
      return Icons.event;
    }
    return Icons.audiotrack;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleAction(String action) {
    switch (action) {
      case 'play':
        onPlay?.call();
        break;
      case 'info':
        onInfo?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }
}