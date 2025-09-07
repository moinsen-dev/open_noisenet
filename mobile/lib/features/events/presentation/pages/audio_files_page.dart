import 'package:flutter/material.dart';

import '../../../../core/database/dao/audio_recording_dao.dart';
import '../../../../core/database/models/audio_recording.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../services/audio_recording_service.dart';
import '../../../../widgets/shared_app_bar.dart';
import '../../../../widgets/audio_player_widget.dart';

class AudioFilesPage extends StatefulWidget {
  const AudioFilesPage({super.key});

  @override
  State<AudioFilesPage> createState() => _AudioFilesPageState();
}

class _AudioFilesPageState extends State<AudioFilesPage> {
  final AudioRecordingDao _recordingDao = AudioRecordingDao();
  final AudioRecordingService _audioService = AudioRecordingService();

  bool _isAudioServiceInitialized = false;
  List<AudioRecording> _recordings = [];
  bool _isLoading = true;
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    _initializeAudioService();
    _loadRecordings();
  }

  Future<void> _initializeAudioService() async {
    try {
      await _audioService.initialize();
      if (mounted) {
        setState(() {
          _isAudioServiceInitialized = true;
        });
      }
    } catch (e) {
      AppLogger.ui('Failed to initialize audio service: $e');
    }
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoading = true);
    try {
      final recordings = await _recordingDao.getRecent(limit: 1000);
      
      // Sort recordings based on selected criteria
      recordings.sort((AudioRecording a, AudioRecording b) {
        switch (_sortBy) {
          case 'newest':
            return b.createdDateTime.compareTo(a.createdDateTime);
          case 'oldest':
            return a.createdDateTime.compareTo(b.createdDateTime);
          case 'duration':
            return b.durationSeconds.compareTo(a.durationSeconds);
          case 'size':
            return (b.fileSize ?? 0).compareTo(a.fileSize ?? 0);
          default:
            return b.createdAt.compareTo(a.createdAt);
        }
      });

      setState(() {
        _recordings = recordings;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.ui('Failed to load recordings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRecording(AudioRecording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text(
          'Are you sure you want to delete this recording?\n\n'
          'Created: ${_formatDate(recording.createdDateTime)}\n'
          'Duration: ${_formatDuration(recording.durationSeconds)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _recordingDao.deleteById(recording.id);
        _loadRecordings(); // Reload the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording deleted successfully')),
          );
        }
      } catch (e) {
        AppLogger.ui('Failed to delete recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete recording: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllRecordings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Recordings'),
        content: Text(
          'Are you sure you want to delete all ${_recordings.length} recordings?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final recording in _recordings) {
          await _recordingDao.deleteById(recording.id);
        }
        _loadRecordings(); // Reload the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All recordings deleted successfully')),
          );
        }
      } catch (e) {
        AppLogger.ui('Failed to delete all recordings: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete all recordings: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dateTime.weekday - 1]} • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day} • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SharedAppBar(
        pageTitle: 'Audio Files',
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort recordings',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _loadRecordings();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'newest',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18),
                    SizedBox(width: 8),
                    Text('Newest first'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'oldest',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 8),
                    Text('Oldest first'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'duration',
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 18),
                    SizedBox(width: 8),
                    Text('By duration'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'size',
                child: Row(
                  children: [
                    Icon(Icons.storage, size: 18),
                    SizedBox(width: 8),
                    Text('By file size'),
                  ],
                ),
              ),
            ],
          ),
          if (_recordings.isNotEmpty)
            IconButton(
              onPressed: _deleteAllRecordings,
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Delete all recordings',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Summary header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surface,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_recordings.length} recording${_recordings.length != 1 ? 's' : ''}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            'Total: ${_formatFileSize(_recordings.fold<int>(0, (sum, r) => sum + (r.fileSize ?? 0)))}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Recordings list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadRecordings,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _recordings.length,
                          itemBuilder: (context, index) {
                            final recording = _recordings[index];
                            return _buildRecordingCard(recording);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.audiotrack_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Audio Recordings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Audio files will appear here when monitoring detects noise events above the threshold.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadRecordings,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingCard(AudioRecording recording) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(recording.createdDateTime),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(recording.durationSeconds),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.storage,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatFileSize(recording.fileSize),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteRecording(recording),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete recording',
                  color: Colors.red,
                ),
              ],
            ),
            
            if (recording.avgLevel != null || recording.peakLevel != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (recording.avgLevel != null) ...[
                    Icon(
                      Icons.volume_up,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Avg: ${recording.avgLevel!.toStringAsFixed(1)} dB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (recording.avgLevel != null && recording.peakLevel != null)
                    const SizedBox(width: 16),
                  if (recording.peakLevel != null) ...[
                    Icon(
                      Icons.trending_up,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Peak: ${recording.peakLevel!.toStringAsFixed(1)} dB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Audio player widget
            if (_isAudioServiceInitialized)
              AudioPlayerWidget(
                recording: recording,
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Initializing audio service...'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}