import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:get_it/get_it.dart';

import '../core/database/models/audio_recording.dart';
import '../core/database/dao/audio_recording_dao.dart';
import '../core/database/dao/ai_analysis_queue_dao.dart';
import '../core/database/models/ai_analysis_queue.dart';
import 'noise_event_detector.dart';
import 'sqlite_preferences_service.dart';

/// State of the continuous recording system
enum ContinuousRecordingState {
  stopped,    // Not recording
  starting,   // Initializing continuous recording
  active,     // Continuously recording with buffer rotation
  paused,     // Temporarily paused
  stopping,   // Shutting down
}

/// Continuous recording buffer entry
class RecordingBuffer {
  final String id;
  final DateTime startTime;
  final String filePath;
  final FlutterSoundRecorder recorder;
  bool isActive;
  Timer? durationTimer;
  
  RecordingBuffer({
    required this.id,
    required this.startTime,
    required this.filePath,
    required this.recorder,
    this.isActive = false,
  });
}

/// Continuous audio recording service with intelligent event detection
/// This service maintains a rolling buffer of audio recordings and automatically
/// captures significant noise events for analysis
class ContinuousRecordingService {
  static final ContinuousRecordingService _instance = ContinuousRecordingService._internal();
  factory ContinuousRecordingService() => _instance;
  ContinuousRecordingService._internal();

  // Services
  final Uuid _uuid = const Uuid();
  final AudioRecordingDao _recordingDao = AudioRecordingDao();
  final AiAnalysisQueueDao _analysisQueueDao = AiAnalysisQueueDao();
  final NoiseEventDetector _eventDetector = NoiseEventDetector();
  final SQLitePreferencesService _preferences = GetIt.instance<SQLitePreferencesService>();

  // Configuration
  static const int sampleRate = 44100;
  static const String audioFormat = 'wav';
  static const Duration retentionPeriod = Duration(days: 7);
  
  // Default settings (will be loaded from preferences)
  Duration _bufferDuration = const Duration(minutes: 15);
  Duration _overlapDuration = const Duration(minutes: 5);
  int _maxBuffers = 3;
  double _autoRecordThreshold = 65.0;
  bool _enableContinuousRecording = false;

  // State
  ContinuousRecordingState _state = ContinuousRecordingState.stopped;
  String? _recordingsDirectory;
  final Queue<RecordingBuffer> _activeBuffers = Queue<RecordingBuffer>();
  Timer? _bufferRotationTimer;
  StreamSubscription<NoiseEvent>? _eventSubscription;

  // Stream controllers
  final StreamController<ContinuousRecordingState> _stateController = 
      StreamController<ContinuousRecordingState>.broadcast();
  final StreamController<AudioRecording> _recordingCreatedController =
      StreamController<AudioRecording>.broadcast();
  final StreamController<Map<String, dynamic>> _statsController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  ContinuousRecordingState get state => _state;
  Stream<ContinuousRecordingState> get stateStream => _stateController.stream;
  Stream<AudioRecording> get recordingCreatedStream => _recordingCreatedController.stream;
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;
  bool get isActive => _state == ContinuousRecordingState.active;
  bool get isStopped => _state == ContinuousRecordingState.stopped;
  int get activeBufferCount => _activeBuffers.length;

  /// Initialize the continuous recording service
  Future<void> initialize() async {
    // Load settings from preferences
    await _loadSettings();
    
    // Configure noise event detector
    _eventDetector.configure(
      sustainedThreshold: _autoRecordThreshold,
    );

    // Create recordings directory
    final appDir = await getApplicationDocumentsDirectory();
    _recordingsDirectory = path.join(appDir.path, 'continuous_recordings');
    await Directory(_recordingsDirectory!).create(recursive: true);

    // Listen to noise events for auto-recording
    _eventSubscription = _eventDetector.eventStream.listen(_onNoiseEvent);

    // Clean up expired recordings on startup
    await _cleanupExpiredRecordings();
    
    print('🎤 ContinuousRecordingService: Initialized');
  }

  /// Load settings from preferences
  Future<void> _loadSettings() async {
    try {
      _bufferDuration = Duration(seconds: await _preferences.getRecordingDurationSeconds());
      _maxBuffers = await _preferences.getMaxRecordingsCount();
      _autoRecordThreshold = await _preferences.getNoiseThreshold();
      
      // Check if continuous recording is enabled (new setting) - default to true as this is our main functionality
      _enableContinuousRecording = await _preferences.getBool('continuous_recording_enabled', defaultValue: true);
      
      print('🔧 Continuous recording settings loaded - Duration: ${_bufferDuration}, Threshold: ${_autoRecordThreshold}dB');
    } catch (e) {
      print('❌ Failed to load continuous recording settings: $e');
    }
  }

  /// Start continuous recording
  Future<bool> startContinuousRecording() async {
    if (!_enableContinuousRecording) {
      print('⚠️ Continuous recording is disabled in settings');
      return false;
    }

    if (_state != ContinuousRecordingState.stopped) {
      return _state == ContinuousRecordingState.active;
    }

    try {
      // Check microphone permission
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw Exception('Microphone permission not granted');
      }

      _setState(ContinuousRecordingState.starting);

      // Create initial recording buffer
      await _createNewBuffer();

      // Start buffer rotation timer
      _bufferRotationTimer = Timer.periodic(_bufferDuration - _overlapDuration, (_) {
        _rotateBuffers();
      });

      _setState(ContinuousRecordingState.active);
      print('✅ Continuous recording started');
      return true;

    } catch (e) {
      print('❌ Failed to start continuous recording: $e');
      _setState(ContinuousRecordingState.stopped);
      return false;
    }
  }

  /// Stop continuous recording
  Future<void> stopContinuousRecording() async {
    if (_state == ContinuousRecordingState.stopped) return;

    _setState(ContinuousRecordingState.stopping);

    // Cancel buffer rotation
    _bufferRotationTimer?.cancel();
    _bufferRotationTimer = null;

    // Stop all active buffers
    for (final buffer in _activeBuffers) {
      await _stopBuffer(buffer, savePermanently: false);
    }
    _activeBuffers.clear();

    _setState(ContinuousRecordingState.stopped);
    print('🛑 Continuous recording stopped');
  }

  /// Create new recording buffer
  Future<void> _createNewBuffer() async {
    final bufferId = _uuid.v4();
    final now = DateTime.now();
    
    // Create filename with timestamp
    final dateFolder = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final bufferPath = path.join(
      _recordingsDirectory!,
      dateFolder,
      'buffer_${bufferId}_${now.millisecondsSinceEpoch}.$audioFormat',
    );

    // Create directory if needed
    await Directory(path.dirname(bufferPath)).create(recursive: true);

    // Create recorder
    final recorder = FlutterSoundRecorder();
    await recorder.openRecorder();

    // Start recording
    await recorder.startRecorder(
      toFile: bufferPath,
      codec: Codec.pcm16WAV,
      sampleRate: sampleRate,
      bitRate: 128000,
    );

    final buffer = RecordingBuffer(
      id: bufferId,
      startTime: now,
      filePath: bufferPath,
      recorder: recorder,
      isActive: true,
    );

    // Set timer to stop this buffer
    buffer.durationTimer = Timer(_bufferDuration, () => _stopBuffer(buffer));

    _activeBuffers.add(buffer);
    print('📼 Created new recording buffer: $bufferId');

    // Emit stats update
    _emitStatsUpdate();
  }

  /// Rotate buffers (start new buffer while keeping overlap)
  Future<void> _rotateBuffers() async {
    if (_state != ContinuousRecordingState.active) return;

    try {
      // Create new buffer
      await _createNewBuffer();

      // Clean up excess buffers
      while (_activeBuffers.length > _maxBuffers) {
        final oldestBuffer = _activeBuffers.removeFirst();
        await _stopBuffer(oldestBuffer, savePermanently: false);
      }

      print('🔄 Buffer rotation completed, active buffers: ${_activeBuffers.length}');
    } catch (e) {
      print('❌ Buffer rotation failed: $e');
    }
  }

  /// Stop a recording buffer
  Future<void> _stopBuffer(RecordingBuffer buffer, {bool savePermanently = false}) async {
    try {
      buffer.durationTimer?.cancel();
      
      if (buffer.isActive) {
        await buffer.recorder.stopRecorder();
        buffer.isActive = false;
      }
      
      await buffer.recorder.closeRecorder();

      if (!savePermanently) {
        // Delete temporary buffer file
        final file = File(buffer.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      print('🔚 Stopped buffer: ${buffer.id}${savePermanently ? ' (saved)' : ' (deleted)'}');
    } catch (e) {
      print('❌ Failed to stop buffer ${buffer.id}: $e');
    }
  }

  /// Handle noise event for auto-recording
  void _onNoiseEvent(NoiseEvent event) {
    if (_state != ContinuousRecordingState.active) return;

    // Check if this event warrants saving current buffer
    if (_shouldSaveForEvent(event)) {
      _saveCurrentBufferForEvent(event);
    }
  }

  /// Check if noise event warrants saving recording
  bool _shouldSaveForEvent(NoiseEvent event) {
    switch (event.type) {
      case NoiseEventType.spike:
        return event.level > _autoRecordThreshold + 10;
      case NoiseEventType.sustained:
        return event.duration > const Duration(minutes: 2);
      case NoiseEventType.pattern:
        return true; // Always interesting
      case NoiseEventType.quiet:
        return false; // Don't save quiet periods
    }
  }

  /// Save current buffer as permanent recording due to event
  Future<void> _saveCurrentBufferForEvent(NoiseEvent event) async {
    if (_activeBuffers.isEmpty) return;

    try {
      // Get the most recent buffer
      final buffer = _activeBuffers.last;
      
      // Stop the buffer and save it permanently
      await buffer.recorder.stopRecorder();
      buffer.isActive = false;
      
      // Create AudioRecording model
      final endTime = DateTime.now();
      final file = File(buffer.filePath);
      final fileSize = await file.exists() ? await file.length() : 0;
      
      final recording = AudioRecording(
        id: buffer.id,
        timestampStart: buffer.startTime.millisecondsSinceEpoch ~/ 1000,
        timestampEnd: endTime.millisecondsSinceEpoch ~/ 1000,
        durationSeconds: endTime.difference(buffer.startTime).inSeconds,
        filePath: buffer.filePath,
        fileSize: fileSize,
        format: audioFormat,
        sampleRate: sampleRate,
        createdAt: buffer.startTime.millisecondsSinceEpoch ~/ 1000,
        expiresAt: endTime.add(retentionPeriod).millisecondsSinceEpoch ~/ 1000,
        triggerType: event.type.name,
        peakLevel: event.level,
        avgLevel: _eventDetector.getCurrentStats()['avg_5min'] as double?,
        noiseEvents: _eventDetector.exportEventsAsJson(buffer.startTime, endTime),
        priority: _eventDetector.getRecordingPriority(),
      );

      // Save to database
      await _recordingDao.insert(recording);
      
      // Queue for AI analysis if high priority
      if (recording.priority >= 3) {
        await _queueForAnalysis(recording);
      }

      // Remove from active buffers and restart a new one
      _activeBuffers.removeLast();
      await _createNewBuffer();

      _recordingCreatedController.add(recording);
      print('💾 Saved event-triggered recording: ${recording.id} (${event.type.name})');

    } catch (e) {
      print('❌ Failed to save buffer for event: $e');
    }
  }

  /// Queue recording for AI analysis
  Future<void> _queueForAnalysis(AudioRecording recording) async {
    try {
      final analysisItem = AiAnalysisQueue(
        recordingId: recording.id,
        analysisType: AnalysisType.noiseClassification,
        modelVersion: '1.0.0',
      );

      await _analysisQueueDao.insert(analysisItem);
      print('📊 Queued high-priority recording for AI analysis: ${recording.id}');
    } catch (e) {
      print('❌ Failed to queue for analysis: $e');
    }
  }

  /// Force save current buffer manually
  Future<AudioRecording?> saveCurrentBuffer({String? eventId}) async {
    if (_activeBuffers.isEmpty || _state != ContinuousRecordingState.active) {
      return null;
    }

    try {
      final buffer = _activeBuffers.last;
      
      // Create a fake manual trigger event
      final manualEvent = NoiseEvent(
        timestamp: DateTime.now(),
        level: _eventDetector.getCurrentStats()['current_level'] as double? ?? 50.0,
        type: NoiseEventType.spike,
        duration: const Duration(seconds: 1),
        metadata: {'manual_trigger': true},
      );
      
      await _saveCurrentBufferForEvent(manualEvent);
      
      // Find the saved recording
      final recent = await _recordingDao.getRecent(limit: 1);
      return recent.isNotEmpty ? recent.first : null;

    } catch (e) {
      print('❌ Failed to manually save buffer: $e');
      return null;
    }
  }

  /// Add noise level measurement to event detector
  void addNoiseMeasurement(double level) {
    _eventDetector.addMeasurement(level);
    _emitStatsUpdate();
  }

  /// Emit statistics update
  void _emitStatsUpdate() {
    final eventStats = _eventDetector.getCurrentStats();
    final stats = {
      ...eventStats,
      'continuous_recording_active': isActive,
      'active_buffers': activeBufferCount,
      'buffer_duration_minutes': _bufferDuration.inMinutes,
      'auto_record_threshold': _autoRecordThreshold,
      'should_trigger_recording': _eventDetector.shouldTriggerRecording(),
      'recording_priority': _eventDetector.getRecordingPriority(),
    };
    
    _statsController.add(stats);
  }

  /// Update continuous recording settings
  Future<void> updateSettings({
    bool? enableContinuousRecording,
    Duration? bufferDuration,
    double? autoRecordThreshold,
    int? maxBuffers,
  }) async {
    bool needsRestart = false;

    if (enableContinuousRecording != null) {
      _enableContinuousRecording = enableContinuousRecording;
      await _preferences.setBool('continuous_recording_enabled', enableContinuousRecording, 
          description: 'Enable continuous recording with intelligent event detection');
    }

    if (bufferDuration != null && bufferDuration != _bufferDuration) {
      _bufferDuration = bufferDuration;
      await _preferences.setRecordingDurationSeconds(bufferDuration.inSeconds);
      needsRestart = true;
    }

    if (autoRecordThreshold != null && autoRecordThreshold != _autoRecordThreshold) {
      _autoRecordThreshold = autoRecordThreshold;
      await _preferences.setNoiseThreshold(autoRecordThreshold);
      _eventDetector.configure(sustainedThreshold: autoRecordThreshold);
    }

    if (maxBuffers != null && maxBuffers != _maxBuffers) {
      _maxBuffers = maxBuffers;
      await _preferences.setMaxRecordingsCount(maxBuffers);
    }

    // Restart continuous recording if needed and currently active
    if (needsRestart && isActive) {
      await stopContinuousRecording();
      await startContinuousRecording();
    }

    print('⚙️ Continuous recording settings updated');
  }

  /// Get current settings
  Map<String, dynamic> getSettings() {
    return {
      'enabled': _enableContinuousRecording,
      'buffer_duration_minutes': _bufferDuration.inMinutes,
      'auto_record_threshold': _autoRecordThreshold,
      'max_buffers': _maxBuffers,
      'overlap_duration_minutes': _overlapDuration.inMinutes,
    };
  }

  /// Clean up expired recordings
  Future<int> _cleanupExpiredRecordings() async {
    try {
      final expiredRecordings = await _recordingDao.getExpired();
      int deletedCount = 0;

      for (final recording in expiredRecordings) {
        final file = File(recording.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        await _recordingDao.deleteById(recording.id);
        deletedCount++;
      }

      if (deletedCount > 0) {
        print('🧹 Cleaned up $deletedCount expired continuous recordings');
      }

      return deletedCount;
    } catch (e) {
      print('❌ Failed to cleanup expired recordings: $e');
      return 0;
    }
  }

  /// Set state and notify listeners
  void _setState(ContinuousRecordingState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Get storage information
  Future<Map<String, dynamic>> getStorageInfo() async {
    final stats = await _recordingDao.getStorageStats();
    final directory = Directory(_recordingsDirectory!);
    
    return {
      ...stats,
      'continuous_recordings_directory': _recordingsDirectory,
      'directory_exists': await directory.exists(),
      'active_buffers': activeBufferCount,
      'settings': getSettings(),
    };
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopContinuousRecording();
    await _eventSubscription?.cancel();
    _eventDetector.dispose();
    await _stateController.close();
    await _recordingCreatedController.close();
    await _statsController.close();
  }
}

/// Extension for SQLitePreferencesService to handle missing bool method
extension ContinuousRecordingPreferences on SQLitePreferencesService {
  Future<bool> getBool(String key, {required bool defaultValue}) async {
    try {
      final value = await getRawPreference(key);
      if (value == null) return defaultValue;
      return value.toLowerCase() == 'true';
    } catch (e) {
      return defaultValue;
    }
  }

  Future<void> setBool(String key, bool value, {String? description}) async {
    await setRawPreference(key, value.toString(), 'boolean', description: description);
  }
}