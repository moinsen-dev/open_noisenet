import 'dart:async';
import 'dart:math';

import '../core/database/models/noise_measurement.dart';
import '../core/database/models/hourly_statistics.dart';
import '../core/database/models/daily_statistics.dart';
import '../core/database/dao/noise_measurement_dao.dart';
import '../core/database/dao/hourly_statistics_dao.dart';
import '../core/database/dao/daily_statistics_dao.dart';

class StatisticsAggregationService {
  static final StatisticsAggregationService _instance = 
      StatisticsAggregationService._internal();
  factory StatisticsAggregationService() => _instance;
  StatisticsAggregationService._internal();

  // DAOs
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  final HourlyStatisticsDao _hourlyDao = HourlyStatisticsDao();
  final DailyStatisticsDao _dailyDao = DailyStatisticsDao();

  // State
  bool _isRunning = false;
  Timer? _hourlyAggregationTimer;
  Timer? _dailyAggregationTimer;

  // Configuration
  static const Duration hourlyAggregationInterval = Duration(minutes: 15);
  static const Duration dailyAggregationInterval = Duration(hours: 1);
  static const double exceedanceThreshold = 55.0; // Default WHO night guideline

  /// Start the aggregation service
  void start() {
    if (_isRunning) return;

    _isRunning = true;

    // Start hourly aggregation timer
    _hourlyAggregationTimer = Timer.periodic(
      hourlyAggregationInterval,
      (_) => _performHourlyAggregation(),
    );

    // Start daily aggregation timer
    _dailyAggregationTimer = Timer.periodic(
      dailyAggregationInterval,
      (_) => _performDailyAggregation(),
    );

    // Perform initial aggregation
    _performHourlyAggregation();
    _performDailyAggregation();

    print('📊 Statistics aggregation service started');
  }

  /// Stop the aggregation service
  void stop() {
    if (!_isRunning) return;

    _isRunning = false;
    _hourlyAggregationTimer?.cancel();
    _dailyAggregationTimer?.cancel();
    _hourlyAggregationTimer = null;
    _dailyAggregationTimer = null;

    print('📊 Statistics aggregation service stopped');
  }

  /// Get current statistics for different time periods
  Future<Map<String, dynamic>> getCurrentStatistics() async {
    final now = DateTime.now();

    try {
      // Current hour stats
      final currentHour = DateTime(now.year, now.month, now.day, now.hour);
      final currentHourStats = await _measurementDao.getByHour(currentHour);

      // Today's stats
      final todayStats = await _measurementDao.getByDay(now);

      // Last 24 hours
      final last24HoursMeasurements = await _measurementDao.getLast24Hours();

      // Weekly stats
      final weeklyStats = await _dailyDao.getCurrentWeek();

      return {
        'current_hour': _summarizeMeasurements(currentHourStats),
        'today': _summarizeMeasurements(todayStats),
        'last_24_hours': _summarizeMeasurements(last24HoursMeasurements),
        'this_week': _summarizeDailyStats(weeklyStats),
        'measurement_count': {
          'current_hour': currentHourStats.length,
          'today': todayStats.length,
          'last_24_hours': last24HoursMeasurements.length,
          'this_week': weeklyStats.length,
        },
      };
    } catch (e) {
      print('❌ Failed to get current statistics: $e');
      return {};
    }
  }

  /// Get detailed statistics for a specific time range
  Future<Map<String, dynamic>> getStatisticsForRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
      final endTimestamp = endDate.millisecondsSinceEpoch ~/ 1000;

      // Get measurements for the range
      final measurements = await _measurementDao.getByTimeRange(
        startTimestamp: startTimestamp,
        endTimestamp: endTimestamp,
      );

      // Get hourly statistics for the range
      final hourlyStats = await _hourlyDao.getByTimeRange(
        startTimestamp: startTimestamp,
        endTimestamp: endTimestamp,
      );

      // Calculate aggregate stats
      final aggregateStats = await _measurementDao.getAggregatedStats(
        startTimestamp: startTimestamp,
        endTimestamp: endTimestamp,
      );

      return {
        'range': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
          'duration_hours': endDate.difference(startDate).inHours,
        },
        'measurements': _summarizeMeasurements(measurements),
        'hourly_breakdown': hourlyStats.map((h) => {
          'hour': h.dateTime.toIso8601String(),
          'avg_leq': h.avgLeq,
          'max_leq': h.maxLeq,
          'min_leq': h.minLeq,
          'exceedances': h.exceedanceCount,
        }).toList(),
        'aggregates': aggregateStats,
      };
    } catch (e) {
      print('❌ Failed to get statistics for range: $e');
      return {};
    }
  }

  /// Get noise pattern analysis
  Future<Map<String, dynamic>> getNoisePatterns() async {
    try {
      // Daily patterns (hourly averages)
      final dailyPatterns = await _hourlyDao.getDailyPattern(daysPeriod: 30);

      // Weekly patterns (daily averages)
      final weeklyPatterns = await _dailyDao.getWeeklyPattern(weeksPeriod: 8);

      // Peak and quiet periods
      final now = DateTime.now();
      final last30Days = now.subtract(const Duration(days: 30));
      
      final loudestHour = await _hourlyDao.getLoudestHour(
        startTimestamp: last30Days.millisecondsSinceEpoch ~/ 1000,
        endTimestamp: now.millisecondsSinceEpoch ~/ 1000,
      );

      final quietestHour = await _hourlyDao.getQuietestHour(
        startTimestamp: last30Days.millisecondsSinceEpoch ~/ 1000,
        endTimestamp: now.millisecondsSinceEpoch ~/ 1000,
      );

      return {
        'daily_patterns': dailyPatterns,
        'weekly_patterns': weeklyPatterns,
        'peak_periods': {
          'loudest_hour': loudestHour != null ? {
            'time': loudestHour.dateTime.toIso8601String(),
            'avg_leq': loudestHour.avgLeq,
            'hour_of_day': loudestHour.hourOfDay,
          } : null,
          'quietest_hour': quietestHour != null ? {
            'time': quietestHour.dateTime.toIso8601String(),
            'avg_leq': quietestHour.avgLeq,
            'hour_of_day': quietestHour.hourOfDay,
          } : null,
        },
      };
    } catch (e) {
      print('❌ Failed to get noise patterns: $e');
      return {};
    }
  }

  /// Get exceedance analysis
  Future<Map<String, dynamic>> getExceedanceAnalysis({
    double threshold = exceedanceThreshold,
    int daysPeriod = 30,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: daysPeriod));

      // Get measurements above threshold
      final exceedances = await _measurementDao.getAboveThreshold(
        thresholdDb: threshold,
      );

      // Filter by date range
      final recentExceedances = exceedances.where((m) =>
        m.dateTime.isAfter(startDate) && m.dateTime.isBefore(now)
      ).toList();

      // Group by hour of day
      final exceedancesByHour = <int, List<NoiseMeasurement>>{};
      for (final exceedance in recentExceedances) {
        final hour = exceedance.hourOfDay;
        exceedancesByHour.putIfAbsent(hour, () => []);
        exceedancesByHour[hour]!.add(exceedance);
      }

      // Calculate statistics
      final hourlyExceedances = exceedancesByHour.map((hour, measurements) =>
        MapEntry(hour, {
          'count': measurements.length,
          'avg_leq': measurements.map((m) => m.leqDb).reduce((a, b) => a + b) / measurements.length,
          'max_leq': measurements.map((m) => m.leqDb).reduce(max),
        })
      );

      return {
        'threshold': threshold,
        'period_days': daysPeriod,
        'total_exceedances': recentExceedances.length,
        'exceedances_per_day': recentExceedances.length / daysPeriod,
        'hourly_distribution': hourlyExceedances,
        'worst_hours': _getWorstHours(hourlyExceedances),
      };
    } catch (e) {
      print('❌ Failed to get exceedance analysis: $e');
      return {};
    }
  }

  /// Perform hourly aggregation
  Future<void> _performHourlyAggregation() async {
    try {
      final now = DateTime.now();
      
      // Process the previous hour to ensure all measurements are included
      final previousHour = DateTime(now.year, now.month, now.day, now.hour - 1);
      
      // Check if we already have stats for this hour
      if (await _hourlyDao.existsForHour(previousHour.millisecondsSinceEpoch ~/ 1000)) {
        return; // Already processed
      }

      // Get measurements for the hour
      final measurements = await _measurementDao.getByHour(previousHour);
      if (measurements.isEmpty) return;

      // Calculate statistics
      final statistics = _calculateHourlyStatistics(previousHour, measurements);
      
      // Store in database
      await _hourlyDao.insertOrReplace(statistics);

      print('📈 Created hourly statistics for ${previousHour.toIso8601String()}');
    } catch (e) {
      print('❌ Failed to perform hourly aggregation: $e');
    }
  }

  /// Perform daily aggregation
  Future<void> _performDailyAggregation() async {
    try {
      final now = DateTime.now();
      
      // Process the previous day to ensure all hourly stats are included
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final dateString = '${yesterday.year.toString().padLeft(4, '0')}-'
                        '${yesterday.month.toString().padLeft(2, '0')}-'
                        '${yesterday.day.toString().padLeft(2, '0')}';
      
      // Check if we already have stats for this day
      if (await _dailyDao.existsForDate(dateString)) {
        return; // Already processed
      }

      // Get hourly statistics for the day
      final hourlyStats = await _hourlyDao.getByDay(yesterday);
      if (hourlyStats.isEmpty) return;

      // Calculate daily statistics
      final statistics = _calculateDailyStatistics(dateString, hourlyStats);
      
      // Store in database
      await _dailyDao.insertOrReplace(statistics);

      print('📈 Created daily statistics for $dateString');
    } catch (e) {
      print('❌ Failed to perform daily aggregation: $e');
    }
  }

  /// Calculate hourly statistics from measurements
  HourlyStatistics _calculateHourlyStatistics(
    DateTime hour, 
    List<NoiseMeasurement> measurements
  ) {
    final leqValues = measurements.map((m) => m.leqDb).toList();
    final l10Values = measurements.map((m) => m.l10Db).where((v) => v != null).cast<double>().toList();
    final l50Values = measurements.map((m) => m.l50Db).where((v) => v != null).cast<double>().toList();
    final l90Values = measurements.map((m) => m.l90Db).where((v) => v != null).cast<double>().toList();

    final avgLeq = leqValues.reduce((a, b) => a + b) / leqValues.length;
    final maxLeq = leqValues.reduce(max);
    final minLeq = leqValues.reduce(min);

    final exceedanceCount = measurements
        .where((m) => m.leqDb >= exceedanceThreshold)
        .length;

    return HourlyStatistics(
      hourTimestamp: hour.millisecondsSinceEpoch ~/ 1000,
      avgLeq: avgLeq,
      maxLeq: maxLeq,
      minLeq: minLeq,
      l10: l10Values.isNotEmpty ? l10Values.reduce((a, b) => a + b) / l10Values.length : null,
      l50: l50Values.isNotEmpty ? l50Values.reduce((a, b) => a + b) / l50Values.length : null,
      l90: l90Values.isNotEmpty ? l90Values.reduce((a, b) => a + b) / l90Values.length : null,
      exceedanceCount: exceedanceCount,
      totalSamples: measurements.length,
    );
  }

  /// Calculate daily statistics from hourly statistics
  DailyStatistics _calculateDailyStatistics(
    String date, 
    List<HourlyStatistics> hourlyStats
  ) {
    final avgLeqValues = hourlyStats.map((h) => h.avgLeq).toList();
    final maxLeqValues = hourlyStats.map((h) => h.maxLeq).toList();
    final minLeqValues = hourlyStats.map((h) => h.minLeq).toList();

    final avgLeq = avgLeqValues.reduce((a, b) => a + b) / avgLeqValues.length;
    final maxLeq = maxLeqValues.reduce(max);
    final minLeq = minLeqValues.reduce(min);

    // Find peak and quiet hours
    final loudestHour = hourlyStats.reduce((a, b) => a.avgLeq > b.avgLeq ? a : b);
    final quietestHour = hourlyStats.reduce((a, b) => a.avgLeq < b.avgLeq ? a : b);

    final totalExceedances = hourlyStats
        .map((h) => h.exceedanceCount)
        .reduce((a, b) => a + b);

    final totalSamples = hourlyStats
        .map((h) => h.totalSamples)
        .reduce((a, b) => a + b);

    return DailyStatistics(
      date: date,
      avgLeq: avgLeq,
      maxLeq: maxLeq,
      minLeq: minLeq,
      peakHour: loudestHour.hourOfDay,
      quietHour: quietestHour.hourOfDay,
      totalExceedances: totalExceedances,
      totalSamples: totalSamples,
    );
  }

  /// Summarize a list of measurements
  Map<String, dynamic> _summarizeMeasurements(List<NoiseMeasurement> measurements) {
    if (measurements.isEmpty) {
      return {
        'count': 0,
        'avg_leq': null,
        'max_leq': null,
        'min_leq': null,
        'exceedances': 0,
      };
    }

    final leqValues = measurements.map((m) => m.leqDb).toList();
    final exceedances = measurements.where((m) => m.leqDb >= exceedanceThreshold).length;

    return {
      'count': measurements.length,
      'avg_leq': leqValues.reduce((a, b) => a + b) / leqValues.length,
      'max_leq': leqValues.reduce(max),
      'min_leq': leqValues.reduce(min),
      'exceedances': exceedances,
      'exceedance_percentage': (exceedances / measurements.length) * 100,
    };
  }

  /// Summarize daily statistics
  Map<String, dynamic> _summarizeDailyStats(List<DailyStatistics> dailyStats) {
    if (dailyStats.isEmpty) {
      return {
        'count': 0,
        'avg_leq': null,
        'max_leq': null,
        'min_leq': null,
        'total_exceedances': 0,
      };
    }

    final avgLeqValues = dailyStats.map((d) => d.avgLeq).toList();
    final totalExceedances = dailyStats.map((d) => d.totalExceedances).reduce((a, b) => a + b);

    return {
      'count': dailyStats.length,
      'avg_leq': avgLeqValues.reduce((a, b) => a + b) / avgLeqValues.length,
      'max_leq': dailyStats.map((d) => d.maxLeq).reduce(max),
      'min_leq': dailyStats.map((d) => d.minLeq).reduce(min),
      'total_exceedances': totalExceedances,
    };
  }

  /// Get worst hours from exceedance analysis
  List<Map<String, dynamic>> _getWorstHours(Map<int, Map<String, dynamic>> hourlyExceedances) {
    final sortedHours = hourlyExceedances.entries.toList()
      ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));

    return sortedHours.take(5).map((entry) => {
      'hour': entry.key,
      'hour_formatted': '${entry.key.toString().padLeft(2, '0')}:00',
      'count': entry.value['count'],
      'avg_leq': entry.value['avg_leq'],
      'max_leq': entry.value['max_leq'],
    }).toList();
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'is_running': _isRunning,
      'hourly_aggregation_interval_minutes': hourlyAggregationInterval.inMinutes,
      'daily_aggregation_interval_hours': dailyAggregationInterval.inHours,
      'exceedance_threshold_db': exceedanceThreshold,
    };
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}