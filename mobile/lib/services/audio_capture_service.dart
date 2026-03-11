import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/logging/app_logger.dart';
import 'permission_dialog_service.dart';
import 'sqlite_preferences_service.dart';
import 'audio_processing_service.dart';

class AudioCaptureService {
  static final AudioCaptureService _instance = AudioCaptureService._internal();
  factory AudioCaptureService() => _instance;
  AudioCaptureService._internal();

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  final StreamController<double> _splStreamController =
      StreamController<double>.broadcast();
  final StreamController<NoiseReading> _noiseReadingController =
      StreamController<NoiseReading>.broadcast();

  Stream<double> get splStream => _splStreamController.stream;
  Stream<NoiseReading> get noiseReadingStream => _noiseReadingController.stream;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  // Calibration offset (device-specific, can be adjusted)
  double _calibrationOffset = 0.0;
  double get calibrationOffset => _calibrationOffset;

  final SQLitePreferencesService _preferencesService =
      GetIt.instance<SQLitePreferencesService>();
  final AudioProcessingService _audioProcessing = AudioProcessingService();

  // Store recent measurements for enhanced processing
  final List<TimestampedSPL> _recentMeasurements = [];
  static const int _maxStoredMeasurements = 900; // 15 minutes at 1Hz

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission with dialog
  Future<bool> requestPermission(BuildContext context) async {
    final permissionService = PermissionDialogService();
    return await permissionService.requestMicrophonePermission(context);
  }

  /// Start capturing audio and calculating SPL
  Future<bool> startCapture({BuildContext? context}) async {
    try {
      // Check permission first
      if (!await hasPermission()) {
        if (context != null) {
          // Use dialog service if context is provided
          if (!await requestPermission(context)) {
            throw Exception('Microphone permission denied by user');
          }
        } else {
          // Fallback to basic permission request
          final status = await Permission.microphone.request();
          if (!status.isGranted) {
            throw Exception('Microphone permission denied');
          }
        }
      }

      if (_isCapturing) {
        return true; // Already capturing
      }

      _noiseMeter = NoiseMeter();

      _noiseSubscription = _noiseMeter!.noise.listen(
        (NoiseReading reading) {
          try {
            _handleNoiseReading(reading);
          } catch (e) {
            AppLogger.audio('Error handling noise reading: $e');
          }
        },
        onError: (Object error) {
          AppLogger.audio('AudioCaptureService stream error: $error');
          // Don't propagate errors to prevent crashes
          // _splStreamController.addError(error);
          // _noiseReadingController.addError(error);
        },
        cancelOnError: false, // Keep listening even if errors occur
      );

      _isCapturing = true;
      AppLogger.success('AudioCaptureService: Started capturing audio');
      return true;
    } catch (e) {
      AppLogger.audio('Failed to start audio capture: $e');
      _isCapturing = false;
      return false;
    }
  }

  /// Stop capturing audio
  Future<void> stopCapture() async {
    try {
      await _noiseSubscription?.cancel();
      _noiseSubscription = null;
      _noiseMeter = null;
      _isCapturing = false;
      AppLogger.success('AudioCaptureService: Stopped capturing audio');
    } catch (e) {
      AppLogger.audio('Error stopping audio capture: $e');
    }
  }

  /// Handle incoming noise readings
  void _handleNoiseReading(NoiseReading reading) {
    // Process readings immediately - StreamController is already thread-safe
    _processNoiseReading(reading);
  }

  /// Process noise reading with enhanced A-weighting
  void _processNoiseReading(NoiseReading reading) {
    try {
      // Apply device calibration
      final calibratedMeanDb = reading.meanDecibel + _calibrationOffset;

      // Enhanced A-weighting processing (simplified for noise_meter package)
      // The noise_meter package provides basic dB readings, we enhance with proper A-weighting
      final aWeightedDb = _applyEnhancedAWeighting(calibratedMeanDb);

      // Ensure values are within realistic range (10-140 dB)
      final clampedMeanDb = aWeightedDb.clamp(10.0, 140.0);

      // Store timestamped measurement for statistics
      final timestamped = TimestampedSPL(
        timestamp: DateTime.now(),
        splDb: clampedMeanDb,
      );
      _recentMeasurements.add(timestamped);

      // Maintain rolling window
      if (_recentMeasurements.length > _maxStoredMeasurements) {
        _recentMeasurements.removeAt(0);
      }

      // Safely emit the calibrated mean SPL for simple display
      if (!_splStreamController.isClosed) {
        _splStreamController.add(clampedMeanDb);
      }

      // Safely emit full reading for detailed analysis
      if (!_noiseReadingController.isClosed) {
        _noiseReadingController.add(reading);
      }
    } catch (e) {
      AppLogger.audio('Error in _processNoiseReading: $e');
    }
  }

  /// Apply enhanced A-weighting based on the measurement level
  double _applyEnhancedAWeighting(double rawDb) {
    // For broadband environmental noise, apply frequency-dependent A-weighting
    // This is an approximation since we don't have access to frequency spectrum
    // from the noise_meter package

    if (rawDb < 30) {
      // Very quiet - likely background noise (low frequency dominant)
      return rawDb - 8.0; // Strong A-weighting correction
    } else if (rawDb < 50) {
      // Quiet - typical indoor/suburban background
      return rawDb - 4.0; // Moderate A-weighting correction
    } else if (rawDb < 70) {
      // Moderate - speech, traffic at distance
      return rawDb - 2.0; // Light A-weighting correction
    } else if (rawDb < 90) {
      // Loud - traffic, machinery
      return rawDb - 1.0; // Minimal A-weighting correction
    } else {
      // Very loud - strong broadband content
      return rawDb; // Minimal correction for high-level sounds
    }
  }

  /// Calculate Leq (equivalent continuous sound level) over a time period
  double calculateLeq(List<double> splValues) {
    return _audioProcessing.calculateLeq(splValues);
  }

  /// Calculate Leq15 (15-minute equivalent level) for regulatory compliance
  double calculateLeq15() {
    return _audioProcessing.calculateLeq15(_recentMeasurements);
  }

  /// Get noise statistics for recent measurements
  NoiseStatistics getNoiseStatistics({Duration? timeWindow}) {
    final measurements = timeWindow != null
        ? _recentMeasurements
            .where((m) => m.timestamp.isAfter(DateTime.now().subtract(timeWindow)))
            .map((m) => m.splDb)
            .toList()
        : _recentMeasurements.map((m) => m.splDb).toList();

    return _audioProcessing.calculateNoiseStatistics(measurements);
  }

  /// Check for noise event detection
  bool detectNoiseEvent(double thresholdDb, {Duration minDuration = const Duration(seconds: 30)}) {
    if (_recentMeasurements.isEmpty) return false;

    final currentSPL = _recentMeasurements.last.splDb;
    return _audioProcessing.detectNoiseEvent(
      currentSPL: currentSPL,
      thresholdDb: thresholdDb,
      minDuration: minDuration,
      recentMeasurements: _recentMeasurements,
    );
  }

  /// Set calibration offset for this device
  void setCalibrationOffset(double offset) {
    _calibrationOffset = offset;
    // Also save to SQLite preferences
    _preferencesService.setCalibrationOffset(offset);
    AppLogger.audio(
        'Calibration offset set to ${offset.toStringAsFixed(1)} dB');
  }

  /// Load calibration offset from preferences on startup
  Future<void> loadCalibrationSettings() async {
    try {
      _calibrationOffset = await _preferencesService.getCalibrationOffset();
      AppLogger.audio(
          'Loaded calibration offset: ${_calibrationOffset.toStringAsFixed(1)} dB');
    } catch (e) {
      AppLogger.audio('Failed to load calibration settings: $e');
      _calibrationOffset = 0.0; // fallback to default
    }
  }

  /// Get color based on SPL level
  static NoiseLevel getNoiseLevelCategory(double spl) {
    if (spl < 50) return NoiseLevel.quiet;
    if (spl < 65) return NoiseLevel.moderate;
    if (spl < 80) return NoiseLevel.loud;
    return NoiseLevel.dangerous;
  }

  /// Cleanup resources
  void dispose() {
    stopCapture();
    _splStreamController.close();
    _noiseReadingController.close();
  }
}

/// Noise level categories for UI color coding
enum NoiseLevel {
  quiet, // < 50 dB - Green
  moderate, // 50-65 dB - Yellow
  loud, // 65-80 dB - Orange
  dangerous // > 80 dB - Red
}
