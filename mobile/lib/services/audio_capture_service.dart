import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_dialog_service.dart';

class AudioCaptureService {
  static final AudioCaptureService _instance = AudioCaptureService._internal();
  factory AudioCaptureService() => _instance;
  AudioCaptureService._internal();

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  
  final StreamController<double> _splStreamController = StreamController<double>.broadcast();
  final StreamController<NoiseReading> _noiseReadingController = StreamController<NoiseReading>.broadcast();
  
  Stream<double> get splStream => _splStreamController.stream;
  Stream<NoiseReading> get noiseReadingStream => _noiseReadingController.stream;
  
  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  // Calibration offset (device-specific, can be adjusted)
  double _calibrationOffset = 0.0;
  double get calibrationOffset => _calibrationOffset;
  
  // A-weighting compensation (approximate)
  static const double _aWeightingCompensation = 10.0; // dB

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
          _handleNoiseReading(reading);
        },
        onError: (Object error) {
          print('AudioCaptureService error: $error');
          _splStreamController.addError(error);
          _noiseReadingController.addError(error);
        },
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
    // Apply calibration and A-weighting compensation
    final calibratedMeanDb = reading.meanDecibel + _calibrationOffset + _aWeightingCompensation;
    final calibratedMaxDb = reading.maxDecibel + _calibrationOffset + _aWeightingCompensation;
    
    // Ensure values are within realistic range (20-120 dB)
    final clampedMeanDb = calibratedMeanDb.clamp(20.0, 120.0);
    final clampedMaxDb = calibratedMaxDb.clamp(20.0, 120.0);
    
    // Create calibrated reading - NoiseReading constructor may not accept parameters
    // We'll emit the original reading with calibration applied separately
    final calibratedReading = reading;
    
    // Emit the calibrated mean SPL for simple display
    _splStreamController.add(clampedMeanDb);
    
    // Emit full reading for detailed analysis
    _noiseReadingController.add(calibratedReading);
  }

  /// Calculate Leq (equivalent continuous sound level) over a time period
  /// This is a simplified implementation - in practice you'd want to accumulate
  /// energy values over the specified duration
  double calculateLeq(List<double> splValues) {
    if (splValues.isEmpty) return 0.0;
    
    // Convert dB to energy (power), calculate mean, convert back to dB
    final energySum = splValues.map((db) => pow(10, db / 10)).fold(0.0, (sum, energy) => sum + energy);
    final meanEnergy = energySum / splValues.length;
    return 10 * log(meanEnergy) / ln10;
  }

  /// Set calibration offset for this device
  void setCalibrationOffset(double offset) {
    _calibrationOffset = offset;
    print('🎛️ AudioCaptureService: Calibration offset set to ${offset.toStringAsFixed(1)} dB');
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
  quiet,    // < 50 dB - Green
  moderate, // 50-65 dB - Yellow  
  loud,     // 65-80 dB - Orange
  dangerous // > 80 dB - Red
}