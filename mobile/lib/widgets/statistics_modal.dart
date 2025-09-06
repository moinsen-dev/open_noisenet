import 'package:flutter/material.dart';

import '../services/statistics_service.dart';

class StatisticsModal extends StatefulWidget {
  const StatisticsModal({super.key});

  @override
  State<StatisticsModal> createState() => _StatisticsModalState();
}

class _StatisticsModalState extends State<StatisticsModal> {
  final StatisticsService _statisticsService = StatisticsService();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  size: 28,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Real-Time Statistics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Statistics Grid
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Current Status Row
                    _buildStatusSection(
                      'Current Status',
                      Icons.monitor_heart,
                      [
                        _buildStatCard(
                          'Monitoring',
                          Icons.circle,
                          StreamBuilder<int>(
                            stream: Stream.periodic(
                                const Duration(seconds: 1), (i) => i),
                            builder: (context, snapshot) {
                              return Text(
                                'Active',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                              );
                            },
                          ),
                        ),
                        _buildStatCard(
                          'Active Recordings',
                          Icons.fiber_smart_record,
                          StreamBuilder<int>(
                            stream: _statisticsService.activeRecordingsStream,
                            initialData: 0,
                            builder: (context, snapshot) {
                              return Text(
                                '${snapshot.data ?? 0}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: (snapshot.data ?? 0) > 0
                                          ? Colors.red
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Measurements Row
                    _buildStatusSection(
                      'Measurements',
                      Icons.data_usage,
                      [
                        _buildStatCard(
                          'Total Measurements',
                          Icons.straighten,
                          StreamBuilder<int>(
                            stream: _statisticsService.measurementCountStream,
                            initialData: 0,
                            builder: (context, snapshot) {
                              return Text(
                                '${snapshot.data ?? 0}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              );
                            },
                          ),
                        ),
                        _buildStatCard(
                          'Sample Count',
                          Icons.grain,
                          StreamBuilder<int>(
                            stream: Stream.periodic(
                                const Duration(seconds: 1), (i) => i),
                            builder: (context, snapshot) {
                              final count =
                                  _statisticsService.currentSampleCount;
                              return Text(
                                '$count',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Averages Row
                    _buildStatusSection(
                      'Sound Level Averages',
                      Icons.equalizer,
                      [
                        _buildStatCard(
                          'Real-Time Average',
                          Icons.timeline,
                          StreamBuilder<double?>(
                            stream: _statisticsService.realTimeAverageStream,
                            builder: (context, snapshot) {
                              final realTimeAvg = snapshot.data;
                              return Column(
                                children: [
                                  Text(
                                    realTimeAvg != null
                                        ? realTimeAvg.toStringAsFixed(1)
                                        : '--',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: _getDecibelColor(
                                              realTimeAvg ?? 0),
                                        ),
                                  ),
                                  Text(
                                    'dB SPL',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        _buildStatCard(
                          'Today\'s Average',
                          Icons.today,
                          StreamBuilder<double?>(
                            stream: _statisticsService.todaysAverageStream,
                            builder: (context, snapshot) {
                              final average = snapshot.data;
                              return Column(
                                children: [
                                  Text(
                                    average != null
                                        ? average.toStringAsFixed(1)
                                        : '--',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: _getDecibelColor(average ?? 0),
                                        ),
                                  ),
                                  Text(
                                    'dB SPL',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Last Update Info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.update,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<int>(
                            stream: Stream.periodic(
                                const Duration(seconds: 1), (i) => i),
                            builder: (context, snapshot) {
                              return Text(
                                'Last updated: ${DateTime.now().toLocal().toString().substring(11, 19)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Statistics update every 5 seconds',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(String title, IconData icon, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: cards.map((card) => Expanded(child: card)).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, IconData icon, Widget valueWidget) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          valueWidget,
        ],
      ),
    );
  }

  Color _getDecibelColor(double db) {
    if (db < 30) return Colors.green;
    if (db < 55) return Colors.blue;
    if (db < 70) return Colors.orange;
    return Colors.red;
  }
}
