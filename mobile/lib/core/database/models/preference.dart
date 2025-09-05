/// Model for storing app preferences and settings in SQLite
class Preference {
  final int? id;
  final String key;
  final String value;
  final String dataType; // 'string', 'int', 'double', 'bool'
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Preference({
    this.id,
    required this.key,
    required this.value,
    required this.dataType,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a Preference from a database row
  factory Preference.fromMap(Map<String, dynamic> map) {
    return Preference(
      id: map['id'] as int?,
      key: map['key'] as String,
      value: map['value'] as String,
      dataType: map['data_type'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert Preference to a database row
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'key': key,
      'value': value,
      'data_type': dataType,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Helper methods to get typed values
  String get stringValue => value;

  int get intValue => int.parse(value);

  double get doubleValue => double.parse(value);

  bool get boolValue => value.toLowerCase() == 'true';

  /// Helper factory methods for different data types
  static Preference createString({
    int? id,
    required String key,
    required String value,
    String? description,
  }) {
    final now = DateTime.now();
    return Preference(
      id: id,
      key: key,
      value: value,
      dataType: 'string',
      description: description,
      createdAt: id == null ? now : now, // createdAt only set on creation
      updatedAt: now,
    );
  }

  static Preference createInt({
    int? id,
    required String key,
    required int value,
    String? description,
  }) {
    final now = DateTime.now();
    return Preference(
      id: id,
      key: key,
      value: value.toString(),
      dataType: 'int',
      description: description,
      createdAt: id == null ? now : now,
      updatedAt: now,
    );
  }

  static Preference createDouble({
    int? id,
    required String key,
    required double value,
    String? description,
  }) {
    final now = DateTime.now();
    return Preference(
      id: id,
      key: key,
      value: value.toString(),
      dataType: 'double',
      description: description,
      createdAt: id == null ? now : now,
      updatedAt: now,
    );
  }

  static Preference createBool({
    int? id,
    required String key,
    required bool value,
    String? description,
  }) {
    final now = DateTime.now();
    return Preference(
      id: id,
      key: key,
      value: value.toString(),
      dataType: 'bool',
      description: description,
      createdAt: id == null ? now : now,
      updatedAt: now,
    );
  }

  /// Create a copy with updated values
  Preference copyWith({
    int? id,
    String? key,
    String? value,
    String? dataType,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Preference(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      dataType: dataType ?? this.dataType,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Always update timestamp when copied
    );
  }

  @override
  String toString() {
    return 'Preference(id: $id, key: $key, value: $value, dataType: $dataType, description: $description)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preference &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          key == other.key &&
          value == other.value &&
          dataType == other.dataType;

  @override
  int get hashCode =>
      id.hashCode ^ key.hashCode ^ value.hashCode ^ dataType.hashCode;
}

/// Predefined preference keys for type safety
class PreferenceKeys {
  // Theme Settings
  static const String isDarkMode = 'is_dark_mode';
  
  // Location Settings  
  static const String locationPermissionGranted = 'location_permission_granted';
  static const String locationAccuracy = 'location_accuracy';
  
  // Audio Settings
  static const String calibrationOffset = 'calibration_offset';
  
  // Sync Settings
  static const String backendUrl = 'backend_url';
  static const String autoSubmissionEnabled = 'auto_submission_enabled';
  static const String submissionIntervalMinutes = 'submission_interval_minutes';
  
  // Privacy Settings
  static const String privacyMode = 'privacy_mode';
  
  // Monitoring Settings
  static const String noiseThreshold = 'noise_threshold';
  static const String recordingDuration = 'recording_duration_seconds';
  static const String maxRecordings = 'max_recordings_count';
  
  // UI Settings
  static const String showAdvancedStats = 'show_advanced_stats';
  static const String chartTimeSpan = 'chart_time_span_hours';
  static const String enableNotifications = 'enable_notifications';
  static const String languageCode = 'language_code';

  /// Get all default preferences with their default values
  static List<Preference> getDefaults() {
    return [
      // Theme
      Preference.createBool(
        key: isDarkMode,
        value: true,
        description: 'Enable dark mode theme',
      ),
      
      // Location
      Preference.createBool(
        key: locationPermissionGranted,
        value: false,
        description: 'Location permission status',
      ),
      Preference.createString(
        key: locationAccuracy,
        value: 'high',
        description: 'GPS accuracy level (low, high, balanced)',
      ),
      
      // Audio
      Preference.createDouble(
        key: calibrationOffset,
        value: 0.0,
        description: 'Audio calibration offset in dB',
      ),
      
      // Sync
      Preference.createString(
        key: backendUrl,
        value: 'http://localhost:8000/api/v1',
        description: 'Backend server URL for data sync',
      ),
      Preference.createBool(
        key: autoSubmissionEnabled,
        value: true,
        description: 'Auto-submit noise events to server',
      ),
      Preference.createInt(
        key: submissionIntervalMinutes,
        value: 5,
        description: 'Interval between auto-submissions in minutes',
      ),
      
      // Privacy
      Preference.createBool(
        key: privacyMode,
        value: false,
        description: 'Enable privacy mode (limits data collection)',
      ),
      
      // Monitoring
      Preference.createDouble(
        key: noiseThreshold,
        value: 55.0,
        description: 'Noise level threshold for event detection (dB)',
      ),
      Preference.createInt(
        key: recordingDuration,
        value: 900, // 15 minutes
        description: 'Audio recording duration in seconds',
      ),
      Preference.createInt(
        key: maxRecordings,
        value: 3,
        description: 'Maximum number of concurrent recordings',
      ),
      
      // UI
      Preference.createBool(
        key: showAdvancedStats,
        value: false,
        description: 'Show advanced noise statistics',
      ),
      Preference.createInt(
        key: chartTimeSpan,
        value: 24,
        description: 'Chart time span in hours',
      ),
      Preference.createBool(
        key: enableNotifications,
        value: true,
        description: 'Enable push notifications',
      ),
      Preference.createString(
        key: languageCode,
        value: 'en',
        description: 'App language code',
      ),
    ];
  }
}