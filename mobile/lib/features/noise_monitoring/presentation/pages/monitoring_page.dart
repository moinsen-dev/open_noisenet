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

class NoiseMonitoringPage extends StatefulWidget {
  const NoiseMonitoringPage({super.key});

  @override
  State<NoiseMonitoringPage> createState() => _NoiseMonitoringPageState();
}

class _NoiseMonitoringPageState extends State<NoiseMonitoringPage> {
  final AudioRecordingService _recordingService = AudioRecordingService();
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  final DailyStatisticsDao _dailyStatsDao = DailyStatisticsDao();

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
          return Padding(
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
                
                const SizedBox(height: 16),
                
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
                
                const SizedBox(height: 24),
                
                // Status information and real-time statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status & Statistics',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow('Monitoring', state is MonitoringActive ? 'Active' : 'Inactive'),
                        FutureBuilder<List<dynamic>>(
                          future: _measurementDao.getRecent(limit: 1),
                          builder: (context, snapshot) {
                            return _buildStatusRow(
                              'Measurements', 
                              snapshot.hasData ? (snapshot.data!.isNotEmpty ? '1+' : '0') : '0',
                            );
                          },
                        ),
                        _buildStatusRow(
                          'Active Recordings', 
                          '${_recordingService.activeRecordingCount}',
                        ),
                        FutureBuilder<DailyStatistics?>(
                          future: _dailyStatsDao.getByDate(_getTodayDateString()),
                          builder: (context, snapshot) {
                            final stats = snapshot.data;
                            return _buildStatusRow(
                              'Today\'s Average', 
                              stats != null ? '${stats.avgLeq.toStringAsFixed(1)} dB' : 'No data',
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

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}