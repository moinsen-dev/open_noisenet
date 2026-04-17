import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/logging/app_logger.dart';

/// Service to manage iOS background audio session for continuous noise monitoring
class IOSBackgroundService {
  static final IOSBackgroundService _instance =
      IOSBackgroundService._internal();
  factory IOSBackgroundService() => _instance;
  IOSBackgroundService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.opennoisenet.mobile/ios_background');

  bool _isBackgroundSessionActive = false;
  Timer? _backgroundTaskTimer;
  String? _currentBackgroundTaskId;
  int _backgroundTaskRenewalCount = 0;
  DateTime? _lastBackgroundTaskRenewedAt;

  /// Check if background session is active
  bool get isActive => _isBackgroundSessionActive;

  /// Initialize the iOS background service
  Future<bool> initialize() async {
    if (!Platform.isIOS) {
      AppLogger.audio('iOS background service only available on iOS');
      return false;
    }

    try {
      // Set up method channel handler
      _channel.setMethodCallHandler(_handleMethodCall);

      AppLogger.success('iOS background service initialized');
      return true;
    } catch (e) {
      AppLogger.audio('Failed to initialize iOS background service: $e');
      return false;
    }
  }

  /// Start background audio session for continuous monitoring
  Future<bool> startBackgroundSession() async {
    if (!Platform.isIOS) return false;
    if (_isBackgroundSessionActive) return true;

    try {
      AppLogger.audio('Starting iOS background audio session...');

      // Configure AVAudioSession for background recording
      final sessionConfigured = await _configureAudioSession();
      if (!sessionConfigured) {
        throw Exception('Failed to configure AVAudioSession');
      }

      // Start background task management
      await _startBackgroundTaskManagement();

      _isBackgroundSessionActive = true;
      AppLogger.success('iOS background audio session started');
      return true;
    } catch (e) {
      AppLogger.audio('Failed to start iOS background session: $e');
      await stopBackgroundSession();
      return false;
    }
  }

  /// Stop background audio session
  Future<void> stopBackgroundSession() async {
    if (!Platform.isIOS) return;
    if (!_isBackgroundSessionActive) return;

    try {
      AppLogger.audio('Stopping iOS background audio session...');

      // Cancel timers
      _backgroundTaskTimer?.cancel();
      _backgroundTaskTimer = null;

      // End background tasks
      await _endBackgroundTasks();

      // Deactivate audio session
      await _deactivateAudioSession();

      _isBackgroundSessionActive = false;
      AppLogger.success('iOS background audio session stopped');
    } catch (e) {
      AppLogger.audio('Error stopping iOS background session: $e');
      _isBackgroundSessionActive = false;
    }
  }

  /// Configure AVAudioSession for background recording
  Future<bool> _configureAudioSession() async {
    try {
      final result = await _channel.invokeMethod('configureAudioSession');

      return result as bool? ?? false;
    } catch (e) {
      AppLogger.audio('Error configuring audio session: $e');
      return false;
    }
  }

  /// Deactivate audio session
  Future<void> _deactivateAudioSession() async {
    try {
      await _channel.invokeMethod('deactivateAudioSession');
    } catch (e) {
      AppLogger.audio('Error deactivating audio session: $e');
    }
  }

  /// Start background task management to extend processing time
  Future<void> _startBackgroundTaskManagement() async {
    // Start a background task that renews itself periodically
    _backgroundTaskTimer = Timer.periodic(
      const Duration(seconds: 25), // Renew before 30-second limit
      (_) => _renewBackgroundTask(),
    );

    await _renewBackgroundTask();
  }

  /// Renew background task to extend processing time
  Future<void> _renewBackgroundTask() async {
    try {
      // End current background task if exists
      if (_currentBackgroundTaskId != null) {
        await _channel.invokeMethod('endBackgroundTask', {
          'taskId': _currentBackgroundTaskId,
        });
      }

      // Start new background task
      final taskId = await _channel.invokeMethod('beginBackgroundTask', {
        'name': 'NoiseMonitoring',
        'expirationHandler': 'handleBackgroundTaskExpiration',
      });

      _currentBackgroundTaskId = taskId as String?;

      if (_currentBackgroundTaskId != null) {
        _backgroundTaskRenewalCount++;
        _lastBackgroundTaskRenewedAt = DateTime.now();
        AppLogger.audio('Background task renewed: $_currentBackgroundTaskId');
      }
    } catch (e) {
      AppLogger.audio('Error renewing background task: $e');
    }
  }

  /// End all background tasks
  Future<void> _endBackgroundTasks() async {
    try {
      if (_currentBackgroundTaskId != null) {
        await _channel.invokeMethod('endBackgroundTask', {
          'taskId': _currentBackgroundTaskId,
        });
        _currentBackgroundTaskId = null;
      }
    } catch (e) {
      AppLogger.audio('Error ending background tasks: $e');
    }
  }

  /// Handle method calls from iOS native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'audioSessionInterrupted':
        AppLogger.audio('Audio session interrupted');
        await _handleAudioInterruption(call.arguments);
        break;

      case 'audioSessionResumed':
        AppLogger.audio('Audio session resumed');
        await _handleAudioResumption();
        break;

      case 'backgroundTaskExpiring':
        AppLogger.audio('Background task expiring, renewing...');
        await _renewBackgroundTask();
        break;

      case 'appWillEnterBackground':
        AppLogger.audio('App entering background');
        await _optimizeForBackground();
        break;

      case 'appDidBecomeActive':
        AppLogger.audio('App became active');
        await _optimizeForForeground();
        break;

      default:
        AppLogger.audio('Unknown iOS method call: ${call.method}');
    }
  }

  /// Handle audio session interruption
  Future<void> _handleAudioInterruption(dynamic arguments) async {
    final type = arguments['type'] as String?;

    if (type == 'began') {
      AppLogger.audio('Audio interruption began');
    } else if (type == 'ended') {
      AppLogger.audio('Audio interruption ended');
      final shouldResume = arguments['shouldResume'] as bool? ?? false;

      if (shouldResume && _isBackgroundSessionActive) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _configureAudioSession();
      }
    }
  }

  /// Handle audio session resumption
  Future<void> _handleAudioResumption() async {
    if (_isBackgroundSessionActive) {
      await _configureAudioSession();
    }
  }

  /// Optimize processing for background mode
  Future<void> _optimizeForBackground() async {
    // Reduce processing frequency in background
    // The audio capture will continue but we can reduce other operations
    AppLogger.audio('Optimizing for background mode');
  }

  /// Optimize processing for foreground mode
  Future<void> _optimizeForForeground() async {
    // Resume full processing in foreground
    AppLogger.audio('Optimizing for foreground mode');
  }

  /// Request background app refresh permission
  Future<bool> requestBackgroundAppRefresh() async {
    try {
      final result = await _channel.invokeMethod('requestBackgroundAppRefresh');
      return result as bool? ?? false;
    } catch (e) {
      AppLogger.audio('Error requesting background app refresh: $e');
      return false;
    }
  }

  /// Check background app refresh status
  Future<String> getBackgroundAppRefreshStatus() async {
    try {
      final result =
          await _channel.invokeMethod('getBackgroundAppRefreshStatus');
      return result as String? ?? 'unknown';
    } catch (e) {
      AppLogger.audio('Error checking background app refresh status: $e');
      return 'unknown';
    }
  }

  /// Get iOS-specific limitations and recommendations
  Map<String, dynamic> getIOSLimitations() {
    return {
      'background_time_limit': '30 seconds (renewable)',
      'audio_session': 'Can record in background with proper configuration',
      'battery_impact': 'Moderate - continuous microphone access',
      'user_permissions': 'Requires microphone and background app refresh',
      'system_interruptions': 'Phone calls and other audio apps will interrupt',
      'app_store_review':
          'May require additional justification for background audio',
      'recommendations': [
        'Inform users about battery usage',
        'Provide clear privacy policy for audio recording',
        'Implement intelligent duty cycling to conserve battery',
        'Handle audio session interruptions gracefully',
      ],
    };
  }

  /// Get service statistics
  Map<String, dynamic> getServiceStatistics() {
    return {
      'isActive': _isBackgroundSessionActive,
      'platform': Platform.operatingSystem,
      'currentBackgroundTask': _currentBackgroundTaskId,
      'backgroundTaskTimer': _backgroundTaskTimer?.isActive ?? false,
      'backgroundTaskRenewalCount': _backgroundTaskRenewalCount,
      'lastBackgroundTaskRenewedAt':
          _lastBackgroundTaskRenewedAt?.toIso8601String(),
    };
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopBackgroundSession();
    AppLogger.audio('iOS background service disposed');
  }
}
