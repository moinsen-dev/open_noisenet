import 'dart:math' as math;

import '../core/logging/app_logger.dart';
import 'audio_processing_service.dart';

/// Service for analyzing noise measurement patterns and preparing data for LLM analysis
class NoisePatternAnalyzer {
  static final NoisePatternAnalyzer _instance = NoisePatternAnalyzer._internal();
  factory NoisePatternAnalyzer() => _instance;
  NoisePatternAnalyzer._internal();

  /// Analyze a sequence of SPL measurements to extract meaningful patterns
  Map<String, dynamic> analyzePattern({
    required List<TimestampedSPL> measurements,
    required DateTime eventStart,
    required DateTime eventEnd,
  }) {
    if (measurements.isEmpty) {
      return _emptyAnalysis();
    }

    try {
      // Extract SPL values and timestamps
      final splValues = measurements.map((m) => m.splDb).toList();
      final timestamps = measurements.map((m) => m.timestamp).toList();

      // Basic statistics
      final basicStats = _calculateBasicStatistics(splValues);

      // Temporal patterns
      final temporalAnalysis = _analyzeTemporalPatterns(measurements, eventStart, eventEnd);

      // Variability analysis
      final variabilityAnalysis = _analyzeVariability(splValues);

      // Peak analysis
      final peakAnalysis = _analyzePeaks(splValues, timestamps);

      // Pattern classification
      final patternType = _classifyPattern(basicStats, temporalAnalysis, variabilityAnalysis);

      return {
        'event_start': eventStart.toIso8601String(),
        'event_end': eventEnd.toIso8601String(),
        'duration_seconds': eventEnd.difference(eventStart).inSeconds,
        'measurement_count': measurements.length,

        // Statistical analysis
        'average_spl_db': basicStats['mean'],
        'peak_spl_db': basicStats['max'],
        'min_spl_db': basicStats['min'],
        'spl_std_dev': basicStats['std_dev'],
        'spl_range_db': basicStats['range'],

        // Pattern characteristics
        'pattern_type': patternType,
        'variability_coefficient': variabilityAnalysis['coefficient_of_variation'],
        'trend': temporalAnalysis['trend'],
        'peak_count': peakAnalysis['peak_count'],
        'peak_intervals_seconds': peakAnalysis['intervals'],

        // Time context
        'time_of_day': _getTimeOfDay(eventStart),
        'day_of_week': _getDayOfWeek(eventStart),
        'is_weekend': eventStart.weekday >= 6,

        // For LLM analysis
        'spl_sequence': _downsampleForLLM(splValues),
        'pattern_summary': _generatePatternSummary(basicStats, temporalAnalysis, variabilityAnalysis, patternType),
      };

    } catch (e) {
      AppLogger.audio('Error analyzing noise pattern: $e');
      return _emptyAnalysis();
    }
  }

  /// Calculate basic statistical measures
  Map<String, double> _calculateBasicStatistics(List<double> values) {
    if (values.isEmpty) return {'mean': 0, 'max': 0, 'min': 0, 'std_dev': 0, 'range': 0};

    final mean = values.reduce((a, b) => a + b) / values.length;
    final max = values.reduce(math.max);
    final min = values.reduce(math.min);

    // Calculate standard deviation
    final variance = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b!) / values.length;
    final stdDev = math.sqrt(variance);

    return {
      'mean': mean,
      'max': max,
      'min': min,
      'std_dev': stdDev,
      'range': max - min,
    };
  }

  /// Analyze temporal patterns in the measurements
  Map<String, dynamic> _analyzeTemporalPatterns(
    List<TimestampedSPL> measurements,
    DateTime start,
    DateTime end,
  ) {
    if (measurements.length < 3) {
      return {'trend': 'insufficient_data', 'rate_of_change': 0.0};
    }

    // Calculate trend using linear regression
    final n = measurements.length;
    final timeIndices = List.generate(n, (i) => i.toDouble());
    final splValues = measurements.map((m) => m.splDb).toList();

    // Simple linear regression
    final sumX = timeIndices.reduce((a, b) => a + b);
    final sumY = splValues.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => timeIndices[i] * splValues[i]).reduce((a, b) => a + b);
    final sumXX = timeIndices.map((x) => x * x).reduce((a, b) => a + b);

    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);

    String trend;
    if (slope > 0.1) {
      trend = 'increasing';
    } else if (slope < -0.1) {
      trend = 'decreasing';
    } else {
      trend = 'stable';
    }

    return {
      'trend': trend,
      'rate_of_change': slope,
      'duration_minutes': end.difference(start).inMinutes,
      'sampling_rate_hz': n / end.difference(start).inSeconds,
    };
  }

  /// Analyze variability in measurements
  Map<String, dynamic> _analyzeVariability(List<double> values) {
    if (values.isEmpty) return {'coefficient_of_variation': 0.0, 'variability_class': 'unknown'};

    final mean = values.reduce((a, b) => a + b) / values.length;
    final stdDev = math.sqrt(values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b!) / values.length);

    final coefficientOfVariation = mean > 0 ? (stdDev / mean) * 100 : 0.0;

    String variabilityClass;
    if (coefficientOfVariation < 5) {
      variabilityClass = 'very_stable';
    } else if (coefficientOfVariation < 15) {
      variabilityClass = 'stable';
    } else if (coefficientOfVariation < 30) {
      variabilityClass = 'variable';
    } else {
      variabilityClass = 'highly_variable';
    }

    return {
      'coefficient_of_variation': coefficientOfVariation,
      'variability_class': variabilityClass,
      'standard_deviation': stdDev,
    };
  }

  /// Analyze peaks in the signal
  Map<String, dynamic> _analyzePeaks(List<double> values, List<DateTime> timestamps) {
    if (values.length < 3) return {'peak_count': 0, 'intervals': []};

    final peaks = <int>[];
    final threshold = values.reduce((a, b) => a + b) / values.length +
                     math.sqrt(values.map((x) => math.pow(x - values.reduce((a, b) => a + b) / values.length, 2)).reduce((a, b) => a + b!) / values.length);

    // Simple peak detection
    for (int i = 1; i < values.length - 1; i++) {
      if (values[i] > values[i - 1] &&
          values[i] > values[i + 1] &&
          values[i] > threshold) {
        peaks.add(i);
      }
    }

    // Calculate intervals between peaks
    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      final interval = timestamps[peaks[i]].difference(timestamps[peaks[i - 1]]).inSeconds.toDouble();
      intervals.add(interval);
    }

    return {
      'peak_count': peaks.length,
      'intervals': intervals,
      'average_interval_seconds': intervals.isNotEmpty ? intervals.reduce((a, b) => a + b) / intervals.length : 0,
      'peak_regularity': _assessPeakRegularity(intervals),
    };
  }

  /// Assess regularity of peak intervals
  String _assessPeakRegularity(List<double> intervals) {
    if (intervals.length < 2) return 'insufficient_data';

    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final stdDev = math.sqrt(intervals.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b!) / intervals.length);
    final cv = mean > 0 ? (stdDev / mean) * 100 : 0;

    if (cv < 20) return 'regular';
    if (cv < 50) return 'semi_regular';
    return 'irregular';
  }

  /// Classify the overall pattern type
  String _classifyPattern(
    Map<String, double> basicStats,
    Map<String, dynamic> temporalAnalysis,
    Map<String, dynamic> variabilityAnalysis,
  ) {
    final mean = basicStats['mean'] ?? 0;
    final stdDev = basicStats['std_dev'] ?? 0;
    final range = basicStats['range'] ?? 0;
    final cv = variabilityAnalysis['coefficient_of_variation'] as double? ?? 0;
    final trend = temporalAnalysis['trend'] as String? ?? 'stable';

    // Impulsive pattern
    if (range > 20 && cv > 30) {
      return 'impulsive';
    }

    // Steady pattern
    if (cv < 10 && trend == 'stable') {
      return 'steady';
    }

    // Fluctuating pattern
    if (cv > 15 && cv < 35) {
      return 'fluctuating';
    }

    // Trending pattern
    if (trend != 'stable') {
      return 'trending_${trend}';
    }

    return 'complex';
  }

  /// Get time of day category
  String _getTimeOfDay(DateTime timestamp) {
    final hour = timestamp.hour;
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }

  /// Get day of week
  String _getDayOfWeek(DateTime timestamp) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[timestamp.weekday - 1];
  }

  /// Downsample SPL sequence for LLM analysis (keep it manageable)
  List<double> _downsampleForLLM(List<double> values) {
    if (values.length <= 20) return values;

    // Keep first, last, peaks, and regular intervals
    final result = <double>[];
    final step = values.length / 15; // Target ~15 samples

    for (int i = 0; i < values.length; i += step.round()) {
      if (i < values.length) {
        result.add(values[i]);
      }
    }

    // Always include the last value
    if (result.last != values.last) {
      result.add(values.last);
    }

    return result;
  }

  /// Generate a human-readable pattern summary
  String _generatePatternSummary(
    Map<String, double> basicStats,
    Map<String, dynamic> temporalAnalysis,
    Map<String, dynamic> variabilityAnalysis,
    String patternType,
  ) {
    final mean = basicStats['mean']?.toStringAsFixed(1) ?? '0';
    final trend = temporalAnalysis['trend'] ?? 'stable';
    final variabilityClass = variabilityAnalysis['variability_class'] ?? 'unknown';
    final duration = temporalAnalysis['duration_minutes'] ?? 0;

    return 'Pattern: $patternType, Average: ${mean}dB, Trend: $trend, '
           'Variability: $variabilityClass, Duration: ${duration}min';
  }

  /// Return empty analysis for error cases
  Map<String, dynamic> _emptyAnalysis() {
    return {
      'average_spl_db': 0.0,
      'peak_spl_db': 0.0,
      'min_spl_db': 0.0,
      'spl_std_dev': 0.0,
      'duration_seconds': 0,
      'pattern_type': 'unknown',
      'time_of_day': 'unknown',
      'spl_sequence': <double>[],
      'pattern_summary': 'Analysis failed - insufficient data',
    };
  }

  /// Extract context from location data
  String extractLocationContext(Map<String, dynamic>? location) {
    if (location == null) return 'unknown_location';

    // This could be enhanced with reverse geocoding
    final type = location['type'] as String?;
    final accuracy = location['accuracy'] as double?;

    if (type != null) return type;
    if (accuracy != null && accuracy < 50) return 'precise_location';

    return 'general_area';
  }

  /// Determine regulatory context based on time and location
  Map<String, dynamic> getRegulatoryContext(DateTime timestamp, String? locationType) {
    final hour = timestamp.hour;
    String timeCategory;
    double whoLimit;

    if (hour >= 7 && hour < 19) {
      timeCategory = 'day';
      whoLimit = 55.0;
    } else if (hour >= 19 && hour < 23) {
      timeCategory = 'evening';
      whoLimit = 50.0;
    } else {
      timeCategory = 'night';
      whoLimit = 40.0;
    }

    return {
      'time_category': timeCategory,
      'who_limit_db': whoLimit,
      'location_type': locationType ?? 'general',
      'is_sensitive_hours': timeCategory == 'night' || timeCategory == 'evening',
    };
  }
}
