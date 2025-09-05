import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/audio_capture_service.dart';

class AudioWaveformWidget extends StatefulWidget {
  final Stream<double> splStream;
  final double width;
  final double height;

  const AudioWaveformWidget({
    super.key,
    required this.splStream,
    this.width = 300,
    this.height = 100,
  });

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget> {
  final List<double> _splValues = [];
  final int _maxDataPoints = 100; // Show last 100 readings
  double _currentSpl = 0.0;
  double _peakHold = 0.0;

  @override
  void initState() {
    super.initState();

    widget.splStream.listen((spl) {
      setState(() {
        _currentSpl = spl;

        // Update peak hold
        if (spl > _peakHold) {
          _peakHold = spl;
        } else {
          // Slowly decay peak hold
          _peakHold = max(_peakHold - 0.5, spl);
        }

        // Add to waveform data
        _splValues.add(spl);
        if (_splValues.length > _maxDataPoints) {
          _splValues.removeAt(0);
        }
      });
    });
  }

  Color _getColorForLevel(double spl) {
    final level = AudioCaptureService.getNoiseLevelCategory(spl);
    switch (level) {
      case NoiseLevel.quiet:
        return Colors.green;
      case NoiseLevel.moderate:
        return Colors.yellow;
      case NoiseLevel.loud:
        return Colors.orange;
      case NoiseLevel.dangerous:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current SPL Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      _currentSpl.toStringAsFixed(1),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: _getColorForLevel(_currentSpl),
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const Text('dB SPL'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      _peakHold.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _getColorForLevel(_peakHold)
                                .withValues(alpha: 0.7),
                          ),
                    ),
                    const Text('Peak'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Peak Meter (Horizontal Bar)
            SizedBox(
              height: 40,
              width: widget.width,
              child: _buildPeakMeter(),
            ),

            const SizedBox(height: 16),

            // Waveform Chart
            SizedBox(
              height: widget.height,
              width: widget.width,
              child: _buildWaveformChart(),
            ),

            // Level indicators
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLevelIndicator('Quiet', Colors.green, NoiseLevel.quiet),
                  _buildLevelIndicator(
                      'Moderate', Colors.yellow, NoiseLevel.moderate),
                  _buildLevelIndicator('Loud', Colors.orange, NoiseLevel.loud),
                  _buildLevelIndicator(
                      'Danger', Colors.red, NoiseLevel.dangerous),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakMeter() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.grey.withValues(alpha: 0.2),
      ),
      child: Stack(
        children: [
          // Background scale
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Colors.green,
                  Colors.yellow,
                  Colors.orange,
                  Colors.red,
                ],
                stops: [0.0, 0.5, 0.75, 1.0],
              ),
            ),
          ),

          // Current level indicator
          Positioned(
            left:
                (_currentSpl.clamp(20.0, 100.0) - 20.0) / 80.0 * widget.width -
                    2,
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 2),
                ],
              ),
            ),
          ),

          // Peak hold indicator
          Positioned(
            left:
                (_peakHold.clamp(20.0, 100.0) - 20.0) / 80.0 * widget.width - 1,
            child: Container(
              width: 2,
              height: 40,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformChart() {
    if (_splValues.length < 2) {
      return Container(
        alignment: Alignment.center,
        child: const Text('Waiting for audio data...'),
      );
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: _maxDataPoints.toDouble() - 1,
        minY: 20,
        maxY: 100,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _splValues.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value);
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: _getColorForLevel(_currentSpl),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _getColorForLevel(_currentSpl).withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelIndicator(String label, Color color, NoiseLevel level) {
    final isActive =
        AudioCaptureService.getNoiseLevelCategory(_currentSpl) == level;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? color : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
