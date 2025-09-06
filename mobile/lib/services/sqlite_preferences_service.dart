import 'package:flutter/material.dart';

import '../core/database/dao/preferences_dao.dart';
import '../core/database/models/preference.dart';

/// SQLite-based preferences service for centralized app settings management
/// This replaces the SharedPreferences-based SettingsService
class SQLitePreferencesService {
  static final SQLitePreferencesService _instance = SQLitePreferencesService._internal();
  factory SQLitePreferencesService() => _instance;
  SQLitePreferencesService._internal();

  final PreferencesDao _dao = PreferencesDao();
  bool _isInitialized = false;

  /// Initialize the service and set up default preferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('🔧 SQLitePreferencesService: Initializing...');
    
    try {
      await _dao.initializeDefaults();
      _isInitialized = true;
      debugPrint('✅ SQLitePreferencesService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ SQLitePreferencesService: Failed to initialize - $e');
      rethrow;
    }
  }

  /// Ensure service is initialized before operations
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('SQLitePreferencesService not initialized. Call initialize() first.');
    }
  }

  // THEME SETTINGS
  
  /// Get dark mode preference
  Future<bool> getIsDarkMode() async {
    _ensureInitialized();
    return await _dao.getIsDarkMode();
  }

  /// Set dark mode preference
  Future<void> setIsDarkMode(bool isDarkMode) async {
    _ensureInitialized();
    await _dao.setIsDarkMode(isDarkMode);
    debugPrint('🎨 Theme: Dark mode set to $isDarkMode');
  }

  // LOCATION SETTINGS

  /// Get location permission status
  Future<bool> getLocationPermissionGranted() async {
    _ensureInitialized();
    return await _dao.getLocationPermissionGranted();
  }

  /// Set location permission status
  Future<void> setLocationPermissionGranted(bool granted) async {
    _ensureInitialized();
    await _dao.setLocationPermissionGranted(granted);
    debugPrint('📍 Location: Permission set to $granted');
  }

  /// Get location accuracy setting
  Future<LocationAccuracy> getLocationAccuracy() async {
    _ensureInitialized();
    final accuracyString = await _dao.getLocationAccuracy();
    return LocationAccuracy.values.firstWhere(
      (accuracy) => accuracy.name == accuracyString,
      orElse: () => LocationAccuracy.high,
    );
  }

  /// Set location accuracy setting
  Future<void> setLocationAccuracy(LocationAccuracy accuracy) async {
    _ensureInitialized();
    await _dao.setLocationAccuracy(accuracy.name);
    debugPrint('📍 Location: Accuracy set to ${accuracy.name}');
  }

  // AUDIO SETTINGS

  /// Get audio calibration offset
  Future<double> getCalibrationOffset() async {
    _ensureInitialized();
    return await _dao.getCalibrationOffset();
  }

  /// Set audio calibration offset
  Future<void> setCalibrationOffset(double offset) async {
    _ensureInitialized();
    await _dao.setCalibrationOffset(offset);
    debugPrint('🎤 Audio: Calibration offset set to ${offset.toStringAsFixed(1)} dB');
  }

  /// Get noise threshold for event detection
  Future<double> getNoiseThreshold() async {
    _ensureInitialized();
    return await _dao.getDouble(PreferenceKeys.noiseThreshold, defaultValue: 55.0);
  }

  /// Set noise threshold for event detection
  Future<void> setNoiseThreshold(double threshold) async {
    _ensureInitialized();
    await _dao.setDouble(PreferenceKeys.noiseThreshold, threshold, 
        description: 'Noise level threshold for event detection (dB)');
    debugPrint('🎤 Audio: Noise threshold set to ${threshold.toStringAsFixed(1)} dB');
  }

  // SYNC SETTINGS

  /// Get backend server URL
  Future<String> getBackendUrl() async {
    _ensureInitialized();
    return await _dao.getBackendUrl();
  }

  /// Set backend server URL
  Future<void> setBackendUrl(String url) async {
    _ensureInitialized();
    await _dao.setBackendUrl(url);
    debugPrint('🌐 Sync: Backend URL set to $url');
  }

  /// Get auto-submission enabled status
  Future<bool> getAutoSubmissionEnabled() async {
    _ensureInitialized();
    return await _dao.getAutoSubmissionEnabled();
  }

  /// Set auto-submission enabled status
  Future<void> setAutoSubmissionEnabled(bool enabled) async {
    _ensureInitialized();
    await _dao.setAutoSubmissionEnabled(enabled);
    debugPrint('🔄 Sync: Auto-submission set to $enabled');
  }

  /// Get submission interval in minutes
  Future<int> getSubmissionIntervalMinutes() async {
    _ensureInitialized();
    return await _dao.getSubmissionIntervalMinutes();
  }

  /// Set submission interval in minutes
  Future<void> setSubmissionIntervalMinutes(int minutes) async {
    _ensureInitialized();
    await _dao.setSubmissionIntervalMinutes(minutes);
    debugPrint('🔄 Sync: Submission interval set to $minutes minutes');
  }

  // PRIVACY SETTINGS

  /// Get privacy mode status
  Future<bool> getPrivacyMode() async {
    _ensureInitialized();
    return await _dao.getPrivacyMode();
  }

  /// Set privacy mode status
  Future<void> setPrivacyMode(bool enabled) async {
    _ensureInitialized();
    await _dao.setPrivacyMode(enabled);
    debugPrint('🔒 Privacy: Privacy mode set to $enabled');
  }

  // RECORDING SETTINGS

  /// Get recording duration in seconds
  Future<int> getRecordingDurationSeconds() async {
    _ensureInitialized();
    return await _dao.getInt(PreferenceKeys.recordingDuration, defaultValue: 900); // 15 minutes
  }

  /// Set recording duration in seconds
  Future<void> setRecordingDurationSeconds(int seconds) async {
    _ensureInitialized();
    await _dao.setInt(PreferenceKeys.recordingDuration, seconds,
        description: 'Audio recording duration in seconds');
    debugPrint('🎙️ Recording: Duration set to ${seconds}s');
  }

  /// Get maximum recordings count
  Future<int> getMaxRecordingsCount() async {
    _ensureInitialized();
    return await _dao.getInt(PreferenceKeys.maxRecordings, defaultValue: 3);
  }

  /// Set maximum recordings count
  Future<void> setMaxRecordingsCount(int count) async {
    _ensureInitialized();
    await _dao.setInt(PreferenceKeys.maxRecordings, count,
        description: 'Maximum number of concurrent recordings');
    debugPrint('🎙️ Recording: Max recordings set to $count');
  }

  // UI SETTINGS

  /// Get show advanced stats preference
  Future<bool> getShowAdvancedStats() async {
    _ensureInitialized();
    return await _dao.getBool(PreferenceKeys.showAdvancedStats, defaultValue: false);
  }

  /// Set show advanced stats preference
  Future<void> setShowAdvancedStats(bool show) async {
    _ensureInitialized();
    await _dao.setBool(PreferenceKeys.showAdvancedStats, show,
        description: 'Show advanced noise statistics');
    debugPrint('📊 UI: Show advanced stats set to $show');
  }

  /// Get chart time span in hours
  Future<int> getChartTimeSpanHours() async {
    _ensureInitialized();
    return await _dao.getInt(PreferenceKeys.chartTimeSpan, defaultValue: 24);
  }

  /// Set chart time span in hours
  Future<void> setChartTimeSpanHours(int hours) async {
    _ensureInitialized();
    await _dao.setInt(PreferenceKeys.chartTimeSpan, hours,
        description: 'Chart time span in hours');
    debugPrint('📊 UI: Chart time span set to ${hours}h');
  }

  /// Get notifications enabled status
  Future<bool> getNotificationsEnabled() async {
    _ensureInitialized();
    return await _dao.getBool(PreferenceKeys.enableNotifications, defaultValue: true);
  }

  /// Set notifications enabled status
  Future<void> setNotificationsEnabled(bool enabled) async {
    _ensureInitialized();
    await _dao.setBool(PreferenceKeys.enableNotifications, enabled,
        description: 'Enable push notifications');
    debugPrint('🔔 UI: Notifications set to $enabled');
  }

  /// Get app language code
  Future<String> getLanguageCode() async {
    _ensureInitialized();
    return await _dao.getString(PreferenceKeys.languageCode, defaultValue: 'en');
  }

  /// Set app language code
  Future<void> setLanguageCode(String languageCode) async {
    _ensureInitialized();
    await _dao.setString(PreferenceKeys.languageCode, languageCode,
        description: 'App language code');
    debugPrint('🌐 UI: Language set to $languageCode');
  }

  // UTILITY METHODS

  /// Get all preferences as a map (for debugging/export)
  Future<Map<String, dynamic>> getAllPreferencesMap() async {
    _ensureInitialized();
    return await _dao.exportToMap();
  }

  /// Reset all preferences to default values
  Future<void> resetToDefaults() async {
    _ensureInitialized();
    debugPrint('🔄 SQLitePreferencesService: Resetting to defaults...');
    await _dao.resetToDefaults();
    debugPrint('✅ SQLitePreferencesService: Reset completed');
  }

  /// Check if a specific preference exists
  Future<bool> hasPreference(String key) async {
    _ensureInitialized();
    return await _dao.exists(key);
  }

  /// Get raw preference value (for custom preferences)
  Future<String?> getRawPreference(String key) async {
    _ensureInitialized();
    final pref = await _dao.getByKey(key);
    return pref?.value;
  }

  /// Set raw preference value (for custom preferences)
  Future<void> setRawPreference(String key, String value, String dataType, {String? description}) async {
    _ensureInitialized();
    final pref = Preference(
      key: key,
      value: value,
      dataType: dataType,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _dao.upsert(pref);
    debugPrint('⚙️ Custom: Set $key = $value ($dataType)');
  }

  /// Get preferences count
  Future<int> getPreferencesCount() async {
    _ensureInitialized();
    return await _dao.count();
  }

  /// Search preferences by key pattern
  Future<List<Preference>> searchPreferences(String pattern) async {
    _ensureInitialized();
    return await _dao.searchByKeyPattern(pattern);
  }

  /// Export all preferences for backup
  Future<Map<String, dynamic>> exportForBackup() async {
    _ensureInitialized();
    final preferences = await _dao.getAll();
    return {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'count': preferences.length,
      'preferences': preferences.map((p) => p.toMap()).toList(),
    };
  }

  /// Import preferences from backup (use with caution)
  Future<void> importFromBackup(Map<String, dynamic> backup) async {
    _ensureInitialized();
    debugPrint('📥 SQLitePreferencesService: Importing from backup...');
    
    final preferencesData = backup['preferences'] as List<dynamic>?;
    if (preferencesData == null) {
      throw ArgumentError('Invalid backup format: missing preferences');
    }

    final preferences = preferencesData
        .map((data) => Preference.fromMap(data as Map<String, dynamic>))
        .toList();

    await _dao.deleteAll();
    await _dao.insertAll(preferences);
    
    debugPrint('✅ SQLitePreferencesService: Imported ${preferences.length} preferences');
  }

  // ONBOARDING SETTINGS

  /// Get onboarding completion status
  Future<bool> getOnboardingComplete() async {
    _ensureInitialized();
    return await _dao.getBool(PreferenceKeys.onboardingComplete, defaultValue: false);
  }

  /// Set onboarding completion status
  Future<void> setOnboardingComplete(bool completed) async {
    _ensureInitialized();
    await _dao.setBool(PreferenceKeys.onboardingComplete, completed,
        description: 'Whether user has completed onboarding flow');
    debugPrint('👋 Onboarding: Complete status set to $completed');
  }
}

/// Location accuracy options (moved from old settings service)
enum LocationAccuracy {
  low,      // Network-based, battery efficient
  high,     // GPS-based, most accurate  
  balanced, // Balanced accuracy and battery
}