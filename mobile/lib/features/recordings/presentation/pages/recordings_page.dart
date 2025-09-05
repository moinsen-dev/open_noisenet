import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../services/audio_recording_service.dart';
import '../../../../core/database/dao/audio_recording_dao.dart';
import '../../../../core/database/models/audio_recording.dart';
import '../widgets/recording_card.dart';

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  final AudioRecordingService _recordingService = AudioRecordingService();
  final AudioRecordingDao _recordingDao = AudioRecordingDao();
  
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _recordingService.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize recording service: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showStorageInfo,
            icon: const Icon(Icons.info_outline),
            tooltip: 'Storage Information',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'cleanup', child: Text('Cleanup Expired')),
              const PopupMenuItem(value: 'settings', child: Text('Recording Settings')),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isInitialized ? _buildFab() : null,
    );
  }

  Widget _buildBody() {
    if (!_isInitialized && _errorMessage.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing recording service...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeServices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshRecordings,
      child: Column(
        children: [
          // Recording Status Card
          _buildRecordingStatusCard(),
          
          // Recordings List
          Expanded(
            child: _buildRecordingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingStatusCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recording Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            StreamBuilder<RecordingState>(
              stream: _recordingService.stateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? RecordingState.stopped;
                final currentRecording = _recordingService.getCurrentRecording();
                
                return Column(
                  children: [
                    Row(
                      children: [
                        _buildStatusIndicator(state),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStateDescription(state),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (currentRecording != null)
                                Text(
                                  'Recording: ${currentRecording.id.substring(0, 8)}...',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          'Active: ${_recordingService.activeRecordingCount}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (state == RecordingState.recording && currentRecording != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _getRecordingProgress(currentRecording),
                        backgroundColor: Colors.grey[300],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(RecordingState state) {
    Color color;
    IconData icon;
    
    switch (state) {
      case RecordingState.recording:
        color = Colors.red;
        icon = Icons.fiber_manual_record;
        break;
      case RecordingState.paused:
        color = Colors.orange;
        icon = Icons.pause;
        break;
      case RecordingState.stopped:
        color = Colors.grey;
        icon = Icons.stop;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getStateDescription(RecordingState state) {
    switch (state) {
      case RecordingState.recording:
        return 'Recording in progress';
      case RecordingState.paused:
        return 'Recording paused';
      case RecordingState.stopped:
        return 'No active recording';
    }
  }

  double _getRecordingProgress(AudioRecording recording) {
    final now = DateTime.now();
    final elapsed = now.difference(recording.startDateTime).inSeconds;
    final total = recording.durationSeconds;
    return total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
  }

  Widget _buildRecordingsList() {
    return FutureBuilder<List<AudioRecording>>(
      future: _recordingDao.getRecent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading recordings: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshRecordings,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final recordings = snapshot.data ?? [];
        
        if (recordings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No recordings found'),
                SizedBox(height: 8),
                Text(
                  'Start monitoring to automatically create recordings',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: recordings.length,
          itemBuilder: (context, index) {
            final recording = recordings[index];
            return RecordingCard(
              recording: recording,
              onPlay: () => _playRecording(recording),
              onDelete: () => _deleteRecording(recording),
              onInfo: () => _showRecordingInfo(recording),
            );
          },
        );
      },
    );
  }

  Widget? _buildFab() {
    return StreamBuilder<RecordingState>(
      stream: _recordingService.stateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? RecordingState.stopped;
        
        switch (state) {
          case RecordingState.stopped:
            return FloatingActionButton.extended(
              onPressed: _startRecording,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Start Recording'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            );
          case RecordingState.recording:
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'pause',
                  onPressed: _pauseRecording,
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.pause),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'stop',
                  onPressed: _stopRecording,
                  backgroundColor: Colors.grey,
                  child: const Icon(Icons.stop),
                ),
              ],
            );
          case RecordingState.paused:
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'resume',
                  onPressed: _resumeRecording,
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.play_arrow),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'stop',
                  onPressed: _stopRecording,
                  backgroundColor: Colors.grey,
                  child: const Icon(Icons.stop),
                ),
              ],
            );
        }
      },
    );
  }

  Future<void> _startRecording() async {
    final recordingId = await _recordingService.startRecording();
    if (recordingId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording started: ${recordingId.substring(0, 8)}...')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start recording'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pauseRecording() async {
    await _recordingService.pauseRecording();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording paused')),
    );
  }

  Future<void> _resumeRecording() async {
    await _recordingService.resumeRecording();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording resumed')),
    );
  }

  Future<void> _stopRecording() async {
    final recording = await _recordingService.stopRecording();
    if (recording != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording saved: ${recording.id.substring(0, 8)}...')),
      );
      _refreshRecordings();
    }
  }

  Future<void> _playRecording(AudioRecording recording) async {
    // TODO: Implement audio playback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio playback not yet implemented')),
    );
  }

  Future<void> _deleteRecording(AudioRecording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text('Are you sure you want to delete this recording?\n\nID: ${recording.id.substring(0, 8)}...'),
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
      final success = await _recordingService.deleteRecording(recording.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording deleted')),
        );
        _refreshRecordings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete recording'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRecordingInfo(AudioRecording recording) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recording Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('ID', recording.id.substring(0, 8) + '...'),
              _buildInfoRow('Duration', '${recording.durationSeconds}s'),
              _buildInfoRow('Format', recording.format.toUpperCase()),
              _buildInfoRow('Sample Rate', '${recording.sampleRate} Hz'),
              if (recording.fileSize != null)
                _buildInfoRow('File Size', '${(recording.fileSize! / 1024).toStringAsFixed(1)} KB'),
              _buildInfoRow('Created', recording.createdDateTime.toString()),
              _buildInfoRow('Expires', recording.expiresDateTime.toString()),
              if (recording.eventId != null)
                _buildInfoRow('Event ID', recording.eventId!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _showStorageInfo() async {
    final storageInfo = await _recordingService.getStorageInfo();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Information'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('Total Recordings', '${storageInfo['total_recordings'] ?? 0}'),
            _buildInfoRow('Total Size', '${((storageInfo['total_size'] ?? 0) / 1024).toStringAsFixed(1)} KB'),
            _buildInfoRow('Active Recordings', '${storageInfo['active_recordings'] ?? 0}'),
            _buildInfoRow('Max Recordings', '${storageInfo['max_recordings'] ?? 0}'),
            const Divider(),
            _buildInfoRow('Directory', '${storageInfo['recordings_directory'] ?? 'Unknown'}'),
            _buildInfoRow('Directory Exists', '${storageInfo['directory_exists'] ?? false}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'cleanup':
        await _cleanupExpired();
        break;
      case 'settings':
        context.push('/settings');
        break;
    }
  }

  Future<void> _cleanupExpired() async {
    final count = await _recordingService.cleanupExpiredRecordings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleaned up $count expired recordings')),
      );
      _refreshRecordings();
    }
  }

  Future<void> _refreshRecordings() async {
    setState(() {}); // Trigger rebuild of FutureBuilder
  }
}