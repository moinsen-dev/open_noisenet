import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/preference.dart';

/// Data Access Object for preferences stored in SQLite
class PreferencesDao {
  static final PreferencesDao _instance = PreferencesDao._internal();
  factory PreferencesDao() => _instance;
  PreferencesDao._internal();

  /// Insert a new preference
  Future<int> insert(Preference preference) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert(
      DatabaseHelper.tablePreferences,
      preference.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple preferences (for initial setup/defaults)
  Future<void> insertAll(List<Preference> preferences) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    
    for (final preference in preferences) {
      batch.insert(
        DatabaseHelper.tablePreferences,
        preference.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore, // Don't overwrite existing
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Get a preference by key
  Future<Preference?> getByKey(String key) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePreferences,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Preference.fromMap(maps.first);
    }
    return null;
  }

  /// Get all preferences
  Future<List<Preference>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePreferences,
      orderBy: 'key ASC',
    );

    return List.generate(maps.length, (i) => Preference.fromMap(maps[i]));
  }

  /// Get preferences by data type
  Future<List<Preference>> getByType(String dataType) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePreferences,
      where: 'data_type = ?',
      whereArgs: [dataType],
      orderBy: 'key ASC',
    );

    return List.generate(maps.length, (i) => Preference.fromMap(maps[i]));
  }

  /// Update a preference by key
  Future<int> updateByKey(String key, Preference preference) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      DatabaseHelper.tablePreferences,
      preference.toMap(),
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Upsert (insert or update) a preference
  Future<void> upsert(Preference preference) async {
    final existing = await getByKey(preference.key);
    
    if (existing != null) {
      // Update existing preference with new values but preserve creation time
      final updated = preference.copyWith(
        id: existing.id,
        createdAt: existing.createdAt,
      );
      await updateByKey(preference.key, updated);
    } else {
      // Insert new preference
      await insert(preference);
    }
  }

  /// Delete a preference by key
  Future<int> deleteByKey(String key) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      DatabaseHelper.tablePreferences,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Delete all preferences (reset to defaults)
  Future<int> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(DatabaseHelper.tablePreferences);
  }

  /// Get preferences as a Map for easy access
  Future<Map<String, Preference>> getAllAsMap() async {
    final preferences = await getAll();
    final Map<String, Preference> prefMap = {};
    
    for (final pref in preferences) {
      prefMap[pref.key] = pref;
    }
    
    return prefMap;
  }

  // Typed getter methods for common preferences

  /// Get string preference value
  Future<String> getString(String key, {String defaultValue = ''}) async {
    final pref = await getByKey(key);
    return pref?.stringValue ?? defaultValue;
  }

  /// Get int preference value
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final pref = await getByKey(key);
    return pref?.intValue ?? defaultValue;
  }

  /// Get double preference value
  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    final pref = await getByKey(key);
    return pref?.doubleValue ?? defaultValue;
  }

  /// Get bool preference value
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final pref = await getByKey(key);
    return pref?.boolValue ?? defaultValue;
  }

  // Typed setter methods for common preferences

  /// Set string preference
  Future<void> setString(String key, String value, {String? description}) async {
    await upsert(Preference.createString(
      key: key,
      value: value,
      description: description,
    ));
  }

  /// Set int preference
  Future<void> setInt(String key, int value, {String? description}) async {
    await upsert(Preference.createInt(
      key: key,
      value: value,
      description: description,
    ));
  }

  /// Set double preference
  Future<void> setDouble(String key, double value, {String? description}) async {
    await upsert(Preference.createDouble(
      key: key,
      value: value,
      description: description,
    ));
  }

  /// Set bool preference
  Future<void> setBool(String key, bool value, {String? description}) async {
    await upsert(Preference.createBool(
      key: key,
      value: value,
      description: description,
    ));
  }

  /// Check if a preference exists
  Future<bool> exists(String key) async {
    final pref = await getByKey(key);
    return pref != null;
  }

  /// Get count of all preferences
  Future<int> count() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseHelper.tablePreferences}');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Search preferences by key pattern
  Future<List<Preference>> searchByKeyPattern(String pattern) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePreferences,
      where: 'key LIKE ?',
      whereArgs: ['%$pattern%'],
      orderBy: 'key ASC',
    );

    return List.generate(maps.length, (i) => Preference.fromMap(maps[i]));
  }

  /// Initialize default preferences if they don't exist
  Future<void> initializeDefaults() async {
    debugPrint('🔧 PreferencesDao: Initializing default preferences...');
    
    try {
      final existingCount = await count();
      if (existingCount == 0) {
        debugPrint('🔧 PreferencesDao: No preferences found, inserting defaults...');
        await insertAll(PreferenceKeys.getDefaults());
        final newCount = await count();
        debugPrint('🔧 PreferencesDao: Inserted $newCount default preferences');
      } else {
        debugPrint('🔧 PreferencesDao: Found $existingCount existing preferences');
      }
    } catch (e) {
      debugPrint('❌ PreferencesDao: Error initializing defaults - $e');
      rethrow;
    }
  }

  /// Reset preferences to defaults (for settings reset)
  Future<void> resetToDefaults() async {
    debugPrint('🔄 PreferencesDao: Resetting preferences to defaults...');
    
    try {
      await deleteAll();
      await insertAll(PreferenceKeys.getDefaults());
      debugPrint('✅ PreferencesDao: Successfully reset to defaults');
    } catch (e) {
      debugPrint('❌ PreferencesDao: Error resetting to defaults - $e');
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

/// Convenience extension for easier typed access
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
  Future<String> getBackendUrl() => getString(PreferenceKeys.backendUrl, defaultValue: 'http://localhost:8000/api/v1');
  Future<void> setBackendUrl(String value) => setString(PreferenceKeys.backendUrl, value, description: 'Backend server URL for data sync');

  Future<bool> getAutoSubmissionEnabled() => getBool(PreferenceKeys.autoSubmissionEnabled, defaultValue: true);
  Future<void> setAutoSubmissionEnabled(bool value) => setBool(PreferenceKeys.autoSubmissionEnabled, value);

  Future<int> getSubmissionIntervalMinutes() => getInt(PreferenceKeys.submissionIntervalMinutes, defaultValue: 5);
  Future<void> setSubmissionIntervalMinutes(int value) => setInt(PreferenceKeys.submissionIntervalMinutes, value);

  // Privacy preferences
  Future<bool> getPrivacyMode() => getBool(PreferenceKeys.privacyMode, defaultValue: false);
  Future<void> setPrivacyMode(bool value) => setBool(PreferenceKeys.privacyMode, value);
}