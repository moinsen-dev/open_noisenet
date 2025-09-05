import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_dialog_service.dart';
import 'sqlite_preferences_service.dart';

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
  
  final SQLitePreferencesService _preferencesService = GetIt.instance<SQLitePreferencesService>();

  // A-weighting compensation (approximate)
  // This helps match readings with typical sound level meters and Apple Watch
  // Reduced from 10.0 to better match reference devices
  static const double _aWeightingCompensation = 5.0; // dB

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
            print('AudioCaptureService: Error handling noise reading - $e');
          }
        },
        onError: (Object error) {
          print('AudioCaptureService error: $error');
          // Don't propagate errors to prevent crashes
          // _splStreamController.addError(error);
          // _noiseReadingController.addError(error);
        },
        cancelOnError: false, // Keep listening even if errors occur
      );

      _isCapturing = true;
      print('✅ AudioCaptureService: Started capturing audio');
      return true;
    } catch (e) {
      print('❌ AudioCaptureService: Failed to start capture - $e');
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
      print('🛑 AudioCaptureService: Stopped capturing audio');
    } catch (e) {
      print('❌ AudioCaptureService: Error stopping capture - $e');
    }
  }

  /// Handle incoming noise readings
  void _handleNoiseReading(NoiseReading reading) {
    // Process readings immediately - StreamController is already thread-safe
    _processNoiseReading(reading);
  }

  /// Process noise reading on the main thread
  void _processNoiseReading(NoiseReading reading) {
    try {
      // Apply calibration and A-weighting compensation
      // This helps match readings with typical sound level meters and Apple Watch
      final calibratedMeanDb =
          reading.meanDecibel + _calibrationOffset + _aWeightingCompensation;

      // Ensure values are within realistic range (20-120 dB)
      final clampedMeanDb = calibratedMeanDb.clamp(20.0, 120.0);

      // Create calibrated reading - NoiseReading constructor may not accept parameters
      // We'll emit the original reading with calibration applied separately
      final calibratedReading = reading;

      // Safely emit the calibrated mean SPL for simple display
      if (!_splStreamController.isClosed) {
        _splStreamController.add(clampedMeanDb);
      }

      // Safely emit full reading for detailed analysis
      if (!_noiseReadingController.isClosed) {
        _noiseReadingController.add(calibratedReading);
      }
    } catch (e) {
      debugPrint('AudioCaptureService: Error in _processNoiseReading - $e');
    }
  }

  /// Calculate Leq (equivalent continuous sound level) over a time period
  /// This is a simplified implementation - in practice you'd want to accumulate
  /// energy values over the specified duration
  double calculateLeq(List<double> splValues) {
    if (splValues.isEmpty) return 0.0;

    // Convert dB to energy (power), calculate mean, convert back to dB
    final energySum = splValues
        .map((db) => pow(10, db / 10))
        .fold(0.0, (sum, energy) => sum + energy);
    final meanEnergy = energySum / splValues.length;
    return 10 * log(meanEnergy) / ln10;
  }

  /// Set calibration offset for this device
  void setCalibrationOffset(double offset) {
    _calibrationOffset = offset;
    // Also save to SQLite preferences
    _preferencesService.setCalibrationOffset(offset);
    debugPrint(
        '🎛️ AudioCaptureService: Calibration offset set to ${offset.toStringAsFixed(1)} dB');
  }

  /// Load calibration offset from preferences on startup
  Future<void> loadCalibrationSettings() async {
    try {
      _calibrationOffset = await _preferencesService.getCalibrationOffset();
      debugPrint(
          '🎛️ AudioCaptureService: Loaded calibration offset: ${_calibrationOffset.toStringAsFixed(1)} dB');
    } catch (e) {
      debugPrint('❌ AudioCaptureService: Failed to load calibration settings - $e');
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
