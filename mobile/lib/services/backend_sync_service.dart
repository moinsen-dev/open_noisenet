/// Service for managing backend synchronization and offline functionality
import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/models/api_models.dart';
import '../services/api_client_service.dart';
import '../core/database/dao/noise_measurement_dao.dart';
import '../services/sqlite_preferences_service.dart';

enum BackendMode {
  offline,      // No backend connection, local only
  anonymous,    // Backend available, anonymous submissions
  authenticated // Backend available, authenticated user
}

class BackendSyncService {
  static const String _queuedEventsKey = 'queued_events';
  static const String _submissionModeKey = 'submission_mode'; // 'disabled', 'anonymous', 'authenticated'
  
  // Lazy initialization of GetIt dependencies
  ApiClientService get _apiClient => GetIt.instance<ApiClientService>();
  SharedPreferences get _prefs => GetIt.instance<SharedPreferences>();
  SQLitePreferencesService get _sqlitePrefs => GetIt.instance<SQLitePreferencesService>();
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  Talker get _logger => GetIt.instance<Talker>();
  
  BackendMode _currentMode = BackendMode.offline;
  final List<NoiseEventModel> _queuedEvents = [];

  BackendMode get currentMode => _currentMode;
  bool get isOnlineMode => _currentMode != BackendMode.offline;
  bool get hasQueuedEvents => _queuedEvents.isNotEmpty;
  int get queuedEventsCount => _queuedEvents.length;

  Future<void> initialize() async {
    await _loadQueuedEvents();
    await _updateBackendMode();
    
    _logger.info('BackendSyncService initialized', {
      'mode': _currentMode.name,
      'queued_events': _queuedEvents.length,
    });
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
      _logger.warning('Failed to update backend mode, defaulting to offline', e);
    }
  }

  /// Get current submission mode setting
  Future<String> getSubmissionMode() async {
    return _prefs.getString(_submissionModeKey) ?? 'disabled';
  }

  /// Set submission mode ('disabled', 'anonymous', 'authenticated')
  Future<void> setSubmissionMode(String mode) async {
    await _prefs.setString(_submissionModeKey, mode);
    await _updateBackendMode();
    _logger.info('Submission mode set to: $mode');
  }

  /// Submit a noise event with appropriate fallback handling
  Future<bool> submitNoiseEvent({
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
  }) async {
    
    final submissionMode = await getSubmissionMode();
    
    // If submission is disabled, only store locally
    if (submissionMode == 'disabled') {
      _logger.info('Backend submission disabled, storing locally only');
      return false;
    }

    // Create event model
    final deviceId = _apiClient.deviceId ?? 'anonymous-${const Uuid().v4()}';
    final event = NoiseEventModel(
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
      eventMetadata: eventMetadata,
    );

    await _updateBackendMode();

    // Handle different submission modes
    switch (_currentMode) {
      case BackendMode.offline:
        return await _queueEventForLater(event);
        
      case BackendMode.anonymous:
        if (submissionMode == 'anonymous' || submissionMode == 'authenticated') {
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
  Future<bool> _submitEventAuthenticated(NoiseEventModel event) async {
    try {
      await _apiClient.createEvent(event);
      _logger.info('Event submitted with authentication');
      return true;
    } catch (e) {
      _logger.warning('Authenticated submission failed, queueing event', e);
      return await _queueEventForLater(event);
    }
  }

  /// Submit event anonymously
  Future<bool> _submitEventAnonymous(NoiseEventModel event) async {
    try {
      final success = await _apiClient.submitAnonymousEvent(event);
      if (success) {
        _logger.info('Event submitted anonymously');
        return true;
      } else {
        return await _queueEventForLater(event);
      }
    } catch (e) {
      _logger.warning('Anonymous submission failed, queueing event', e);
      return await _queueEventForLater(event);
    }
  }

  /// Queue event for later submission
  Future<bool> _queueEventForLater(NoiseEventModel event) async {
    _queuedEvents.add(event);
    await _saveQueuedEvents();
    
    _logger.info('Event queued for later submission', {
      'queue_size': _queuedEvents.length,
    });
    
    return false; // Indicates it wasn't submitted immediately
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
        if (_currentMode == BackendMode.authenticated && submissionMode == 'authenticated') {
          success = await _submitEventAuthenticated(event);
        } else if (submissionMode == 'anonymous' || submissionMode == 'authenticated') {
          success = await _submitEventAnonymous(event);
        }

        if (success) {
          successCount++;
          eventsToRemove.add(event);
        }
      } catch (e) {
        _logger.warning('Failed to sync queued event', e);
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
    
    return {
      'mode': _currentMode.name,
      'submission_enabled': submissionMode != 'disabled',
      'submission_mode': submissionMode,
      'queued_events': _queuedEvents.length,
      'authenticated': _apiClient.isAuthenticated,
      'device_id': _apiClient.deviceId,
    };
  }

  /// Load queued events from storage
  Future<void> _loadQueuedEvents() async {
    try {
      final data = _prefs.getString(_queuedEventsKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(data) as List<dynamic>;
        _queuedEvents.clear();
        _queuedEvents.addAll(
          jsonList.map((json) => NoiseEventModel.fromJson(json as Map<String, dynamic>))
        );
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
      // Get local measurements count
      final totalLocalEvents = await _measurementDao.count();
      
      return {
        'total_local_events': totalLocalEvents,
        'queued_for_submission': _queuedEvents.length,
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
}