import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../core/logging/app_logger.dart';

/// Data class for noise events
class NoiseEvent {
  final DateTime timestamp;
  final double level;
  final NoiseEventType type;
  final Duration duration;
  final Map<String, dynamic>? metadata;

  const NoiseEvent({
    required this.timestamp,
    required this.level,
    required this.type,
    required this.duration,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level,
      'type': type.name,
      'duration_ms': duration.inMilliseconds,
      'metadata': metadata,
    };
  }
}

/// Types of noise events
enum NoiseEventType {
  spike, // Sudden loud noise
  sustained, // Prolonged noise above threshold
  pattern, // Repeating noise pattern
  quiet, // Unusually quiet period
}

/// Intelligent noise event detection service
/// Analyzes continuous audio stream to identify significant noise events
class NoiseEventDetector {
  static final NoiseEventDetector _instance = NoiseEventDetector._internal();
  factory NoiseEventDetector() => _instance;
  NoiseEventDetector._internal();

  // Configuration
  double _spikeThreshold = 75.0; // dB
  double _sustainedThreshold = 65.0; // dB
  Duration _sustainedMinDuration = const Duration(minutes: 2);
  Duration _quietThreshold = const Duration(minutes: 5);
  double _quietLevel = 45.0; // dB

  // State tracking
  final Queue<double> _recentLevels = Queue<double>();
  final Queue<DateTime> _recentTimestamps = Queue<DateTime>();
  final List<NoiseEvent> _detectedEvents = <NoiseEvent>[];

  // Rolling averages for different time windows
  static const int _shortWindowSeconds = 30;
  static const int _mediumWindowSeconds = 300; // 5 minutes
  static const int _longWindowSeconds = 900; // 15 minutes

  // Sustained noise tracking
  DateTime? _sustainedNoiseStart;
  double _sustainedNoiseLevel = 0.0;

  // Quiet period tracking
  DateTime? _quietPeriodStart;

  // Stream controllers for events
  final StreamController<NoiseEvent> _eventController =
      StreamController<NoiseEvent>.broadcast();

  /// Stream of detected noise events
  Stream<NoiseEvent> get eventStream => _eventController.stream;

  /// Configure detection thresholds
  void configure({
    double? spikeThreshold,
    double? sustainedThreshold,
    Duration? sustainedMinDuration,
    Duration? quietThreshold,
    double? quietLevel,
  }) {
    _spikeThreshold = spikeThreshold ?? _spikeThreshold;
    _sustainedThreshold = sustainedThreshold ?? _sustainedThreshold;
    _sustainedMinDuration = sustainedMinDuration ?? _sustainedMinDuration;
    _quietThreshold = quietThreshold ?? _quietThreshold;
    _quietLevel = quietLevel ?? _quietLevel;
    AppLogger.event(
        'NoiseEventDetector configured - Spike: ${_spikeThreshold}dB, Sustained: ${_sustainedThreshold}dB');
  }

  /// Add new noise level measurement
  void addMeasurement(double level) {
    final now = DateTime.now();

    // Add to rolling buffer
    _recentLevels.add(level);
    _recentTimestamps.add(now);

    // Maintain rolling window (keep last 15 minutes)
    while (_recentTimestamps.isNotEmpty &&
        now.difference(_recentTimestamps.first) > const Duration(minutes: 15)) {
      _recentLevels.removeFirst();
      _recentTimestamps.removeFirst();
    }

    // Analyze for events
    _analyzeForSpike(level, now);
    _analyzeForSustainedNoise(level, now);
    _analyzeForQuietPeriod(level, now);
  }

  /// Detect sudden noise spikes
  void _analyzeForSpike(double level, DateTime timestamp) {
    if (level > _spikeThreshold) {
      // Check if this is significantly higher than recent average
      final recentAvg = _getAverageLevel(_shortWindowSeconds);
      if (recentAvg != null && level > recentAvg + 10) {
        final event = NoiseEvent(
          timestamp: timestamp,
          level: level,
          type: NoiseEventType.spike,
          duration: const Duration(seconds: 1),
          metadata: {
            'recent_avg': recentAvg,
            'spike_difference': level - recentAvg,
          },
        );
        _emitEvent(event);
      }
    }
  }

  /// Detect sustained noise above threshold
  void _analyzeForSustainedNoise(double level, DateTime timestamp) {
    if (level > _sustainedThreshold) {
      // Start tracking sustained noise if not already
      if (_sustainedNoiseStart == null) {
        _sustainedNoiseStart = timestamp;
        _sustainedNoiseLevel = level;
      } else {
        // Update sustained noise level (use average)
        _sustainedNoiseLevel = (_sustainedNoiseLevel + level) / 2;
      }
    } else {
      // Check if we had sustained noise that just ended
      if (_sustainedNoiseStart != null) {
        final duration = timestamp.difference(_sustainedNoiseStart!);
        if (duration >= _sustainedMinDuration) {
          final event = NoiseEvent(
            timestamp: _sustainedNoiseStart!,
            level: _sustainedNoiseLevel,
            type: NoiseEventType.sustained,
            duration: duration,
            metadata: {
              'end_timestamp': timestamp.toIso8601String(),
              'avg_level': _sustainedNoiseLevel,
            },
          );
          _emitEvent(event);
        }
        _sustainedNoiseStart = null;
        _sustainedNoiseLevel = 0.0;
      }
    }
  }

  /// Detect unusually quiet periods
  void _analyzeForQuietPeriod(double level, DateTime timestamp) {
    if (level < _quietLevel) {
      // Start tracking quiet period if not already
      _quietPeriodStart ??= timestamp;
    } else {
      // Check if we had a quiet period that just ended
      if (_quietPeriodStart != null) {
        final duration = timestamp.difference(_quietPeriodStart!);
        if (duration >= _quietThreshold) {
          final event = NoiseEvent(
            timestamp: _quietPeriodStart!,
            level: _quietLevel,
            type: NoiseEventType.quiet,
            duration: duration,
            metadata: {
              'end_timestamp': timestamp.toIso8601String(),
            },
          );
          _emitEvent(event);
        }
        _quietPeriodStart = null;
      }
    }
  }

  /// Get average noise level for specified time window
  double? _getAverageLevel(int windowSeconds) {
    if (_recentLevels.isEmpty) return null;

    final cutoff = DateTime.now().subtract(Duration(seconds: windowSeconds));
    double sum = 0.0;
    int count = 0;

    for (int i = _recentTimestamps.length - 1; i >= 0; i--) {
      if (_recentTimestamps.elementAt(i).isAfter(cutoff)) {
        sum += _recentLevels.elementAt(i);
        count++;
      } else {
        break;
      }
    }

    return count > 0 ? sum / count : null;
  }

  /// Emit detected event
  void _emitEvent(NoiseEvent event) {
    _detectedEvents.add(event);
    _eventController.add(event);
    AppLogger.event(
        'Detected ${event.type.name} event: ${event.level.toStringAsFixed(1)}dB for ${event.duration}');

    // Keep only recent events (last 24 hours)
    _detectedEvents.removeWhere((e) =>
        DateTime.now().difference(e.timestamp) > const Duration(days: 1));
  }

  /// Get current noise level statistics
  Map<String, dynamic> getCurrentStats() {
    return {
      'current_level': _recentLevels.isNotEmpty ? _recentLevels.last : 0.0,
      'avg_30s': _getAverageLevel(_shortWindowSeconds),
      'avg_5min': _getAverageLevel(_mediumWindowSeconds),
      'avg_15min': _getAverageLevel(_longWindowSeconds),
      'peak_15min': _getPeakLevel(_longWindowSeconds),
      'sustained_active': _sustainedNoiseStart != null,
      'quiet_active': _quietPeriodStart != null,
      'recent_events_count': _detectedEvents.length,
    };
  }

  /// Get peak noise level for specified time window
  double? _getPeakLevel(int windowSeconds) {
    if (_recentLevels.isEmpty) return null;

    final cutoff = DateTime.now().subtract(Duration(seconds: windowSeconds));
    double peak = 0.0;

    for (int i = _recentTimestamps.length - 1; i >= 0; i--) {
      if (_recentTimestamps.elementAt(i).isAfter(cutoff)) {
        final level = _recentLevels.elementAt(i);
        if (level > peak) peak = level;
      } else {
        break;
      }
    }

    return peak > 0 ? peak : null;
  }

  /// Get recent events
  List<NoiseEvent> getRecentEvents({int limit = 10}) {
    return _detectedEvents.take(limit).toList().reversed.toList();
  }

  /// Check if current conditions warrant recording
  bool shouldTriggerRecording() {
    final stats = getCurrentStats();

    // Trigger if sustained noise is active
    if (stats['sustained_active'] == true) return true;

    // Trigger if recent spike detected
    final recentSpikes = _detectedEvents
        .where((e) =>
            e.type == NoiseEventType.spike &&
            DateTime.now().difference(e.timestamp) < const Duration(minutes: 1))
        .length;
    if (recentSpikes > 0) return true;

    // Trigger if current level is significantly above average
    final current = stats['current_level'] as double;
    final avg15min = stats['avg_15min'] as double?;
    if (avg15min != null && current > avg15min + 15) return true;

    return false;
  }

  /// Get priority level for current noise conditions
  int getRecordingPriority() {
    final stats = getCurrentStats();
    final current = stats['current_level'] as double;

    // Critical: Very loud or sustained noise
    if (current > 85 || stats['sustained_active'] == true) return 4;

    // High: Loud noise or multiple recent events
    if (current > 75 || _detectedEvents.length > 3) return 3;

    // Medium: Moderate noise above threshold
    if (current > _sustainedThreshold) return 2;

    // Low: Normal levels
    return 1;
  }

  /// Export events for recording metadata
  String exportEventsAsJson(DateTime startTime, DateTime endTime) {
    final relevantEvents = _detectedEvents
        .where((e) =>
            e.timestamp.isAfter(startTime) && e.timestamp.isBefore(endTime))
        .map((e) => e.toMap())
        .toList();

    return jsonEncode(relevantEvents);
  }

  /// Clean up resources
  void dispose() {
    _eventController.close();
    _recentLevels.clear();
    _recentTimestamps.clear();
    _detectedEvents.clear();
  }
}
