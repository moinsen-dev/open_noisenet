import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/monitoring_bloc.dart';

class NoiseMonitoringPage extends StatelessWidget {
  const NoiseMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noise Monitor'),
        actions: [
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
                // Current noise level display
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Current Noise Level',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${state is MonitoringActive ? state.currentLevel : 0.0} dB',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getNoiseLevelDescription(state is MonitoringActive ? state.currentLevel : 0.0),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Control buttons
                if (state is MonitoringInactive)
                  ElevatedButton(
                    onPressed: () {
                      context.read<MonitoringBloc>().add(const StartMonitoring());
                    },
                    child: const Text('Start Monitoring'),
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
                  ),
                
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
  
  String _getNoiseLevelDescription(double level) {
    if (level < 30) return 'Very Quiet';
    if (level < 45) return 'Quiet';
    if (level < 55) return 'Moderate';
    if (level < 65) return 'Loud';
    if (level < 75) return 'Very Loud';
    return 'Extremely Loud';
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