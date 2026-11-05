import 'dart:async';
import 'dart:math';

import 'package:audio_streamer/audio_streamer.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/logging/app_logger.dart';
import 'permission_dialog_service.dart';
import 'sqlite_preferences_service.dart';
import 'audio_processing_service.dart';
import 'buffer_level.dart';
import 'level_history.dart';
import 'sound_analysis/sound_analysis_models.dart';

class AudioCaptureService {
  static final AudioCaptureService _instance = AudioCaptureService._internal();
  factory AudioCaptureService() => _instance;
  AudioCaptureService._internal();

  static const int requestedSampleRate = 48000;

  final AudioStreamer _audioStreamer = AudioStreamer();
  StreamSubscription<List<double>>? _audioSubscription;

  final StreamController<double> _splStreamController =
      StreamController<double>.broadcast();
  final StreamController<NoiseReading> _noiseReadingController =
      StreamController<NoiseReading>.broadcast();
  final StreamController<PcmAudioFrame> _pcmFrameController =
      StreamController<PcmAudioFrame>.broadcast();

  Stream<double> get splStream => _splStreamController.stream;
  Stream<NoiseReading> get noiseReadingStream => _noiseReadingController.stream;
  Stream<PcmAudioFrame> get pcmFrameStream => _pcmFrameController.stream;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;
  DateTime? _lastSampleAt;
  int _capturedSampleCount = 0;
  int _restartCount = 0;
  DateTime? _lastRestartAt;
  int _actualSampleRate = requestedSampleRate;
  bool _actualSampleRateVerified = false;
  bool get actualSampleRateVerified => _actualSampleRateVerified;
  double _lastClippingRatio = 0;
  DateTime? get lastSampleAt => _lastSampleAt;
  int get capturedSampleCount => _capturedSampleCount;

  // Calibration offset (device-specific, can be adjusted)
  double _calibrationOffset = 0.0;
  double get calibrationOffset => _calibrationOffset;

  final SQLitePreferencesService _preferencesService =
      GetIt.instance<SQLitePreferencesService>();
  final AudioProcessingService _audioProcessing = AudioProcessingService();

  // PCM buffers arrive more often than once a second; retain by time.
  final LevelHistory _recentMeasurements = LevelHistory();

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
  Future<bool> startCapture(
      {BuildContext? context, bool allowPermissionPrompt = true}) async {
    try {
      // Check permission first
      if (!await hasPermission()) {
        if (!allowPermissionPrompt) return false;
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

      _actualSampleRateVerified = false;
      _audioStreamer.sampleRate = requestedSampleRate;
      _audioSubscription = _audioStreamer.audioStream.listen(
        (List<double> samples) {
          try {
            _handleAudioBuffer(samples);
          } catch (e) {
            AppLogger.audio('Error handling PCM audio buffer: $e');
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
      unawaited(_refreshActualSampleRate());
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
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      _isCapturing = false;
      AppLogger.success('AudioCaptureService: Stopped capturing audio');
    } catch (e) {
      AppLogger.audio('Error stopping audio capture: $e');
    }
  }

  /// Restart the microphone stream after an interruption or stalled stream.
  Future<bool> restartCapture({BuildContext? context}) async {
    AppLogger.warning('AudioCaptureService: Restarting audio capture');
    await stopCapture();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final restarted = await startCapture(context: context);
    if (restarted) {
      _restartCount++;
      _lastRestartAt = DateTime.now();
    }
    return restarted;
  }

  /// Fan out one microphone stream to level DSP and ephemeral model windows.
  void _handleAudioBuffer(List<double> samples) {
    if (samples.isEmpty) return;

    final capturedAt = DateTime.now();
    final immutableSamples = List<double>.unmodifiable(samples);
    _lastClippingRatio =
        samples.where((sample) => sample.abs() >= 0.98).length / samples.length;

    if (!_pcmFrameController.isClosed) {
      _pcmFrameController.add(PcmAudioFrame(
        samples: immutableSamples,
        sampleRate: _actualSampleRate,
        capturedAt: capturedAt,
      ));
    }

    _processAudioLevel(samples);

    // Legacy noise readings are peak-based and used only if a listener asks
    // for them; they do not feed the event or level calculations.
    if (_noiseReadingController.hasListener &&
        !_noiseReadingController.isClosed) {
      _noiseReadingController.add(NoiseReading(List<double>.from(samples)));
    }
  }

  Future<void> _refreshActualSampleRate() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final actual = await _audioStreamer.actualSampleRate;
        if (actual > 0) {
          _actualSampleRate = actual;
          _actualSampleRateVerified = true;
          AppLogger.audio(
            'AudioCaptureService: actual PCM rate is $_actualSampleRate Hz',
          );
          return;
        }
      } catch (e) {
        if (attempt == 3) {
          AppLogger.audio(
            'AudioCaptureService: could not read actual sample rate; '
            'using $requestedSampleRate Hz ($e)',
          );
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Process an unweighted PCM RMS estimate with the configured offset.
  void _processAudioLevel(List<double> samples) {
    try {
      // The library NoiseReading uses peak amplitudes, not RMS. A weighted
      // or calibrated pressure value cannot be inferred from that value.
      final clampedMeanDb =
          bufferLevelDb(samples, offsetDb: _calibrationOffset);
      if (clampedMeanDb == null) return;
      _lastSampleAt = DateTime.now();
      _capturedSampleCount++;

      // Store timestamped measurement for statistics
      final timestamped = TimestampedSPL(
        timestamp: DateTime.now(),
        splDb: clampedMeanDb,
      );
      _recentMeasurements.add(timestamped);

      // Safely emit the calibrated mean SPL for simple display
      if (!_splStreamController.isClosed) {
        _splStreamController.add(clampedMeanDb);
      }
    } catch (e) {
      AppLogger.audio('Error in _processAudioLevel: $e');
    }
  }

  /// Calculate Leq (equivalent continuous sound level) over a time period
  double calculateLeq(List<double> splValues) {
    return _audioProcessing.calculateLeq(splValues);
  }

  /// Estimate Leq over available samples in the last 15 minutes.
  double calculateLeq15() {
    return _audioProcessing.calculateLeq15(_recentMeasurements.samples);
  }

  /// Get noise statistics for recent measurements
  NoiseStatistics getNoiseStatistics({Duration? timeWindow}) {
    final measurements = timeWindow != null
        ? _recentMeasurements.samples
            .where(
                (m) => m.timestamp.isAfter(DateTime.now().subtract(timeWindow)))
            .map((m) => m.splDb)
            .toList()
        : _recentMeasurements.samples.map((m) => m.splDb).toList();

    return _audioProcessing.calculateNoiseStatistics(measurements);
  }

  /// Check for noise event detection
  bool detectNoiseEvent(double thresholdDb,
      {Duration minDuration = const Duration(seconds: 30)}) {
    if (_recentMeasurements.isEmpty) return false;

    final currentSPL = _recentMeasurements.last.splDb;
    return _audioProcessing.detectNoiseEvent(
      currentSPL: currentSPL,
      thresholdDb: thresholdDb,
      minDuration: minDuration,
      recentMeasurements: _recentMeasurements.samples,
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
    _pcmFrameController.close();
  }

  /// Runtime diagnostics for unattended sensor operation.
  Map<String, dynamic> getDiagnostics() {
    return {
      'isCapturing': _isCapturing,
      'capturedSampleCount': _capturedSampleCount,
      'restartCount': _restartCount,
      'lastRestartAt': _lastRestartAt?.toIso8601String(),
      'lastSampleAt': _lastSampleAt?.toIso8601String(),
      'requestedSampleRateHz': requestedSampleRate,
      'actualSampleRateHz': _actualSampleRate,
      'calibrationOffsetDb': _calibrationOffset,
      'levelQuality': _calibrationOffset == 0
          ? 'uncalibrated_estimate'
          : 'offset_adjusted_unverified',
      'lastClippingRatio': _lastClippingRatio,
      'timeSinceLastSampleMs': _lastSampleAt == null
          ? null
          : DateTime.now().difference(_lastSampleAt!).inMilliseconds,
    };
  }
}

/// Noise level categories for UI color coding
enum NoiseLevel {
  quiet, // < 50 dB - Green
  moderate, // 50-65 dB - Yellow
  loud, // 65-80 dB - Orange
  dangerous // > 80 dB - Red
}
