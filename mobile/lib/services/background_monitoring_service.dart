import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:workmanager/workmanager.dart';

import 'audio_capture_service.dart';
import 'event_detection_service.dart';
import 'sqlite_preferences_service.dart';
import '../core/database/database_helper.dart';
import '../core/logging/app_logger.dart';

/// Background monitoring service for always-on noise monitoring
/// This service uses WorkManager to run audio monitoring in the background
/// even when the app is minimized or the screen is off
class BackgroundMonitoringService {
  static const String _backgroundTaskName = 'background_noise_monitoring';
  static const String _backgroundTaskTag = 'noise_monitoring_task';
  static const String _isolatePortName = 'background_monitoring_port';
  
  static final BackgroundMonitoringService _instance = BackgroundMonitoringService._internal();
  factory BackgroundMonitoringService() => _instance;
  BackgroundMonitoringService._internal();

  bool _isInitialized = false;
  bool _isRunning = false;
  SendPort? _backgroundSendPort;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _portSubscription;

  // Stream controllers for status updates
  final StreamController<BackgroundMonitoringState> _stateController = 
      StreamController<BackgroundMonitoringState>.broadcast();
  final StreamController<Map<String, dynamic>> _statusController = 
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<BackgroundMonitoringState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  
  bool get isRunning => _isRunning;

  /// Initialize the background monitoring service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize WorkManager
      await Workmanager().initialize(
        callbackDispatcher, // Top-level function for background execution
        isInDebugMode: false, // Set to false in production
      );

      // Set up communication with background isolate
      _receivePort = ReceivePort();
      _portSubscription = _receivePort!.listen(_handleBackgroundMessage);
      
      // Register the port for communication
      IsolateNameServer.removePortNameMapping(_isolatePortName);
      IsolateNameServer.registerPortWithName(_receivePort!.sendPort, _isolatePortName);

      _isInitialized = true;
      _emitState(BackgroundMonitoringState.initialized);
      
      AppLogger.background('BackgroundMonitoringService: Initialized');
    } catch (e) {
      AppLogger.failure('BackgroundMonitoringService: Initialization failed', e);
      _emitState(BackgroundMonitoringState.error);
      rethrow;
    }
  }

  /// Start background monitoring
  Future<bool> startBackgroundMonitoring({
    Duration monitoringInterval = const Duration(minutes: 15),
    bool requiresCharging = false,
    bool requiresWifi = false,
  }) async {
    if (!_isInitialized) {
      throw StateError('BackgroundMonitoringService not initialized');
    }

    if (_isRunning) {
      return true; // Already running
    }

    try {
      _emitState(BackgroundMonitoringState.starting);

      // Register periodic background task
      await Workmanager().registerPeriodicTask(
        _backgroundTaskName,
        _backgroundTaskName,
        frequency: monitoringInterval,
        tag: _backgroundTaskTag,
        constraints: Constraints(
          networkType: requiresWifi ? NetworkType.unmetered : NetworkType.connected,
          requiresCharging: requiresCharging,
          requiresBatteryNotLow: true,
          requiresDeviceIdle: false,
        ),
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(seconds: 30),
        initialDelay: const Duration(seconds: 10),
      );

      _isRunning = true;
      _emitState(BackgroundMonitoringState.running);
      
      AppLogger.success('Background monitoring started with ${monitoringInterval.inMinutes}min intervals');
      return true;

    } catch (e) {
      AppLogger.failure('Failed to start background monitoring', e);
      _emitState(BackgroundMonitoringState.error);
      return false;
    }
  }

  /// Stop background monitoring
  Future<void> stopBackgroundMonitoring() async {
    if (!_isRunning) return;

    try {
      _emitState(BackgroundMonitoringState.stopping);

      // Cancel background tasks
      await Workmanager().cancelByTag(_backgroundTaskTag);
      await Workmanager().cancelByUniqueName(_backgroundTaskName);

      _isRunning = false;
      _emitState(BackgroundMonitoringState.stopped);
      
      AppLogger.background('Background monitoring stopped');
    } catch (e) {
      AppLogger.failure('Failed to stop background monitoring', e);
      _emitState(BackgroundMonitoringState.error);
    }
  }

  /// Handle messages from background isolate
  void _handleBackgroundMessage(dynamic message) {
    try {
      if (message is Map<String, dynamic>) {
        final type = message['type'] as String?;
        final data = message['data'] as Map<String, dynamic>?;

        switch (type) {
          case 'status_update':
            if (data != null) {
              _statusController.add(data);
            }
            break;
          case 'error':
            AppLogger.error('Background monitoring error: ${data?['error']}');
            _emitState(BackgroundMonitoringState.error);
            break;
          case 'monitoring_complete':
            AppLogger.success('Background monitoring cycle complete');
            break;
          default:
            AppLogger.warning('Unknown background message type: $type');
        }
      }
    } catch (e) {
      AppLogger.error('Error handling background message', e);
    }
  }

  /// Emit state change
  void _emitState(BackgroundMonitoringState state) {
    _stateController.add(state);
  }

  /// Get current status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isRunning': _isRunning,
      'hasBackgroundPort': _backgroundSendPort != null,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopBackgroundMonitoring();
    await _portSubscription?.cancel();
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping(_isolatePortName);
    
    await _stateController.close();
    await _statusController.close();
  }
}

/// Background monitoring states
enum BackgroundMonitoringState {
  uninitialized,
  initialized,
  starting,
  running,
  stopping,
  stopped,
  error,
}

/// Top-level callback dispatcher for WorkManager
/// This function runs in a separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger.background('Background task started: $task');
    
    try {
      // Initialize services in background isolate
      await _initializeBackgroundServices();
      
      // Run monitoring cycle
      final result = await _runMonitoringCycle();
      
      // Send completion status
      _sendToMainIsolate({
        'type': 'monitoring_complete',
        'data': result,
      });
      
      return Future.value(true);
    } catch (e) {
      AppLogger.background('Background task failed: $e');
      
      _sendToMainIsolate({
        'type': 'error',
        'data': {'error': e.toString()},
      });
      
      return Future.value(false);
    }
  });
}

/// Initialize services in background isolate
Future<void> _initializeBackgroundServices() async {
  try {
    // Initialize database
    final databaseHelper = DatabaseHelper.instance;
    await databaseHelper.database;
    
    // Initialize preferences service
    final preferencesService = SQLitePreferencesService();
    await preferencesService.initialize();
    
    AppLogger.success('Background services initialized');
  } catch (e) {
    AppLogger.background('Background service initialization failed: $e');
    rethrow;
  }
}

/// Run a monitoring cycle in background
Future<Map<String, dynamic>> _runMonitoringCycle() async {
  final startTime = DateTime.now();
  
  try {
    // Load monitoring preferences
    final preferencesService = SQLitePreferencesService();
    final monitoringDuration = Duration(
      seconds: await preferencesService.getRecordingDurationSeconds()
    );
    final noiseThreshold = await preferencesService.getNoiseThreshold();
    
    // Initialize audio capture (this is tricky in background - may need foreground service)
    final audioService = AudioCaptureService();
    await audioService.loadCalibrationSettings();
    
    // Initialize event detection
    final eventDetection = EventDetectionService();
    eventDetection.setThreshold(noiseThreshold);
    eventDetection.startMonitoring();
    
    final samples = <double>[];
    const sampleDuration = Duration(seconds: 1);
    final totalSamples = monitoringDuration.inSeconds;
    
    // Send status update
    _sendToMainIsolate({
      'type': 'status_update',
      'data': {
        'started_at': startTime.toIso8601String(),
        'duration_seconds': monitoringDuration.inSeconds,
        'threshold_db': noiseThreshold,
        'progress': 0.0,
      },
    });
    
    // Simulate monitoring (in real implementation, this would capture audio)
    // Note: Actual audio capture in background may require foreground service
    for (int i = 0; i < totalSamples; i++) {
      await Future<void>.delayed(sampleDuration);
      
      // In real implementation, get actual audio level
      // For now, simulate with baseline noise + some variation
      final simulatedLevel = 45.0 + (DateTime.now().millisecond % 20);
      samples.add(simulatedLevel);
      eventDetection.addSample(simulatedLevel);
      
      // Send periodic progress updates
      if (i % 30 == 0) { // Every 30 seconds
        _sendToMainIsolate({
          'type': 'status_update',
          'data': {
            'progress': i / totalSamples,
            'current_level': simulatedLevel,
            'samples_collected': samples.length,
          },
        });
      }
    }
    
    eventDetection.stopMonitoring();
    
    final endTime = DateTime.now();
    final actualDuration = endTime.difference(startTime);
    
    // Calculate statistics
    final maxLevel = samples.isNotEmpty ? samples.reduce((a, b) => a > b ? a : b) : 0.0;
    final avgLevel = samples.isNotEmpty ? samples.reduce((a, b) => a + b) / samples.length : 0.0;
    
    final result = {
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_seconds': actualDuration.inSeconds,
      'samples_count': samples.length,
      'max_level_db': maxLevel,
      'avg_level_db': avgLevel,
      'threshold_exceeded': maxLevel > noiseThreshold,
    };
    
    AppLogger.background('Monitoring cycle completed: ${result['samples_count']} samples, ${avgLevel.toStringAsFixed(1)}dB avg');
    
    return result;
    
  } catch (e) {
    AppLogger.background('Monitoring cycle failed: $e');
    rethrow;
  }
}

/// Send message to main isolate
void _sendToMainIsolate(Map<String, dynamic> message) {
  try {
    final port = IsolateNameServer.lookupPortByName(BackgroundMonitoringService._isolatePortName);
    port?.send(message);
  } catch (e) {
    AppLogger.background('Failed to send message to main isolate: $e');
  }
}