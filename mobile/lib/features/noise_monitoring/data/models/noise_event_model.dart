import 'package:json_annotation/json_annotation.dart';

import '../../../../services/event_detection_service.dart';
import '../../../../services/location_service.dart';

part 'noise_event_model.g.dart';

@JsonSerializable()
class NoiseEventModel {
  /// Unique identifier for the event (UUID)
  final String? id;
  
  /// Device ID that recorded the event
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
  
  /// Processing status
  final String status;
  
  /// Local-only fields (not sent to server)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isSubmitted;
  
  @JsonKey(includeFromJson: false, includeToJson: false)
  final DateTime? localTimestamp;
  
  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? retryCount;
  
  const NoiseEventModel({
    this.id,
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
    this.status = 'pending',
    this.isSubmitted = false,
    this.localTimestamp,
    this.retryCount = 0,
  });
  
  /// Create from detection service event
  factory NoiseEventModel.fromDetectedEvent(
    NoiseEvent event, {
    required String deviceId,
    LocationData? location,
    Map<String, dynamic>? metadata,
  }) {
    return NoiseEventModel(
      deviceId: deviceId,
      timestampStart: event.startTime,
      timestampEnd: event.endTime,
      leqDb: event.averageLeqDb,
      lmaxDb: event.maxLevelDb,
      lminDb: event.minLevelDb,
      laeqDb: event.averageLeqDb, // A-weighted equivalent (using same value for now)
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
      localTimestamp: DateTime.now(),
    );
  }
  
  /// Create copy with updated fields
  NoiseEventModel copyWith({
    String? id,
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
    String? status,
    bool? isSubmitted,
    DateTime? localTimestamp,
    int? retryCount,
  }) {
    return NoiseEventModel(
      id: id ?? this.id,
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
      status: status ?? this.status,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      localTimestamp: localTimestamp ?? this.localTimestamp,
      retryCount: retryCount ?? this.retryCount,
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
    json['localTimestamp'] = localTimestamp?.toIso8601String();
    json['retryCount'] = retryCount;
    return json;
  }
  
  /// Create from local storage JSON
  factory NoiseEventModel.fromLocalJson(Map<String, dynamic> json) {
    final event = NoiseEventModel.fromJson(json);
    return event.copyWith(
      isSubmitted: json['isSubmitted'] as bool? ?? false,
      localTimestamp: json['localTimestamp'] != null 
          ? DateTime.parse(json['localTimestamp'] as String)
          : null,
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
  
  @override
  String toString() {
    return 'NoiseEventModel(${timestampStart.toIso8601String()}, ${leqDb.toStringAsFixed(1)} dB, ${duration.inSeconds}s, submitted: $isSubmitted)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoiseEventModel && 
           other.id == id &&
           other.deviceId == deviceId &&
           other.timestampStart == timestampStart;
  }
  
  @override
  int get hashCode => Object.hash(id, deviceId, timestampStart);
}