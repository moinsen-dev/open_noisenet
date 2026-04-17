import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/event_detection_service.dart';
import '../../../../services/location_service.dart';

part 'noise_event_model.g.dart';

class EventLifecycleState {
  static const String detectedLocal = 'detected_local';
  static const String segmentedLocal = 'segmented_local';
  static const String uploading = 'uploading';
  static const String queuedForUpload = 'queued_for_upload';
  static const String uploaded = 'uploaded';
  static const String acknowledgedByServer = 'acknowledged_by_server';
  static const String failed = 'failed';
}

class EventAnalysisState {
  static const String notStarted = 'not_started';
  static const String classifiedOnDevice = 'classified_on_device';
  static const String queuedForServerAnalysis = 'queued_for_server_analysis';
  static const String serverClassified = 'server_classified';
  static const String failed = 'failed';
}

@JsonSerializable()
class NoiseEventModel {
  /// Unique identifier for the event (UUID)
  final String? id;

  @JsonKey(name: 'event_uuid')
  final String? eventUuid;

  /// Device ID that recorded the event
  @JsonKey(name: 'device_id')
  final String deviceId;

  /// Event timing
  @JsonKey(name: 'timestamp_start')
  final DateTime timestampStart;

  @JsonKey(name: 'timestamp_end')
  final DateTime timestampEnd;

  /// Noise measurements
  @JsonKey(name: 'leq_db')
  final double leqDb; // Equivalent continuous sound level

  @JsonKey(name: 'lmax_db')
  final double? lmaxDb; // Maximum sound level

  @JsonKey(name: 'lmin_db')
  final double? lminDb; // Minimum sound level

  @JsonKey(name: 'laeq_db')
  final double? laeqDb; // A-weighted equivalent level

  @JsonKey(name: 'exceedance_pct')
  final double? exceedancePct; // Percentage of time above threshold

  /// Additional measurements
  @JsonKey(name: 'samples_count')
  final int? samplesCount;

  /// Event trigger information
  @JsonKey(name: 'rule_triggered')
  final String? ruleTriggered;

  /// Location information
  @JsonKey(name: 'location_lat')
  final double? locationLat;

  @JsonKey(name: 'location_lng')
  final double? locationLng;

  /// Location source information
  @JsonKey(name: 'location_source')
  final String? locationSource;

  @JsonKey(name: 'location_accuracy')
  final double? locationAccuracy;

  /// Additional metadata
  @JsonKey(name: 'event_metadata')
  final Map<String, dynamic>? eventMetadata;

  @JsonKey(name: 'analysis_state')
  final String analysisState;

  @JsonKey(name: 'classification_label')
  final String? classificationLabel;

  @JsonKey(name: 'classification_confidence')
  final double? classificationConfidence;

  @JsonKey(name: 'classification_source')
  final String? classificationSource;

  @JsonKey(name: 'segment_type')
  final String? segmentType;

  @JsonKey(name: 'reportability_score')
  final double? reportabilityScore;

  @JsonKey(name: 'reportability_reason')
  final String? reportabilityReason;

  @JsonKey(name: 'peak_to_average_delta_db')
  final double? peakToAverageDeltaDb;

  @JsonKey(name: 'variability_db')
  final double? variabilityDb;

  @JsonKey(name: 'threshold_exceedance_ratio')
  final double? thresholdExceedanceRatio;

  @JsonKey(name: 'analysis_updated_at')
  final DateTime? analysisUpdatedAt;

  /// Continuous recording references (new fields for Phase 3)
  @JsonKey(name: 'recording_file_id')
  final String? recordingFileId; // Reference to continuous recording file

  @JsonKey(name: 'recording_start_offset_ms')
  final int?
      recordingStartOffsetMs; // Millisecond offset in recording when event started

  @JsonKey(name: 'recording_end_offset_ms')
  final int?
      recordingEndOffsetMs; // Millisecond offset in recording when event ended

  /// Event classification fields (from Phase 2)
  @JsonKey(name: 'event_type')
  final String? eventType; // brief_disturbance, sustained_noise, etc.

  @JsonKey(name: 'event_confidence')
  final double? eventConfidence; // 0.0-1.0 confidence in classification

  @JsonKey(name: 'duration_class')
  final String? durationClass; // brief, short, medium, extended

  @JsonKey(name: 'intensity_class')
  final String? intensityClass; // moderate, loud, very_loud

  /// Processing status
  final String status;

  /// Local-only fields (not sent to server)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isSubmitted;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final String lifecycleState;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final DateTime? localTimestamp;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? retryCount;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final int uploadAttemptCount;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final DateTime? lastUploadAttemptAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final DateTime? lastUploadedAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final DateTime? serverAcknowledgedAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? serverEventId;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? lastErrorCode;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? lastErrorMessage;

  const NoiseEventModel({
    this.id,
    this.eventUuid,
    required this.deviceId,
    required this.timestampStart,
    required this.timestampEnd,
    required this.leqDb,
    this.lmaxDb,
    this.lminDb,
    this.laeqDb,
    this.exceedancePct,
    this.samplesCount,
    this.ruleTriggered,
    this.locationLat,
    this.locationLng,
    this.locationSource,
    this.locationAccuracy,
    this.eventMetadata,
    this.analysisState = EventAnalysisState.notStarted,
    this.classificationLabel,
    this.classificationConfidence,
    this.classificationSource,
    this.segmentType,
    this.reportabilityScore,
    this.reportabilityReason,
    this.peakToAverageDeltaDb,
    this.variabilityDb,
    this.thresholdExceedanceRatio,
    this.analysisUpdatedAt,
    this.status = 'pending',
    this.isSubmitted = false,
    this.lifecycleState = EventLifecycleState.segmentedLocal,
    this.localTimestamp,
    this.retryCount = 0,
    this.uploadAttemptCount = 0,
    this.lastUploadAttemptAt,
    this.lastUploadedAt,
    this.serverAcknowledgedAt,
    this.serverEventId,
    this.lastErrorCode,
    this.lastErrorMessage,
    // New continuous recording fields
    this.recordingFileId,
    this.recordingStartOffsetMs,
    this.recordingEndOffsetMs,
    this.eventType,
    this.eventConfidence,
    this.durationClass,
    this.intensityClass,
  });

  /// Create from detection service event
  factory NoiseEventModel.fromDetectedEvent(
    NoiseEvent event, {
    String? eventUuid,
    required String deviceId,
    LocationData? location,
    Map<String, dynamic>? metadata,
  }) {
    return NoiseEventModel(
      eventUuid: eventUuid ?? const Uuid().v4(),
      deviceId: deviceId,
      timestampStart: event.startTime,
      timestampEnd: event.endTime,
      leqDb: event.averageLeqDb,
      lmaxDb: event.maxLevelDb,
      lminDb: event.minLevelDb,
      laeqDb: event
          .averageLeqDb, // A-weighted equivalent (using same value for now)
      samplesCount: event.samples.length,
      ruleTriggered: event.ruleTriggered,
      locationLat: location?.latitude,
      locationLng: location?.longitude,
      locationSource: location?.source.name,
      locationAccuracy: location?.accuracy,
      eventMetadata: {
        'duration_seconds': event.duration.inSeconds,
        'sample_interval': 1.0, // Assuming 1 second intervals
        'detection_version': '1.0.0',
        ...?metadata,
      },
      analysisState: EventAnalysisState.notStarted,
      lifecycleState: EventLifecycleState.segmentedLocal,
      localTimestamp: DateTime.now(),
    );
  }

  /// Create copy with updated fields
  NoiseEventModel copyWith({
    String? id,
    String? eventUuid,
    String? deviceId,
    DateTime? timestampStart,
    DateTime? timestampEnd,
    double? leqDb,
    double? lmaxDb,
    double? lminDb,
    double? laeqDb,
    double? exceedancePct,
    int? samplesCount,
    String? ruleTriggered,
    double? locationLat,
    double? locationLng,
    String? locationSource,
    double? locationAccuracy,
    Map<String, dynamic>? eventMetadata,
    String? analysisState,
    String? classificationLabel,
    double? classificationConfidence,
    String? classificationSource,
    String? segmentType,
    double? reportabilityScore,
    String? reportabilityReason,
    double? peakToAverageDeltaDb,
    double? variabilityDb,
    double? thresholdExceedanceRatio,
    DateTime? analysisUpdatedAt,
    String? status,
    bool? isSubmitted,
    String? lifecycleState,
    DateTime? localTimestamp,
    int? retryCount,
    int? uploadAttemptCount,
    DateTime? lastUploadAttemptAt,
    DateTime? lastUploadedAt,
    DateTime? serverAcknowledgedAt,
    String? serverEventId,
    String? lastErrorCode,
    String? lastErrorMessage,
    // New continuous recording fields
    String? recordingFileId,
    int? recordingStartOffsetMs,
    int? recordingEndOffsetMs,
    String? eventType,
    double? eventConfidence,
    String? durationClass,
    String? intensityClass,
  }) {
    return NoiseEventModel(
      id: id ?? this.id,
      eventUuid: eventUuid ?? this.eventUuid,
      deviceId: deviceId ?? this.deviceId,
      timestampStart: timestampStart ?? this.timestampStart,
      timestampEnd: timestampEnd ?? this.timestampEnd,
      leqDb: leqDb ?? this.leqDb,
      lmaxDb: lmaxDb ?? this.lmaxDb,
      lminDb: lminDb ?? this.lminDb,
      laeqDb: laeqDb ?? this.laeqDb,
      exceedancePct: exceedancePct ?? this.exceedancePct,
      samplesCount: samplesCount ?? this.samplesCount,
      ruleTriggered: ruleTriggered ?? this.ruleTriggered,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationSource: locationSource ?? this.locationSource,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      eventMetadata: eventMetadata ?? this.eventMetadata,
      analysisState: analysisState ?? this.analysisState,
      classificationLabel: classificationLabel ?? this.classificationLabel,
      classificationConfidence:
          classificationConfidence ?? this.classificationConfidence,
      classificationSource: classificationSource ?? this.classificationSource,
      segmentType: segmentType ?? this.segmentType,
      reportabilityScore: reportabilityScore ?? this.reportabilityScore,
      reportabilityReason: reportabilityReason ?? this.reportabilityReason,
      peakToAverageDeltaDb: peakToAverageDeltaDb ?? this.peakToAverageDeltaDb,
      variabilityDb: variabilityDb ?? this.variabilityDb,
      thresholdExceedanceRatio:
          thresholdExceedanceRatio ?? this.thresholdExceedanceRatio,
      analysisUpdatedAt: analysisUpdatedAt ?? this.analysisUpdatedAt,
      status: status ?? this.status,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      localTimestamp: localTimestamp ?? this.localTimestamp,
      retryCount: retryCount ?? this.retryCount,
      uploadAttemptCount: uploadAttemptCount ?? this.uploadAttemptCount,
      lastUploadAttemptAt: lastUploadAttemptAt ?? this.lastUploadAttemptAt,
      lastUploadedAt: lastUploadedAt ?? this.lastUploadedAt,
      serverAcknowledgedAt: serverAcknowledgedAt ?? this.serverAcknowledgedAt,
      serverEventId: serverEventId ?? this.serverEventId,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      // New continuous recording fields
      recordingFileId: recordingFileId ?? this.recordingFileId,
      recordingStartOffsetMs:
          recordingStartOffsetMs ?? this.recordingStartOffsetMs,
      recordingEndOffsetMs: recordingEndOffsetMs ?? this.recordingEndOffsetMs,
      eventType: eventType ?? this.eventType,
      eventConfidence: eventConfidence ?? this.eventConfidence,
      durationClass: durationClass ?? this.durationClass,
      intensityClass: intensityClass ?? this.intensityClass,
    );
  }

  /// Duration of the event
  Duration get duration => timestampEnd.difference(timestampStart);

  /// Check if event has location data
  bool get hasLocation => locationLat != null && locationLng != null;

  /// Get location source as enum
  LocationSource? get locationSourceEnum {
    if (locationSource == null) return null;
    return LocationSource.values.firstWhere(
      (source) => source.name == locationSource,
      orElse: () => LocationSource.fallback,
    );
  }

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() => _$NoiseEventModelToJson(this);

  /// Create from JSON
  factory NoiseEventModel.fromJson(Map<String, dynamic> json) =>
      _$NoiseEventModelFromJson(json);

  /// Convert to local storage JSON (includes local fields)
  Map<String, dynamic> toLocalJson() {
    final json = toJson();
    json['isSubmitted'] = isSubmitted;
    json['lifecycleState'] = lifecycleState;
    json['localTimestamp'] = localTimestamp?.toIso8601String();
    json['retryCount'] = retryCount;
    json['uploadAttemptCount'] = uploadAttemptCount;
    json['lastUploadAttemptAt'] = lastUploadAttemptAt?.toIso8601String();
    json['lastUploadedAt'] = lastUploadedAt?.toIso8601String();
    json['serverAcknowledgedAt'] = serverAcknowledgedAt?.toIso8601String();
    json['serverEventId'] = serverEventId;
    json['lastErrorCode'] = lastErrorCode;
    json['lastErrorMessage'] = lastErrorMessage;
    return json;
  }

  /// Create from local storage JSON
  factory NoiseEventModel.fromLocalJson(Map<String, dynamic> json) {
    final event = NoiseEventModel.fromJson(json);
    final derivedEventUuid = event.eventUuid ??
        event.id ??
        '${event.deviceId}-${event.timestampStart.millisecondsSinceEpoch}';
    return event.copyWith(
      eventUuid: derivedEventUuid,
      isSubmitted: json['isSubmitted'] as bool? ?? false,
      analysisState: json['analysis_state'] as String? ??
          json['analysisState'] as String? ??
          event.analysisState,
      lifecycleState: json['lifecycleState'] as String? ??
          (json['isSubmitted'] as bool? ?? false
              ? EventLifecycleState.acknowledgedByServer
              : EventLifecycleState.segmentedLocal),
      localTimestamp: json['localTimestamp'] != null
          ? DateTime.parse(json['localTimestamp'] as String)
          : null,
      retryCount: json['retryCount'] as int? ?? 0,
      uploadAttemptCount: json['uploadAttemptCount'] as int? ?? 0,
      lastUploadAttemptAt: json['lastUploadAttemptAt'] != null
          ? DateTime.parse(json['lastUploadAttemptAt'] as String)
          : null,
      lastUploadedAt: json['lastUploadedAt'] != null
          ? DateTime.parse(json['lastUploadedAt'] as String)
          : null,
      serverAcknowledgedAt: json['serverAcknowledgedAt'] != null
          ? DateTime.parse(json['serverAcknowledgedAt'] as String)
          : null,
      serverEventId: json['serverEventId'] as String?,
      lastErrorCode: json['lastErrorCode'] as String?,
      lastErrorMessage: json['lastErrorMessage'] as String?,
    );
  }

  @override
  String toString() {
    return 'NoiseEventModel(${eventUuid ?? 'no-uuid'}, ${timestampStart.toIso8601String()}, ${leqDb.toStringAsFixed(1)} dB, ${duration.inSeconds}s, lifecycle: $lifecycleState, analysis: $analysisState)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoiseEventModel &&
        other.eventUuid == eventUuid &&
        other.deviceId == deviceId &&
        other.timestampStart == timestampStart;
  }

  @override
  int get hashCode => Object.hash(eventUuid, deviceId, timestampStart);
}
