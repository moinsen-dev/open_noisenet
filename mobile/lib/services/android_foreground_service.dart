import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/logging/app_logger.dart';

/// Keeps the Flutter-owned Android sensor pipeline in a visible microphone
/// foreground service while monitoring is active.
class AndroidForegroundService {
  static final AndroidForegroundService _instance =
      AndroidForegroundService._internal();
  factory AndroidForegroundService() => _instance;
  AndroidForegroundService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.opennoisenet.mobile/noise_service');

  bool _isServiceRunning = false;
  DateTime? _lastNotificationUpdateAt;
  final StreamController<void> _stopRequestController =
      StreamController<void>.broadcast();
  bool _methodHandlerRegistered = false;

  bool get isRunning => _isServiceRunning;
  Stream<void> get stopRequests => _stopRequestController.stream;

  Future<bool> initialize() async {
    if (!Platform.isAndroid) return false;
    try {
      if (!_methodHandlerRegistered) {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'stopMonitoring' &&
              !_stopRequestController.isClosed) {
            _stopRequestController.add(null);
          }
        });
        _methodHandlerRegistered = true;
      }
      _isServiceRunning =
          await _channel.invokeMethod<bool>('isServiceRunning') ?? false;
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Android foreground service initialization failed',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> consumeRestartRequest() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('consumeRestartRequest') ?? false;
  }

  Future<bool> startService({bool resumeOnly = false}) async {
    if (!Platform.isAndroid) return false;

    try {
      final started = await _channel.invokeMethod<bool>('startService', {
            'resumeOnly': resumeOnly,
          }) ??
          false;
      if (!started) return false;
      _isServiceRunning = true;
      _lastNotificationUpdateAt = null;
      AppLogger.success('Android microphone foreground service started');
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to start Android microphone foreground service',
        error,
        stackTrace,
      );
      _isServiceRunning = false;
      return false;
    }
  }

  Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    _lastNotificationUpdateAt = null;

    try {
      await _channel.invokeMethod<bool>('stopService');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to stop Android microphone foreground service',
        error,
        stackTrace,
      );
    } finally {
      _isServiceRunning = false;
    }
  }

  Future<bool> isNativeServiceRunning() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isServiceRunning') ?? false;
  }

  Future<void> updateReading(double spl) async {
    if (!_isServiceRunning) return;
    final now = DateTime.now();
    if (_lastNotificationUpdateAt != null &&
        now.difference(_lastNotificationUpdateAt!) <
            const Duration(seconds: 5)) {
      return;
    }
    _lastNotificationUpdateAt = now;
    try {
      await _channel.invokeMethod<bool>('updateNotification', {
        'spl': spl,
        'status': _getMonitoringStatus(spl),
      });
    } catch (error) {
      AppLogger.audio('Error updating Android sensor notification: $error');
    }
  }

  String _getMonitoringStatus(double spl) {
    if (spl < 35) return 'Very Quiet';
    if (spl < 50) return 'Quiet';
    if (spl < 55) return 'Moderate';
    if (spl < 65) return 'Loud';
    if (spl < 75) return 'Very Loud';
    if (spl < 85) return 'Harmful';
    return 'Dangerous';
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestBatteryOptimization') ??
          false;
    } catch (error) {
      AppLogger.audio(
          'Error requesting battery optimization exemption: $error');
      return false;
    }
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel
              .invokeMethod<bool>('isBatteryOptimizationDisabled') ??
          false;
    } catch (error) {
      AppLogger.audio('Error reading battery optimization status: $error');
      return false;
    }
  }

  Map<String, dynamic> getServiceStatistics() => {
        'isRunning': _isServiceRunning,
        'platform': Platform.operatingSystem,
        'uptime': _isServiceRunning ? 'Active' : 'Stopped',
      };

  Future<void> dispose() => stopService();
}
