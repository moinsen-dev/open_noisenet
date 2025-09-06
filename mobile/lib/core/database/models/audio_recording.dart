import 'package:json_annotation/json_annotation.dart';

part 'audio_recording.g.dart';

/// Trigger types for recordings
enum RecordingTriggerType {
  manual,    // User started recording manually
  threshold, // Triggered by noise threshold
  sustained, // Triggered by sustained noise
  scheduled, // Triggered by schedule
}

/// Priority levels for recordings
enum RecordingPriority {
  low,      // 1 - Normal recordings
  medium,   // 2 - Interesting noise events
  high,     // 3 - Significant noise pollution
  critical, // 4 - Urgent noise violations
}

@JsonSerializable()
class AudioRecording {
  final String id;
  @JsonKey(name: 'event_id')
  final String? eventId;
  @JsonKey(name: 'timestamp_start')
  final int timestampStart;
  @JsonKey(name: 'timestamp_end')
  final int timestampEnd;
  @JsonKey(name: 'duration_seconds')
  final int durationSeconds;
  @JsonKey(name: 'file_path')
  final String filePath;
  @JsonKey(name: 'file_size')
  final int? fileSize;
  @JsonKey(name: 'sample_rate')
  final int? sampleRate;
  final String format; // wav, opus, etc.
  @JsonKey(name: 'is_analyzed')
  final bool isAnalyzed;
  @JsonKey(name: 'analysis_result')
  final String? analysisResult; // JSON string
  @JsonKey(name: 'created_at')
  final int createdAt;
  @JsonKey(name: 'expires_at')
  final int expiresAt;
  // New fields for continuous recording
  @JsonKey(name: 'trigger_type')
  final String triggerType; // manual, threshold, sustained, scheduled
  @JsonKey(name: 'peak_level')
  final double? peakLevel; // highest dB during recording
  @JsonKey(name: 'avg_level')
  final double? avgLevel; // average dB level
  @JsonKey(name: 'noise_events')
  final String? noiseEvents; // JSON array of detected events
  final int priority; // 1=low, 2=medium, 3=high, 4=critical

  const AudioRecording({
    required this.id,
    this.eventId,
    required this.timestampStart,
    required this.timestampEnd,
    required this.durationSeconds,
    required this.filePath,
    this.fileSize,
    this.sampleRate,
    this.format = 'wav',
    this.isAnalyzed = false,
    this.analysisResult,
    required this.createdAt,
    required this.expiresAt,
    // New fields for continuous recording
    this.triggerType = 'manual',
    this.peakLevel,
    this.avgLevel,
    this.noiseEvents,
    this.priority = 1, // default to low priority
  });

  /// Create from database map
  factory AudioRecording.fromMap(Map<String, dynamic> map) {
    return AudioRecording(
      id: map['id'] as String,
      eventId: map['event_id'] as String?,
      timestampStart: map['timestamp_start'] as int,
      timestampEnd: map['timestamp_end'] as int,
      durationSeconds: map['duration_seconds'] as int,
      filePath: map['file_path'] as String,
      fileSize: map['file_size'] as int?,
      sampleRate: map['sample_rate'] as int?,
      format: map['format'] as String? ?? 'wav',
      isAnalyzed: (map['is_analyzed'] as int? ?? 0) == 1,
      analysisResult: map['analysis_result'] as String?,
      createdAt: map['created_at'] as int,
      expiresAt: map['expires_at'] as int,
      // New fields with safe defaults
      triggerType: map['trigger_type'] as String? ?? 'manual',
      peakLevel: map['peak_level'] as double?,
      avgLevel: map['avg_level'] as double?,
      noiseEvents: map['noise_events'] as String?,
      priority: map['priority'] as int? ?? 1,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'timestamp_start': timestampStart,
      'timestamp_end': timestampEnd,
      'duration_seconds': durationSeconds,
      'file_path': filePath,
      'file_size': fileSize,
      'sample_rate': sampleRate,
      'format': format,
      'is_analyzed': isAnalyzed ? 1 : 0,
      'analysis_result': analysisResult,
      'created_at': createdAt,
      'expires_at': expiresAt,
      // New fields
      'trigger_type': triggerType,
      'peak_level': peakLevel,
      'avg_level': avgLevel,
      'noise_events': noiseEvents,
      'priority': priority,
    };
  }

  /// Get start DateTime
  DateTime get startDateTime => DateTime.fromMillisecondsSinceEpoch(timestampStart * 1000);

  /// Get end DateTime
  DateTime get endDateTime => DateTime.fromMillisecondsSinceEpoch(timestampEnd * 1000);

  /// Get creation DateTime
  DateTime get createdDateTime => DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  /// Get expiration DateTime
  DateTime get expiresDateTime => DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);

  /// Check if recording has expired
  bool get hasExpired => DateTime.now().isAfter(expiresDateTime);

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    final kb = fileSize! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Get parsed analysis result
  Map<String, dynamic>? get parsedAnalysisResult {
    if (analysisResult == null) return null;
    try {
      return _parseJson(analysisResult!);
    } catch (e) {
      return null;
    }
  }

  /// Get parsed noise events
  List<Map<String, dynamic>>? get parsedNoiseEvents {
    if (noiseEvents == null) return null;
    try {
      // This would need proper JSON parsing implementation
      // For now, return empty list
      return [];
    } catch (e) {
      return null;
    }
  }

  /// Get trigger type as enum
  RecordingTriggerType get triggerTypeEnum {
    switch (triggerType.toLowerCase()) {
      case 'threshold':
        return RecordingTriggerType.threshold;
      case 'sustained':
        return RecordingTriggerType.sustained;
      case 'scheduled':
        return RecordingTriggerType.scheduled;
      default:
        return RecordingTriggerType.manual;
    }
  }

  /// Get priority as enum
  RecordingPriority get priorityEnum {
    switch (priority) {
      case 2:
        return RecordingPriority.medium;
      case 3:
        return RecordingPriority.high;
      case 4:
        return RecordingPriority.critical;
      default:
        return RecordingPriority.low;
    }
  }

  /// Check if this recording was triggered automatically
  bool get isAutoTriggered => triggerTypeEnum != RecordingTriggerType.manual;

  /// Helper method to parse JSON
  Map<String, dynamic> _parseJson(String jsonString) {
    // This would need proper JSON parsing implementation
    // For now, return empty map
    return {};
  }

  /// Create copy with updated values
  AudioRecording copyWith({
    String? id,
    String? eventId,
    int? timestampStart,
    int? timestampEnd,
    int? durationSeconds,
    String? filePath,
    int? fileSize,
    int? sampleRate,
    String? format,
    bool? isAnalyzed,
    String? analysisResult,
    int? createdAt,
    int? expiresAt,
    String? triggerType,
    double? peakLevel,
    double? avgLevel,
    String? noiseEvents,
    int? priority,
  }) {
    return AudioRecording(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      timestampStart: timestampStart ?? this.timestampStart,
      timestampEnd: timestampEnd ?? this.timestampEnd,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      sampleRate: sampleRate ?? this.sampleRate,
      format: format ?? this.format,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
      analysisResult: analysisResult ?? this.analysisResult,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      triggerType: triggerType ?? this.triggerType,
      peakLevel: peakLevel ?? this.peakLevel,
      avgLevel: avgLevel ?? this.avgLevel,
      noiseEvents: noiseEvents ?? this.noiseEvents,
      priority: priority ?? this.priority,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$AudioRecordingToJson(this);

  /// Create from JSON
  factory AudioRecording.fromJson(Map<String, dynamic> json) =>
      _$AudioRecordingFromJson(json);

  @override
  String toString() {
    return 'AudioRecording($id, ${startDateTime.toIso8601String()}, ${durationSeconds}s, $format)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioRecording && 
           other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}