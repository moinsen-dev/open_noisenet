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
      await _addToSubmittedList(key);
    } else {
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
  Future<void> markEventAsSubmitted(NoiseEventModel event, String? serverId) async {
    final updatedEvent = event.copyWith(
      id: serverId ?? event.id,
      isSubmitted: true,
      status: 'processed',
    );
    
    final key = _generateEventKey(event);
    
    // Remove from pending list
    await _removeFromPendingList(key);
    
    // Save updated event
    await saveEvent(updatedEvent);
    
    AppLogger.database('Marked event as submitted: $key');
  }
  
  /// Update event retry count
  Future<void> updateEventRetryCount(NoiseEventModel event, int retryCount) async {
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
    final allKeys = [...(_prefs.getStringList(_keyPendingList) ?? []), 
                     ...(_prefs.getStringList(_keySubmittedList) ?? [])];
    
    for (final key in allKeys) {
      await _prefs.remove(key);
    }
    
    await _prefs.remove(_keyPendingList);
    await _prefs.remove(_keySubmittedList);
    
    AppLogger.database('Cleared all events');
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
      'averageLeq': allLeqValues.isEmpty ? 0.0 : 
          allLeqValues.reduce((a, b) => a + b) / allLeqValues.length,
      'maxLeq': allLeqValues.isEmpty ? 0.0 : allLeqValues.reduce((a, b) => a > b ? a : b),
      'oldestEvent': allEvents.map((e) => e.timestampStart).reduce((a, b) => a.isBefore(b) ? a : b),
      'newestEvent': allEvents.map((e) => e.timestampStart).reduce((a, b) => a.isAfter(b) ? a : b),
    };
  }
  
  /// Generate unique key for event storage
  String _generateEventKey(NoiseEventModel event) {
    return '$_keyPrefix${event.deviceId}_${event.timestampStart.millisecondsSinceEpoch}';
  }
  
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