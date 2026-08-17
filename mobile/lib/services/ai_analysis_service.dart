import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'audio_extraction_service.dart';
import 'event_detection_service.dart';
import 'noise_pattern_analyzer.dart';
import 'audio_processing_service.dart';
import '../features/noise_monitoring/data/models/noise_event_model.dart';
import '../features/noise_monitoring/data/repositories/event_repository.dart';
import '../core/database/dao/audio_recording_dao.dart';
import '../core/logging/app_logger.dart';

/// Service that integrates continuous recording system with AI analysis capabilities
class AIAnalysisService {
  final NoisePatternAnalyzer _patternAnalyzer;
  final AudioExtractionService _extractionService = AudioExtractionService();
  final EventDetectionService _eventDetectionService = EventDetectionService();
  final AudioRecordingDao _audioRecordingDao = AudioRecordingDao();

  AIAnalysisService({
    required NoisePatternAnalyzer patternAnalyzer,
  }) : _patternAnalyzer = patternAnalyzer;

  // Analysis status tracking
  final Map<String, AnalysisStatus> _analysisQueue = {};
  final StreamController<AIAnalysisResult> _resultController =
      StreamController<AIAnalysisResult>.broadcast();

  Stream<AIAnalysisResult> get analysisResults => _resultController.stream;

  /// On-device LLM analysis (cactus) was removed; local rule-based analysis only.
  bool get hasAnalysisCapability => false;

  /// Initialize the AI analysis service.
  /// The on-device LLM (cactus) was removed; analysis uses local pattern rules.
  Future<bool> initialize() async {
    AppLogger.event('AI Analysis Service: on-device LLM unavailable, using local rule analysis');
    return false;
  }

  /// Queue an event for AI analysis
  Future<bool> queueEventForAnalysis({
    required NoiseEventModel event,
    AnalysisPriority priority = AnalysisPriority.normal,
    int bufferMs = 5000,
  }) async {
    try {
      final eventId = event.id ?? 'unknown_event';

      // Check if already in queue or analyzed
      if (_analysisQueue.containsKey(eventId)) {
        AppLogger.event('Event $eventId already in analysis queue');
        return false;
      }

      // Prepare event for analysis
      final analysisData = await _extractionService.prepareEventForAIAnalysis(
        event: event,
        bufferMs: bufferMs,
      );

      if (analysisData == null) {
        AppLogger.event('Failed to prepare event $eventId for AI analysis');
        return false;
      }

      // Add to analysis queue
      _analysisQueue[eventId] = AnalysisStatus(
        eventId: eventId,
        status: AnalysisState.queued,
        queuedAt: DateTime.now(),
        priority: priority,
        analysisData: analysisData,
      );

      AppLogger.event('Event $eventId queued for AI analysis');

      // Start processing immediately if possible
      _processAnalysisQueue();

      return true;
    } catch (e) {
      AppLogger.event('Error queuing event for analysis: $e');
      return false;
    }
  }

  /// Process events in the analysis queue
  Future<void> _processAnalysisQueue() async {
    final queuedEvents = _analysisQueue.entries
        .where((entry) => entry.value.status == AnalysisState.queued)
        .map((entry) => entry.value)
        .toList();

    if (queuedEvents.isEmpty) return;

    // Sort by priority and queue time
    queuedEvents.sort((a, b) {
      final priorityComparison = b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      return a.queuedAt.compareTo(b.queuedAt);
    });

    // Process the highest priority event
    final nextEvent = queuedEvents.first;
    await _processEvent(nextEvent);
  }

  /// Process a single event for AI analysis
  Future<void> _processEvent(AnalysisStatus analysisStatus) async {
    try {
      final eventId = analysisStatus.eventId;
      AppLogger.event('Starting AI analysis for event $eventId');

      // Update status to processing
      _analysisQueue[eventId] = analysisStatus.copyWith(
        status: AnalysisState.processing,
        processedAt: DateTime.now(),
      );

      // Simulate AI analysis process
      // In a real implementation, this would:
      // 1. Send audio file to AI service (local or remote)
      // 2. Perform sound classification
      // 3. Extract acoustic features
      // 4. Generate insights and recommendations

      final result = await _performAIAnalysis(analysisStatus.analysisData);

      // Update status to completed
      _analysisQueue[eventId] = analysisStatus.copyWith(
        status: AnalysisState.completed,
        completedAt: DateTime.now(),
        result: result,
      );

      // Emit result
      _resultController.add(result);

      AppLogger.event('AI analysis completed for event $eventId: ${result.classification}');

      // Process next event in queue
      await Future.delayed(const Duration(milliseconds: 100));
      _processAnalysisQueue();

    } catch (e) {
      AppLogger.event('Error processing AI analysis: $e');

      // Mark as failed
      _analysisQueue[analysisStatus.eventId] = analysisStatus.copyWith(
        status: AnalysisState.failed,
        error: e.toString(),
      );
    }
  }

  /// Perform the actual analysis. The on-device LLM (cactus) was removed;
  /// analysis now combines local pattern analysis with rule-based fallback.
  Future<AIAnalysisResult> _performAIAnalysis(Map<String, dynamic> analysisData) async {
    final eventId = analysisData['eventId'] as String;
    final extractedAudioPath = analysisData['extractedAudioPath'] as String?;

    try {
      // Extract measurement data and analyze patterns locally
      final eventMetrics = analysisData['eventMetrics'] as Map<String, dynamic>? ?? {};
      final classification = analysisData['eventClassification'] as Map<String, dynamic>? ?? {};
      final measurements = analysisData['measurements'] as List<TimestampedSPL>? ?? [];

      final patternData = _patternAnalyzer.analyzePattern(
        measurements: measurements,
        eventStart: DateTime.now().subtract(Duration(seconds: (eventMetrics['durationSeconds'] as int?) ?? 0)),
        eventEnd: DateTime.now(),
      );

      final leqDb = eventMetrics['leqDb'] as double? ?? 50.0;
      final intensityClass = classification['intensityClass'] as String? ?? 'moderate';

      return AIAnalysisResult(
        eventId: eventId,
        classification: 'general_noise_fallback',
        confidence: 0.3,
        insights: {
          'likely_source': 'Unable to determine - AI analysis unavailable',
          'impact_level': intensityClass,
          'recommendation': 'Manual review recommended',
          'acoustic_features': ['fallback_analysis'],
          'regulatory_context': 'Standard noise ordinance applies',
          'leq_db': leqDb,
          'pattern_analysis': patternData['pattern_summary'],
          'analysis_method': 'local_pattern_rules',
        },
        processedAt: DateTime.now(),
        analysisVersion: '2.0-local-rules',
        extractedAudioPath: extractedAudioPath,
      );
    } catch (e) {
      AppLogger.event('AI analysis failed for event $eventId, using fallback: $e');
      return _createFallbackAnalysis(eventId, analysisData, extractedAudioPath);
    }
  }

  /// Create fallback analysis when AI processing fails
  AIAnalysisResult _createFallbackAnalysis(
    String eventId,
    Map<String, dynamic> analysisData,
    String? extractedAudioPath
  ) {
    final metrics = analysisData['eventMetrics'] as Map<String, dynamic>? ?? {};
    final leqDb = metrics['leqDb'] as double? ?? 50.0;
    final classification = analysisData['eventClassification'] as Map<String, dynamic>? ?? {};
    final intensityClass = classification['intensityClass'] as String? ?? 'moderate';

    return AIAnalysisResult(
      eventId: eventId,
      classification: 'general_noise_fallback',
      confidence: 0.3,
      insights: {
        'likely_source': 'Unable to determine - AI analysis unavailable',
        'impact_level': intensityClass,
        'recommendation': 'Manual review recommended',
        'acoustic_features': ['fallback_analysis'],
        'regulatory_context': 'Standard noise ordinance applies',
        'leq_db': leqDb,
      },
      processedAt: DateTime.now(),
      analysisVersion: '2.0-fallback',
      extractedAudioPath: extractedAudioPath,
    );
  }

  /// Get time of day category for context
  String _getTimeOfDay(DateTime time) {
    final hour = time.hour;
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 22) return 'evening';
    return 'night';
  }

  /// Get analysis status for an event
  AnalysisStatus? getAnalysisStatus(String eventId) {
    return _analysisQueue[eventId];
  }

  /// Get all analysis results
  List<AnalysisStatus> getAllAnalysisStatuses() {
    return _analysisQueue.values.toList()
      ..sort((a, b) => b.queuedAt.compareTo(a.queuedAt));
  }

  /// Get recent AI analysis results
  Future<List<AIAnalysisResult>> getRecentResults({int limit = 20}) async {
    final completedAnalyses = _analysisQueue.values
        .where((status) => status.result != null)
        .map((status) => status.result!)
        .toList();

    // Sort by processed time (newest first)
    completedAnalyses.sort((a, b) => b.processedAt.compareTo(a.processedAt));

    return completedAnalyses.take(limit).toList();
  }

  /// Clean up old analysis results
  Future<void> cleanupOldResults({int maxAgeHours = 48}) async {
    final cutoffTime = DateTime.now().subtract(Duration(hours: maxAgeHours));

    final keysToRemove = _analysisQueue.keys.where((key) {
      final analysis = _analysisQueue[key]!;
      return analysis.completedAt?.isBefore(cutoffTime) == true ||
             (analysis.status == AnalysisState.failed &&
              analysis.queuedAt.isBefore(cutoffTime));
    }).toList();

    for (final key in keysToRemove) {
      _analysisQueue.remove(key);
    }

    // Also clean up extracted audio files
    await _extractionService.cleanupOldExtractions(maxAgeHours: maxAgeHours);

    AppLogger.event('Cleaned up ${keysToRemove.length} old analysis results');
  }

  /// Get analysis statistics
  Map<String, dynamic> getAnalysisStats() {
    final statuses = _analysisQueue.values.toList();

    return {
      'total_analyses': statuses.length,
      'queued': statuses.where((s) => s.status == AnalysisState.queued).length,
      'processing': statuses.where((s) => s.status == AnalysisState.processing).length,
      'completed': statuses.where((s) => s.status == AnalysisState.completed).length,
      'failed': statuses.where((s) => s.status == AnalysisState.failed).length,
      'success_rate': statuses.isEmpty ? 0.0 :
        statuses.where((s) => s.status == AnalysisState.completed).length / statuses.length,
      'average_processing_time': _calculateAverageProcessingTime(statuses),
    };
  }

  double _calculateAverageProcessingTime(List<AnalysisStatus> statuses) {
    final completedAnalyses = statuses
        .where((s) => s.status == AnalysisState.completed &&
                      s.processedAt != null && s.completedAt != null)
        .toList();

    if (completedAnalyses.isEmpty) return 0.0;

    final totalMs = completedAnalyses
        .map((s) => s.completedAt!.difference(s.processedAt!).inMilliseconds)
        .fold<int>(0, (sum, duration) => sum + duration);

    return totalMs / completedAnalyses.length;
  }

  /// Dispose resources
  void dispose() {
    _resultController.close();
    _analysisQueue.clear();
  }
}

/// Analysis priority levels
enum AnalysisPriority {
  low,
  normal,
  high,
  urgent,
}

/// Analysis state tracking
enum AnalysisState {
  queued,
  processing,
  completed,
  failed,
}

/// Analysis status tracking
class AnalysisStatus {
  final String eventId;
  final AnalysisState status;
  final DateTime queuedAt;
  final DateTime? processedAt;
  final DateTime? completedAt;
  final AnalysisPriority priority;
  final Map<String, dynamic> analysisData;
  final AIAnalysisResult? result;
  final String? error;

  const AnalysisStatus({
    required this.eventId,
    required this.status,
    required this.queuedAt,
    this.processedAt,
    this.completedAt,
    required this.priority,
    required this.analysisData,
    this.result,
    this.error,
  });

  AnalysisStatus copyWith({
    String? eventId,
    AnalysisState? status,
    DateTime? queuedAt,
    DateTime? processedAt,
    DateTime? completedAt,
    AnalysisPriority? priority,
    Map<String, dynamic>? analysisData,
    AIAnalysisResult? result,
    String? error,
  }) {
    return AnalysisStatus(
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
      queuedAt: queuedAt ?? this.queuedAt,
      processedAt: processedAt ?? this.processedAt,
      completedAt: completedAt ?? this.completedAt,
      priority: priority ?? this.priority,
      analysisData: analysisData ?? this.analysisData,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

/// AI analysis result
class AIAnalysisResult {
  final String eventId;
  final String classification;
  final double confidence;
  final Map<String, dynamic> insights;
  final DateTime processedAt;
  final String analysisVersion;
  final String? extractedAudioPath;

  const AIAnalysisResult({
    required this.eventId,
    required this.classification,
    required this.confidence,
    required this.insights,
    required this.processedAt,
    required this.analysisVersion,
    this.extractedAudioPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'classification': classification,
      'confidence': confidence,
      'insights': insights,
      'processedAt': processedAt.toIso8601String(),
      'analysisVersion': analysisVersion,
      'extractedAudioPath': extractedAudioPath,
    };
  }

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AIAnalysisResult(
      eventId: json['eventId'] as String,
      classification: json['classification'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      insights: json['insights'] as Map<String, dynamic>,
      processedAt: DateTime.parse(json['processedAt'] as String),
      analysisVersion: json['analysisVersion'] as String,
      extractedAudioPath: json['extractedAudioPath'] as String?,
    );
  }

  @override
  String toString() {
    return 'AIAnalysisResult($eventId: $classification, confidence: ${(confidence * 100).toInt()}%)';
  }
}
