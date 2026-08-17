import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preference.dart';

/// Web-compatible PreferencesDao backed by SharedPreferences (localStorage).
///
/// The native implementation stores preferences in SQLite (see
/// preferences_dao_io.dart). On the web there is no sqflite/path_provider
/// implementation, so this variant persists the same data as JSON values in
/// SharedPreferences. The public API is identical, so callers cannot tell the
/// difference.
class PreferencesDao {
  static final PreferencesDao _instance = PreferencesDao._internal();
  factory PreferencesDao() => _instance;
  PreferencesDao._internal();

  static const String _prefix = 'pref_';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<int> insert(Preference preference) async {
    final prefs = await _prefs;
    await prefs.setString(_prefix + preference.key, json.encode(preference.toMap()));
    return 1;
  }

  Future<void> insertAll(List<Preference> preferences) async {
    for (final preference in preferences) {
      await insert(preference);
    }
  }

  Future<Preference?> getByKey(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    try {
      return Preference.fromMap(json.decode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ PreferencesDao(web): failed to decode $key: $e');
      return null;
    }
  }

  Future<List<Preference>> getAll() async {
    final prefs = await _prefs;
    final result = <Preference>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        result.add(Preference.fromMap(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // ignore corrupt entries
      }
    }
    result.sort((a, b) => a.key.compareTo(b.key));
    return result;
  }

  Future<List<Preference>> getByType(String dataType) async {
    final all = await getAll();
    return all.where((p) => p.dataType == dataType).toList();
  }

  Future<int> updateByKey(String key, Preference preference) =>
      insert(preference);

  /// Upsert (insert or update) a preference
  Future<void> upsert(Preference preference) async {
    final existing = await getByKey(preference.key);
    if (existing != null) {
      final updated = preference.copyWith(
        id: existing.id,
        createdAt: existing.createdAt,
      );
      await updateByKey(preference.key, updated);
    } else {
      await insert(preference);
    }
  }

  Future<int> deleteByKey(String key) async {
    final prefs = await _prefs;
    final removed = await prefs.remove(_prefix + key);
    return removed ? 1 : 0;
  }

  Future<int> deleteAll() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    return keys.length;
  }

  Future<Map<String, Preference>> getAllAsMap() async {
    final preferences = await getAll();
    final Map<String, Preference> prefMap = {};
    for (final pref in preferences) {
      prefMap[pref.key] = pref;
    }
    return prefMap;
  }

  // Typed getter methods for common preferences

  Future<String> getString(String key, {String defaultValue = ''}) async {
    final pref = await getByKey(key);
    return pref?.stringValue ?? defaultValue;
  }

  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final pref = await getByKey(key);
    return pref?.intValue ?? defaultValue;
  }

  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    final pref = await getByKey(key);
    return pref?.doubleValue ?? defaultValue;
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final pref = await getByKey(key);
    return pref?.boolValue ?? defaultValue;
  }

  // Typed setter methods for common preferences

  Future<void> setString(String key, String value, {String? description}) async {
    await upsert(Preference.createString(key: key, value: value, description: description));
  }

  Future<void> setInt(String key, int value, {String? description}) async {
    await upsert(Preference.createInt(key: key, value: value, description: description));
  }

  Future<void> setDouble(String key, double value, {String? description}) async {
    await upsert(Preference.createDouble(key: key, value: value, description: description));
  }

  Future<void> setBool(String key, bool value, {String? description}) async {
    await upsert(Preference.createBool(key: key, value: value, description: description));
  }

  Future<bool> exists(String key) async {
    final pref = await getByKey(key);
    return pref != null;
  }

  Future<int> count() async {
    final prefs = await _prefs;
    return prefs.getKeys().where((k) => k.startsWith(_prefix)).length;
  }

  Future<List<Preference>> searchByKeyPattern(String pattern) async {
    final all = await getAll();
    return all.where((p) => p.key.contains(pattern)).toList();
  }

  /// Initialize default preferences if they don't exist
  Future<void> initializeDefaults() async {
    debugPrint('🔧 PreferencesDao(web): Initializing default preferences...');
    try {
      final existingCount = await count();
      if (existingCount == 0) {
        debugPrint('🔧 PreferencesDao(web): No preferences found, inserting defaults...');
        await insertAll(PreferenceKeys.getDefaults());
        debugPrint('🔧 PreferencesDao(web): Inserted ${await count()} default preferences');
      } else {
        debugPrint('🔧 PreferencesDao(web): Found $existingCount existing preferences');
      }
    } catch (e) {
      debugPrint('❌ PreferencesDao(web): Error initializing defaults - $e');
      rethrow;
    }
  }

  /// Reset preferences to defaults (for settings reset)
  Future<void> resetToDefaults() async {
    debugPrint('🔄 PreferencesDao(web): Resetting preferences to defaults...');
    try {
      await deleteAll();
      await insertAll(PreferenceKeys.getDefaults());
      debugPrint('✅ PreferencesDao(web): Successfully reset to defaults');
    } catch (e) {
      debugPrint('❌ PreferencesDao(web): Error resetting to defaults - $e');
      rethrow;
    }
  }

  /// Export preferences to Map (for backup/debugging)
  Future<Map<String, dynamic>> exportToMap() async {
    final preferences = await getAll();
    final Map<String, dynamic> exportData = {};
    for (final pref in preferences) {
      switch (pref.dataType) {
        case 'string':
          exportData[pref.key] = pref.stringValue;
          break;
        case 'int':
          exportData[pref.key] = pref.intValue;
          break;
        case 'double':
          exportData[pref.key] = pref.doubleValue;
          break;
        case 'bool':
          exportData[pref.key] = pref.boolValue;
          break;
        default:
          exportData[pref.key] = pref.value;
      }
    }
    return exportData;
  }
}

/// Convenience extension for easier typed access (same as io variant)
extension PreferencesDaoExtensions on PreferencesDao {
  // Theme preferences
  Future<bool> getIsDarkMode() => getBool(PreferenceKeys.isDarkMode, defaultValue: true);
  Future<void> setIsDarkMode(bool value) => setBool(PreferenceKeys.isDarkMode, value, description: 'Enable dark mode theme');

  // Location preferences
  Future<bool> getLocationPermissionGranted() => getBool(PreferenceKeys.locationPermissionGranted, defaultValue: false);
  Future<void> setLocationPermissionGranted(bool value) => setBool(PreferenceKeys.locationPermissionGranted, value);

  Future<String> getLocationAccuracy() => getString(PreferenceKeys.locationAccuracy, defaultValue: 'high');
  Future<void> setLocationAccuracy(String value) => setString(PreferenceKeys.locationAccuracy, value);

  // Audio preferences
  Future<double> getCalibrationOffset() => getDouble(PreferenceKeys.calibrationOffset, defaultValue: 0.0);
  Future<void> setCalibrationOffset(double value) => setDouble(PreferenceKeys.calibrationOffset, value, description: 'Audio calibration offset in dB');

  // Sync preferences
  Future<String> getBackendUrl() => getString(PreferenceKeys.backendUrl, defaultValue: 'http://localhost:8100/api/v1');
  Future<void> setBackendUrl(String value) => setString(PreferenceKeys.backendUrl, value, description: 'Backend server URL for data sync');

  Future<bool> getAutoSubmissionEnabled() => getBool(PreferenceKeys.autoSubmissionEnabled, defaultValue: true);
  Future<void> setAutoSubmissionEnabled(bool value) => setBool(PreferenceKeys.autoSubmissionEnabled, value);

  Future<int> getSubmissionIntervalMinutes() => getInt(PreferenceKeys.submissionIntervalMinutes, defaultValue: 5);
  Future<void> setSubmissionIntervalMinutes(int value) => setInt(PreferenceKeys.submissionIntervalMinutes, value);

  // Privacy preferences
  Future<bool> getPrivacyMode() => getBool(PreferenceKeys.privacyMode, defaultValue: false);
  Future<void> setPrivacyMode(bool value) => setBool(PreferenceKeys.privacyMode, value);

  // Network preferences
  Future<bool> getForceOfflineMode() => getBool(PreferenceKeys.forceOfflineMode, defaultValue: false);
  Future<void> setForceOfflineMode(bool value) => setBool(PreferenceKeys.forceOfflineMode, value);
}
