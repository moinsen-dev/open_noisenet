import 'dart:async';
import 'dart:math';

import '../core/database/dao/noise_measurement_dao.dart';
import '../core/database/dao/daily_statistics_dao.dart';
import '../core/database/models/daily_statistics.dart';
import 'audio_recording_service.dart';

class StatisticsService {
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  StatisticsService._internal();

  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  final DailyStatisticsDao _dailyStatsDao = DailyStatisticsDao();
  final AudioRecordingService _recordingService = AudioRecordingService();

  // Stream controllers for real-time updates
  final StreamController<int> _measurementCountController = 
      StreamController<int>.broadcast();
  final StreamController<int> _activeRecordingsController = 
      StreamController<int>.broadcast();
  final StreamController<double?> _todaysAverageController = 
      StreamController<double?>.broadcast();
  final StreamController<double?> _realTimeAverageController = 
      StreamController<double?>.broadcast();

  // Timers for periodic updates
  Timer? _updateTimer;
  bool _isActive = false;

  // Cache for real-time average calculation
  final List<double> _allSamples = [];
  double? _cachedRealTimeAverage;

  // Getters for streams
  Stream<int> get measurementCountStream => _measurementCountController.stream;
  Stream<int> get activeRecordingsStream => _activeRecordingsController.stream;
  Stream<double?> get todaysAverageStream => _todaysAverageController.stream;
  Stream<double?> get realTimeAverageStream => _realTimeAverageController.stream;

  /// Start the statistics service with real-time updates
  void start() {
    if (_isActive) return;
    
    _isActive = true;
    _allSamples.clear();
    _cachedRealTimeAverage = null;

    // Update statistics every 5 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateStatistics();
    });

    // Initial update
    _updateStatistics();
    
    print('📊 StatisticsService: Started real-time statistics updates');
  }

  /// Stop the statistics service
  void stop() {
    if (!_isActive) return;
    
    _isActive = false;
    _updateTimer?.cancel();
    _updateTimer = null;
    _allSamples.clear();
    _cachedRealTimeAverage = null;
    
    print('🛑 StatisticsService: Stopped statistics updates');
  }

  /// Add a new SPL sample for real-time average calculation
  void addSample(double splDb) {
    if (!_isActive) return;
    
    _allSamples.add(splDb);
    
    // Limit to last 1000 samples to prevent memory issues
    if (_allSamples.length > 1000) {
      _allSamples.removeAt(0);
    }
    
    // Calculate real-time average
    if (_allSamples.isNotEmpty) {
      // Calculate Leq (equivalent continuous sound level)
      final energySum = _allSamples
          .map((db) => pow(10, db / 10))
          .fold(0.0, (sum, energy) => sum + energy);
      final averageEnergy = energySum / _allSamples.length;
      final realTimeLeq = 10 * log(averageEnergy) / ln10;
      
      _cachedRealTimeAverage = realTimeLeq;
      _realTimeAverageController.add(realTimeLeq);
    }
  }

  /// Update all statistics by querying the database
  Future<void> _updateStatistics() async {
    if (!_isActive) return;

    try {
      // Update measurement count
      final measurementCount = await _measurementDao.count();
      _measurementCountController.add(measurementCount);

      // Update active recordings count
      final activeRecordings = _recordingService.activeRecordingCount;
      _activeRecordingsController.add(activeRecordings);

      // Update today's average from database
      final todaysStats = await _getTodaysAverage();
      _todaysAverageController.add(todaysStats);

    } catch (e) {
      print('❌ StatisticsService: Error updating statistics: $e');
    }
  }

  /// Calculate today's average from database measurements
  Future<double?> _getTodaysAverage() async {
    try {
      // First try to get from daily statistics
      final today = DateTime.now();
      final dateString = '${today.year.toString().padLeft(4, '0')}-'
                        '${today.month.toString().padLeft(2, '0')}-'
                        '${today.day.toString().padLeft(2, '0')}';
      
      final dailyStats = await _dailyStatsDao.getByDate(dateString);
      if (dailyStats != null) {
        return dailyStats.avgLeq;
      }

      // If no daily stats, calculate from individual measurements
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final measurements = await _measurementDao.getByTimeRange(
        startTimestamp: startOfDay.millisecondsSinceEpoch ~/ 1000,
        endTimestamp: endOfDay.millisecondsSinceEpoch ~/ 1000,
      );

      if (measurements.isEmpty) {
        return null;
      }

      // Calculate average Leq from measurements
      final totalLeq = measurements
          .map((m) => m.leqDb)
          .fold(0.0, (sum, leq) => sum + leq);
      
      return totalLeq / measurements.length;

    } catch (e) {
      print('❌ StatisticsService: Error calculating today\'s average: $e');
      return null;
    }
  }

  /// Get current real-time average (cached value)
  double? get currentRealTimeAverage => _cachedRealTimeAverage;

  /// Get current sample count
  int get currentSampleCount => _allSamples.length;

  /// Force an immediate statistics update
  Future<void> forceUpdate() async {
    await _updateStatistics();
  }

  /// Get comprehensive statistics for debugging
  Map<String, dynamic> getStatus() {
    return {
      'isActive': _isActive,
      'sampleCount': _allSamples.length,
      'realTimeAverage': _cachedRealTimeAverage?.toStringAsFixed(1),
      'hasUpdateTimer': _updateTimer != null,
    };
  }

  /// Dispose of resources
  void dispose() {
    stop();
    _measurementCountController.close();
    _activeRecordingsController.close();
    _todaysAverageController.close();
    _realTimeAverageController.close();
  }
}