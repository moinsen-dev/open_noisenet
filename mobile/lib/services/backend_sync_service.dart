// Service for managing backend synchronization and offline functionality.
import 'dart:async';
import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/models/api_models.dart';
import '../features/noise_monitoring/data/models/noise_event_model.dart'
    show EventAnalysisState, EventLifecycleState;
import '../features/noise_monitoring/data/repositories/event_repository.dart';
import '../services/api_client_service.dart';
import '../services/audio_capture_service.dart';
import '../services/sqlite_preferences_service.dart';

enum BackendMode {
  offline, // No backend connection, local only
  anonymous, // Backend available, anonymous submissions
  authenticated // Backend available, authenticated user
}

class EventSubmissionResult {
  final String eventUuid;
  final String lifecycleState;
  final String analysisState;
  final bool queued;
  final bool acknowledged;
  final String? serverEventId;
  final DateTime? uploadedAt;
  final DateTime? acknowledgedAt;
  final String? classificationLabel;
  final double? reportabilityScore;
  final String? classificationSource;

  const EventSubmissionResult({
    required this.eventUuid,
    required this.lifecycleState,
    required this.analysisState,
    required this.queued,
    required this.acknowledged,
    this.serverEventId,
    this.uploadedAt,
    this.acknowledgedAt,
    this.classificationLabel,
    this.reportabilityScore,
    this.classificationSource,
  });

  factory EventSubmissionResult.localOnly(
    String eventUuid, {
    String analysisState = EventAnalysisState.notStarted,
  }) {
    return EventSubmissionResult(
      eventUuid: eventUuid,
      lifecycleState: EventLifecycleState.segmentedLocal,
      analysisState: analysisState,
      queued: false,
      acknowledged: false,
    );
  }

  factory EventSubmissionResult.queued(
    String eventUuid, {
    String analysisState = EventAnalysisState.notStarted,
  }) {
    return EventSubmissionResult(
      eventUuid: eventUuid,
      lifecycleState: EventLifecycleState.queuedForUpload,
      analysisState: analysisState,
      queued: true,
      acknowledged: false,
    );
  }

  factory EventSubmissionResult.acknowledged(EventReceipt receipt) {
    return EventSubmissionResult(
      eventUuid: receipt.eventUuid,
      lifecycleState: EventLifecycleState.acknowledgedByServer,
      analysisState: receipt.analysisState,
      queued: false,
      acknowledged: true,
      serverEventId: receipt.serverEventId,
      uploadedAt: receipt.receivedAt,
      acknowledgedAt: receipt.acknowledgedAt,
      classificationLabel: receipt.classificationLabel,
      reportabilityScore: receipt.reportabilityScore,
      classificationSource: receipt.classificationSource,
    );
  }
}

class BackendSyncService {
  static const String _queuedEventsKey = 'queued_events';
  static const String _submissionModeKey =
      'submission_mode'; // 'disabled', 'anonymous', 'authenticated'

  // Lazy initialization of GetIt dependencies
  ApiClientService get _apiClient => GetIt.instance<ApiClientService>();
  SharedPreferences get _prefs => GetIt.instance<SharedPreferences>();
  SQLitePreferencesService get _sqlitePrefs =>
      GetIt.instance<SQLitePreferencesService>();
  Talker get _logger => GetIt.instance<Talker>();
  EventRepository? _eventRepository;

  BackendMode _currentMode = BackendMode.offline;
  final List<NoiseEventModel> _queuedEvents = [];
  Timer? _maintenanceTimer;
  DateTime? _lastHeartbeatAttemptAt;
  DateTime? _lastHeartbeatSucceededAt;
  DateTime? _lastSyncAttemptAt;
  DateTime? _lastSyncSucceededAt;
  DateTime? _lastProContextRefreshAttemptAt;
  DateTime? _lastProContextRefreshSucceededAt;
  String? _lastHeartbeatError;
  String? _lastProContextRefreshError;
  bool _sensorModeActive = false;
  bool _maintenanceInProgress = false;

  static const Duration _maintenanceInterval = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(minutes: 1);

  BackendMode get currentMode => _currentMode;
  bool get isOnlineMode => _currentMode != BackendMode.offline;
  bool get hasQueuedEvents => _queuedEvents.isNotEmpty;
  int get queuedEventsCount => _queuedEvents.length;
  AudioCaptureService get _audioCapture =>
      GetIt.instance<AudioCaptureService>();

  Future<void> initialize() async {
    _eventRepository = await EventRepository.getInstance();
    await _loadQueuedEvents();
    await _updateBackendMode();
    _startMaintenanceLoop();

    _logger.info('BackendSyncService initialized', {
      'mode': _currentMode.name,
      'queued_events': _queuedEvents.length,
    });
  }

  void _startMaintenanceLoop() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = Timer.periodic(_maintenanceInterval, (_) {
      unawaited(_runMaintenanceTick());
    });
    unawaited(_runMaintenanceTick());
  }

  Future<void> setSensorModeActive(bool isActive) async {
    _sensorModeActive = isActive;
    if (isActive) {
      await performImmediateMaintenance();
    }
  }

  Future<void> performImmediateMaintenance() async {
    await _runMaintenanceTick(forceHeartbeat: true);
  }

  Future<void> _runMaintenanceTick({bool forceHeartbeat = false}) async {
    if (_maintenanceInProgress) {
      return;
    }
    _maintenanceInProgress = true;
    try {
      await _updateBackendMode();

      if (_currentMode == BackendMode.offline) {
        return;
      }

      final now = DateTime.now();
      final shouldSyncQueue = _queuedEvents.isNotEmpty;
      final shouldHeartbeat = _sensorModeActive &&
          (forceHeartbeat ||
              _lastHeartbeatSucceededAt == null ||
              now.difference(_lastHeartbeatSucceededAt!) >= _heartbeatInterval);

      if (shouldHeartbeat) {
        await _sendDeviceHeartbeat();
      }

      _lastProContextRefreshAttemptAt = now;
      if (_apiClient.isAuthenticated || _apiClient.assignedSiteId != null) {
        await _apiClient.refreshProDeviceContext();
        _lastProContextRefreshError = _apiClient.lastProContextError;
        if (_lastProContextRefreshError == null) {
          _lastProContextRefreshSucceededAt = DateTime.now();
        } else {
          _logger.warning(
            'Pro context refresh reported an error',
            _lastProContextRefreshError,
          );
        }
      }

      if (shouldSyncQueue) {
        _lastSyncAttemptAt = now;
        final submitted = await syncQueuedEvents();
        if (submitted > 0) {
          _lastSyncSucceededAt = DateTime.now();
        }
      }

      await _apiClient.refreshKnownDeviceContext();
    } finally {
      _maintenanceInProgress = false;
    }
  }

  /// Update current backend mode based on connectivity and authentication
  Future<void> _updateBackendMode() async {
    try {
      // Check if user has forced offline mode
      final isForceOffline = await _sqlitePrefs.getForceOfflineMode();

      if (isForceOffline) {
        _currentMode = BackendMode.offline;
        _logger.info('Backend mode: Force offline mode enabled by user');
        return;
      }

      final isAvailable = await _apiClient.isBackendAvailable();

      if (!isAvailable) {
        _currentMode = BackendMode.offline;
        _logger.info('Backend mode: Offline (backend not available)');
      } else if (_apiClient.isAuthenticated) {
        _currentMode = BackendMode.authenticated;
        _logger.info('Backend mode: Authenticated');
      } else {
        _currentMode = BackendMode.anonymous;
        _logger.info('Backend mode: Anonymous');
      }

      _logger.debug('Backend mode updated: ${_currentMode.name}');
    } catch (e) {
      _currentMode = BackendMode.offline;
      _logger.warning(
          'Failed to update backend mode, defaulting to offline', e);
    }
  }

  /// Get current submission mode setting
  Future<String> getSubmissionMode() async {
    final autoSubmissionEnabled = await _sqlitePrefs.getAutoSubmissionEnabled();
    if (!autoSubmissionEnabled) {
      return 'disabled';
    }

    final derivedMode =
        _apiClient.isAuthenticated ? 'authenticated' : 'anonymous';
    final legacyMode = _prefs.getString(_submissionModeKey);

    if (legacyMode != derivedMode) {
      await _prefs.setString(_submissionModeKey, derivedMode);
    }

    return derivedMode;
  }

  /// Set submission mode ('disabled', 'anonymous', 'authenticated')
  Future<void> setSubmissionMode(String mode) async {
    await _prefs.setString(_submissionModeKey, mode);
    await _sqlitePrefs.setAutoSubmissionEnabled(mode != 'disabled');
    await _updateBackendMode();
    _logger.info('Submission mode set to: $mode');
  }

  /// Submit a noise event with appropriate fallback handling
  Future<EventSubmissionResult> submitNoiseEvent({
    String? eventUuid,
    required DateTime timestampStart,
    required DateTime timestampEnd,
    required double leqDb,
    double? lmaxDb,
    double? lminDb,
    double? laeqDb,
    double? exceedancePct,
    int? samplesCount,
    String? ruleTriggered,
    double? locationLat,
    double? locationLng,
    Map<String, dynamic>? weatherConditions,
    Map<String, dynamic>? eventMetadata,
    String? classificationLabel,
    double? classificationConfidence,
    String? classificationSource,
    String? segmentType,
    double? reportabilityScore,
    String? reportabilityReason,
    double? peakToAverageDeltaDb,
    double? variabilityDb,
    double? thresholdExceedanceRatio,
    String? analysisState,
    DateTime? analysisUpdatedAt,
  }) async {
    final submissionMode = await getSubmissionMode();
    final resolvedEventUuid = eventUuid ?? const Uuid().v4();

    // If submission is disabled, only store locally
    if (submissionMode == 'disabled') {
      _logger.info('Backend submission disabled, storing locally only');
      return EventSubmissionResult.localOnly(
        resolvedEventUuid,
        analysisState: analysisState ?? EventAnalysisState.notStarted,
      );
    }

    String deviceId = await _apiClient.ensureDeviceId();

    if (_currentMode != BackendMode.offline) {
      try {
        final registeredDevice = await _apiClient.ensureDeviceRegistered();
        deviceId = registeredDevice.deviceId;
        await _apiClient.refreshKnownDeviceContext();
      } catch (e) {
        _logger.warning(
          'Failed to register device before event submission, falling back to local device identity',
          e,
        );
      }
    }

    // Create event model
    final enrichedMetadata = <String, dynamic>{
      ...?eventMetadata,
      'device_context': {
        'site_id': _apiClient.assignedSiteId,
        'zone_id': _apiClient.assignedZoneId,
        'calibration_profile_id': _apiClient.assignedCalibrationProfileId,
      },
      'sensor_runtime': {
        'sensor_mode_active': _sensorModeActive,
        'captured_sample_count': _audioCapture.capturedSampleCount,
        ..._audioCapture.getDiagnostics(),
      },
    };
    final event = NoiseEventModel(
      eventUuid: resolvedEventUuid,
      deviceId: deviceId,
      timestampStart: timestampStart,
      timestampEnd: timestampEnd,
      leqDb: leqDb,
      lmaxDb: lmaxDb,
      lminDb: lminDb,
      laeqDb: laeqDb,
      exceedancePct: exceedancePct,
      samplesCount: samplesCount,
      ruleTriggered: ruleTriggered,
      locationLat: locationLat,
      locationLng: locationLng,
      weatherConditions: weatherConditions,
      eventMetadata: enrichedMetadata,
      classificationLabel: classificationLabel,
      classificationConfidence: classificationConfidence,
      classificationSource: classificationSource,
      segmentType: segmentType,
      reportabilityScore: reportabilityScore,
      reportabilityReason: reportabilityReason,
      peakToAverageDeltaDb: peakToAverageDeltaDb,
      variabilityDb: variabilityDb,
      thresholdExceedanceRatio: thresholdExceedanceRatio,
      analysisState: analysisState,
      analysisUpdatedAt: analysisUpdatedAt,
    );

    await _updateBackendMode();
    await _markUploadAttempt(resolvedEventUuid);

    // Handle different submission modes
    switch (_currentMode) {
      case BackendMode.offline:
        return await _queueEventForLater(event);

      case BackendMode.anonymous:
        if (submissionMode == 'anonymous' ||
            submissionMode == 'authenticated') {
          return await _submitEventAnonymous(event);
        }
        return await _queueEventForLater(event);

      case BackendMode.authenticated:
        if (submissionMode == 'authenticated') {
          return await _submitEventAuthenticated(event);
        } else if (submissionMode == 'anonymous') {
          return await _submitEventAnonymous(event);
        }
        return await _queueEventForLater(event);
    }
  }

  /// Submit event with authentication
  Future<EventSubmissionResult> _submitEventAuthenticated(
    NoiseEventModel event,
  ) async {
    try {
      final receipt = await _apiClient.createEvent(event);
      await _markAcknowledged(receipt);
      _logger.info('Event submitted with authentication');
      return EventSubmissionResult.acknowledged(receipt);
    } catch (e) {
      _logger.warning('Authenticated submission failed, queueing event', e);
      return await _queueEventForLater(
        event,
        lastErrorCode: 'authenticated_submit_failed',
        lastErrorMessage: e.toString(),
      );
    }
  }

  /// Submit event anonymously
  Future<EventSubmissionResult> _submitEventAnonymous(
    NoiseEventModel event,
  ) async {
    try {
      final receipt = await _apiClient.submitAnonymousEvent(event);
      if (receipt != null) {
        await _markAcknowledged(receipt);
        _logger.info('Event submitted anonymously');
        return EventSubmissionResult.acknowledged(receipt);
      } else {
        return await _queueEventForLater(event);
      }
    } catch (e) {
      _logger.warning('Anonymous submission failed, queueing event', e);
      return await _queueEventForLater(
        event,
        lastErrorCode: 'anonymous_submit_failed',
        lastErrorMessage: e.toString(),
      );
    }
  }

  /// Queue event for later submission
  Future<EventSubmissionResult> _queueEventForLater(
    NoiseEventModel event, {
    String? lastErrorCode,
    String? lastErrorMessage,
  }) async {
    final alreadyQueued = _queuedEvents.any(
      (queuedEvent) => queuedEvent.eventUuid == event.eventUuid,
    );
    if (!alreadyQueued) {
      _queuedEvents.add(event);
    }
    await _saveQueuedEvents();
    await _eventRepository?.updateEventLifecycle(
      eventUuid: event.eventUuid ?? const Uuid().v4(),
      lifecycleState: EventLifecycleState.queuedForUpload,
      analysisState: event.analysisState ?? EventAnalysisState.notStarted,
      isSubmitted: false,
      lastErrorCode: lastErrorCode ?? '',
      lastErrorMessage: lastErrorMessage ?? '',
    );

    _logger.info('Event queued for later submission', {
      'queue_size': _queuedEvents.length,
    });

    return EventSubmissionResult.queued(
      event.eventUuid ?? const Uuid().v4(),
      analysisState: event.analysisState ?? EventAnalysisState.notStarted,
    );
  }

  /// Attempt to sync all queued events
  Future<int> syncQueuedEvents() async {
    if (_queuedEvents.isEmpty) return 0;

    await _updateBackendMode();

    if (_currentMode == BackendMode.offline) {
      _logger.info('Backend still offline, keeping events queued');
      return 0;
    }

    final submissionMode = await getSubmissionMode();
    if (submissionMode == 'disabled') {
      _logger.info('Submission disabled, clearing queue without sending');
      final count = _queuedEvents.length;
      _queuedEvents.clear();
      await _saveQueuedEvents();
      return count;
    }

    int successCount = 0;
    final eventsToRemove = <NoiseEventModel>[];

    for (final event in List<NoiseEventModel>.from(_queuedEvents)) {
      bool success = false;

      try {
        if (event.eventUuid != null) {
          await _markUploadAttempt(event.eventUuid!);
        }
        if (_currentMode == BackendMode.authenticated &&
            submissionMode == 'authenticated') {
          final result = await _submitEventAuthenticated(event);
          success = result.acknowledged;
        } else if (submissionMode == 'anonymous' ||
            submissionMode == 'authenticated') {
          final result = await _submitEventAnonymous(event);
          success = result.acknowledged;
        }

        if (success) {
          successCount++;
          eventsToRemove.add(event);
        }
      } catch (e) {
        _logger.warning('Failed to sync queued event', e);
        if (event.eventUuid != null) {
          await _eventRepository?.updateEventLifecycle(
            eventUuid: event.eventUuid!,
            lifecycleState: EventLifecycleState.failed,
            isSubmitted: false,
            lastErrorCode: 'sync_failed',
            lastErrorMessage: e.toString(),
          );
        }
      }
    }

    // Remove successfully submitted events from queue
    for (final event in eventsToRemove) {
      _queuedEvents.remove(event);
    }

    await _saveQueuedEvents();

    _logger.info('Sync completed', {
      'submitted': successCount,
      'remaining': _queuedEvents.length,
    });

    return successCount;
  }

  /// Clear all queued events without submitting
  Future<void> clearQueue() async {
    final count = _queuedEvents.length;
    _queuedEvents.clear();
    await _saveQueuedEvents();

    _logger.info('Event queue cleared', {'count': count});
  }

  /// Get backend status for UI display
  Future<Map<String, dynamic>> getBackendStatus() async {
    await _updateBackendMode();
    final submissionMode = await getSubmissionMode();
    final lifecycleStats =
        await (_eventRepository ?? await EventRepository.getInstance())
            .getLifecycleStats();

    return {
      'mode': _currentMode.name,
      'submission_enabled': submissionMode != 'disabled',
      'submission_mode': submissionMode,
      'queued_events': _queuedEvents.length,
      'authenticated': _apiClient.isAuthenticated,
      'device_id': _apiClient.deviceId,
      'backend_url': _apiClient.baseUrl,
      'sensor_mode_active': _sensorModeActive,
      'assigned_site_id': _apiClient.assignedSiteId,
      'assigned_zone_id': _apiClient.assignedZoneId,
      'assigned_calibration_profile_id':
          _apiClient.assignedCalibrationProfileId,
      'assigned_organization_id': _apiClient.assignedOrganizationId,
      'assigned_organization_name': _apiClient.assignedOrganizationName,
      'assigned_organization_plan': _apiClient.assignedOrganizationPlan,
      'assigned_site_name': _apiClient.assignedSiteName,
      'assigned_zone_name': _apiClient.assignedZoneName,
      'assigned_calibration_profile_name':
          _apiClient.assignedCalibrationProfileName,
      'effective_policy_id': _apiClient.effectivePolicyId,
      'effective_policy_name': _apiClient.effectivePolicyName,
      'effective_policy_scope': _apiClient.effectivePolicyScope,
      'effective_evidence_mode': _apiClient.effectiveEvidenceMode,
      'effective_policy_retention_days':
          _apiClient.effectivePolicyRetentionDays,
      'effective_day_threshold_db': _apiClient.effectiveDayThresholdDb,
      'effective_night_threshold_db': _apiClient.effectiveNightThresholdDb,
      'pro_context_access_state':
          _apiClient.lastProContext?.accessState ?? 'unavailable',
      'pro_context_refreshed_at':
          _apiClient.lastProContextRefreshedAt?.toIso8601String(),
      'pro_context_error': _apiClient.lastProContextError,
      'pro_context_refresh_attempt_at':
          _lastProContextRefreshAttemptAt?.toIso8601String(),
      'pro_context_refresh_succeeded_at':
          _lastProContextRefreshSucceededAt?.toIso8601String(),
      'pro_context_refresh_error': _lastProContextRefreshError,
      'pro_context': _apiClient.lastProContext?.toDiagnosticMap(),
      'last_heartbeat_at': _lastHeartbeatSucceededAt?.toIso8601String(),
      'last_heartbeat_attempt_at': _lastHeartbeatAttemptAt?.toIso8601String(),
      'last_heartbeat_error': _lastHeartbeatError,
      'device_last_heartbeat_at': _apiClient.lastHeartbeatAt?.toIso8601String(),
      'device_runtime_status': _apiClient.lastRuntimeStatus,
      'last_sync_attempt_at': _lastSyncAttemptAt?.toIso8601String(),
      'last_sync_succeeded_at': _lastSyncSucceededAt?.toIso8601String(),
      ...lifecycleStats,
    };
  }

  /// Load queued events from storage
  Future<void> _loadQueuedEvents() async {
    try {
      final data = _prefs.getString(_queuedEventsKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(data) as List<dynamic>;
        _queuedEvents.clear();
        _queuedEvents.addAll(jsonList.map(
            (json) => NoiseEventModel.fromJson(json as Map<String, dynamic>)));
      }
    } catch (e) {
      _logger.error('Failed to load queued events', e);
    }
  }

  /// Save queued events to storage
  Future<void> _saveQueuedEvents() async {
    try {
      final jsonList = _queuedEvents.map((event) => event.toJson()).toList();
      final data = json.encode(jsonList);
      await _prefs.setString(_queuedEventsKey, data);
    } catch (e) {
      _logger.error('Failed to save queued events', e);
    }
  }

  /// Get submission statistics
  Future<Map<String, dynamic>> getSubmissionStats() async {
    try {
      final lifecycleStats =
          await (_eventRepository ?? await EventRepository.getInstance())
              .getLifecycleStats();

      return {
        'total_local_events': lifecycleStats['local_events'] ?? 0,
        'queued_for_submission': _queuedEvents.length,
        'uploaded_events': lifecycleStats['uploaded_events'] ?? 0,
        'acknowledged_events': lifecycleStats['acknowledged_events'] ?? 0,
        'device_classified_events':
            lifecycleStats['device_classified_events'] ?? 0,
        'server_classified_events':
            lifecycleStats['server_classified_events'] ?? 0,
        'current_mode': _currentMode.name,
        'submission_mode': await getSubmissionMode(),
      };
    } catch (e) {
      _logger.error('Failed to get submission stats', e);
      return {
        'total_local_events': 0,
        'queued_for_submission': _queuedEvents.length,
        'current_mode': _currentMode.name,
        'submission_mode': await getSubmissionMode(),
      };
    }
  }

  Future<void> _markUploadAttempt(String eventUuid) async {
    final repository = _eventRepository ?? await EventRepository.getInstance();
    final existingEvent = await repository.getEventByUuid(eventUuid);
    final attemptCount = (existingEvent?.uploadAttemptCount ?? 0) + 1;

    await repository.updateEventLifecycle(
      eventUuid: eventUuid,
      lifecycleState: EventLifecycleState.uploading,
      analysisState:
          existingEvent?.analysisState ?? EventAnalysisState.notStarted,
      isSubmitted: false,
      uploadAttemptCount: attemptCount,
      lastUploadAttemptAt: DateTime.now(),
      lastErrorCode: '',
      lastErrorMessage: '',
    );
  }

  Future<void> _markAcknowledged(EventReceipt receipt) async {
    await (_eventRepository ?? await EventRepository.getInstance())
        .updateEventLifecycle(
      eventUuid: receipt.eventUuid,
      lifecycleState: EventLifecycleState.acknowledgedByServer,
      analysisState: receipt.analysisState,
      isSubmitted: true,
      lastUploadedAt: receipt.receivedAt,
      serverAcknowledgedAt: receipt.acknowledgedAt,
      serverEventId: receipt.serverEventId,
      classificationLabel: receipt.classificationLabel,
      reportabilityScore: receipt.reportabilityScore,
      classificationSource: receipt.classificationSource,
      analysisUpdatedAt: receipt.acknowledgedAt,
      lastErrorCode: '',
      lastErrorMessage: '',
    );
  }

  Future<void> _sendDeviceHeartbeat() async {
    _lastHeartbeatAttemptAt = DateTime.now();

    try {
      final registeredDevice = await _apiClient.ensureDeviceRegistered();
      final diagnostics = _audioCapture.getDiagnostics();
      final proContext = _apiClient.lastProContext?.toDiagnosticMap();
      await _apiClient.sendHeartbeat(
        HeartbeatRequest(
          deviceId: registeredDevice.deviceId,
          timestamp: DateTime.now().toUtc(),
        ),
        status: {
          'sensor_mode_active': _sensorModeActive,
          'queued_events': _queuedEvents.length,
          'backend_mode': _currentMode.name,
          'captured_sample_count': diagnostics['capturedSampleCount'],
          'restart_count': diagnostics['restartCount'],
          'last_sample_at': diagnostics['lastSampleAt'],
          'time_since_last_sample_ms': diagnostics['timeSinceLastSampleMs'],
          'assigned_site_id': _apiClient.assignedSiteId,
          'assigned_zone_id': _apiClient.assignedZoneId,
          'assigned_calibration_profile_id':
              _apiClient.assignedCalibrationProfileId,
          'assigned_organization_id': _apiClient.assignedOrganizationId,
          'assigned_organization_name': _apiClient.assignedOrganizationName,
          'assigned_site_name': _apiClient.assignedSiteName,
          'assigned_zone_name': _apiClient.assignedZoneName,
          'assigned_calibration_profile_name':
              _apiClient.assignedCalibrationProfileName,
          'effective_policy_id': _apiClient.effectivePolicyId,
          'effective_policy_name': _apiClient.effectivePolicyName,
          'effective_policy_scope': _apiClient.effectivePolicyScope,
          'effective_evidence_mode': _apiClient.effectiveEvidenceMode,
          'pro_context_access_state':
              _apiClient.lastProContext?.accessState ?? 'unavailable',
          'pro_context': proContext,
        },
      );
      _lastHeartbeatSucceededAt = DateTime.now();
      _lastHeartbeatError = null;
    } catch (e) {
      _lastHeartbeatError = e.toString();
      _logger.warning('Device heartbeat failed', e);
    }
  }
}
