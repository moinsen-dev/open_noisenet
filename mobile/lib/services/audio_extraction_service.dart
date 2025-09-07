import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;

import '../core/database/dao/audio_recording_dao.dart';
import '../core/database/models/audio_recording.dart';
import '../features/noise_monitoring/data/models/noise_event_model.dart';
import '../core/logging/app_logger.dart';

/// Service for extracting audio segments from continuous recordings for AI analysis
class AudioExtractionService {
  static final AudioExtractionService _instance = AudioExtractionService._internal();
  factory AudioExtractionService() => _instance;
  AudioExtractionService._internal();

  final AudioRecordingDao _audioRecordingDao = AudioRecordingDao();

  /// Extract audio segment from continuous recording for a given event
  /// Returns the path to the extracted audio file
  Future<String?> extractEventAudio({
    required NoiseEventModel event,
    int bufferMs = 5000, // 5 seconds buffer before and after event
    String outputFormat = 'wav',
  }) async {
    try {
      // Check if event has recording reference
      if (event.recordingFileId == null || 
          event.recordingStartOffsetMs == null || 
          event.recordingEndOffsetMs == null) {
        AppLogger.event('Event has no recording reference: ${event.id}');
        return null;
      }

      // Get the continuous recording file
      final recording = await _audioRecordingDao.getById(event.recordingFileId!);
      if (recording == null) {
        AppLogger.event('Recording file not found: ${event.recordingFileId}');
        return null;
      }

      // Check if the recording file exists
      final recordingFile = File(recording.filePath);
      if (!await recordingFile.exists()) {
        AppLogger.event('Recording file does not exist: ${recording.filePath}');
        return null;
      }

      // Calculate extraction parameters
      final startTimeMs = (event.recordingStartOffsetMs! - bufferMs).clamp(0, recording.durationSeconds * 1000);
      final endTimeMs = (event.recordingEndOffsetMs! + bufferMs).clamp(0, recording.durationSeconds * 1000);
      final durationMs = endTimeMs - startTimeMs;

      if (durationMs <= 0) {
        AppLogger.event('Invalid extraction duration: ${durationMs}ms');
        return null;
      }

      // Generate output file path
      final outputPath = await _generateExtractionPath(
        event: event,
        format: outputFormat,
      );

      // Extract audio segment using FFmpeg (if available) or copy approach
      final success = await _extractAudioSegment(
        sourcePath: recording.filePath,
        outputPath: outputPath,
        startTimeMs: startTimeMs,
        durationMs: durationMs,
        format: outputFormat,
      );

      if (success) {
        AppLogger.event('Audio extracted for event ${event.id}: $outputPath');
        return outputPath;
      } else {
        AppLogger.event('Failed to extract audio for event ${event.id}');
        return null;
      }
    } catch (e) {
      AppLogger.event('Error extracting audio for event ${event.id}: $e');
      return null;
    }
  }

  /// Extract audio segment using available tools
  Future<bool> _extractAudioSegment({
    required String sourcePath,
    required String outputPath,
    required int startTimeMs,
    required int durationMs,
    required String format,
  }) async {
    try {
      // Method 1: Try using FFmpeg if available (most accurate)
      if (await _isFFmpegAvailable()) {
        return await _extractWithFFmpeg(
          sourcePath: sourcePath,
          outputPath: outputPath,
          startTimeMs: startTimeMs,
          durationMs: durationMs,
          format: format,
        );
      }

      // Method 2: Basic file copying (fallback for same format)
      if (format == 'wav' && path.extension(sourcePath).toLowerCase() == '.wav') {
        return await _extractWithFileCopy(
          sourcePath: sourcePath,
          outputPath: outputPath,
          startTimeMs: startTimeMs,
          durationMs: durationMs,
        );
      }

      AppLogger.event('No suitable extraction method available');
      return false;
    } catch (e) {
      AppLogger.event('Error in _extractAudioSegment: $e');
      return false;
    }
  }

  /// Extract using FFmpeg (most accurate method)
  Future<bool> _extractWithFFmpeg({
    required String sourcePath,
    required String outputPath,
    required int startTimeMs,
    required int durationMs,
    required String format,
  }) async {
    try {
      final startSeconds = startTimeMs / 1000.0;
      final durationSeconds = durationMs / 1000.0;

      // FFmpeg command to extract audio segment
      final result = await Process.run('ffmpeg', [
        '-i', sourcePath,
        '-ss', startSeconds.toStringAsFixed(3),
        '-t', durationSeconds.toStringAsFixed(3),
        '-c', 'copy', // Copy without re-encoding when possible
        '-y', // Overwrite output file
        outputPath,
      ]);

      if (result.exitCode == 0) {
        AppLogger.event('FFmpeg extraction successful');
        return true;
      } else {
        AppLogger.event('FFmpeg extraction failed: ${result.stderr}');
        return false;
      }
    } catch (e) {
      AppLogger.event('Error running FFmpeg: $e');
      return false;
    }
  }

  /// Extract using basic file operations (less accurate, for WAV files only)
  Future<bool> _extractWithFileCopy({
    required String sourcePath,
    required String outputPath,
    required int startTimeMs,
    required int durationMs,
  }) async {
    try {
      // This is a simplified approach for WAV files
      // In a real implementation, you'd need to:
      // 1. Parse WAV header
      // 2. Calculate byte offsets from time offsets
      // 3. Copy the appropriate portion of the file
      // 4. Update the WAV header with new duration

      // For now, we'll copy the entire file as a fallback
      // This is not ideal but ensures we don't lose the audio
      final sourceFile = File(sourcePath);
      final outputFile = File(outputPath);
      
      await sourceFile.copy(outputPath);
      
      AppLogger.event('File copy extraction completed (full file)');
      return true;
    } catch (e) {
      AppLogger.event('Error in file copy extraction: $e');
      return false;
    }
  }

  /// Check if FFmpeg is available on the system
  Future<bool> _isFFmpegAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Generate output file path for extracted audio
  Future<String> _generateExtractionPath({
    required NoiseEventModel event,
    required String format,
  }) async {
    // Create extractions directory if it doesn't exist
    final extractionsDir = Directory('/data/user/0/com.example.open_noisenet/app_flutter/extractions');
    if (!await extractionsDir.exists()) {
      await extractionsDir.create(recursive: true);
    }

    // Generate unique filename
    final timestamp = event.timestampStart.toIso8601String().replaceAll(':', '-');
    final filename = 'event_${event.id}_${timestamp}.$format';
    
    return path.join(extractionsDir.path, filename);
  }

  /// Get extraction info for an event without actually extracting
  Future<Map<String, dynamic>?> getExtractionInfo(NoiseEventModel event) async {
    try {
      if (event.recordingFileId == null) return null;

      final recording = await _audioRecordingDao.getById(event.recordingFileId!);
      if (recording == null) return null;

      final recordingFile = File(recording.filePath);
      final fileExists = await recordingFile.exists();

      return {
        'hasRecordingReference': true,
        'recordingFileId': event.recordingFileId,
        'recordingFilePath': recording.filePath,
        'recordingFileExists': fileExists,
        'startOffsetMs': event.recordingStartOffsetMs,
        'endOffsetMs': event.recordingEndOffsetMs,
        'eventDurationMs': (event.recordingEndOffsetMs ?? 0) - (event.recordingStartOffsetMs ?? 0),
        'recordingDurationSeconds': recording.durationSeconds,
        'extractable': fileExists && event.recordingStartOffsetMs != null && event.recordingEndOffsetMs != null,
      };
    } catch (e) {
      AppLogger.event('Error getting extraction info: $e');
      return null;
    }
  }

  /// Clean up old extracted files
  Future<void> cleanupOldExtractions({int maxAgeHours = 24}) async {
    try {
      final extractionsDir = Directory('/data/user/0/com.example.open_noisenet/app_flutter/extractions');
      if (!await extractionsDir.exists()) return;

      final cutoffTime = DateTime.now().subtract(Duration(hours: maxAgeHours));
      
      await for (final entity in extractionsDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            await entity.delete();
            AppLogger.event('Deleted old extraction: ${entity.path}');
          }
        }
      }
    } catch (e) {
      AppLogger.event('Error cleaning up extractions: $e');
    }
  }

  /// Get list of available extracted files
  Future<List<Map<String, dynamic>>> getExtractedFiles() async {
    try {
      final extractionsDir = Directory('/data/user/0/com.example.open_noisenet/app_flutter/extractions');
      if (!await extractionsDir.exists()) return [];

      final files = <Map<String, dynamic>>[];
      
      await for (final entity in extractionsDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add({
            'path': entity.path,
            'name': path.basename(entity.path),
            'size': stat.size,
            'modified': stat.modified,
            'sizeFormatted': _formatFileSize(stat.size),
          });
        }
      }

      // Sort by modification time (newest first)
      files.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
      
      return files;
    } catch (e) {
      AppLogger.event('Error listing extracted files: $e');
      return [];
    }
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Prepare event for AI analysis by extracting audio and returning metadata
  Future<Map<String, dynamic>?> prepareEventForAIAnalysis({
    required NoiseEventModel event,
    int bufferMs = 5000,
    String outputFormat = 'wav',
  }) async {
    try {
      // Get extraction info first
      final extractionInfo = await getExtractionInfo(event);
      if (extractionInfo == null || extractionInfo['extractable'] != true) {
        return null;
      }

      // Extract the audio
      final extractedPath = await extractEventAudio(
        event: event,
        bufferMs: bufferMs,
        outputFormat: outputFormat,
      );

      if (extractedPath == null) return null;

      // Return comprehensive metadata for AI analysis
      return {
        'eventId': event.id,
        'extractedAudioPath': extractedPath,
        'eventClassification': {
          'type': event.eventType,
          'confidence': event.eventConfidence,
          'durationClass': event.durationClass,
          'intensityClass': event.intensityClass,
        },
        'eventMetrics': {
          'leqDb': event.leqDb,
          'lmaxDb': event.lmaxDb,
          'lminDb': event.lminDb,
          'duration': event.duration.inSeconds,
          'samplesCount': event.samplesCount,
        },
        'extractionParams': {
          'bufferMs': bufferMs,
          'format': outputFormat,
          'startOffsetMs': event.recordingStartOffsetMs,
          'endOffsetMs': event.recordingEndOffsetMs,
        },
        'location': event.hasLocation ? {
          'lat': event.locationLat,
          'lng': event.locationLng,
          'accuracy': event.locationAccuracy,
          'source': event.locationSource,
        } : null,
        'timestamp': event.timestampStart.toIso8601String(),
        'readyForAIAnalysis': true,
      };
    } catch (e) {
      AppLogger.event('Error preparing event for AI analysis: $e');
      return null;
    }
  }
}