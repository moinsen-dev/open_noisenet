import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../bloc/monitoring_bloc.dart';
import '../../../../services/permission_dialog_service.dart';
import '../../../../services/audio_recording_service.dart';
import '../../../../services/audio_capture_service.dart';
import '../../../../core/database/dao/noise_measurement_dao.dart';
import '../../../../core/database/dao/daily_statistics_dao.dart';
import '../../../../core/database/models/daily_statistics.dart';
import '../../../../widgets/audio_waveform_widget.dart';
import '../../../../services/continuous_recording_service.dart';
import '../../../../services/statistics_service.dart';

class NoiseMonitoringPage extends StatefulWidget {
  const NoiseMonitoringPage({super.key});

  @override
  State<NoiseMonitoringPage> createState() => _NoiseMonitoringPageState();
}

class _NoiseMonitoringPageState extends State<NoiseMonitoringPage> {
  final AudioRecordingService _recordingService = AudioRecordingService();
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  final DailyStatisticsDao _dailyStatsDao = DailyStatisticsDao();
  final ContinuousRecordingService _continuousRecordingService = ContinuousRecordingService();
  final StatisticsService _statisticsService = StatisticsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noise Monitor'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => context.push('/recordings'),
            icon: const Icon(Icons.audiotrack),
            tooltip: 'View Recordings',
          ),
          IconButton(
            onPressed: () async {
              await PermissionDialogService().showPermissionStatus(context);
            },
            icon: const Icon(Icons.mic),
            tooltip: 'Microphone Permission Status',
          ),
        ],
      ),
      body: BlocBuilder<MonitoringBloc, MonitoringState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Waveform widget with proper lifecycle management
                if (state is MonitoringActive)
                  AudioWaveformWidget(
                    key: const ValueKey('audio_waveform'), // Stable key to prevent recreation
                    splStream: GetIt.instance<AudioCaptureService>().splStream,
                    width: MediaQuery.of(context).size.width - 32,
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 32,
                        height: 200, // Approximate height to match AudioWaveformWidget
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mic_off,
                              size: 48,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Monitoring Inactive',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start monitoring to see real-time noise levels',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Continuous Recording Status
                _buildContinuousRecordingStatus(),
                
                const SizedBox(height: 8),
                
                // Control buttons
                if (state is MonitoringInactive || state is MonitoringError)
                  ElevatedButton(
                    onPressed: () {
                      context.read<MonitoringBloc>().add(StartMonitoring(context: context));
                    },
                    child: Text(state is MonitoringError ? 'Retry Monitoring' : 'Start Monitoring'),
                  )
                else if (state is MonitoringActive)
                  ElevatedButton(
                    onPressed: () {
                      context.read<MonitoringBloc>().add(const StopMonitoring());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    child: const Text('Stop Monitoring'),
                  )
                else if (state is MonitoringStarting)
                  const CircularProgressIndicator()
                else if (state is MonitoringStopping)
                  const CircularProgressIndicator(),

                // Error display
                if (state is MonitoringError) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  state.message,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (state.message.toLowerCase().contains('permission')) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await PermissionDialogService().showPermissionStatus(context);
                                },
                                icon: const Icon(Icons.info_outline),
                                label: const Text('Check Permission Status'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Status information and real-time statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status & Statistics',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow('Monitoring', state is MonitoringActive ? 'Active' : 'Inactive'),
                        StreamBuilder<int>(
                          stream: _statisticsService.measurementCountStream,
                          initialData: 0,
                          builder: (context, snapshot) {
                            return _buildStatusRow(
                              'Measurements', 
                              '${snapshot.data ?? 0}',
                            );
                          },
                        ),
                        StreamBuilder<int>(
                          stream: _statisticsService.activeRecordingsStream,
                          initialData: 0,
                          builder: (context, snapshot) {
                            return _buildStatusRow(
                              'Active Recordings', 
                              '${snapshot.data ?? 0}',
                            );
                          },
                        ),
                        StreamBuilder<double?>(
                          stream: _statisticsService.todaysAverageStream,
                          builder: (context, snapshot) {
                            final average = snapshot.data;
                            return _buildStatusRow(
                              'Today\'s Average', 
                              average != null ? '${average.toStringAsFixed(1)} dB' : 'No data',
                            );
                          },
                        ),
                        StreamBuilder<double?>(
                          stream: _statisticsService.realTimeAverageStream,
                          builder: (context, snapshot) {
                            final realTimeAvg = snapshot.data;
                            return _buildStatusRow(
                              'Real-Time Average', 
                              realTimeAvg != null ? '${realTimeAvg.toStringAsFixed(1)} dB' : 'No data',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildContinuousRecordingStatus() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _continuousRecordingService.statsStream,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final isActive = stats?['continuous_recording_active'] == true;
        final activeBuffers = stats?['active_buffers'] as int? ?? 0;
        final shouldTrigger = stats?['should_trigger_recording'] == true;
        final currentLevel = stats?['current_level'] as double? ?? 0.0;
        final threshold = stats?['auto_record_threshold'] as double? ?? 65.0;

        if (stats == null) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.fiber_smart_record : Icons.radio_button_unchecked,
                      color: isActive ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Continuous Recording',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: shouldTrigger ? Colors.orange : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          shouldTrigger ? 'DETECTING' : 'MONITORING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                
                if (isActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusItem('Active Buffers', '$activeBuffers'),
                      ),
                      Expanded(
                        child: _buildStatusItem('Threshold', '${threshold.toInt()} dB'),
                      ),
                      Expanded(
                        child: _buildStatusItem(
                          'Current Level', 
                          '${currentLevel.toStringAsFixed(1)} dB',
                          color: currentLevel > threshold ? Colors.orange : null,
                        ),
                      ),
                    ],
                  ),
                  
                  // Show recent events if any
                  if (stats['recent_events_count'] != null && (stats['recent_events_count'] as int) > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '${stats['recent_events_count']} recent noise events detected',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Continuous recording is disabled. Enable it in Settings to automatically capture noise events.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
                
                // Quick action buttons
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (isActive) ...[
                      TextButton.icon(
                        onPressed: () async {
                          final recording = await _continuousRecordingService.saveCurrentBuffer();
                          if (recording != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Recording saved: ${recording.id.substring(0, 8)}...'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_alt, size: 16),
                        label: const Text('Save Current'),
                      ),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}