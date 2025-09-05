import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/models/preference.dart';
import 'settings_service.dart';
import 'sqlite_preferences_service.dart' as sqlite_prefs;

/// Service to migrate preferences from SharedPreferences to SQLite
class PreferencesMigrationService {
  static final PreferencesMigrationService _instance = PreferencesMigrationService._internal();
  factory PreferencesMigrationService() => _instance;
  PreferencesMigrationService._internal();

  final SettingsService _oldSettings = SettingsService();
  final sqlite_prefs.SQLitePreferencesService _newPrefs = sqlite_prefs.SQLitePreferencesService();

  /// Check if migration is needed (old SharedPreferences exist but SQLite is empty/new)
  Future<bool> needsMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasOldData = prefs.getKeys().isNotEmpty;
      
      if (!hasOldData) {
        debugPrint('🔄 Migration: No old SharedPreferences data found');
        return false;
      }
      
      // Check if new SQLite preferences are empty (only defaults)
      final sqliteCount = await _newPrefs.getPreferencesCount();
      final hasOnlyDefaults = sqliteCount == PreferenceKeys.getDefaults().length;
      
      debugPrint('🔄 Migration: SharedPreferences keys: ${prefs.getKeys().length}, SQLite preferences: $sqliteCount');
      
      return hasOldData && hasOnlyDefaults;
    } catch (e) {
      debugPrint('❌ Migration: Error checking migration needs - $e');
      return false;
    }
  }

  /// Migrate all preferences from SharedPreferences to SQLite
  Future<void> migratePreferences() async {
    debugPrint('🔄 Starting preference migration from SharedPreferences to SQLite...');
    
    try {
      // Ensure both services are initialized
      await _oldSettings.initialize();
      await _newPrefs.initialize();

      final migrationMap = await _buildMigrationMap();
      int migratedCount = 0;

      for (final entry in migrationMap.entries) {
        final key = entry.key;
        final migrator = entry.value;
        
        try {
          final migrated = await migrator();
          if (migrated) {
            migratedCount++;
            debugPrint('✅ Migrated: $key');
          }
        } catch (e) {
          debugPrint('❌ Failed to migrate $key: $e');
        }
      }

      debugPrint('✅ Migration completed: $migratedCount/${migrationMap.length} preferences migrated');

      // Optionally clean up old SharedPreferences
      await _cleanupOldPreferences();

    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      rethrow;
    }
  }

  /// Build map of migration functions for each preference
  Future<Map<String, Future<bool> Function()>> _buildMigrationMap() async {
    return {
      'is_dark_mode': () => _migrateBool(
        oldGetter: () => _oldSettings.isDarkMode,
        newSetter: (value) => _newPrefs.setIsDarkMode(value),
      ),
      
      'location_permission_granted': () => _migrateBool(
        oldGetter: () => _oldSettings.isLocationPermissionGranted,
        newSetter: (value) => _newPrefs.setLocationPermissionGranted(value),
      ),
      
      'location_accuracy': () => _migrateLocationAccuracy(),
      
      'calibration_offset': () => _migrateDouble(
        oldGetter: () => _oldSettings.calibrationOffset,
        newSetter: (value) => _newPrefs.setCalibrationOffset(value),
      ),
      
      'backend_url': () => _migrateString(
        oldGetter: () => _oldSettings.backendUrl,
        newSetter: (value) => _newPrefs.setBackendUrl(value),
      ),
      
      'auto_submission_enabled': () => _migrateBool(
        oldGetter: () => _oldSettings.isAutoSubmissionEnabled,
        newSetter: (value) => _newPrefs.setAutoSubmissionEnabled(value),
      ),
      
      'submission_interval_minutes': () => _migrateInt(
        oldGetter: () => _oldSettings.submissionIntervalMinutes,
        newSetter: (value) => _newPrefs.setSubmissionIntervalMinutes(value),
      ),
      
      'privacy_mode': () => _migrateBool(
        oldGetter: () => _oldSettings.isPrivacyMode,
        newSetter: (value) => _newPrefs.setPrivacyMode(value),
      ),
    };
  }

  /// Generic migration for bool values
  Future<bool> _migrateBool({
    required bool Function() oldGetter,
    required Future<void> Function(bool) newSetter,
  }) async {
    try {
      final value = oldGetter();
      await newSetter(value);
      return true;
    } catch (e) {
      debugPrint('❌ Bool migration error: $e');
      return false;
    }
  }

  /// Generic migration for string values
  Future<bool> _migrateString({
    required String Function() oldGetter,
    required Future<void> Function(String) newSetter,
  }) async {
    try {
      final value = oldGetter();
      await newSetter(value);
      return true;
    } catch (e) {
      debugPrint('❌ String migration error: $e');
      return false;
    }
  }

  /// Generic migration for int values
  Future<bool> _migrateInt({
    required int Function() oldGetter,
    required Future<void> Function(int) newSetter,
  }) async {
    try {
      final value = oldGetter();
      await newSetter(value);
      return true;
    } catch (e) {
      debugPrint('❌ Int migration error: $e');
      return false;
    }
  }

  /// Generic migration for double values
  Future<bool> _migrateDouble({
    required double Function() oldGetter,
    required Future<void> Function(double) newSetter,
  }) async {
    try {
      final value = oldGetter();
      await newSetter(value);
      return true;
    } catch (e) {
      debugPrint('❌ Double migration error: $e');
      return false;
    }
  }

  /// Special migration for location accuracy enum
  Future<bool> _migrateLocationAccuracy() async {
    try {
      final oldAccuracy = _oldSettings.locationAccuracy;
      // Convert between the two enum types
      final newAccuracy = _convertLocationAccuracy(oldAccuracy);
      await _newPrefs.setLocationAccuracy(newAccuracy);
      return true;
    } catch (e) {
      debugPrint('❌ Location accuracy migration error: $e');
      return false;
    }
  }

  /// Convert from old LocationAccuracy enum to new one
  sqlite_prefs.LocationAccuracy _convertLocationAccuracy(LocationAccuracy oldAccuracy) {
    switch (oldAccuracy) {
      case LocationAccuracy.low:
        return sqlite_prefs.LocationAccuracy.low;
      case LocationAccuracy.high:
        return sqlite_prefs.LocationAccuracy.high;
      case LocationAccuracy.balanced:
        return sqlite_prefs.LocationAccuracy.balanced;
    }
  }

  /// Clean up old SharedPreferences after successful migration
  Future<void> _cleanupOldPreferences() async {
    debugPrint('🧹 Cleaning up old SharedPreferences...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // List of keys to remove (only our app's keys)
      const keysToRemove = [
        'is_dark_mode',
        'location_permission_granted', 
        'location_accuracy',
        'calibration_offset',
        'backend_url',
        'auto_submission_enabled',
        'submission_interval_minutes',
        'privacy_mode',
      ];

      int removedCount = 0;
      for (final key in keysToRemove) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
          removedCount++;
        }
      }

      debugPrint('🧹 Cleaned up $removedCount old preference keys');
    } catch (e) {
      debugPrint('❌ Cleanup error: $e');
      // Non-critical error, don't rethrow
    }
  }

  /// Create backup of old preferences before migration
  Future<Map<String, dynamic>> createBackup() async {
    debugPrint('💾 Creating backup of old SharedPreferences...');
    
    try {
      await _oldSettings.initialize();
      
      return {
        'version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'preferences': _oldSettings.getAllSettings(),
      };
    } catch (e) {
      debugPrint('❌ Backup creation error: $e');
      rethrow;
    }
  }

  /// Restore from backup if migration fails
  Future<void> restoreFromBackup(Map<String, dynamic> backup) async {
    debugPrint('🔄 Restoring from backup...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupPrefs = backup['preferences'] as Map<String, dynamic>;
      
      for (final entry in backupPrefs.entries) {
        final key = entry.key;
        final value = entry.value;
        
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        }
      }
      
      debugPrint('✅ Restored ${backupPrefs.length} preferences from backup');
    } catch (e) {
      debugPrint('❌ Restore error: $e');
      rethrow;
    }
  }

  /// Complete migration process with backup and error handling
  Future<void> performSafeMigration() async {
    debugPrint('🔄 Starting safe preference migration...');
    
    // Check if migration is needed
    if (!await needsMigration()) {
      debugPrint('ℹ️ Migration not needed, skipping...');
      return;
    }

    Map<String, dynamic>? backup;
    
    try {
      // Create backup first
      backup = await createBackup();
      debugPrint('💾 Backup created successfully');
      
      // Perform migration
      await migratePreferences();
      
      debugPrint('✅ Safe migration completed successfully');
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      
      // Attempt to restore from backup
      if (backup != null) {
        try {
          await restoreFromBackup(backup);
          debugPrint('🔄 Restored from backup after migration failure');
        } catch (restoreError) {
          debugPrint('❌ Restore also failed: $restoreError');
          // At this point, both migration and restore failed
          // App should fall back to default preferences
        }
      }
      
      rethrow;
    }
  }
}