import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/monitoring_bloc.dart';
import '../../../../services/audio_capture_service.dart';
import '../../../../services/permission_dialog_service.dart';
import '../../../../widgets/audio_waveform_widget.dart';

class NoiseMonitoringPage extends StatelessWidget {
  const NoiseMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noise Monitor'),
        actions: [
          IconButton(
            onPressed: () async {
              await PermissionDialogService().showPermissionStatus(context);
            },
            icon: const Icon(Icons.mic),
            tooltip: 'Microphone Permission Status',
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: BlocBuilder<MonitoringBloc, MonitoringState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Waveform and noise level display
                if (state is MonitoringActive)
                  AudioWaveformWidget(
                    splStream: AudioCaptureService().splStream,
                    width: MediaQuery.of(context).size.width - 32,
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
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
                
                // Status information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow('Monitoring', state is MonitoringActive ? 'Active' : 'Inactive'),
                        _buildStatusRow('Events Detected', '0'), // TODO: Real data
                        _buildStatusRow('Last Sync', 'Never'), // TODO: Real data
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
}