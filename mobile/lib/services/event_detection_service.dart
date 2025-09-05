import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:io';

import 'location_service.dart';
import '../features/noise_monitoring/data/models/noise_event_model.dart';
import '../features/noise_monitoring/data/repositories/event_repository.dart';
import '../core/database/models/noise_measurement.dart';
import '../core/database/dao/noise_measurement_dao.dart';
import 'package:uuid/uuid.dart';

class NoiseEvent {
  final DateTime startTime;
  final DateTime endTime;
  final double averageLeqDb;
  final double maxLevelDb;
  final double minLevelDb;
  final List<double> samples;
  final String? ruleTriggered;

  const NoiseEvent({
    required this.startTime,
    required this.endTime,
    required this.averageLeqDb,
    required this.maxLevelDb,
    required this.minLevelDb,
    required this.samples,
    this.ruleTriggered,
  });

  Duration get duration => endTime.difference(startTime);

  /// Calculate exceedance percentage above a threshold
  double getExceedancePercentage(double thresholdDb) {
    if (samples.isEmpty) return 0.0;
    final exceedingSamples = samples.where((db) => db >= thresholdDb).length;
    return (exceedingSamples / samples.length) * 100.0;
  }

  @override
  String toString() {
    return 'NoiseEvent(${startTime.toIso8601String()}, ${averageLeqDb.toStringAsFixed(1)} dB, ${duration.inSeconds}s)';
  }
}

class EventDetectionService {
  static final EventDetectionService _instance =
      EventDetectionService._internal();
  factory EventDetectionService() => _instance;
  EventDetectionService._internal();

  // Services
  final LocationService _locationService = LocationService();
  final Uuid _uuid = const Uuid();
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();

  // Configuration (will be moved to settings later)
  double _thresholdDb = 60.0;
  Duration _windowDuration = const Duration(minutes: 10);

  // Rolling window for SPL values
  final Queue<_TimestampedSample> _rollingWindow = Queue<_TimestampedSample>();

  // Minute aggregation
  final Queue<_TimestampedSample> _minuteBuffer = Queue<_TimestampedSample>();
  DateTime? _lastMinuteProcessed;
  Timer? _minuteAggregationTimer;

  // Event tracking
  NoiseEvent? _currentEvent;
  bool _isMonitoring = false;
  Timer? _cleanupTimer;

  // Stream controllers
  final StreamController<NoiseEvent> _eventController =
      StreamController<NoiseEvent>.broadcast();
  final StreamController<double> _averageLeqController =
      StreamController<double>.broadcast();

  // Getters
  Stream<NoiseEvent> get eventStream => _eventController.stream;
  Stream<double> get averageLeqStream => _averageLeqController.stream;
  double get thresholdDb => _thresholdDb;
  Duration get windowDuration => _windowDuration;
  bool get isMonitoring => _isMonitoring;

  /// Start monitoring for events
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _rollingWindow.clear();
    _minuteBuffer.clear();
    _currentEvent = null;
    _lastMinuteProcessed = null;

    // Start cleanup timer to remove old samples
    _cleanupTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _cleanupOldSamples());

    // Start minute aggregation timer
    _minuteAggregationTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _processMinuteAggregation());

    print(
        '🎯 EventDetectionService: Started monitoring with threshold $_thresholdDb dB');
  }

  /// Stop monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _minuteAggregationTimer?.cancel();
    _minuteAggregationTimer = null;

    // Process any remaining minute data
    _processMinuteAggregation();

    // Finalize any current event
    if (_currentEvent != null) {
      _finalizeCurrentEvent();
    }

    _rollingWindow.clear();
    _minuteBuffer.clear();
    print('🛑 EventDetectionService: Stopped monitoring');
  }

  /// Add a new SPL sample
  void addSample(double splDb) {
    if (!_isMonitoring) return;

    final now = DateTime.now();
    _rollingWindow.add(_TimestampedSample(now, splDb));
    
    // Also add to minute buffer for aggregation
    _minuteBuffer.add(_TimestampedSample(now, splDb));

    // Clean up old samples outside the window
    _cleanupOldSamples();

    // Calculate current window statistics
    final stats = _calculateWindowStats();

    if (stats != null) {
      // Emit current average
      _averageLeqController.add(stats.averageLeq);

      // Check for threshold exceedance
      _checkThresholdExceedance(stats, now);
    }
  }

  /// Update detection threshold
  void setThreshold(double thresholdDb) {
    if (thresholdDb != _thresholdDb) {
      _thresholdDb = thresholdDb;
      print('🎛️ EventDetectionService: Threshold updated to $_thresholdDb dB');
    }
  }

  /// Update window duration
  void setWindowDuration(Duration duration) {
    if (duration != _windowDuration) {
      _windowDuration = duration;
      print(
          '⏱️ EventDetectionService: Window duration updated to ${duration.inMinutes} minutes');
      // Clean up samples that are now outside the new window
      _cleanupOldSamples();
    }
  }

  /// Calculate statistics for the current rolling window
  _WindowStats? _calculateWindowStats() {
    if (_rollingWindow.length < 2) return null;

    final samples = _rollingWindow.map((s) => s.splDb).toList();

    // Calculate Leq (equivalent continuous sound level)
    // Leq = 10 * log10(1/T * sum(10^(Li/10)))
    final energySum = samples
        .map((db) => pow(10, db / 10))
        .fold(0.0, (sum, energy) => sum + energy);
    final averageEnergy = energySum / samples.length;
    final leq = 10 * log(averageEnergy) / ln10;

    final maxLevel = samples.reduce(max);
    final minLevel = samples.reduce(min);

    return _WindowStats(
      averageLeq: leq,
      maxLevel: maxLevel,
      minLevel: minLevel,
      sampleCount: samples.length,
      samples: List.from(samples),
    );
  }

  /// Check if current window exceeds threshold and handle event logic
  void _checkThresholdExceedance(_WindowStats stats, DateTime timestamp) {
    final exceedsThreshold = stats.averageLeq >= _thresholdDb;

    if (exceedsThreshold && _currentEvent == null) {
      // Start new event
      _currentEvent = NoiseEvent(
        startTime: _rollingWindow.first.timestamp,
        endTime: timestamp,
        averageLeqDb: stats.averageLeq,
        maxLevelDb: stats.maxLevel,
        minLevelDb: stats.minLevel,
        samples: stats.samples,
        ruleTriggered:
            'threshold_${_thresholdDb}dB_${_windowDuration.inMinutes}min',
      );

      print(
          '🚨 Event started: ${stats.averageLeq.toStringAsFixed(1)} dB >= $_thresholdDb dB');
    } else if (exceedsThreshold && _currentEvent != null) {
      // Update ongoing event
      _currentEvent = NoiseEvent(
        startTime: _currentEvent!.startTime,
        endTime: timestamp,
        averageLeqDb: stats.averageLeq,
        maxLevelDb: max(_currentEvent!.maxLevelDb, stats.maxLevel),
        minLevelDb: min(_currentEvent!.minLevelDb, stats.minLevel),
        samples: stats.samples,
        ruleTriggered: _currentEvent!.ruleTriggered,
      );
    } else if (!exceedsThreshold && _currentEvent != null) {
      // End current event
      print(
          '✅ Event ended: ${_currentEvent!.averageLeqDb.toStringAsFixed(1)} dB < $_thresholdDb dB');
      _finalizeCurrentEvent();
    }
  }

  /// Finalize and emit the current event
  void _finalizeCurrentEvent() async {
    if (_currentEvent == null) return;

    // Only emit events that lasted at least 30 seconds
    if (_currentEvent!.duration.inSeconds >= 30) {
      // Get current location for the event
      final location = await _locationService.getCurrentLocation();
      
      // Create a NoiseEventModel for storage/submission
      final eventModel = await _createNoiseEventModel(_currentEvent!, location);
      
      // Store the event in the database
      await _storeEvent(eventModel);
      
      _eventController.add(_currentEvent!);
      print('📤 Event emitted with location: ${_currentEvent!}');
    }

    _currentEvent = null;
  }

  /// Create a NoiseEventModel from a NoiseEvent with location data
  Future<NoiseEventModel> _createNoiseEventModel(NoiseEvent event, LocationData? location) async {
    final deviceId = Platform.isAndroid 
        ? 'android-${_uuid.v4().substring(0, 8)}' 
        : 'ios-${_uuid.v4().substring(0, 8)}';

    return NoiseEventModel.fromDetectedEvent(
      event,
      deviceId: deviceId,
      location: location,
      metadata: {
        'detection_service_version': '1.0',
        'platform': Platform.operatingSystem,
        'event_uuid': _uuid.v4(),
      },
    );
  }

  /// Store the event in the local database
  Future<void> _storeEvent(NoiseEventModel event) async {
    try {
      final repository = await EventRepository.getInstance();
      await repository.saveEvent(event);
      print('💾 Event stored locally: ${event.id}');
    } catch (e) {
      print('❌ Failed to store event: $e');
    }
  }

  /// Remove samples that are older than the window duration
  void _cleanupOldSamples() {
    final cutoffTime = DateTime.now().subtract(_windowDuration);

    while (_rollingWindow.isNotEmpty &&
        _rollingWindow.first.timestamp.isBefore(cutoffTime)) {
      _rollingWindow.removeFirst();
    }
  }

  /// Process minute-level aggregation of samples
  void _processMinuteAggregation() async {
    if (_minuteBuffer.isEmpty) return;

    final now = DateTime.now();
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    
    // Check if we have a complete minute to process
    if (_lastMinuteProcessed != null && currentMinute == _lastMinuteProcessed) {
      return; // Already processed this minute
    }

    // Get samples for the previous minute
    final previousMinute = currentMinute.subtract(const Duration(minutes: 1));
    final minuteStart = previousMinute.millisecondsSinceEpoch;
    final minuteEnd = currentMinute.millisecondsSinceEpoch;

    // Filter samples for the previous minute
    final minuteSamples = _minuteBuffer
        .where((sample) => 
            sample.timestamp.millisecondsSinceEpoch >= minuteStart &&
            sample.timestamp.millisecondsSinceEpoch < minuteEnd)
        .map((sample) => sample.splDb)
        .toList();

    if (minuteSamples.isNotEmpty) {
      // Calculate minute statistics
      final measurement = _createNoiseMeasurement(previousMinute, minuteSamples);
      
      // Store in database
      try {
        await _measurementDao.insert(measurement);
        print('📊 Stored minute measurement: ${measurement.toString()}');
      } catch (e) {
        print('❌ Failed to store minute measurement: $e');
      }
    }

    // Clean up processed samples from buffer
    _minuteBuffer.removeWhere((sample) => 
        sample.timestamp.millisecondsSinceEpoch < minuteEnd);

    _lastMinuteProcessed = currentMinute;
  }

  /// Create NoiseMeasurement from samples
  NoiseMeasurement _createNoiseMeasurement(DateTime timestamp, List<double> samples) {
    if (samples.isEmpty) {
      throw ArgumentError('Cannot create measurement from empty samples');
    }

    // Sort samples for percentile calculations
    final sortedSamples = List<double>.from(samples)..sort();
    final count = sortedSamples.length;

    // Calculate basic statistics
    final maxDb = sortedSamples.last;
    final minDb = sortedSamples.first;

    // Calculate Leq (equivalent continuous sound level)
    final energySum = samples
        .map((db) => pow(10, db / 10))
        .fold(0.0, (sum, energy) => sum + energy);
    final averageEnergy = energySum / samples.length;
    final leq = 10 * log(averageEnergy) / ln10;

    // Calculate percentiles
    final l10Index = ((count - 1) * 0.9).round(); // 90th percentile (loud events)
    final l50Index = ((count - 1) * 0.5).round(); // 50th percentile (median)
    final l90Index = ((count - 1) * 0.1).round(); // 10th percentile (background)

    final l10Db = sortedSamples[l10Index];
    final l50Db = sortedSamples[l50Index];
    final l90Db = sortedSamples[l90Index];

    return NoiseMeasurement(
      timestamp: timestamp.millisecondsSinceEpoch ~/ 1000,
      leqDb: leq,
      lmaxDb: maxDb,
      lminDb: minDb,
      l10Db: l10Db,
      l50Db: l50Db,
      l90Db: l90Db,
      samplesCount: count,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Get current window status
  Map<String, dynamic> getStatus() {
    final stats = _calculateWindowStats();

    return {
      'isMonitoring': _isMonitoring,
      'thresholdDb': _thresholdDb,
      'windowDurationMinutes': _windowDuration.inMinutes,
      'sampleCount': _rollingWindow.length,
      'minuteBufferCount': _minuteBuffer.length,
      'lastMinuteProcessed': _lastMinuteProcessed?.toIso8601String(),
      'currentAverageLeq': stats?.averageLeq.toStringAsFixed(1),
      'hasActiveEvent': _currentEvent != null,
      'activeEventDuration': _currentEvent?.duration.inSeconds,
    };
  }

  /// Dispose of resources
  void dispose() {
    stopMonitoring();
    _eventController.close();
    _averageLeqController.close();
  }
}

class _TimestampedSample {
  final DateTime timestamp;
  final double splDb;

  const _TimestampedSample(this.timestamp, this.splDb);
}

class _WindowStats {
  final double averageLeq;
  final double maxLevel;
  final double minLevel;
  final int sampleCount;
  final List<double> samples;

  const _WindowStats({
    required this.averageLeq,
    required this.maxLevel,
    required this.minLevel,
    required this.sampleCount,
    required this.samples,
  });
}
