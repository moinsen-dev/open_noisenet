import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../features/app/presentation/bloc/app_bloc.dart';
import '../../../../services/audio_capture_service.dart';
import '../../../../services/location_service.dart';
import '../../../../services/recording_service.dart';
import '../../../../services/sqlite_preferences_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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

              // Sync Settings
              _buildSyncSection(context),
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
    return FutureBuilder<String>(
      future: _preferencesService.getBackendUrl(),
      builder: (context, snapshot) {
        final backendUrl = snapshot.data ?? 'Loading...';
        return ListTile(
          leading: const Icon(Icons.cloud_sync),
          title: const Text('Sync Settings'),
          subtitle: Text('Backend: $backendUrl'),
          onTap: () => _showSyncDialog(context),
        );
      },
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Calibration'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
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
            ],
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
    final autoSubmissionEnabled =
        await _preferencesService.getAutoSubmissionEnabled();

    final controller = TextEditingController(text: backendUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://localhost:8000/api/v1',
              ),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setStateLocal) {
                return SwitchListTile(
                  title: const Text('Auto-submit events'),
                  value: autoSubmissionEnabled,
                  onChanged: (value) async {
                    await _preferencesService.setAutoSubmissionEnabled(value);
                    setStateLocal(() {
                      // Update local state within dialog
                    });
                    setState(() {});
                  },
                );
              },
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
              await _preferencesService.setBackendUrl(controller.text);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
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
}
