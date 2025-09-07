import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/dao/noise_measurement_dao.dart';
import '../../../../core/database/dao/daily_statistics_dao.dart';
import '../../../../core/database/dao/audio_recording_dao.dart';
import '../../../../core/database/models/noise_measurement.dart';
import '../../../../core/database/models/daily_statistics.dart';
import '../../../../core/database/models/audio_recording.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../services/audio_recording_service.dart';
import '../../../../widgets/shared_app_bar.dart';
import 'audio_player_page.dart';

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
      AppLogger.ui('Failed to initialize audio service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SharedAppBar(
        pageTitle: 'Dashboard',
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

              // Recent Events
              _buildRecentEvents(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _dailyStatsDao.getByDate(_getTodayDateString()),
        _audioRecordingDao.count(),
        _audioRecordingDao.countAnalyzed(),
        _measurementDao.count(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data![0] as DailyStatistics?;
        final totalRecordings = snapshot.data![1] as int;
        final analyzedRecordings = snapshot.data![2] as int;
        final totalMeasurements = snapshot.data![3] as int;

        return Column(
          children: [
            // First row - Primary stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Today\'s Average',
                    stats?.avgLeq.toStringAsFixed(1) ?? '--',
                    'dB',
                    Icons.volume_up,
                    Colors.blue,
                    onTap: () => context.push('/noise-levels'),
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
                    onTap: () => context.push('/noise-levels'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Second row - Events and Recordings
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Noise Events',
                    '${stats?.totalExceedances ?? 0}',
                    'today',
                    Icons.warning,
                    Colors.orange,
                    onTap: () => context.push('/noise-events'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Audio Files',
                    '$totalRecordings',
                    'recordings',
                    Icons.audiotrack,
                    Colors.green,
                    onTap: () => context.push('/audio-files'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Third row - Analysis and Storage
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Analyzed Files',
                    '$analyzedRecordings',
                    'processed',
                    Icons.analytics,
                    Colors.purple,
                    onTap: () => context.push('/analysis-results'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<int>(
                    future: _audioRecordingDao.getTotalFileSize(),
                    builder: (context, sizeSnapshot) {
                      return _buildStatCard(
                        'Storage Used',
                        _formatFileSize(sizeSnapshot.data ?? 0),
                        '',
                        Icons.storage,
                        Colors.brown,
                        onTap: () => context.push('/storage-management'),
                      );
                    },
                  ),
                ),
              ],
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
    Color color, {
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // More comfortable padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            Row(
              children: [
                Icon(icon, size: 24, color: color), // Larger icon
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // More spacing
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          // Larger value text
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      unit,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11, // Smaller unit text
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
                                      (measurements.length - value.toInt())) %
                                  24;
                              return Text(
                                  '${hour.toString().padLeft(2, '0')}:00');
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
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3),
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
                        final hasRecording = recordingSnapshot.hasData &&
                            recordingSnapshot.data != null;

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
                                      ? () => _playEventRecording(
                                          recordingSnapshot.data!)
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

  String _formatLargeNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${bytes}B';
  }

  Future<int> _calculateMonitoringDays() async {
    try {
      // Get measurements with oldest first
      final measurements = await _measurementDao.getByTimeRange(
        startTimestamp: 0,
        endTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        orderBy: 'timestamp ASC',
        limit: 1,
      );

      if (measurements.isEmpty) return 0;

      final oldestDate = DateTime.fromMillisecondsSinceEpoch(
        measurements.first.timestamp * 1000,
      );
      final now = DateTime.now();
      return now.difference(oldestDate).inDays + 1;
    } catch (e) {
      return 0;
    }
  }

  /// Find audio recording associated with a noise measurement
  Future<AudioRecording?> _findAssociatedRecording(
      NoiseMeasurement measurement) async {
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
          content:
              Text('Audio service is still initializing, please try again'),
        ),
      );
      return;
    }

    // Navigate to full-screen audio player page
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AudioPlayerPage(recording: recording),
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {}); // Trigger rebuild to refresh FutureBuilders
  }

  /// Create a test recording for debugging audio playback
  Future<void> _createTestRecording() async {
    if (!_isAudioServiceInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio service not initialized yet. Please wait...'),
        ),
      );
      return;
    }

    try {
      // Show progress dialog
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Recording test audio (5s)...'),
            ],
          ),
        ),
      );

      AppLogger.ui('Starting test recording creation...');
      final recordingId = await _audioRecordingService.createTestRecording();

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      if (recordingId != null) {
        AppLogger.ui('Test recording created successfully: $recordingId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Test recording created! ID: ${recordingId.substring(0, 8)}...'),
              action: SnackBarAction(
                label: 'Refresh',
                onPressed: () => _refreshData(),
              ),
            ),
          );
        }
      } else {
        AppLogger.ui('Failed to create test recording');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Failed to create test recording. Check logs for details.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.ui('Error creating test recording: $e');
      // Close progress dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
