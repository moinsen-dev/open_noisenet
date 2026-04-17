import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/logging/app_logger.dart';
import '../models/noise_event_model.dart';

class EventRepository {
  static const String _keyPrefix = 'noise_events_';
  static const String _keyPendingList = 'pending_events_list';
  static const String _keySubmittedList = 'submitted_events_list';

  final SharedPreferences _prefs;

  EventRepository._(this._prefs);

  static EventRepository? _instance;

  static Future<EventRepository> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = EventRepository._(prefs);
    }
    return _instance!;
  }

  /// Save event locally
  Future<void> saveEvent(NoiseEventModel event) async {
    final key = _generateEventKey(event);
    final json = event.toLocalJson();

    await _prefs.setString(key, jsonEncode(json));

    // Add to appropriate list
    if (event.isSubmitted) {
      await _removeFromPendingList(key);
      await _addToSubmittedList(key);
    } else {
      await _removeFromSubmittedList(key);
      await _addToPendingList(key);
    }

    AppLogger.database('Saved event: ${event.toString()}');
  }

  /// Get event by key
  Future<NoiseEventModel?> getEvent(String eventKey) async {
    final jsonString = _prefs.getString(eventKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return NoiseEventModel.fromLocalJson(json);
    } catch (e) {
      AppLogger.database('Error loading event $eventKey: $e');
      return null;
    }
  }

  /// Get event by stable event UUID
  Future<NoiseEventModel?> getEventByUuid(String eventUuid) async {
    final directKey = _keyForEventUuid(eventUuid);
    final directMatch = await getEvent(directKey);
    if (directMatch != null) {
      return directMatch;
    }

    final allEvents = await getAllEvents();
    for (final event in allEvents) {
      if (event.eventUuid == eventUuid) {
        return event;
      }
    }

    return null;
  }

  /// Get all pending events (not yet submitted)
  Future<List<NoiseEventModel>> getPendingEvents() async {
    final eventKeys = _prefs.getStringList(_keyPendingList) ?? [];
    final events = <NoiseEventModel>[];

    for (final key in eventKeys) {
      final event = await getEvent(key);
      if (event != null) {
        events.add(event);
      }
    }

    // Sort by timestamp
    events.sort((a, b) => a.timestampStart.compareTo(b.timestampStart));
    return events;
  }

  /// Get all submitted events
  Future<List<NoiseEventModel>> getSubmittedEvents({int? limit}) async {
    final eventKeys = _prefs.getStringList(_keySubmittedList) ?? [];
    final events = <NoiseEventModel>[];

    // Take most recent events if limit specified
    final keysToLoad = limit != null && eventKeys.length > limit
        ? eventKeys.take(limit)
        : eventKeys;

    for (final key in keysToLoad) {
      final event = await getEvent(key);
      if (event != null) {
        events.add(event);
      }
    }

    // Sort by timestamp (newest first)
    events.sort((a, b) => b.timestampStart.compareTo(a.timestampStart));
    return events;
  }

  /// Get all events (pending and submitted)
  Future<List<NoiseEventModel>> getAllEvents({int? limit}) async {
    final pending = await getPendingEvents();
    final submitted = await getSubmittedEvents();

    final allEvents = [...pending, ...submitted];
    allEvents.sort((a, b) => b.timestampStart.compareTo(a.timestampStart));

    if (limit != null && allEvents.length > limit) {
      return allEvents.take(limit).toList();
    }

    return allEvents;
  }

  /// Mark event as submitted
  Future<void> markEventAsSubmitted(
      NoiseEventModel event, String? serverId) async {
    final updatedEvent = event.copyWith(
      id: serverId ?? event.id,
      isSubmitted: true,
      status: 'processed',
      lifecycleState: EventLifecycleState.acknowledgedByServer,
      serverEventId: serverId ?? event.serverEventId,
      lastUploadedAt: event.lastUploadedAt ?? DateTime.now(),
      serverAcknowledgedAt: DateTime.now(),
    );

    // Save updated event
    await saveEvent(updatedEvent);

    AppLogger.database(
      'Marked event as submitted: ${updatedEvent.eventUuid ?? updatedEvent.id}',
    );
  }

  /// Update event retry count
  Future<void> updateEventRetryCount(
      NoiseEventModel event, int retryCount) async {
    final updatedEvent = event.copyWith(retryCount: retryCount);
    await saveEvent(updatedEvent);
  }

  /// Delete event
  Future<void> deleteEvent(NoiseEventModel event) async {
    final key = _generateEventKey(event);

    await _prefs.remove(key);
    await _removeFromPendingList(key);
    await _removeFromSubmittedList(key);

    AppLogger.database('Deleted event: $key');
  }

  /// Clear all events
  Future<void> clearAllEvents() async {
    final allKeys = [
      ...(_prefs.getStringList(_keyPendingList) ?? []),
      ...(_prefs.getStringList(_keySubmittedList) ?? [])
    ];

    for (final key in allKeys) {
      await _prefs.remove(key);
    }

    await _prefs.remove(_keyPendingList);
    await _prefs.remove(_keySubmittedList);

    AppLogger.database('Cleared all events');
  }

  Future<void> updateEventLifecycle({
    required String eventUuid,
    required String lifecycleState,
    String? analysisState,
    bool? isSubmitted,
    int? uploadAttemptCount,
    DateTime? lastUploadAttemptAt,
    DateTime? lastUploadedAt,
    DateTime? serverAcknowledgedAt,
    String? serverEventId,
    String? classificationLabel,
    double? classificationConfidence,
    String? classificationSource,
    String? segmentType,
    double? reportabilityScore,
    String? reportabilityReason,
    double? peakToAverageDeltaDb,
    double? variabilityDb,
    double? thresholdExceedanceRatio,
    DateTime? analysisUpdatedAt,
    String? lastErrorCode,
    String? lastErrorMessage,
  }) async {
    final existing = await getEventByUuid(eventUuid);
    if (existing == null) {
      AppLogger.database(
          'Skipping lifecycle update for unknown event: $eventUuid');
      return;
    }

    final updated = existing.copyWith(
      lifecycleState: lifecycleState,
      analysisState: analysisState ?? existing.analysisState,
      isSubmitted: isSubmitted ?? existing.isSubmitted,
      uploadAttemptCount: uploadAttemptCount ?? existing.uploadAttemptCount,
      lastUploadAttemptAt: lastUploadAttemptAt ?? existing.lastUploadAttemptAt,
      lastUploadedAt: lastUploadedAt ?? existing.lastUploadedAt,
      serverAcknowledgedAt:
          serverAcknowledgedAt ?? existing.serverAcknowledgedAt,
      serverEventId: serverEventId ?? existing.serverEventId,
      classificationLabel: classificationLabel ?? existing.classificationLabel,
      classificationConfidence:
          classificationConfidence ?? existing.classificationConfidence,
      classificationSource:
          classificationSource ?? existing.classificationSource,
      segmentType: segmentType ?? existing.segmentType,
      reportabilityScore: reportabilityScore ?? existing.reportabilityScore,
      reportabilityReason: reportabilityReason ?? existing.reportabilityReason,
      peakToAverageDeltaDb:
          peakToAverageDeltaDb ?? existing.peakToAverageDeltaDb,
      variabilityDb: variabilityDb ?? existing.variabilityDb,
      thresholdExceedanceRatio:
          thresholdExceedanceRatio ?? existing.thresholdExceedanceRatio,
      analysisUpdatedAt: analysisUpdatedAt ?? existing.analysisUpdatedAt,
      lastErrorCode: lastErrorCode,
      lastErrorMessage: lastErrorMessage,
      status:
          (isSubmitted ?? existing.isSubmitted) ? 'processed' : existing.status,
    );

    await saveEvent(updated);
  }

  /// Get event statistics
  Future<Map<String, dynamic>> getEventStats() async {
    final pending = await getPendingEvents();
    final submitted = await getSubmittedEvents();

    if (pending.isEmpty && submitted.isEmpty) {
      return {
        'totalEvents': 0,
        'pendingEvents': 0,
        'submittedEvents': 0,
        'averageLeq': 0.0,
        'maxLeq': 0.0,
        'oldestEvent': null,
        'newestEvent': null,
      };
    }

    final allEvents = [...pending, ...submitted];
    final allLeqValues = allEvents.map((e) => e.leqDb).toList();

    return {
      'totalEvents': allEvents.length,
      'pendingEvents': pending.length,
      'submittedEvents': submitted.length,
      'averageLeq': allLeqValues.isEmpty
          ? 0.0
          : allLeqValues.reduce((a, b) => a + b) / allLeqValues.length,
      'maxLeq': allLeqValues.isEmpty
          ? 0.0
          : allLeqValues.reduce((a, b) => a > b ? a : b),
      'oldestEvent': allEvents
          .map((e) => e.timestampStart)
          .reduce((a, b) => a.isBefore(b) ? a : b),
      'newestEvent': allEvents
          .map((e) => e.timestampStart)
          .reduce((a, b) => a.isAfter(b) ? a : b),
    };
  }

  Future<Map<String, dynamic>> getLifecycleStats() async {
    final allEvents = await getAllEvents();

    return {
      'local_events': allEvents.length,
      'queued_events': allEvents
          .where((event) =>
              event.lifecycleState == EventLifecycleState.queuedForUpload)
          .length,
      'uploaded_events':
          allEvents.where((event) => event.lastUploadedAt != null).length,
      'acknowledged_events':
          allEvents.where((event) => event.serverAcknowledgedAt != null).length,
      'failed_events': allEvents
          .where((event) => event.lifecycleState == EventLifecycleState.failed)
          .length,
      'device_classified_events': allEvents
          .where((event) =>
              event.analysisState == EventAnalysisState.classifiedOnDevice)
          .length,
      'server_classified_events': allEvents
          .where((event) =>
              event.analysisState == EventAnalysisState.serverClassified)
          .length,
      'analysis_failed_events': allEvents
          .where((event) => event.analysisState == EventAnalysisState.failed)
          .length,
      'last_acknowledged_at': allEvents
          .where((event) => event.serverAcknowledgedAt != null)
          .map((event) => event.serverAcknowledgedAt!)
          .fold<DateTime?>(null, (latest, current) {
        if (latest == null) {
          return current;
        }
        return current.isAfter(latest) ? current : latest;
      })?.toIso8601String(),
      'last_analysis_update_at': allEvents
          .where((event) => event.analysisUpdatedAt != null)
          .map((event) => event.analysisUpdatedAt!)
          .fold<DateTime?>(null, (latest, current) {
        if (latest == null) {
          return current;
        }
        return current.isAfter(latest) ? current : latest;
      })?.toIso8601String(),
    };
  }

  Future<List<NoiseEventModel>> getRecentEvents({int limit = 20}) async {
    return getAllEvents(limit: limit);
  }

  /// Generate unique key for event storage
  String _generateEventKey(NoiseEventModel event) {
    final eventUuid = event.eventUuid;
    if (eventUuid != null && eventUuid.isNotEmpty) {
      return _keyForEventUuid(eventUuid);
    }

    return '$_keyPrefix${event.deviceId}_${event.timestampStart.millisecondsSinceEpoch}';
  }

  String _keyForEventUuid(String eventUuid) => '$_keyPrefix$eventUuid';

  /// Add event key to pending list
  Future<void> _addToPendingList(String eventKey) async {
    final list = _prefs.getStringList(_keyPendingList) ?? [];
    if (!list.contains(eventKey)) {
      list.add(eventKey);
      await _prefs.setStringList(_keyPendingList, list);
    }
  }

  /// Remove event key from pending list
  Future<void> _removeFromPendingList(String eventKey) async {
    final list = _prefs.getStringList(_keyPendingList) ?? [];
    list.remove(eventKey);
    await _prefs.setStringList(_keyPendingList, list);
  }

  /// Add event key to submitted list
  Future<void> _addToSubmittedList(String eventKey) async {
    final list = _prefs.getStringList(_keySubmittedList) ?? [];
    if (!list.contains(eventKey)) {
      list.insert(0, eventKey); // Add to front for newest-first order

      // Keep only last 100 submitted events to save space
      if (list.length > 100) {
        final removedKey = list.removeLast();
        await _prefs.remove(removedKey);
      }

      await _prefs.setStringList(_keySubmittedList, list);
    }
  }

  /// Remove event key from submitted list
  Future<void> _removeFromSubmittedList(String eventKey) async {
    final list = _prefs.getStringList(_keySubmittedList) ?? [];
    list.remove(eventKey);
    await _prefs.setStringList(_keySubmittedList, list);
  }
}
