import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../features/noise_monitoring/data/models/noise_event_model.dart';
import '../features/noise_monitoring/data/repositories/event_repository.dart';
import '../core/logging/app_logger.dart';
import 'settings_service.dart';

class EventSubmissionService {
  static final EventSubmissionService _instance =
      EventSubmissionService._internal();
  factory EventSubmissionService() => _instance;
  EventSubmissionService._internal();

  final Dio _dio = Dio();
  final SettingsService _settingsService = SettingsService();
  EventRepository? _eventRepository;
  Timer? _submissionTimer;
  bool _isSubmitting = false;

  // Configuration (will be moved to settings later)
  String _baseUrl = 'http://localhost:8000/api/v1'; // Default backend URL
  Duration _submissionInterval = const Duration(minutes: 5);
  int _maxRetries = 3;

  // Stream controllers for submission status
  final StreamController<SubmissionStatus> _statusController =
      StreamController<SubmissionStatus>.broadcast();

  Stream<SubmissionStatus> get statusStream => _statusController.stream;

  /// Initialize the service
  Future<void> initialize({
    String? baseUrl,
    Duration? submissionInterval,
    int? maxRetries,
  }) async {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (submissionInterval != null) _submissionInterval = submissionInterval;
    if (maxRetries != null) _maxRetries = maxRetries;

    _eventRepository = await EventRepository.getInstance();

    // Configure Dio
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add request/response interceptors for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (object) => AppLogger.network('HTTP: $object'),
    ));

    AppLogger.network('EventSubmissionService initialized with baseUrl: $_baseUrl');
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
      // Apply privacy settings before submission
      final sanitizedEvent = await _sanitizeEventForSubmission(event);
      
      final response = await _dio.post<Map<String, dynamic>>(
        '/events/',
        data: sanitizedEvent.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>;
        final serverId = responseData['id']?.toString();

        // Mark event as submitted in local storage
        await _eventRepository!.markEventAsSubmitted(event, serverId);

        _statusController.add(SubmissionStatus.success(
          eventId: event.id ?? 'unknown',
          serverId: serverId,
          message: 'Event submitted successfully',
        ));

        AppLogger.network('Event submitted successfully: ${event.toString()}');

        return SubmissionResult(
          success: true,
          serverId: serverId,
          statusCode: response.statusCode,
        );
      } else {
        _statusController.add(SubmissionStatus.error(
          eventId: event.id ?? 'unknown',
          message: 'Server returned ${response.statusCode}',
        ));

        return SubmissionResult(
          success: false,
          statusCode: response.statusCode,
          error: 'Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);

      _statusController.add(SubmissionStatus.error(
        eventId: event.id ?? 'unknown',
        message: errorMessage,
      ));

      AppLogger.network('Failed to submit event: $errorMessage');

      return SubmissionResult(
        success: false,
        statusCode: e.response?.statusCode,
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
          AppLogger.network('Skipping event with max retries: ${event.toString()}');
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

  /// Handle Dio HTTP errors
  String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.sendTimeout:
        return 'Send timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.badResponse:
        if (error.response != null) {
          return 'Server error: ${error.response!.statusCode}';
        }
        return 'Bad response';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Connection error - check network';
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return 'No internet connection';
        }
        return 'Unknown error: ${error.message}';
      default:
        return 'Network error';
    }
  }

  /// Update configuration
  void updateConfiguration({
    String? baseUrl,
    Duration? submissionInterval,
    int? maxRetries,
  }) {
    if (baseUrl != null && baseUrl != _baseUrl) {
      _baseUrl = baseUrl;
      _dio.options.baseUrl = _baseUrl;
      AppLogger.network('Updated baseUrl: $_baseUrl');
    }

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

  /// Sanitize event based on privacy settings before submission
  Future<NoiseEventModel> _sanitizeEventForSubmission(NoiseEventModel event) async {
    // If privacy mode is enabled, remove location data
    if (_settingsService.isPrivacyMode) {
      return NoiseEventModel(
        id: event.id,
        deviceId: event.deviceId,
        timestampStart: event.timestampStart,
        timestampEnd: event.timestampEnd,
        leqDb: event.leqDb,
        lmaxDb: event.lmaxDb,
        lminDb: event.lminDb,
        laeqDb: event.laeqDb,
        exceedancePct: event.exceedancePct,
        samplesCount: event.samplesCount,
        ruleTriggered: event.ruleTriggered,
        // Remove all location fields for privacy
        locationLat: null,
        locationLng: null,
        locationSource: null,
        locationAccuracy: null,
        eventMetadata: {
          ...?event.eventMetadata,
          'privacy_mode': true,
          'location_removed': true,
        },
        status: event.status,
        isSubmitted: event.isSubmitted,
        localTimestamp: event.localTimestamp,
        retryCount: event.retryCount,
      );
    }

    // Return the original event if privacy mode is off
    return event;
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
