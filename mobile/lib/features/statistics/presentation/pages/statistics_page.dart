import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/database/dao/noise_measurement_dao.dart';
import '../../../../core/database/dao/hourly_statistics_dao.dart';
import '../../../../core/database/dao/daily_statistics_dao.dart';
import '../../../../core/database/models/noise_measurement.dart';
import '../../../../core/database/models/hourly_statistics.dart';
import '../../../../core/database/models/daily_statistics.dart';
import '../widgets/statistics_card.dart';
import '../widgets/noise_chart.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with TickerProviderStateMixin {
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  final HourlyStatisticsDao _hourlyStatsDao = HourlyStatisticsDao();
  final DailyStatisticsDao _dailyStatsDao = DailyStatisticsDao();

  late TabController _tabController;
  String _selectedPeriod = '24h';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.access_time),
            onSelected: (String period) {
              setState(() {
                _selectedPeriod = period;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: '24h', child: Text('Last 24 Hours')),
              const PopupMenuItem(value: '7d', child: Text('Last 7 Days')),
              const PopupMenuItem(value: '30d', child: Text('Last 30 Days')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overview'),
            Tab(icon: Icon(Icons.show_chart), text: 'Trends'),
            Tab(icon: Icon(Icons.pie_chart), text: 'Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTrendsTab(),
          _buildAnalysisTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Statistics Cards
            _buildSummaryCards(),
            const SizedBox(height: 24),
            
            // Current Status
            _buildCurrentStatus(),
            const SizedBox(height: 24),
            
            // Quick Stats Chart
            _buildQuickStatsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Time Series Chart
          NoiseChart(
            title: 'Noise Level Trends',
            period: _selectedPeriod,
            dao: _measurementDao,
          ),
          const SizedBox(height: 24),
          
          // Hourly Patterns
          _buildHourlyPatterns(),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Distribution Analysis
          _buildDistributionChart(),
          const SizedBox(height: 24),
          
          // Percentile Breakdown
          _buildPercentileBreakdown(),
          const SizedBox(height: 24),
          
          // Daily Comparison
          _buildDailyComparison(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return FutureBuilder<DailyStatistics?>(
      future: _dailyStatsDao.getByDate(_getTodayDateString()),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        
        return Row(
          children: [
            Expanded(
              child: StatisticsCard(
                title: 'Average Level',
                value: '${stats?.avgLeq.toStringAsFixed(1) ?? '--'} dB',
                icon: Icons.volume_up,
                color: Colors.blue,
                subtitle: 'Today',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatisticsCard(
                title: 'Peak Level',
                value: '${stats?.maxLeq.toStringAsFixed(1) ?? '--'} dB',
                icon: Icons.trending_up,
                color: Colors.red,
                subtitle: 'Today',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<NoiseMeasurement>>(
              future: _measurementDao.getRecent(limit: 1),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildStatusItem('Current Level', 'No data', Icons.volume_off, Colors.grey);
                }
                
                final latest = snapshot.data!.first;
                final level = latest.leqDb;
                Color statusColor;
                String statusText;
                
                if (level >= 75) {
                  statusColor = Colors.red;
                  statusText = 'Loud';
                } else if (level >= 60) {
                  statusColor = Colors.orange;
                  statusText = 'Moderate';
                } else if (level >= 45) {
                  statusColor = Colors.green;
                  statusText = 'Quiet';
                } else {
                  statusColor = Colors.blue;
                  statusText = 'Very Quiet';
                }
                
                return Column(
                  children: [
                    _buildStatusItem(
                      'Current Level', 
                      '${level.toStringAsFixed(1)} dB', 
                      Icons.volume_up, 
                      statusColor,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusItem(
                      'Status', 
                      statusText, 
                      Icons.info, 
                      statusColor,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
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

  Widget _buildQuickStatsChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity (Last 6 Hours)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<NoiseMeasurement>>(
                future: _measurementDao.getByTimeRange(
                  startTimestamp: DateTime.now().subtract(const Duration(hours: 6)).millisecondsSinceEpoch ~/ 1000,
                  endTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No recent data'));
                  }

                  final measurements = snapshot.data!.take(36).toList(); // Every 10 minutes
                  final spots = measurements.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.leqDb);
                  }).toList();

                  return LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text('${value.toInt()}'),
                          ),
                        ),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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

  Widget _buildHourlyPatterns() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Patterns (Today)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<HourlyStatistics>>(
                future: _hourlyStatsDao.getRecent(limit: 24),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No hourly data'));
                  }

                  final hours = List.generate(24, (index) => index);
                  final statsMap = Map.fromEntries(
                    snapshot.data!.map((stat) {
                      final dateTime = DateTime.fromMillisecondsSinceEpoch(stat.hourTimestamp * 1000);
                      return MapEntry(dateTime.hour, stat.avgLeq);
                    }),
                  );

                  final spots = hours.map((hour) {
                    final value = statsMap[hour] ?? 0.0;
                    return FlSpot(hour.toDouble(), value);
                  }).toList();

                  return LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text('${value.toInt()}'),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) => Text('${value.toInt()}h'),
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: false,
                          color: Colors.green,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
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

  Widget _buildDistributionChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Noise Level Distribution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<NoiseMeasurement>>(
                future: _measurementDao.getLast24Hours(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data for distribution'));
                  }

                  // Create distribution buckets
                  final buckets = <String, int>{
                    '< 40 dB': 0,
                    '40-50 dB': 0,
                    '50-60 dB': 0,
                    '60-70 dB': 0,
                    '70-80 dB': 0,
                    '> 80 dB': 0,
                  };

                  for (final measurement in snapshot.data!) {
                    final level = measurement.leqDb;
                    if (level < 40) {
                      buckets['< 40 dB'] = buckets['< 40 dB']! + 1;
                    } else if (level < 50) {
                      buckets['40-50 dB'] = buckets['40-50 dB']! + 1;
                    } else if (level < 60) {
                      buckets['50-60 dB'] = buckets['50-60 dB']! + 1;
                    } else if (level < 70) {
                      buckets['60-70 dB'] = buckets['60-70 dB']! + 1;
                    } else if (level < 80) {
                      buckets['70-80 dB'] = buckets['70-80 dB']! + 1;
                    } else {
                      buckets['> 80 dB'] = buckets['> 80 dB']! + 1;
                    }
                  }

                  final colors = [Colors.green, Colors.lightGreen, Colors.yellow, Colors.orange, Colors.red, Colors.purple];
                  final sections = buckets.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final bucketEntry = entry.value;
                    final count = bucketEntry.value;
                    final total = snapshot.data!.length;
                    final percentage = total > 0 ? (count / total * 100) : 0.0;
                    
                    return PieChartSectionData(
                      color: colors[index],
                      value: count.toDouble(),
                      title: count > 0 ? '${percentage.toStringAsFixed(1)}%' : '',
                      radius: 60,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList();

                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: buckets.entries.toList().asMap().entries.map((entry) {
                            final index = entry.key;
                            final bucketEntry = entry.value;
                            return Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color: colors[index],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${bucketEntry.key}: ${bucketEntry.value}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentileBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Percentile Analysis (Last 24h)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<NoiseMeasurement>>(
              future: _measurementDao.getLast24Hours(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No data available');
                }

                // Calculate percentiles
                final levels = snapshot.data!.map((m) => m.leqDb).toList()..sort();
                final l10 = levels.isNotEmpty ? levels[(levels.length * 0.9).floor()] : 0.0;
                final l50 = levels.isNotEmpty ? levels[(levels.length * 0.5).floor()] : 0.0;
                final l90 = levels.isNotEmpty ? levels[(levels.length * 0.1).floor()] : 0.0;

                return Column(
                  children: [
                    _buildPercentileRow('L10 (Loud Events)', l10, Colors.red),
                    const SizedBox(height: 8),
                    _buildPercentileRow('L50 (Median Level)', l50, Colors.orange),
                    const SizedBox(height: 8),
                    _buildPercentileRow('L90 (Background)', l90, Colors.green),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentileRow(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(
          '${value.toStringAsFixed(1)} dB',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildDailyComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Comparison',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<DailyStatistics>>(
                future: _dailyStatsDao.getRecent(limit: 7),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No weekly data'));
                  }

                  final stats = snapshot.data!.reversed.toList(); // Most recent first
                  final spots = stats.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.avgLeq);
                  }).toList();

                  return LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text('${value.toInt()}'),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < stats.length) {
                                final date = DateTime.tryParse(stats[index].date);
                                return Text(date != null ? '${date.day}/${date.month}' : '');
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          ),
                          dotData: const FlDotData(show: true),
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

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshData() async {
    setState(() {}); // Trigger rebuild of FutureBuilders
  }
}