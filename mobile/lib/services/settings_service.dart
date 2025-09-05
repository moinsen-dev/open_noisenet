import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  // Settings keys
  static const String _keyIsDarkMode = 'is_dark_mode';
  static const String _keyLocationPermissionGranted = 'location_permission_granted';
  static const String _keyLocationAccuracy = 'location_accuracy';
  static const String _keyCalibrationOffset = 'calibration_offset';
  static const String _keyBackendUrl = 'backend_url';
  static const String _keyAutoSubmissionEnabled = 'auto_submission_enabled';
  static const String _keySubmissionInterval = 'submission_interval_minutes';
  static const String _keyPrivacyMode = 'privacy_mode';

  /// Initialize the settings service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  void _ensureInitialized() {
    if (_prefs == null) {
      throw Exception('SettingsService not initialized. Call initialize() first.');
    }
  }

  // Theme Settings
  bool get isDarkMode {
    _ensureInitialized();
    return _prefs!.getBool(_keyIsDarkMode) ?? true; // Default to dark mode
  }

  Future<bool> setIsDarkMode(bool isDarkMode) async {
    _ensureInitialized();
    return await _prefs!.setBool(_keyIsDarkMode, isDarkMode);
  }

  // Location Settings
  bool get isLocationPermissionGranted {
    _ensureInitialized();
    return _prefs!.getBool(_keyLocationPermissionGranted) ?? false;
  }

  Future<bool> setLocationPermissionGranted(bool granted) async {
    _ensureInitialized();
    return await _prefs!.setBool(_keyLocationPermissionGranted, granted);
  }

  LocationAccuracy get locationAccuracy {
    _ensureInitialized();
    final accuracyString = _prefs!.getString(_keyLocationAccuracy) ?? 'high';
    return LocationAccuracy.values.firstWhere(
      (accuracy) => accuracy.name == accuracyString,
      orElse: () => LocationAccuracy.high,
    );
  }

  Future<bool> setLocationAccuracy(LocationAccuracy accuracy) async {
    _ensureInitialized();
    return await _prefs!.setString(_keyLocationAccuracy, accuracy.name);
  }

  // Audio Settings
  double get calibrationOffset {
    _ensureInitialized();
    return _prefs!.getDouble(_keyCalibrationOffset) ?? 0.0;
  }

  Future<bool> setCalibrationOffset(double offset) async {
    _ensureInitialized();
    return await _prefs!.setDouble(_keyCalibrationOffset, offset);
  }

  // Sync Settings
  String get backendUrl {
    _ensureInitialized();
    return _prefs!.getString(_keyBackendUrl) ?? 'http://localhost:8000/api/v1';
  }

  Future<bool> setBackendUrl(String url) async {
    _ensureInitialized();
    return await _prefs!.setString(_keyBackendUrl, url);
  }

  bool get isAutoSubmissionEnabled {
    _ensureInitialized();
    return _prefs!.getBool(_keyAutoSubmissionEnabled) ?? true;
  }

  Future<bool> setAutoSubmissionEnabled(bool enabled) async {
    _ensureInitialized();
    return await _prefs!.setBool(_keyAutoSubmissionEnabled, enabled);
  }

  int get submissionIntervalMinutes {
    _ensureInitialized();
    return _prefs!.getInt(_keySubmissionInterval) ?? 5;
  }

  Future<bool> setSubmissionIntervalMinutes(int minutes) async {
    _ensureInitialized();
    return await _prefs!.setInt(_keySubmissionInterval, minutes);
  }

  // Privacy Settings
  bool get isPrivacyMode {
    _ensureInitialized();
    return _prefs!.getBool(_keyPrivacyMode) ?? false;
  }

  Future<bool> setPrivacyMode(bool enabled) async {
    _ensureInitialized();
    return await _prefs!.setBool(_keyPrivacyMode, enabled);
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _ensureInitialized();
    await _prefs!.clear();
  }

  /// Get all settings as a map for debugging
  Map<String, dynamic> getAllSettings() {
    _ensureInitialized();
    return {
      'isDarkMode': isDarkMode,
      'isLocationPermissionGranted': isLocationPermissionGranted,
      'locationAccuracy': locationAccuracy.name,
      'calibrationOffset': calibrationOffset,
      'backendUrl': backendUrl,
      'isAutoSubmissionEnabled': isAutoSubmissionEnabled,
      'submissionIntervalMinutes': submissionIntervalMinutes,
      'isPrivacyMode': isPrivacyMode,
    };
  }
}

/// Location accuracy options for settings
enum LocationAccuracy {
  low, // Network-based, battery efficient
  high, // GPS-based, most accurate
  balanced, // Balanced accuracy and battery
}