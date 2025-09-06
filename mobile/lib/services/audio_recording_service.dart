import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import '../core/database/models/audio_recording.dart';
import '../core/database/dao/audio_recording_dao.dart';
import '../core/database/models/ai_analysis_queue.dart';
import '../core/database/dao/ai_analysis_queue_dao.dart';
import '../core/logging/app_logger.dart';

enum RecordingState {
  stopped,
  recording,
  paused,
}

class AudioRecordingService {
  static final AudioRecordingService _instance = AudioRecordingService._internal();
  factory AudioRecordingService() => _instance;
  AudioRecordingService._internal();

  // Services
  late FlutterSoundRecorder _recorder;
  late just_audio.AudioPlayer _audioPlayer;
  final Uuid _uuid = const Uuid();
  final AudioRecordingDao _recordingDao = AudioRecordingDao();
  final AiAnalysisQueueDao _analysisQueueDao = AiAnalysisQueueDao();

  // Configuration
  static const int maxRecordings = 3; // Circular buffer size
  static const Duration recordingDuration = Duration(minutes: 15);
  static const int sampleRate = 44100;
  static const String audioFormat = 'wav';
  static const Duration retentionPeriod = Duration(days: 7);

  // State
  RecordingState _state = RecordingState.stopped;
  AudioRecording? _currentRecording;
  Timer? _recordingTimer;
  String? _recordingsDirectory;
  final Queue<AudioRecording> _activeRecordings = Queue<AudioRecording>();

  // Stream controllers
  final StreamController<RecordingState> _stateController = 
      StreamController<RecordingState>.broadcast();
  final StreamController<AudioRecording> _recordingCompletedController =
      StreamController<AudioRecording>.broadcast();

  // Getters
  RecordingState get state => _state;
  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<AudioRecording> get recordingCompletedStream => _recordingCompletedController.stream;
  bool get isRecording => _state == RecordingState.recording;
  bool get isPaused => _state == RecordingState.paused;
  bool get isStopped => _state == RecordingState.stopped;
  int get activeRecordingCount => _activeRecordings.length;

  /// Initialize the audio recording service
  Future<void> initialize() async {
    // Initialize flutter_sound recorder
    _recorder = FlutterSoundRecorder();
    await _recorder.openRecorder();

    // Initialize just_audio player
    _audioPlayer = just_audio.AudioPlayer();

    // Create recordings directory
    final appDir = await getApplicationDocumentsDirectory();
    _recordingsDirectory = path.join(appDir.path, 'recordings');
    await Directory(_recordingsDirectory!).create(recursive: true);

    // Load existing recordings from database
    await _loadActiveRecordings();

    // Clean up expired recordings on startup
    await _cleanupExpiredRecordings();
  }

  /// Start recording audio with optional event association
  Future<String?> startRecording({String? eventId}) async {
    try {
      // Check if we have recording permission
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw Exception('Microphone permission not granted');
      }

      // Stop current recording if any
      if (_state != RecordingState.stopped) {
        await stopRecording();
      }

      // Generate recording info
      final recordingId = _uuid.v4();
      final now = DateTime.now();
      final expiresAt = now.add(retentionPeriod);
      
      // Create filename with timestamp
      final dateFolder = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final recordingPath = path.join(
        _recordingsDirectory!,
        dateFolder,
        'recording_${recordingId}_${now.millisecondsSinceEpoch}.$audioFormat',
      );

      // Create directory if needed
      await Directory(path.dirname(recordingPath)).create(recursive: true);

      // Start recording using flutter_sound
      await _recorder.startRecorder(
        toFile: recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: sampleRate,
        bitRate: 128000,
      );

      // Create recording model
      _currentRecording = AudioRecording(
        id: recordingId,
        eventId: eventId,
        timestampStart: now.millisecondsSinceEpoch ~/ 1000,
        timestampEnd: now.add(recordingDuration).millisecondsSinceEpoch ~/ 1000,
        durationSeconds: recordingDuration.inSeconds,
        filePath: recordingPath,
        format: audioFormat,
        sampleRate: sampleRate,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        expiresAt: expiresAt.millisecondsSinceEpoch ~/ 1000,
      );

      // Update state
      _state = RecordingState.recording;
      _stateController.add(_state);

      // Set timer to automatically stop recording
      _recordingTimer = Timer(recordingDuration, () => stopRecording());

      AppLogger.recording('Started audio recording: $recordingId');
      return recordingId;

    } catch (e) {
      AppLogger.recording('Failed to start recording: $e');
      return null;
    }
  }

  /// Stop current recording
  Future<AudioRecording?> stopRecording() async {
    try {
      if (_state == RecordingState.stopped || _currentRecording == null) {
        return null;
      }

      // Stop the recorder
      final recordingPath = await _recorder.stopRecorder();
      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (recordingPath == null) {
        throw Exception('Recording path is null');
      }

      // Update recording with actual end time and file size
      final endTime = DateTime.now();
      final file = File(recordingPath);
      final fileSize = await file.exists() ? await file.length() : 0;

      final completedRecording = _currentRecording!.copyWith(
        timestampEnd: endTime.millisecondsSinceEpoch ~/ 1000,
        durationSeconds: endTime.difference(_currentRecording!.startDateTime).inSeconds,
        fileSize: fileSize,
      );

      // Store in database
      await _recordingDao.insert(completedRecording);

      // Add to circular buffer
      await _addToCircularBuffer(completedRecording);

      // Queue for AI analysis if enabled
      await _queueForAnalysis(completedRecording);

      // Update state
      _state = RecordingState.stopped;
      _stateController.add(_state);
      _recordingCompletedController.add(completedRecording);

      _currentRecording = null;

      AppLogger.recording('Completed recording: ${completedRecording.id}');
      return completedRecording;

    } catch (e) {
      AppLogger.recording('Failed to stop recording: $e');
      _state = RecordingState.stopped;
      _stateController.add(_state);
      _currentRecording = null;
      return null;
    }
  }

  /// Pause current recording
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) return;

    try {
      await _recorder.pauseRecorder();
      _recordingTimer?.cancel();
      _state = RecordingState.paused;
      _stateController.add(_state);
    } catch (e) {
      AppLogger.recording('Failed to pause recording: $e');
    }
  }

  /// Resume paused recording
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) return;

    try {
      await _recorder.resumeRecorder();
      
      // Restart timer with remaining duration
      if (_currentRecording != null) {
        final remainingDuration = _currentRecording!.endDateTime.difference(DateTime.now());
        if (remainingDuration.isNegative) {
          await stopRecording();
        } else {
          _recordingTimer = Timer(remainingDuration, () => stopRecording());
        }
      }

      _state = RecordingState.recording;
      _stateController.add(_state);
    } catch (e) {
      AppLogger.recording('Failed to resume recording: $e');
    }
  }

  /// Get all active recordings
  List<AudioRecording> getActiveRecordings() {
    return List<AudioRecording>.from(_activeRecordings);
  }

  /// Get recording by ID
  Future<AudioRecording?> getRecording(String id) async {
    return await _recordingDao.getById(id);
  }

  /// Delete a specific recording
  Future<bool> deleteRecording(String id) async {
    try {
      final recording = await _recordingDao.getById(id);
      if (recording == null) return false;

      // Delete file
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from database
      await _recordingDao.deleteById(id);

      // Remove from active recordings
      _activeRecordings.removeWhere((r) => r.id == id);

      // Delete analysis queue items
      await _analysisQueueDao.deleteByRecordingId(id);

      AppLogger.recording('Deleted recording: $id');
      return true;
    } catch (e) {
      AppLogger.recording('Failed to delete recording $id: $e');
      return false;
    }
  }

  /// Clean up expired recordings
  Future<int> cleanupExpiredRecordings() async {
    return await _cleanupExpiredRecordings();
  }

  /// Get storage information
  Future<Map<String, dynamic>> getStorageInfo() async {
    final stats = await _recordingDao.getStorageStats();
    final directory = Directory(_recordingsDirectory!);
    
    return {
      ...stats,
      'recordings_directory': _recordingsDirectory,
      'directory_exists': await directory.exists(),
      'active_recordings': _activeRecordings.length,
      'max_recordings': maxRecordings,
    };
  }

  /// Load active recordings from database on startup
  Future<void> _loadActiveRecordings() async {
    try {
      final recordings = await _recordingDao.getRecent(limit: maxRecordings);
      _activeRecordings.clear();
      _activeRecordings.addAll(recordings);
    } catch (e) {
      AppLogger.recording('Failed to load active recordings: $e');
    }
  }

  /// Add recording to circular buffer, removing oldest if necessary
  Future<void> _addToCircularBuffer(AudioRecording recording) async {
    _activeRecordings.add(recording);

    // Remove oldest recordings if we exceed the buffer size
    while (_activeRecordings.length > maxRecordings) {
      final oldest = _activeRecordings.removeFirst();
      await deleteRecording(oldest.id);
    }
  }

  /// Queue recording for AI analysis
  Future<void> _queueForAnalysis(AudioRecording recording) async {
    try {
      // Queue for noise classification
      final analysisItem = AiAnalysisQueue(
        recordingId: recording.id,
        analysisType: AnalysisType.noiseClassification,
        modelVersion: '1.0.0',
      );

      await _analysisQueueDao.insert(analysisItem);
      AppLogger.recording('Queued recording for AI analysis: ${recording.id}');
    } catch (e) {
      AppLogger.recording('Failed to queue for analysis: $e');
    }
  }

  /// Clean up expired recordings from database and filesystem
  Future<int> _cleanupExpiredRecordings() async {
    try {
      final expiredRecordings = await _recordingDao.getExpired();
      int deletedCount = 0;

      for (final recording in expiredRecordings) {
        if (await deleteRecording(recording.id)) {
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        AppLogger.recording('Cleaned up $deletedCount expired recordings');
      }

      return deletedCount;
    } catch (e) {
      AppLogger.recording('Failed to cleanup expired recordings: $e');
      return 0;
    }
  }

  /// Check if recording is supported
  Future<bool> isRecordingSupported() async {
    final permission = await Permission.microphone.status;
    return permission.isGranted;
  }

  /// Get current recording info
  AudioRecording? getCurrentRecording() {
    return _currentRecording;
  }

  /// Get recording amplitude (if recording)
  Future<double> getAmplitude() async {
    if (_state != RecordingState.recording) return 0.0;
    
    try {
      // flutter_sound doesn't provide real-time amplitude
      // We'll return a mock value for now
      return 0.5;
    } catch (e) {
      return 0.0;
    }
  }

  /// Play an audio recording
  Future<void> playRecording(AudioRecording recording) async {
    try {
      // Check if file exists
      final file = File(recording.filePath);
      if (!file.existsSync()) {
        throw Exception('Audio file not found: ${recording.filePath}');
      }

      // Check file size
      final fileSize = file.lengthSync();
      if (fileSize == 0) {
        throw Exception('Audio file is empty: ${recording.filePath}');
      }

      AppLogger.recording('Attempting to play: ${recording.filePath} ($fileSize bytes, ${recording.format})');

      // Stop any currently playing audio
      await _audioPlayer.stop();

      // Try to load and play the audio file with better error handling
      try {
        await _audioPlayer.setFilePath(recording.filePath);
        await _audioPlayer.play();
        AppLogger.recording('Successfully playing audio recording: ${recording.id}');
      } catch (platformException) {
        // If direct file path fails, try using setAudioSource with file URI
        AppLogger.recording('Direct file path failed, trying alternative method...');
        await _audioPlayer.setAudioSource(
          just_audio.AudioSource.uri(Uri.file(recording.filePath)),
        );
        await _audioPlayer.play();
        AppLogger.recording('Successfully playing audio recording (alternative method): ${recording.id}');
      }
    } catch (e) {
      AppLogger.recording('Failed to play recording ${recording.id}: $e');
      AppLogger.recording('File path: ${recording.filePath}');
      AppLogger.recording('File format: ${recording.format}');
      rethrow;
    }
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      AppLogger.recording('Failed to stop playback: $e');
    }
  }

  /// Check if audio is currently playing
  bool get isPlaying => _audioPlayer.playing;

  /// Get current playback position
  Stream<Duration> get playbackPositionStream => _audioPlayer.positionStream;

  /// Dispose of resources
  Future<void> dispose() async {
    _recordingTimer?.cancel();
    await _recorder.closeRecorder();
    await _audioPlayer.dispose();
    await _stateController.close();
    await _recordingCompletedController.close();
  }
}