import 'package:json_annotation/json_annotation.dart';

part 'ai_analysis_queue.g.dart';

enum AnalysisStatus {
  pending,
  processing,
  completed,
  failed,
}

enum AnalysisType {
  noiseClassification,
  eventDetection,
  anomalyDetection,
}

@JsonSerializable()
class AiAnalysisQueue {
  final int? id;
  @JsonKey(name: 'recording_id')
  final String recordingId;
  final AnalysisStatus status;
  @JsonKey(name: 'model_version')
  final String? modelVersion;
  @JsonKey(name: 'analysis_type')
  final AnalysisType analysisType;
  final String? result; // JSON string
  @JsonKey(name: 'confidence_score')
  final double? confidenceScore;
  @JsonKey(name: 'processed_at')
  final int? processedAt;
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  const AiAnalysisQueue({
    this.id,
    required this.recordingId,
    this.status = AnalysisStatus.pending,
    this.modelVersion,
    required this.analysisType,
    this.result,
    this.confidenceScore,
    this.processedAt,
    this.errorMessage,
  });

  /// Create from database map
  factory AiAnalysisQueue.fromMap(Map<String, dynamic> map) {
    return AiAnalysisQueue(
      id: map['id'] as int?,
      recordingId: map['recording_id'] as String,
      status: _statusFromString(map['status'] as String? ?? 'pending'),
      modelVersion: map['model_version'] as String?,
      analysisType: _analysisTypeFromString(map['analysis_type'] as String),
      result: map['result'] as String?,
      confidenceScore: map['confidence_score'] as double?,
      processedAt: map['processed_at'] as int?,
      errorMessage: map['error_message'] as String?,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'recording_id': recordingId,
      'status': status.name,
      'model_version': modelVersion,
      'analysis_type': analysisType.name,
      'result': result,
      'confidence_score': confidenceScore,
      'processed_at': processedAt,
      'error_message': errorMessage,
    };
  }

  /// Helper to convert string to AnalysisStatus
  static AnalysisStatus _statusFromString(String status) {
    switch (status) {
      case 'pending':
        return AnalysisStatus.pending;
      case 'processing':
        return AnalysisStatus.processing;
      case 'completed':
        return AnalysisStatus.completed;
      case 'failed':
        return AnalysisStatus.failed;
      default:
        return AnalysisStatus.pending;
    }
  }

  /// Helper to convert string to AnalysisType
  static AnalysisType _analysisTypeFromString(String type) {
    switch (type) {
      case 'noiseClassification':
        return AnalysisType.noiseClassification;
      case 'eventDetection':
        return AnalysisType.eventDetection;
      case 'anomalyDetection':
        return AnalysisType.anomalyDetection;
      default:
        return AnalysisType.noiseClassification;
    }
  }

  /// Get processing DateTime
  DateTime? get processedDateTime {
    if (processedAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(processedAt! * 1000);
  }

  /// Check if analysis is complete
  bool get isComplete => status == AnalysisStatus.completed;

  /// Check if analysis failed
  bool get hasFailed => status == AnalysisStatus.failed;

  /// Check if analysis is in progress
  bool get isInProgress => status == AnalysisStatus.processing;

  /// Get parsed result
  Map<String, dynamic>? get parsedResult {
    if (result == null) return null;
    try {
      return _parseJson(result!);
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

  /// Get confidence percentage
  String? get confidencePercentage {
    if (confidenceScore == null) return null;
    return '${(confidenceScore! * 100).toStringAsFixed(1)}%';
  }

  /// Create copy with updated values
  AiAnalysisQueue copyWith({
    int? id,
    String? recordingId,
    AnalysisStatus? status,
    String? modelVersion,
    AnalysisType? analysisType,
    String? result,
    double? confidenceScore,
    int? processedAt,
    String? errorMessage,
  }) {
    return AiAnalysisQueue(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      status: status ?? this.status,
      modelVersion: modelVersion ?? this.modelVersion,
      analysisType: analysisType ?? this.analysisType,
      result: result ?? this.result,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      processedAt: processedAt ?? this.processedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$AiAnalysisQueueToJson(this);

  /// Create from JSON
  factory AiAnalysisQueue.fromJson(Map<String, dynamic> json) =>
      _$AiAnalysisQueueFromJson(json);

  @override
  String toString() {
    return 'AiAnalysisQueue($recordingId, $status, ${analysisType.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiAnalysisQueue && 
           other.recordingId == recordingId &&
           other.analysisType == analysisType;
  }

  @override
  int get hashCode => Object.hash(recordingId, analysisType);
}