import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'location_service.dart';
import 'backend_sync_service.dart';
import 'recording_service.dart';
import '../core/database/dao/audio_recording_dao.dart';
import '../features/noise_monitoring/data/models/noise_event_model.dart';
import '../features/noise_monitoring/data/repositories/event_repository.dart';
import '../core/database/models/noise_measurement.dart';
import '../core/database/dao/noise_measurement_dao.dart';
import '../core/logging/app_logger.dart';
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
  BackendSyncService get _backendSync => GetIt.instance<BackendSyncService>();
  final RecordingService _recordingService = RecordingService();
  final AudioRecordingDao _audioRecordingDao = AudioRecordingDao();
  final Uuid _uuid = const Uuid();
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();

  // Configuration (will be moved to settings later)
  double _thresholdDb = 60.0;
  Duration _windowDuration = const Duration(minutes: 10);
  
  // Event merging configuration
  Duration _gracePeriod = const Duration(seconds: 30); // Grace period before ending event
  Duration _mergeWindow = const Duration(seconds: 30); // Window for merging nearby events
  
  // Event state tracking
  DateTime? _lastThresholdExceedance;
  Timer? _graceTimer;

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

    AppLogger.event(
        'EventDetectionService: Started monitoring with threshold $_thresholdDb dB');
  }

  /// Stop monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _minuteAggregationTimer?.cancel();
    _minuteAggregationTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;

    // Process any remaining minute data
    _processMinuteAggregation();

    // Finalize any current event
    if (_currentEvent != null) {
      _finalizeCurrentEvent();
    }

    _rollingWindow.clear();
    _minuteBuffer.clear();
    _lastThresholdExceedance = null;
    AppLogger.event('EventDetectionService: Stopped monitoring');
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
      AppLogger.event(
          'EventDetectionService: Threshold updated to $_thresholdDb dB');
    }
  }

  /// Update window duration
  void setWindowDuration(Duration duration) {
    if (duration != _windowDuration) {
      _windowDuration = duration;
      AppLogger.event(
          'EventDetectionService: Window duration updated to ${duration.inMinutes} minutes');
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

  /// Check if current window exceeds threshold and handle event logic with merging
  void _checkThresholdExceedance(_WindowStats stats, DateTime timestamp) {
    final exceedsThreshold = stats.averageLeq >= _thresholdDb;

    if (exceedsThreshold) {
      _lastThresholdExceedance = timestamp;
      
      // Cancel any existing grace timer since we have new exceedance
      _graceTimer?.cancel();
      _graceTimer = null;

      if (_currentEvent == null) {
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

        AppLogger.event(
            'Event started: ${stats.averageLeq.toStringAsFixed(1)} dB >= $_thresholdDb dB');
      } else {
        // Update ongoing event - extend and update statistics
        _currentEvent = NoiseEvent(
          startTime: _currentEvent!.startTime,
          endTime: timestamp,
          averageLeqDb: _calculateWeightedAverage(
            _currentEvent!.averageLeqDb, 
            stats.averageLeq,
            _currentEvent!.duration.inSeconds,
            stats.sampleCount
          ),
          maxLevelDb: max(_currentEvent!.maxLevelDb, stats.maxLevel),
          minLevelDb: min(_currentEvent!.minLevelDb, stats.minLevel),
          samples: _mergeRecentSamples(_currentEvent!.samples, stats.samples),
          ruleTriggered: _currentEvent!.ruleTriggered,
        );
      }
    } else if (!exceedsThreshold && _currentEvent != null) {
      // Start grace period timer if not already active
      if (_graceTimer == null) {
        _graceTimer = Timer(_gracePeriod, () {
          // Grace period expired, finalize event
          AppLogger.event(
              'Event ended after grace period: ${_currentEvent!.averageLeqDb.toStringAsFixed(1)} dB');
          _finalizeCurrentEvent();
          _graceTimer = null;
        });
        
        AppLogger.event(
            'Grace period started for event: ${_currentEvent!.averageLeqDb.toStringAsFixed(1)} dB');
      }
    }
  }

  /// Finalize and emit the current event with classification
  void _finalizeCurrentEvent() async {
    if (_currentEvent == null) return;

    // Classify event based on duration and characteristics
    final eventType = _classifyEvent(_currentEvent!);
    
    // Only emit events that meet minimum criteria
    if (_shouldEmitEvent(_currentEvent!, eventType)) {
      // Get current location for the event
      final location = await _locationService.getCurrentLocation();

      // Create a NoiseEventModel for storage/submission with enhanced metadata
      final eventModel = await _createNoiseEventModel(_currentEvent!, location, eventType);

      // Store the event in the database
      await _storeEvent(eventModel);

      _eventController.add(_currentEvent!);
      AppLogger.event('Event emitted [${eventType.type}]: ${_currentEvent!} with location');
    } else {
      AppLogger.event('Event discarded (too short): ${_currentEvent!}');
    }

    _currentEvent = null;
  }

  /// Create a NoiseEventModel from a NoiseEvent with location data and classification
  Future<NoiseEventModel> _createNoiseEventModel(
      NoiseEvent event, LocationData? location, EventClassification classification) async {
    final deviceId = Platform.isAndroid
        ? 'android-${_uuid.v4().substring(0, 8)}'
        : 'ios-${_uuid.v4().substring(0, 8)}';

    // Find the continuous recording file that contains this event
    final recordingRef = await _findContinuousRecordingForEvent(event);

    return NoiseEventModel.fromDetectedEvent(
      event,
      deviceId: deviceId,
      location: location,
      metadata: {
        'detection_service_version': '2.0',
        'platform': Platform.operatingSystem,
        'event_uuid': _uuid.v4(),
        'event_type': classification.type,
        'confidence': classification.confidence,
        'duration_classification': classification.durationClass,
        'intensity_classification': classification.intensityClass,
        'continuous_recording_ref': recordingRef != null ? 'linked' : 'not_found',
        'grace_period_used': _gracePeriod.inSeconds,
        'merge_window_used': _mergeWindow.inSeconds,
      },
    ).copyWith(
      // Add the continuous recording reference fields
      recordingFileId: recordingRef?['fileId'] as String?,
      recordingStartOffsetMs: recordingRef?['startOffsetMs'] as int?,
      recordingEndOffsetMs: recordingRef?['endOffsetMs'] as int?,
      eventType: classification.type,
      eventConfidence: classification.confidence,
      durationClass: classification.durationClass,
      intensityClass: classification.intensityClass,
    );
  }

  /// Store the event in the local database and submit to backend
  Future<void> _storeEvent(NoiseEventModel event) async {
    try {
      // Store locally first
      final repository = await EventRepository.getInstance();
      await repository.saveEvent(event);
      AppLogger.event('Event stored locally: ${event.id}');

      // Try to submit to backend
      await _submitEventToBackend(event);
    } catch (e) {
      AppLogger.event('Failed to store event: $e');
    }
  }

  /// Submit event to backend via BackendSyncService
  Future<void> _submitEventToBackend(NoiseEventModel event) async {
    try {
      final success = await _backendSync.submitNoiseEvent(
        timestampStart: event.timestampStart,
        timestampEnd: event.timestampEnd,
        leqDb: event.leqDb,
        lmaxDb: event.lmaxDb,
        lminDb: event.lminDb,
        laeqDb: event.laeqDb,
        exceedancePct: event.exceedancePct,
        samplesCount: event.samplesCount,
        ruleTriggered: event.ruleTriggered,
        locationLat: event.locationLat,
        locationLng: event.locationLng,
        eventMetadata: event.eventMetadata,
      );

      if (success) {
        AppLogger.event('Event successfully submitted to backend');
      } else {
        AppLogger.event('Event queued for later submission');
      }
    } catch (e) {
      AppLogger.event('Failed to submit event to backend: $e');
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
    final currentMinute =
        DateTime(now.year, now.month, now.day, now.hour, now.minute);

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
      final measurement =
          _createNoiseMeasurement(previousMinute, minuteSamples);

      // Store in database
      try {
        await _measurementDao.insert(measurement);
        AppLogger.event('Stored minute measurement: ${measurement.toString()}');
      } catch (e) {
        AppLogger.event('Failed to store minute measurement: $e');
      }
    }

    // Clean up processed samples from buffer
    _minuteBuffer.removeWhere(
        (sample) => sample.timestamp.millisecondsSinceEpoch < minuteEnd);

    _lastMinuteProcessed = currentMinute;
  }

  /// Create NoiseMeasurement from samples
  NoiseMeasurement _createNoiseMeasurement(
      DateTime timestamp, List<double> samples) {
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
    final l10Index =
        ((count - 1) * 0.9).round(); // 90th percentile (loud events)
    final l50Index = ((count - 1) * 0.5).round(); // 50th percentile (median)
    final l90Index =
        ((count - 1) * 0.1).round(); // 10th percentile (background)

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

  /// Get current window status with enhanced event tracking
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
      'gracePeriodActive': _graceTimer != null,
      'gracePeriodSeconds': _gracePeriod.inSeconds,
      'mergeWindowSeconds': _mergeWindow.inSeconds,
      'lastThresholdExceedance': _lastThresholdExceedance?.toIso8601String(),
    };
  }

  /// Calculate weighted average for merging events
  double _calculateWeightedAverage(double avg1, double avg2, int duration1, int samples2) {
    // Convert dB to energy for proper averaging
    final energy1 = pow(10, avg1 / 10) * duration1;
    final energy2 = pow(10, avg2 / 10) * samples2;
    final totalEnergy = energy1 + energy2;
    final totalTime = duration1 + samples2;
    return 10 * log(totalEnergy / totalTime) / ln10;
  }
  
  /// Merge recent samples for ongoing events (keep last N samples)
  List<double> _mergeRecentSamples(List<double> existing, List<double> newSamples) {
    final merged = List<double>.from(existing);
    merged.addAll(newSamples);
    // Keep only last 1000 samples to prevent memory issues
    if (merged.length > 1000) {
      return merged.sublist(merged.length - 1000);
    }
    return merged;
  }
  
  /// Classify event based on duration and characteristics
  EventClassification _classifyEvent(NoiseEvent event) {
    final duration = event.duration;
    final averageDb = event.averageLeqDb;
    final maxDb = event.maxLevelDb;
    final variability = maxDb - event.minLevelDb;
    
    String type;
    String durationClass;
    String intensityClass;
    double confidence = 0.8; // Base confidence
    
    // Classify by duration
    if (duration.inSeconds < 60) {
      durationClass = 'brief';
      type = 'brief_disturbance';
    } else if (duration.inMinutes < 15) {
      durationClass = 'short';
      type = variability > 10 ? 'intermittent_activity' : 'sustained_noise';
    } else if (duration.inMinutes < 60) {
      durationClass = 'medium';
      type = variability > 15 ? 'complex_event' : 'continuous_activity';
      confidence = 0.9; // Higher confidence for longer events
    } else {
      durationClass = 'extended';
      type = 'long_term_activity';
      confidence = 0.95; // Very high confidence for very long events
    }
    
    // Classify by intensity
    if (averageDb < 65) {
      intensityClass = 'moderate';
    } else if (averageDb < 80) {
      intensityClass = 'loud';
      confidence += 0.05; // Slightly more confident about loud events
    } else {
      intensityClass = 'very_loud';
      confidence += 0.1; // Much more confident about very loud events
    }
    
    return EventClassification(
      type: type,
      confidence: confidence.clamp(0.0, 1.0),
      durationClass: durationClass,
      intensityClass: intensityClass,
    );
  }
  
  /// Determine if event should be emitted based on classification
  bool _shouldEmitEvent(NoiseEvent event, EventClassification classification) {
    // Minimum duration: 30 seconds for brief events, 10 seconds for very loud events
    final minDuration = classification.intensityClass == 'very_loud' 
        ? const Duration(seconds: 10)
        : const Duration(seconds: 30);
    
    return event.duration >= minDuration;
  }
  
  /// Update grace period configuration
  void setGracePeriod(Duration period) {
    if (period != _gracePeriod) {
      _gracePeriod = period;
      AppLogger.event(
          'EventDetectionService: Grace period updated to ${period.inSeconds} seconds');
    }
  }
  
  /// Update merge window configuration
  void setMergeWindow(Duration window) {
    if (window != _mergeWindow) {
      _mergeWindow = window;
      AppLogger.event(
          'EventDetectionService: Merge window updated to ${window.inSeconds} seconds');
    }
  }
  
  /// Find the continuous recording file that contains this event
  Future<Map<String, dynamic>?> _findContinuousRecordingForEvent(NoiseEvent event) async {
    try {
      // Query the database for recordings that overlap with the event time
      final recordings = await _audioRecordingDao.getByTimeRange(
        startTimestamp: event.startTime.millisecondsSinceEpoch ~/ 1000 - 3600, // 1 hour buffer before
        endTimestamp: event.endTime.millisecondsSinceEpoch ~/ 1000 + 3600, // 1 hour buffer after
      );
      
      // Filter for continuous recordings only
      final continuousRecordings = recordings.where((r) => r.triggerType == 'continuous').toList();
      
      // Find the recording that contains the event
      for (final recording in continuousRecordings) {
        final recordingStart = DateTime.fromMillisecondsSinceEpoch(recording.timestampStart * 1000);
        final recordingEnd = DateTime.fromMillisecondsSinceEpoch(recording.timestampEnd * 1000);
        
        // Check if the event overlaps with this recording
        if (event.startTime.isAfter(recordingStart.subtract(const Duration(minutes: 1))) &&
            event.startTime.isBefore(recordingEnd.add(const Duration(minutes: 1)))) {
          
          // Calculate offsets in milliseconds from the start of the recording
          final startOffsetMs = event.startTime.difference(recordingStart).inMilliseconds;
          final endOffsetMs = event.endTime.difference(recordingStart).inMilliseconds;
          
          // Ensure offsets are within valid range
          final clampedStartOffsetMs = startOffsetMs.clamp(0, recording.durationSeconds * 1000);
          final clampedEndOffsetMs = endOffsetMs.clamp(0, recording.durationSeconds * 1000);
          
          return {
            'fileId': recording.id,
            'startOffsetMs': clampedStartOffsetMs,
            'endOffsetMs': clampedEndOffsetMs,
            'recordingFilePath': recording.filePath,
            'recordingDuration': recording.durationSeconds,
          };
        }
      }
      
      AppLogger.event('No continuous recording found for event: $event');
      return null;
    } catch (e) {
      AppLogger.event('Error finding continuous recording for event: $e');
      return null;
    }
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

class EventClassification {
  final String type;
  final double confidence;
  final String durationClass;
  final String intensityClass;

  const EventClassification({
    required this.type,
    required this.confidence,
    required this.durationClass,
    required this.intensityClass,
  });

  @override
  String toString() {
    return 'EventClassification(type: $type, confidence: ${confidence.toStringAsFixed(2)}, '
        'duration: $durationClass, intensity: $intensityClass)';
  }
}
