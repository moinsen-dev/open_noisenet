import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/database/dao/noise_measurement_dao.dart';
import '../../../../core/database/models/noise_measurement.dart';

class NoiseChart extends StatefulWidget {
  final String title;
  final String period;
  final NoiseMeasurementDao dao;
  final double? height;

  const NoiseChart({
    super.key,
    required this.title,
    required this.period,
    required this.dao,
    this.height = 300,
  });

  @override
  State<NoiseChart> createState() => _NoiseChartState();
}

class _NoiseChartState extends State<NoiseChart> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(
                  label: Text(widget.period),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: widget.height,
              child: FutureBuilder<List<NoiseMeasurement>>(
                future: _getMeasurementsForPeriod(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No data available'),
                        ],
                      ),
                    );
                  }

                  final measurements = snapshot.data!;
                  return _buildChart(measurements);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<NoiseMeasurement>> _getMeasurementsForPeriod() {
    final now = DateTime.now();
    late DateTime startTime;

    switch (widget.period) {
      case '24h':
        startTime = now.subtract(const Duration(hours: 24));
        break;
      case '7d':
        startTime = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        startTime = now.subtract(const Duration(days: 30));
        break;
      default:
        startTime = now.subtract(const Duration(hours: 24));
    }

    return widget.dao.getByTimeRange(
      startTimestamp: startTime.millisecondsSinceEpoch ~/ 1000,
      endTimestamp: now.millisecondsSinceEpoch ~/ 1000,
      limit: widget.period == '24h'
          ? 144
          : (widget.period == '7d' ? 168 : 720), // Reasonable sample sizes
    );
  }

  Widget _buildChart(List<NoiseMeasurement> measurements) {
    final spots = measurements.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.leqDb);
    }).toList();

    // Calculate min/max for better scaling
    final levels = measurements.map((m) => m.leqDb).toList();
    final minLevel = levels.reduce((a, b) => a < b ? a : b);
    final maxLevel = levels.reduce((a, b) => a > b ? a : b);

    // Add some padding to the Y-axis range
    final yMin = (minLevel - 5).clamp(0, double.infinity);
    final yMax = maxLevel + 5;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: Colors.grey,
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: 10,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (measurements.length / 6).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < measurements.length) {
                  final measurement = measurements[index];
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(
                    measurement.timestamp * 1000,
                  );

                  String label;
                  switch (widget.period) {
                    case '24h':
                      label =
                          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                      break;
                    case '7d':
                      label = '${dateTime.day}/${dateTime.month}';
                      break;
                    case '30d':
                      label = '${dateTime.day}/${dateTime.month}';
                      break;
                    default:
                      label =
                          '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                  }

                  return Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey.shade300),
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        minY: yMin.toDouble(),
        maxY: yMax.toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            belowBarData: BarAreaData(
              show: true,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
            dotData: FlDotData(
              show: measurements.length <=
                  50, // Only show dots for smaller datasets
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 0,
                );
              },
            ),
            isStrokeCapRound: true,
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final measurement = measurements[touchedSpot.x.toInt()];
                final dateTime = DateTime.fromMillisecondsSinceEpoch(
                  measurement.timestamp * 1000,
                );

                return LineTooltipItem(
                  '${touchedSpot.y.toStringAsFixed(1)} dB\n${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
            // tooltipBgColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
