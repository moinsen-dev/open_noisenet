import 'dart:async';

import 'package:get_it/get_it.dart';
import '../features/noise_monitoring/data/models/noise_event_model.dart';
import '../features/noise_monitoring/data/repositories/event_repository.dart';
import '../core/logging/app_logger.dart';
import 'backend_sync_service.dart';

class EventSubmissionService {
  static final EventSubmissionService _instance =
      EventSubmissionService._internal();
  factory EventSubmissionService() => _instance;
  EventSubmissionService._internal();

  final BackendSyncService _backendSync = GetIt.instance<BackendSyncService>();
  EventRepository? _eventRepository;
  Timer? _submissionTimer;
  bool _isSubmitting = false;

  // Configuration (will be moved to settings later)
  Duration _submissionInterval = const Duration(minutes: 5);
  int _maxRetries = 3;

  // Stream controllers for submission status
  final StreamController<SubmissionStatus> _statusController =
      StreamController<SubmissionStatus>.broadcast();

  Stream<SubmissionStatus> get statusStream => _statusController.stream;

  /// Initialize the service
  Future<void> initialize({
    Duration? submissionInterval,
    int? maxRetries,
  }) async {
    if (submissionInterval != null) _submissionInterval = submissionInterval;
    if (maxRetries != null) _maxRetries = maxRetries;

    _eventRepository = await EventRepository.getInstance();

    AppLogger.network(
        'EventSubmissionService initialized as BackendSyncService compatibility wrapper');
  }

  /// Start automatic submission of pending events
  void startAutoSubmission() {
    stopAutoSubmission();

    _submissionTimer = Timer.periodic(_submissionInterval, (_) async {
      await _submitPendingEvents();
    });

    // Submit immediately on start
    _submitPendingEvents();

    AppLogger.network(
        'Auto-submission started (every ${_submissionInterval.inMinutes} minutes)');
  }

  /// Stop automatic submission
  void stopAutoSubmission() {
    _submissionTimer?.cancel();
    _submissionTimer = null;
    AppLogger.network('Auto-submission stopped');
  }

  /// Submit a single event
  Future<SubmissionResult> submitEvent(NoiseEventModel event) async {
    if (_eventRepository == null) {
      throw Exception('EventSubmissionService not initialized');
    }

    try {
      final result = await _backendSync.submitNoiseEvent(
        eventUuid: event.eventUuid,
        timestampStart: event.timestampStart,
        timestampEnd: event.timestampEnd,
        leqDb: event.leqDb,
        lmaxDb: event.lmaxDb,
        lminDb: event.lminDb,
        laeqDb: event.laeqDb,
        exceedancePct: event.exceedancePct,
        samplesCount: event.samplesCount,
        ruleTriggered: event.ruleTriggered,
        locationLat: event.locationLat,
        locationLng: event.locationLng,
        eventMetadata: event.eventMetadata,
        classificationLabel: event.classificationLabel,
        classificationConfidence: event.classificationConfidence,
        classificationSource: event.classificationSource,
        segmentType: event.segmentType,
        reportabilityScore: event.reportabilityScore,
        reportabilityReason: event.reportabilityReason,
        peakToAverageDeltaDb: event.peakToAverageDeltaDb,
        variabilityDb: event.variabilityDb,
        thresholdExceedanceRatio: event.thresholdExceedanceRatio,
        analysisState: event.analysisState,
        analysisUpdatedAt: event.analysisUpdatedAt,
      );

      if (result.acknowledged || result.queued) {
        _statusController.add(SubmissionStatus.success(
          eventId: event.id ?? 'unknown',
          serverId: result.serverEventId,
          message: result.acknowledged
              ? 'Event submitted successfully'
              : 'Event queued for automatic retry',
        ));

        return SubmissionResult(
          success: result.acknowledged,
          serverId: result.serverEventId,
          statusCode: result.acknowledged ? 200 : 202,
        );
      }

      final errorMessage = 'Event was neither acknowledged nor queued';

      _statusController.add(SubmissionStatus.error(
        eventId: event.id ?? 'unknown',
        message: errorMessage,
      ));

      return SubmissionResult(
        success: false,
        error: errorMessage,
      );
    } catch (e) {
      final errorMessage = 'Unexpected error: $e';

      _statusController.add(SubmissionStatus.error(
        eventId: event.id ?? 'unknown',
        message: errorMessage,
      ));

      return SubmissionResult(
        success: false,
        error: errorMessage,
      );
    }
  }

  /// Submit all pending events
  Future<BatchSubmissionResult> _submitPendingEvents() async {
    if (_isSubmitting || _eventRepository == null) {
      return const BatchSubmissionResult(
        totalEvents: 0,
        successfulSubmissions: 0,
        failedSubmissions: 0,
      );
    }

    _isSubmitting = true;

    try {
      final pendingEvents = await _eventRepository!.getPendingEvents();

      if (pendingEvents.isEmpty) {
        return const BatchSubmissionResult(
          totalEvents: 0,
          successfulSubmissions: 0,
          failedSubmissions: 0,
        );
      }

      AppLogger.network('Submitting ${pendingEvents.length} pending events...');

      int successful = 0;
      int failed = 0;

      for (final event in pendingEvents) {
        // Check retry count
        if (event.retryCount! >= _maxRetries) {
          AppLogger.network(
              'Skipping event with max retries: ${event.toString()}');
          continue;
        }

        final result = await submitEvent(event);

        if (result.success) {
          successful++;
        } else {
          failed++;
          // Increment retry count
          await _eventRepository!
              .updateEventRetryCount(event, event.retryCount! + 1);
        }

        // Small delay between submissions to avoid overwhelming server
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      _statusController.add(SubmissionStatus.batchComplete(
        successful: successful,
        failed: failed,
        total: pendingEvents.length,
      ));

      AppLogger.network(
          'Batch submission complete: $successful successful, $failed failed');

      return BatchSubmissionResult(
        totalEvents: pendingEvents.length,
        successfulSubmissions: successful,
        failedSubmissions: failed,
      );
    } finally {
      _isSubmitting = false;
    }
  }

  /// Force immediate submission of all pending events
  Future<BatchSubmissionResult> submitAllPendingEvents() async {
    return await _submitPendingEvents();
  }

  /// Get submission statistics
  Future<Map<String, dynamic>> getSubmissionStats() async {
    if (_eventRepository == null) return {};

    final stats = await _eventRepository!.getEventStats();
    return {
      ...stats,
      'isAutoSubmissionActive': _submissionTimer?.isActive ?? false,
      'submissionInterval': _submissionInterval.inMinutes,
      'maxRetries': _maxRetries,
      'isCurrentlySubmitting': _isSubmitting,
    };
  }

  /// Update configuration
  void updateConfiguration({
    Duration? submissionInterval,
    int? maxRetries,
  }) {
    if (submissionInterval != null &&
        submissionInterval != _submissionInterval) {
      _submissionInterval = submissionInterval;
      // Restart auto-submission with new interval if active
      if (_submissionTimer?.isActive ?? false) {
        startAutoSubmission();
      }
      AppLogger.network(
          'Updated submission interval: ${_submissionInterval.inMinutes} minutes');
    }

    if (maxRetries != null) {
      _maxRetries = maxRetries;
      AppLogger.network('Updated max retries: $_maxRetries');
    }
  }

  /// Dispose of resources
  void dispose() {
    stopAutoSubmission();
    _statusController.close();
  }
}

class SubmissionResult {
  final bool success;
  final String? serverId;
  final int? statusCode;
  final String? error;

  const SubmissionResult({
    required this.success,
    this.serverId,
    this.statusCode,
    this.error,
  });
}

class BatchSubmissionResult {
  final int totalEvents;
  final int successfulSubmissions;
  final int failedSubmissions;

  const BatchSubmissionResult({
    required this.totalEvents,
    required this.successfulSubmissions,
    required this.failedSubmissions,
  });
}

abstract class SubmissionStatus {
  const SubmissionStatus();

  factory SubmissionStatus.success({
    required String eventId,
    String? serverId,
    String? message,
  }) = SubmissionSuccess;

  factory SubmissionStatus.error({
    required String eventId,
    required String message,
  }) = SubmissionError;

  factory SubmissionStatus.batchComplete({
    required int successful,
    required int failed,
    required int total,
  }) = BatchSubmissionComplete;
}

class SubmissionSuccess extends SubmissionStatus {
  final String eventId;
  final String? serverId;
  final String? message;

  const SubmissionSuccess({
    required this.eventId,
    this.serverId,
    this.message,
  });
}

class SubmissionError extends SubmissionStatus {
  final String eventId;
  final String message;

  const SubmissionError({
    required this.eventId,
    required this.message,
  });
}

class BatchSubmissionComplete extends SubmissionStatus {
  final int successful;
  final int failed;
  final int total;

  const BatchSubmissionComplete({
    required this.successful,
    required this.failed,
    required this.total,
  });
}
