import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../features/app/presentation/bloc/app_bloc.dart';
import '../../../../services/audio_capture_service.dart';
import '../../../../services/location_service.dart';
import '../../../../services/recording_service.dart';
import '../../../../services/sqlite_preferences_service.dart';
import '../../../../services/api_client_service.dart';
import '../../../../services/backend_sync_service.dart';
import '../../../../services/network_utils.dart';
import '../../../../core/database/dao/noise_measurement_dao.dart';
import '../../../../core/database/dao/daily_statistics_dao.dart';
import '../../../../core/database/dao/audio_recording_dao.dart';
import '../../../../core/database/dao/ai_analysis_queue_dao.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../widgets/shared_app_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SQLitePreferencesService _preferencesService =
      GetIt.instance<SQLitePreferencesService>();
  final LocationService _locationService = LocationService();
  final AudioCaptureService _audioService =
      GetIt.instance<AudioCaptureService>();
  final RecordingService _recordingService = RecordingService();
  final ApiClientService _apiClientService = GetIt.instance<ApiClientService>();
  final BackendSyncService _syncService = GetIt.instance<BackendSyncService>();

  // Database DAOs for data management
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  final DailyStatisticsDao _statisticsDao = DailyStatisticsDao();
  final AudioRecordingDao _audioRecordingDao = AudioRecordingDao();
  final AiAnalysisQueueDao _aiAnalysisDao = AiAnalysisQueueDao();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SharedAppBar(
        pageTitle: 'Settings',
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, appState) {
          return ListView(
            children: [
              // Theme Settings
              _buildThemeSection(context, appState),
              const Divider(),

              // Location Settings
              _buildLocationSection(context),
              const Divider(),

              // Audio Settings
              _buildAudioSection(context),
              const Divider(),

              // Continuous Recording Settings
              _buildContinuousRecordingSection(context),
              const Divider(),

              // Backend Integration 
              _buildSyncSection(context),
              const Divider(),

              // Authentication
              _buildAuthSection(context),
              const Divider(),

              // Data Management
              _buildDataManagementSection(context),
              const Divider(),

              // Privacy & Info
              _buildPrivacySection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, AppState appState) {
    final isDarkMode = appState is AppLoaded ? appState.isDarkMode : true;

    return ListTile(
      leading: const Icon(Icons.dark_mode),
      title: const Text('Dark Mode'),
      subtitle: Text(isDarkMode ? 'Dark theme enabled' : 'Light theme enabled'),
      trailing: Switch(
        value: isDarkMode,
        onChanged: (value) {
          context.read<AppBloc>().add(AppThemeChanged(isDarkMode: value));
        },
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.location_on),
          title: const Text('Location Settings'),
          subtitle: const Text('Manage location permissions and accuracy'),
          onTap: () => _showLocationDialog(context),
        ),
        FutureBuilder<bool>(
          future: _locationService.hasLocationPermission(),
          builder: (context, snapshot) {
            final hasPermission = snapshot.data ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    hasPermission ? Icons.check_circle : Icons.error,
                    color: hasPermission ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasPermission
                        ? 'Location permission granted'
                        : 'Location permission denied',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAudioSection(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.volume_up),
      title: const Text('Audio Settings'),
      subtitle: Text(
          'Calibration: ${_audioService.calibrationOffset.toStringAsFixed(1)} dB'),
      onTap: () => _showAudioDialog(context),
    );
  }

  Widget _buildContinuousRecordingSection(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        final settings = _recordingService.getSettings();
        final state = _recordingService.state;
        return {
          ...settings,
          'state': state.name,
        };
      }(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final isEnabled = data?['enabled'] == true;
        final isActive = data?['state'] == 'active';

        return Column(
          children: [
            ListTile(
              leading: Icon(
                isActive
                    ? Icons.fiber_smart_record
                    : Icons.radio_button_unchecked,
                color: isActive ? Colors.red : null,
              ),
              title: const Text('Continuous Recording'),
              subtitle: Text(isEnabled
                  ? (isActive
                      ? 'Active - Auto-detecting noise events'
                      : 'Enabled - Ready to start')
                  : 'Disabled - Manual recording only'),
              trailing: Switch(
                value: isEnabled,
                onChanged: (value) async {
                  await _recordingService.updateSettings(
                    enableContinuousRecording: value,
                  );
                  setState(() {});
                },
              ),
              onTap: () => _showContinuousRecordingDialog(context),
            ),
            if (isEnabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Buffer: ${data?['buffer_duration_minutes'] ?? 15} min',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Threshold: ${data?['auto_record_threshold'] ?? 65}dB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSyncSection(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<String>(
          future: _preferencesService.getBackendUrl(),
          builder: (context, snapshot) {
            final backendUrl = snapshot.data ?? 'Loading...';
            return ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: const Text('Backend Integration'),
              subtitle: Text('Backend: $backendUrl'),
              onTap: () => _showSyncDialog(context),
            );
          },
        ),
        FutureBuilder<bool>(
          future: _preferencesService.getForceOfflineMode(),
          builder: (context, snapshot) {
            final isOfflineMode = snapshot.data ?? false;
            return ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Offline Mode'),
              subtitle: Text(isOfflineMode 
                  ? 'Offline only - Backend disabled' 
                  : 'Auto-detect backend connectivity'),
              trailing: Switch(
                value: isOfflineMode,
                onChanged: (value) async {
                  await _preferencesService.setForceOfflineMode(value);
                  setState(() {});
                },
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _syncService.getBackendStatus(),
            builder: (context, snapshot) {
              final status = snapshot.data;
              if (status == null) {
                return Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Checking backend status...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }
              
              final mode = status['mode'] as String;
              final queuedEvents = status['queued_events'] as int;
              
              Color statusColor;
              IconData statusIcon;
              String statusText;
              
              switch (mode) {
                case 'offline':
                  statusColor = Colors.grey;
                  statusIcon = Icons.cloud_off;
                  statusText = queuedEvents > 0 
                      ? 'Offline - $queuedEvents events queued' 
                      : 'Offline mode';
                  break;
                case 'anonymous':
                  statusColor = Colors.orange;
                  statusIcon = Icons.cloud_queue;
                  statusText = 'Anonymous mode - Ready to sync';
                  break;
                case 'authenticated':
                  statusColor = Colors.green;
                  statusIcon = Icons.cloud_done;
                  statusText = 'Authenticated - Syncing enabled';
                  break;
                default:
                  statusColor = Colors.red;
                  statusIcon = Icons.error;
                  statusText = 'Unknown status';
              }
              
              return Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuthSection(BuildContext context) {
    return ListTile(
      leading: Icon(
        _apiClientService.isAuthenticated ? Icons.verified_user : Icons.login,
        color: _apiClientService.isAuthenticated ? Colors.green : null,
      ),
      title: const Text('Account Authentication'),
      subtitle: Text(_apiClientService.isAuthenticated 
          ? 'Authenticated and connected' 
          : 'Login to sync data with backend'),
      onTap: () => context.go('/auth'),
    );
  }

  Widget _buildDataManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Data Management',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep, color: Colors.orange),
          title: const Text('Clear All Data'),
          subtitle:
              const Text('Remove all recordings, measurements, and events'),
          onTap: () => _showClearAllDataDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.folder_delete, color: Colors.orange),
          title: const Text('Clear Recording Files'),
          subtitle: const Text('Delete audio files but keep measurement data'),
          onTap: () => _showClearRecordingFilesDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore, color: Colors.red),
          title: const Text('Reset Settings'),
          subtitle: const Text('Restore all settings to defaults'),
          onTap: () => _showResetSettingsDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('Storage Usage'),
          subtitle: const Text('View disk usage and data statistics'),
          onTap: () => _showStorageUsageDialog(context),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.privacy_tip),
          title: const Text('Privacy Policy'),
          onTap: () => _showPrivacyPolicy(context),
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About'),
          onTap: () => _showAboutDialog(context),
        ),
      ],
    );
  }

  void _showLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Location data is used to tag noise events with their geographic position.'),
            SizedBox(height: 16),
            Text(
                'This helps create accurate noise maps and identify problem areas.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _locationService.requestLocationPermission(context);
              setState(() {});
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showAudioDialog(BuildContext context) {
    double currentOffset = _audioService.calibrationOffset;
    final threshold =
        _recordingService.getSettings()['auto_record_threshold'] as double;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Calibration'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Adjust calibration to match a professional sound level meter:'),
                const SizedBox(height: 16),
                Slider(
                  value: currentOffset,
                  min: -10.0,
                  max: 10.0,
                  divisions: 40,
                  label: '${currentOffset.toStringAsFixed(1)} dB',
                  onChanged: (value) {
                    setState(() {
                      currentOffset = value;
                    });
                  },
                ),
                Text('Current offset: ${currentOffset.toStringAsFixed(1)} dB'),
                const SizedBox(height: 4),
                Text(
                  'Effective threshold: ${(threshold + currentOffset).toStringAsFixed(1)} dB',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Typical smartphone microphone offsets:\n'
                  '• Pixel / Google phones: -10 to -15 dB\n'
                  '• iPhones: -8 to -12 dB\n'
                  '• Samsung: -12 to -18 dB\n'
                  '• Budget Android: -15 to -25 dB\n'
                  '\n'
                  'Set a NEGATIVE offset if your readings seem too high. '
                  'For best results, calibrate against a reference SPL meter '
                  'or a known quiet environment (~30-35 dB).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              _audioService.setCalibrationOffset(currentOffset);
              await _preferencesService.setCalibrationOffset(currentOffset);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showContinuousRecordingDialog(BuildContext context) async {
    // Load current settings
    final settings = _recordingService.getSettings();
    double bufferDuration =
        (settings['buffer_duration_minutes'] as int).toDouble();
    double autoRecordThreshold = settings['auto_record_threshold'] as double;
    int maxBuffers = settings['max_buffers'] as int;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continuous Recording Settings'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Continuous recording automatically captures noise pollution events using a rolling buffer system.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Buffer Duration Slider
                Text(
                    'Recording Buffer Duration: ${bufferDuration.toInt()} minutes'),
                Slider(
                  value: bufferDuration,
                  min: 5.0,
                  max: 30.0,
                  divisions: 25,
                  label: '${bufferDuration.toInt()} min',
                  onChanged: (value) {
                    setState(() {
                      bufferDuration = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Auto Record Threshold Slider
                Text(
                    'Auto-Record Threshold: ${autoRecordThreshold.toInt()} dB'),
                Slider(
                  value: autoRecordThreshold,
                  min: 50.0,
                  max: 80.0,
                  divisions: 30,
                  label: '${autoRecordThreshold.toInt()} dB',
                  onChanged: (value) {
                    setState(() {
                      autoRecordThreshold = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Max Buffers Slider
                Text('Maximum Buffers: $maxBuffers'),
                Slider(
                  value: maxBuffers.toDouble(),
                  min: 2.0,
                  max: 5.0,
                  divisions: 3,
                  label: maxBuffers.toString(),
                  onChanged: (value) {
                    setState(() {
                      maxBuffers = value.toInt();
                    });
                  },
                ),

                const SizedBox(height: 16),
                const Text(
                  'Higher thresholds save storage but may miss quieter events. Lower thresholds capture more events but use more space.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _recordingService.updateSettings(
                bufferDuration: Duration(minutes: bufferDuration.toInt()),
                autoRecordThreshold: autoRecordThreshold,
                maxBuffers: maxBuffers,
              );
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {}); // Refresh the settings page
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog(BuildContext context) async {
    // Load current values asynchronously
    final backendUrl = await _preferencesService.getBackendUrl();
    final autoSubmissionEnabled = await _preferencesService.getAutoSubmissionEnabled();

    showDialog<void>(
      context: context,
      builder: (context) => _BackendConfigDialog(
        initialUrl: backendUrl,
        initialAutoSubmission: autoSubmissionEnabled,
        apiClientService: _apiClientService,
        preferencesService: _preferencesService,
        onSave: () => setState(() {}),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'OpenNoiseNet Privacy Policy\n\n'
            '• We collect noise level measurements and optional location data\n'
            '• No audio recordings are stored without explicit consent\n'
            '• Location data can be disabled in settings\n'
            '• All data is anonymized and used for environmental research\n'
            '• You can delete your data at any time\n\n'
            'For more information, visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDataDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear All Data'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete:'),
            SizedBox(height: 8),
            Text('• All noise measurements and events'),
            Text('• All audio recording files'),
            Text('• Daily statistics and analysis data'),
            Text('• AI analysis queue items'),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _clearAllData();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data cleared successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
  }

  void _showClearRecordingFilesDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_delete, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear Recording Files'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will delete:'),
            SizedBox(height: 8),
            Text('• All audio recording files (.wav files)'),
            Text('• Audio recording database entries'),
            SizedBox(height: 8),
            Text('This will keep:'),
            SizedBox(height: 8),
            Text('• Noise measurements and events'),
            Text('• Daily statistics'),
            SizedBox(height: 16),
            Text(
              'Deleted files cannot be recovered!',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _clearRecordingFiles();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recording files cleared successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Files'),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_backup_restore, color: Colors.red),
            SizedBox(width: 8),
            Text('Reset Settings'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will reset to defaults:'),
            SizedBox(height: 8),
            Text('• Audio calibration settings'),
            Text('• Recording preferences'),
            Text('• Sync and backend settings'),
            Text('• Theme preferences'),
            SizedBox(height: 16),
            Text('Your data will not be affected.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _resetSettings();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to defaults'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Refresh the page to show updated settings
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Settings'),
          ),
        ],
      ),
    );
  }

  void _showStorageUsageDialog(BuildContext context) async {
    // Calculate storage usage
    final storageInfo = await _calculateStorageUsage();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storage),
            SizedBox(width: 8),
            Text('Storage Usage'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Database Records:',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text('• Noise Measurements: ${storageInfo['measurementCount']}'),
              Text('• Audio Recordings: ${storageInfo['recordingCount']}'),
              Text('• Daily Statistics: ${storageInfo['statisticsCount']}'),
              Text('• Analysis Queue: ${storageInfo['analysisCount']}'),
              const SizedBox(height: 16),
              Text('Storage Size:',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text('• Audio Files: ${storageInfo['audioFilesSize']}'),
              Text('• Database: ${storageInfo['databaseSize']}'),
              Text('• Total Usage: ${storageInfo['totalSize']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'OpenNoiseNet',
      applicationVersion: '0.1.0',
      applicationLegalese: '© 2024 OpenNoiseNet Project',
      children: const [
        SizedBox(height: 16),
        Text(
          'Open-source environmental noise monitoring platform. '
          'Help build a global network of citizen-operated noise sensors.',
        ),
      ],
    );
  }

  /// Clear all data including measurements, recordings, and statistics
  Future<void> _clearAllData() async {
    try {
      AppLogger.ui('Starting complete data clear...');

      // Clear all database tables
      await _measurementDao.deleteAll();
      await _statisticsDao.deleteAll();
      await _audioRecordingDao.deleteAll();
      await _aiAnalysisDao.deleteAll();

      // Clear all recording files
      await _clearRecordingFilesOnly();

      AppLogger.ui('All data cleared successfully');
    } catch (e) {
      AppLogger.ui('Error clearing all data: $e');
      rethrow;
    }
  }

  /// Clear only recording files and audio recording database entries
  Future<void> _clearRecordingFiles() async {
    try {
      AppLogger.ui('Starting recording files clear...');

      // Clear audio recording database entries
      await _audioRecordingDao.deleteAll();

      // Clear actual files
      await _clearRecordingFilesOnly();

      AppLogger.ui('Recording files cleared successfully');
    } catch (e) {
      AppLogger.ui('Error clearing recording files: $e');
      rethrow;
    }
  }

  /// Clear only the physical recording files from disk
  Future<void> _clearRecordingFilesOnly() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');
      final continuousRecordingsDir =
          Directory('${appDir.path}/continuous_recordings');

      // Delete recordings directory
      if (await recordingsDir.exists()) {
        await recordingsDir.delete(recursive: true);
        AppLogger.ui('Deleted recordings directory');
      }

      // Delete continuous recordings directory
      if (await continuousRecordingsDir.exists()) {
        await continuousRecordingsDir.delete(recursive: true);
        AppLogger.ui('Deleted continuous recordings directory');
      }

      // Recreate empty directories
      await recordingsDir.create(recursive: true);
      await continuousRecordingsDir.create(recursive: true);
    } catch (e) {
      AppLogger.ui('Error clearing recording files: $e');
      rethrow;
    }
  }

  /// Reset all settings to defaults
  Future<void> _resetSettings() async {
    try {
      AppLogger.ui('Starting settings reset...');

      // Reset audio calibration
      _audioService.setCalibrationOffset(0.0);
      await _preferencesService.setCalibrationOffset(0.0);

      // Reset backend URL to default
      await _preferencesService.setBackendUrl('http://localhost:8100/api/v1');

      // Reset auto-submission
      await _preferencesService.setAutoSubmissionEnabled(false);

      // Reset recording settings to defaults
      await _recordingService.updateSettings(
        enableContinuousRecording: false,
        bufferDuration: const Duration(minutes: 15),
        autoRecordThreshold: 65.0,
        maxBuffers: 3,
      );

      // Reset theme to default (dark mode)
      if (context.mounted) {
        context.read<AppBloc>().add(const AppThemeChanged(isDarkMode: true));
      }

      AppLogger.ui('Settings reset to defaults successfully');
    } catch (e) {
      AppLogger.ui('Error resetting settings: $e');
      rethrow;
    }
  }

  /// Calculate storage usage statistics
  Future<Map<String, dynamic>> _calculateStorageUsage() async {
    try {
      // Get database record counts
      final measurementCount = await _measurementDao.count();
      final recordingCount = await _audioRecordingDao.count();
      final statisticsCount = await _statisticsDao.count();
      final analysisCount = await _aiAnalysisDao.count();

      // Calculate file sizes
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');
      final continuousRecordingsDir =
          Directory('${appDir.path}/continuous_recordings');

      int audioFilesSize = 0;

      // Calculate recordings directory size
      if (await recordingsDir.exists()) {
        audioFilesSize += await _calculateDirectorySize(recordingsDir);
      }

      // Calculate continuous recordings directory size
      if (await continuousRecordingsDir.exists()) {
        audioFilesSize +=
            await _calculateDirectorySize(continuousRecordingsDir);
      }

      // Estimate database size (rough calculation)
      int databaseSize =
          (measurementCount * 150) + // ~150 bytes per measurement
              (recordingCount * 200) + // ~200 bytes per recording entry
              (statisticsCount * 100) + // ~100 bytes per statistic
              (analysisCount * 50); // ~50 bytes per analysis queue item

      final totalSize = audioFilesSize + databaseSize;

      return {
        'measurementCount': measurementCount,
        'recordingCount': recordingCount,
        'statisticsCount': statisticsCount,
        'analysisCount': analysisCount,
        'audioFilesSize': _formatBytes(audioFilesSize),
        'databaseSize': _formatBytes(databaseSize),
        'totalSize': _formatBytes(totalSize),
      };
    } catch (e) {
      AppLogger.ui('Error calculating storage usage: $e');
      return {
        'measurementCount': 0,
        'recordingCount': 0,
        'statisticsCount': 0,
        'analysisCount': 0,
        'audioFilesSize': 'Unknown',
        'databaseSize': 'Unknown',
        'totalSize': 'Unknown',
      };
    }
  }

  /// Calculate the total size of a directory
  Future<int> _calculateDirectorySize(Directory directory) async {
    int size = 0;

    await for (FileSystemEntity entity in directory.list(recursive: true)) {
      if (entity is File) {
        try {
          size += await entity.length();
        } catch (e) {
          // Ignore files that can't be read
        }
      }
    }

    return size;
  }

  /// Format bytes into human-readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Enhanced backend configuration dialog with auto-detect and presets
class _BackendConfigDialog extends StatefulWidget {
  final String initialUrl;
  final bool initialAutoSubmission;
  final ApiClientService apiClientService;
  final SQLitePreferencesService preferencesService;
  final VoidCallback onSave;

  const _BackendConfigDialog({
    required this.initialUrl,
    required this.initialAutoSubmission,
    required this.apiClientService,
    required this.preferencesService,
    required this.onSave,
  });

  @override
  State<_BackendConfigDialog> createState() => _BackendConfigDialogState();
}

class _BackendConfigDialogState extends State<_BackendConfigDialog> {
  late TextEditingController _urlController;
  late bool _autoSubmissionEnabled;
  
  bool _isTestingConnection = false;
  bool _isDetectingIP = false;
  bool _showPresets = false;
  bool _showNetworkDebug = false;
  String _connectionStatus = '';
  List<BackendPreset> _presets = [];
  Map<String, dynamic>? _networkDebugInfo;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _autoSubmissionEnabled = widget.initialAutoSubmission;
    _loadPresets();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await widget.apiClientService.getRecommendedUrls();
      setState(() {
        _presets = presets;
      });
    } catch (e) {
      debugPrint('Failed to load presets: $e');
    }
  }

  Future<void> _testConnection() async {
    if (_isTestingConnection) return;
    
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      await widget.apiClientService.setBaseUrl(_urlController.text);
      final result = await widget.apiClientService.testConnectionDetailed();
      
      setState(() {
        _isTestingConnection = false;
        if (result.success) {
          _connectionStatus = '✓ Connection successful (${result.latencyMs}ms)';
        } else {
          _connectionStatus = '✗ ${result.error}';
        }
      });
    } catch (e) {
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = '✗ Unexpected error: ${e.toString()}';
      });
    }
  }

  Future<void> _autoDetectIP() async {
    if (_isDetectingIP) return;
    
    setState(() {
      _isDetectingIP = true;
    });

    try {
      final networkUtils = NetworkUtils();
      final detectedUrl = await networkUtils.getRecommendedBackendUrl(port: 8100);
      
      setState(() {
        _urlController.text = detectedUrl;
        _isDetectingIP = false;
      });
      
      // Auto-test the detected URL
      _testConnection();
    } catch (e) {
      setState(() {
        _isDetectingIP = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-detect failed: $e')),
      );
    }
  }

  Future<void> _loadNetworkDebugInfo() async {
    try {
      final debugInfo = await widget.apiClientService.getNetworkDebugInfo();
      setState(() {
        _networkDebugInfo = debugInfo;
      });
    } catch (e) {
      setState(() {
        _networkDebugInfo = {'error': e.toString()};
      });
    }
  }

  Widget _buildPresetsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Presets:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ..._presets.map((preset) => Card(
          child: ListTile(
            title: Text(preset.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.description),
                const SizedBox(height: 4),
                Text(
                  preset.url,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            trailing: preset.isAutoDetect
                ? Icon(Icons.auto_fix_high, color: Theme.of(context).colorScheme.secondary)
                : null,
            onTap: () {
              setState(() {
                _urlController.text = preset.url;
                _showPresets = false;
              });
              // Auto-test the preset URL
              _testConnection();
            },
          ),
        )),
      ],
    );
  }

  Widget _buildNetworkDebugInfo() {
    if (_networkDebugInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network Debug Information:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Text(
              _formatNetworkDebugInfo(_networkDebugInfo!),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatNetworkDebugInfo(Map<String, dynamic> info) {
    final buffer = StringBuffer();
    buffer.writeln('Platform: ${info['platform']}');
    buffer.writeln('Current URL: ${info['currentBackendUrl']}');
    buffer.writeln('Authenticated: ${info['isAuthenticated']}');
    buffer.writeln('Detected Host IP: ${info['detectedHostIP'] ?? 'None'}');
    buffer.writeln('Recommended URL: ${info['recommendedURL'] ?? 'None'}');
    
    if (info['interfaces'] != null && info['interfaces'] is List) {
      buffer.writeln('\nNetwork Interfaces:');
      final interfaces = info['interfaces'] as List;
      for (final interface in interfaces) {
        if (interface is Map<String, dynamic>) {
          buffer.writeln('  ${interface['name']}:');
          final addresses = interface['addresses'];
          if (addresses is List) {
            for (final addr in addresses) {
              if (addr is Map<String, dynamic> && addr['type'] == 'IPv4') {
                final isLocal = addr['isLocalNetwork'] == true;
                buffer.writeln('    ${addr['address']} (${isLocal ? 'Local' : 'External'})');
              }
            }
          }
        }
      }
    }
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backend Integration'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // URL Input with auto-detect button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Backend URL',
                        hintText: 'http://192.168.1.100:8100/api/v1',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _isDetectingIP ? null : _autoDetectIP,
                      icon: _isDetectingIP
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find, size: 16),
                      label: const Text('Auto'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick setup section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Setup',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'For your MacBook (192.168.178.157):',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'http://192.168.178.157:8100/api/v1',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _urlController.text = 'http://192.168.178.157:8100/api/v1';
                            },
                            child: const Text('Use'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Connection test button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cable),
                  label: const Text('Test Connection'),
                ),
              ),
              
              // Connection status
              if (_connectionStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _connectionStatus.startsWith('✓')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Presets toggle
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPresets = !_showPresets;
                        });
                      },
                      icon: Icon(_showPresets ? Icons.expand_less : Icons.expand_more),
                      label: const Text('Quick Presets'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showNetworkDebug = !_showNetworkDebug;
                      });
                      if (_showNetworkDebug && _networkDebugInfo == null) {
                        _loadNetworkDebugInfo();
                      }
                    },
                    icon: Icon(_showNetworkDebug ? Icons.expand_less : Icons.expand_more),
                    label: const Text('Debug'),
                  ),
                ],
              ),
              
              // Presets section
              if (_showPresets) ...[
                const SizedBox(height: 16),
                _buildPresetsList(),
              ],
              
              // Network debug section
              if (_showNetworkDebug) ...[
                const SizedBox(height: 16),
                _buildNetworkDebugInfo(),
              ],
              
              const SizedBox(height: 16),
              
              // Authentication status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authentication Status:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          widget.apiClientService.isAuthenticated
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: widget.apiClientService.isAuthenticated
                              ? Colors.green
                              : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.apiClientService.isAuthenticated
                              ? 'Authenticated'
                              : 'Not authenticated',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    if (widget.apiClientService.deviceId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Device ID: ${widget.apiClientService.deviceId}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Auto-submit toggle
              SwitchListTile(
                title: const Text('Auto-submit events'),
                subtitle: const Text('Automatically send noise events to backend'),
                value: _autoSubmissionEnabled,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    _autoSubmissionEnabled = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            // Save settings
            await widget.preferencesService.setBackendUrl(_urlController.text);
            await widget.preferencesService.setAutoSubmissionEnabled(_autoSubmissionEnabled);
            await widget.apiClientService.setBaseUrl(_urlController.text);
            
            Navigator.pop(context);
            widget.onSave();
            
            // Show success feedback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Backend settings saved'),
                backgroundColor: Colors.green,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
