import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/dao/noise_measurement_dao.dart';
import '../../../../core/database/dao/daily_statistics_dao.dart';
import '../../../../core/database/dao/audio_recording_dao.dart';
import '../../../../core/database/models/noise_measurement.dart';
import '../../../../core/database/models/daily_statistics.dart';
import '../../../../core/database/models/audio_recording.dart';
import '../../../../services/audio_recording_service.dart';

class EventsDashboardPage extends StatefulWidget {
  const EventsDashboardPage({super.key});

  @override
  State<EventsDashboardPage> createState() => _EventsDashboardPageState();
}

class _EventsDashboardPageState extends State<EventsDashboardPage> {
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  final DailyStatisticsDao _dailyStatsDao = DailyStatisticsDao();
  final AudioRecordingDao _audioRecordingDao = AudioRecordingDao();
  final AudioRecordingService _audioRecordingService = AudioRecordingService();
  
  bool _isAudioServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAudioService();
  }

  Future<void> _initializeAudioService() async {
    try {
      await _audioRecordingService.initialize();
      if (mounted) {
        setState(() {
          _isAudioServiceInitialized = true;
        });
      }
    } catch (e) {
      print('Failed to initialize audio service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => context.push('/statistics'),
            icon: const Icon(Icons.analytics),
            tooltip: 'View detailed statistics',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Overview Cards
              _buildStatisticsCards(),
              const SizedBox(height: 24),
              
              // 24-hour Chart
              _build24HourChart(),
              const SizedBox(height: 24),
              
              // Recent Events
              _buildRecentEvents(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return FutureBuilder<DailyStatistics?>(
      future: _dailyStatsDao.getByDate(_getTodayDateString()),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Today\'s Average',
                stats?.avgLeq.toStringAsFixed(1) ?? '--',
                'dB',
                Icons.volume_up,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Peak Level',
                stats?.maxLeq.toStringAsFixed(1) ?? '--',
                'dB',
                Icons.trending_up,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Exceedances',
                '${stats?.totalExceedances ?? 0}',
                'events',
                Icons.warning,
                Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _build24HourChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '24-Hour Noise Levels',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<NoiseMeasurement>>(
                future: _measurementDao.getLast24Hours(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No data available'),
                    );
                  }

                  final measurements = snapshot.data!;
                  final spots = measurements.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      entry.value.leqDb,
                    );
                  }).toList();

                  return LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text('${value.toInt()}');
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final hour = (DateTime.now().hour - 
                                (measurements.length - value.toInt())) % 24;
                              return Text('${hour.toString().padLeft(2, '0')}:00');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 2,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEvents() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Noise Events',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<NoiseMeasurement>>(
              future: _measurementDao.getRecent(limit: 10),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No recent events'),
                    ),
                  );
                }

                // Filter for measurements above 65dB threshold
                final recentEvents = snapshot.data!
                    .where((m) => (m.lmaxDb ?? m.leqDb) >= 65.0)
                    .take(10)
                    .toList();

                if (recentEvents.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No recent loud events'),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentEvents.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final measurement = recentEvents[index];
                    final dateTime = DateTime.fromMillisecondsSinceEpoch(
                      measurement.timestamp * 1000,
                    );
                    final maxDb = measurement.lmaxDb ?? measurement.leqDb;
                    
                    return FutureBuilder<AudioRecording?>(
                      future: _findAssociatedRecording(measurement),
                      builder: (context, recordingSnapshot) {
                        final hasRecording = recordingSnapshot.hasData && recordingSnapshot.data != null;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getEventColor(maxDb),
                            child: Icon(
                              hasRecording ? Icons.volume_up : Icons.graphic_eq,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '${maxDb.toStringAsFixed(1)} dB',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} • ${_getEventDescription(maxDb)}${hasRecording ? ' • Audio available' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasRecording)
                                IconButton(
                                  onPressed: _isAudioServiceInitialized 
                                    ? () => _playEventRecording(recordingSnapshot.data!)
                                    : null,
                                  icon: Icon(
                                    Icons.play_circle_filled,
                                    color: _isAudioServiceInitialized 
                                      ? null 
                                      : Colors.grey,
                                  ),
                                  tooltip: _isAudioServiceInitialized 
                                    ? 'Play recording' 
                                    : 'Audio service initializing...',
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              Text(
                                _formatTimeAgo(dateTime),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getEventColor(double db) {
    if (db >= 85) return Colors.red;
    if (db >= 75) return Colors.orange;
    if (db >= 65) return Colors.yellow[700]!;
    return Colors.green;
  }

  String _getEventDescription(double db) {
    if (db >= 85) return 'Very loud';
    if (db >= 75) return 'Loud';
    if (db >= 65) return 'Moderate';
    return 'Quiet';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Find audio recording associated with a noise measurement
  Future<AudioRecording?> _findAssociatedRecording(NoiseMeasurement measurement) async {
    try {
      // Look for recordings that overlap with the measurement timestamp (+/- 30 seconds)
      final measurementTime = measurement.timestamp;
      final startTime = measurementTime - 30;
      final endTime = measurementTime + 30;
      
      final recordings = await _audioRecordingDao.getByTimeRange(
        startTimestamp: startTime,
        endTimestamp: endTime,
        limit: 1,
        orderBy: 'timestamp_start DESC',
      );
      
      if (recordings.isNotEmpty) {
        return recordings.first;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Play audio recording for a noise event
  Future<void> _playEventRecording(AudioRecording recording) async {
    if (!_isAudioServiceInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio service is still initializing, please try again'),
        ),
      );
      return;
    }

    try {
      await _audioRecordingService.playRecording(recording);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing noise event recording (${recording.durationSeconds}s)'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Stop',
              onPressed: () => _audioRecordingService.stopPlayback(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play recording: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {}); // Trigger rebuild to refresh FutureBuilders
  }
}