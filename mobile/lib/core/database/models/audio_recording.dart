import 'package:json_annotation/json_annotation.dart';

part 'audio_recording.g.dart';

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