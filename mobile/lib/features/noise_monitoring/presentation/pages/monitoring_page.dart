import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../services/audio_capture_service.dart';
import '../../../../services/permission_dialog_service.dart';
import '../../../../services/recording_service.dart';
import '../../../../services/statistics_service.dart';
import '../../../../widgets/audio_waveform_widget.dart';
import '../../../../widgets/statistics_modal.dart';
import '../bloc/monitoring_bloc.dart';

class NoiseMonitoringPage extends StatefulWidget {
  const NoiseMonitoringPage({super.key});

  @override
  State<NoiseMonitoringPage> createState() => _NoiseMonitoringPageState();
}

class _NoiseMonitoringPageState extends State<NoiseMonitoringPage> {
  final RecordingService _recordingService = RecordingService();
  final StatisticsService _statisticsService = StatisticsService();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MonitoringBloc, MonitoringState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Noise Monitor'),
            automaticallyImplyLeading: false,
            actions: [
              // Dynamic Start/Stop Monitoring Button
              if (state is MonitoringInactive || state is MonitoringError)
                IconButton(
                  onPressed: () {
                    context
                        .read<MonitoringBloc>()
                        .add(StartMonitoring(context: context));
                  },
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Start Monitoring',
                )
              else if (state is MonitoringActive)
                IconButton(
                  onPressed: () {
                    context.read<MonitoringBloc>().add(const StopMonitoring());
                  },
                  icon: const Icon(Icons.stop),
                  tooltip: 'Stop Monitoring',
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                )
              else if (state is MonitoringStarting ||
                  state is MonitoringStopping)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              const SizedBox(width: 8),

              // Statistics Modal Button
              IconButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => const StatisticsModal(),
                  );
                },
                icon: const Icon(Icons.analytics),
                tooltip: 'View Statistics',
              ),
              
              // Talker Logs Viewer Button
              IconButton(
                onPressed: () {
                  AppLogger.ui('Opening Talker logs viewer');
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => TalkerScreen(
                        talker: AppLogger.instance,
                        appBarTitle: 'OpenNoiseNet Logs',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report),
                tooltip: 'View Debug Logs',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Waveform widget with proper lifecycle management
                  if (state is MonitoringActive)
                    AudioWaveformWidget(
                      key: const ValueKey(
                          'audio_waveform'), // Stable key to prevent recreation
                      splStream:
                          GetIt.instance<AudioCaptureService>().splStream,
                      width: MediaQuery.of(context).size.width - 32,
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 32,
                          height:
                              280, // Increased height to accommodate the button
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
                              const SizedBox(height: 24),
                              // Large green play button
                              FilledButton.icon(
                                onPressed: () {
                                  context
                                      .read<MonitoringBloc>()
                                      .add(StartMonitoring(context: context));
                                },
                                icon: const Icon(Icons.play_arrow, size: 24),
                                label: const Text(
                                  'Start Monitoring',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Real-time Statistics
                  _buildRealTimeStatistics(),

                  const SizedBox(height: 8),

                  // Continuous Recording Status
                  _buildContinuousRecordingStatus(),

                  const SizedBox(height: 8),

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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    state.message,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (state.message
                                .toLowerCase()
                                .contains('permission')) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await PermissionDialogService()
                                        .showPermissionStatus(context);
                                  },
                                  icon: const Icon(Icons.info_outline),
                                  label: const Text('Check Permission Status'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinuousRecordingStatus() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _recordingService.statsStream,
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
                      isActive
                          ? Icons.fiber_smart_record
                          : Icons.radio_button_unchecked,
                      color: isActive ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recording',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                        child: _buildStatusItem(
                            'Active Buffers', '$activeBuffers'),
                      ),
                      Expanded(
                        child: _buildStatusItem(
                            'Threshold', '${threshold.toInt()} dB'),
                      ),
                      Expanded(
                        child: _buildStatusItem(
                          'Current Level',
                          '${currentLevel.toStringAsFixed(1)} dB',
                          color:
                              currentLevel > threshold ? Colors.orange : null,
                        ),
                      ),
                    ],
                  ),

                  // Show recent events if any
                  if (stats['recent_events_count'] != null &&
                      (stats['recent_events_count'] as int) > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active,
                              size: 16, color: Colors.orange),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
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
                          final recording =
                              await _recordingService.saveCurrentBuffer();
                          if (recording != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Recording saved: ${recording.id.substring(0, 8)}...'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_alt, size: 16),
                        label: const Text('Save Current'),
                      ),
                    ],
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

  Widget _buildRealTimeStatistics() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timeline,
                  size: 18,
                  color: Colors.blue,
                ),
                const SizedBox(width: 6),
                Text(
                  'Real-Time Averages',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCompactStatItem(
                      'Day', _statisticsService.dayAverageStream),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStatItem(
                      'Hour', _statisticsService.hourAverageStream),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStatItem(
                      '15m Peak', _statisticsService.fifteenMinPeakStream),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatItem(String label, Stream<double?> valueStream) {
    return StreamBuilder<double?>(
      stream: valueStream,
      builder: (context, snapshot) {
        final value = snapshot.data;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value != null ? value.toStringAsFixed(1) : '--',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: value != null ? _getDecibelColor(value) : null,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'dB',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getDecibelColor(double db) {
    if (db < 30) return Colors.green;
    if (db < 55) return Colors.blue;
    if (db < 70) return Colors.orange;
    return Colors.red;
  }
}
