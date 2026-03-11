import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../core/logging/app_logger.dart';
import 'audio_capture_service.dart';
import 'event_detection_service.dart';

/// Service to manage Android foreground service for continuous noise monitoring
class AndroidForegroundService {
  static final AndroidForegroundService _instance = AndroidForegroundService._internal();
  factory AndroidForegroundService() => _instance;
  AndroidForegroundService._internal();

  static const MethodChannel _channel = MethodChannel('com.opennoisenet.mobile/noise_service');

  final AudioCaptureService _audioCapture = AudioCaptureService();
  final EventDetectionService _eventDetection = EventDetectionService();

  bool _isServiceRunning = false;
  StreamSubscription<double>? _splSubscription;
  Timer? _notificationUpdateTimer;

  /// Check if the service is currently running
  bool get isRunning => _isServiceRunning;

  /// Initialize the foreground service
  Future<bool> initialize() async {
    if (!Platform.isAndroid) {
      AppLogger.audio('Foreground service only available on Android');
      return false;
    }

    try {
      // Set up method channel handler for communication from Android service
      _channel.setMethodCallHandler(_handleMethodCall);

      AppLogger.success('Android foreground service initialized');
      return true;
    } catch (e) {
      AppLogger.audio('Failed to initialize Android foreground service: $e');
      return false;
    }
  }

  /// Start the foreground service for continuous monitoring
  Future<bool> startService() async {
    if (!Platform.isAndroid) return false;
    if (_isServiceRunning) return true;

    try {
      AppLogger.audio('Starting Android foreground service...');

      // Start the Android foreground service
      await _channel.invokeMethod('startService');

      // Start audio capture
      final audioStarted = await _audioCapture.startCapture();
      if (!audioStarted) {
        throw Exception('Failed to start audio capture');
      }

      // Start event detection
      await _eventDetection.startMonitoring(_audioCapture.splStream);

      // Subscribe to SPL updates for notification
      _splSubscription = _audioCapture.splStream.listen(_onSPLUpdate);

      // Start periodic notification updates
      _notificationUpdateTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _updateNotification(),
      );

      _isServiceRunning = true;
      AppLogger.success('Android foreground service started successfully');
      return true;

    } catch (e) {
      AppLogger.audio('Failed to start Android foreground service: $e');
      await stopService(); // Cleanup on failure
      return false;
    }
  }

  /// Stop the foreground service
  Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    if (!_isServiceRunning) return;

    try {
      AppLogger.audio('Stopping Android foreground service...');

      // Cancel timers and subscriptions
      _notificationUpdateTimer?.cancel();
      _notificationUpdateTimer = null;

      await _splSubscription?.cancel();
      _splSubscription = null;

      // Stop audio capture and event detection
      await _audioCapture.stopCapture();
      _eventDetection.stopMonitoring();

      // Stop the Android service
      await _channel.invokeMethod('stopService');

      _isServiceRunning = false;
      AppLogger.success('Android foreground service stopped');

    } catch (e) {
      AppLogger.audio('Error stopping Android foreground service: $e');
      _isServiceRunning = false; // Force reset state
    }
  }

  /// Handle method calls from Android service
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'startMonitoring':
        AppLogger.audio('Android service requested monitoring start');
        // Audio capture should already be running
        break;

      case 'stopMonitoring':
        AppLogger.audio('Android service requested monitoring stop');
        await stopService();
        break;

      case 'getServiceStatus':
        return {
          'isRunning': _isServiceRunning,
          'hasAudioPermission': await _audioCapture.hasPermission(),
        };

      default:
        AppLogger.audio('Unknown method call from Android service: ${call.method}');
    }
  }

  /// Handle SPL updates from audio capture
  void _onSPLUpdate(double spl) {
    // SPL updates are handled by the periodic notification update
    // This could be used for real-time processing if needed
  }

  /// Update the foreground service notification with current status
  Future<void> _updateNotification() async {
    if (!_isServiceRunning) return;

    try {
      // Get current noise statistics
      final stats = _audioCapture.getNoiseStatistics(
        timeWindow: const Duration(minutes: 1)
      );

      final currentSPL = stats.leq;
      final status = _getMonitoringStatus(currentSPL);

      // Update Android notification
      await _channel.invokeMethod('updateNotification', {
        'spl': currentSPL,
        'status': status,
        'leq15': _audioCapture.calculateLeq15(),
        'eventsDetected': _eventDetection.getRecentEventCount(),
      });

    } catch (e) {
      AppLogger.audio('Error updating notification: $e');
    }
  }

  /// Get monitoring status text based on current SPL
  String _getMonitoringStatus(double spl) {
    if (spl < 35) return 'Very Quiet';
    if (spl < 50) return 'Quiet';
    if (spl < 55) return 'Moderate';
    if (spl < 65) return 'Loud';
    if (spl < 75) return 'Very Loud';
    if (spl < 85) return 'Harmful';
    return 'Dangerous';
  }

  /// Request battery optimization exemption (Android 6+)
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod('requestBatteryOptimization');
      return result as bool? ?? false;
    } catch (e) {
      AppLogger.audio('Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  /// Check if battery optimization is disabled for the app
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return result as bool? ?? false;
    } catch (e) {
      AppLogger.audio('Error checking battery optimization status: $e');
      return false;
    }
  }

  /// Get service statistics
  Map<String, dynamic> getServiceStatistics() {
    return {
      'isRunning': _isServiceRunning,
      'platform': Platform.operatingSystem,
      'hasAudioCapture': _audioCapture.isCapturing,
      'hasEventDetection': _eventDetection.isMonitoring,
      'uptime': _isServiceRunning ? 'Active' : 'Stopped',
    };
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopService();
    AppLogger.audio('Android foreground service disposed');
  }
}
