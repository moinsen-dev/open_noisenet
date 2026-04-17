// API data models for backend communication.

import 'package:json_annotation/json_annotation.dart';

part 'api_models.g.dart';

/// Device types supported by the backend
enum DeviceType {
  @JsonValue('smartphone')
  smartphone,
  @JsonValue('esp32')
  esp32,
  @JsonValue('raspberry_pi')
  raspberryPi,
  @JsonValue('custom')
  custom,
}

/// Event processing status
enum EventStatus {
  @JsonValue('active')
  active,
  @JsonValue('processed')
  processed,
  @JsonValue('archived')
  archived,
  @JsonValue('invalid')
  invalid,
}

/// Device registration/update model
@JsonSerializable()
class DeviceModel {
  @JsonKey(name: 'device_id')
  final String deviceId;
  final String name;
  @JsonKey(name: 'device_type')
  final DeviceType deviceType;
  @JsonKey(name: 'firmware_version')
  final String? firmwareVersion;
  @JsonKey(name: 'hardware_info')
  final Map<String, dynamic>? hardwareInfo;
  @JsonKey(name: 'calibration_offset')
  final double calibrationOffset;
  @JsonKey(name: 'location_lat')
  final double? locationLat;
  @JsonKey(name: 'location_lng')
  final double? locationLng;
  final String? address;
  @JsonKey(name: 'is_public')
  final bool isPublic;

  DeviceModel({
    required this.deviceId,
    required this.name,
    this.deviceType = DeviceType.smartphone,
    this.firmwareVersion,
    this.hardwareInfo,
    this.calibrationOffset = 0.0,
    this.locationLat,
    this.locationLng,
    this.address,
    this.isPublic = false,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceModelFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceModelToJson(this);
}

/// Noise event model for API submission
@JsonSerializable()
class NoiseEventModel {
  @JsonKey(name: 'event_uuid')
  final String? eventUuid;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'timestamp_start')
  final DateTime timestampStart;
  @JsonKey(name: 'timestamp_end')
  final DateTime timestampEnd;
  @JsonKey(name: 'leq_db')
  final double leqDb;
  @JsonKey(name: 'lmax_db')
  final double? lmaxDb;
  @JsonKey(name: 'lmin_db')
  final double? lminDb;
  @JsonKey(name: 'laeq_db')
  final double? laeqDb;
  @JsonKey(name: 'exceedance_pct')
  final double? exceedancePct;
  @JsonKey(name: 'samples_count')
  final int? samplesCount;
  @JsonKey(name: 'rule_triggered')
  final String? ruleTriggered;
  @JsonKey(name: 'location_lat')
  final double? locationLat;
  @JsonKey(name: 'location_lng')
  final double? locationLng;
  @JsonKey(name: 'weather_conditions')
  final Map<String, dynamic>? weatherConditions;
  @JsonKey(name: 'event_metadata')
  final Map<String, dynamic>? eventMetadata;
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
  @JsonKey(name: 'analysis_state')
  final String? analysisState;
  @JsonKey(name: 'analysis_updated_at')
  final DateTime? analysisUpdatedAt;

  NoiseEventModel({
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
    this.weatherConditions,
    this.eventMetadata,
    this.classificationLabel,
    this.classificationConfidence,
    this.classificationSource,
    this.segmentType,
    this.reportabilityScore,
    this.reportabilityReason,
    this.peakToAverageDeltaDb,
    this.variabilityDb,
    this.thresholdExceedanceRatio,
    this.analysisState,
    this.analysisUpdatedAt,
  });

  factory NoiseEventModel.fromJson(Map<String, dynamic> json) =>
      _$NoiseEventModelFromJson(json);
  Map<String, dynamic> toJson() => _$NoiseEventModelToJson(this);
}

class EventReceipt {
  final String eventUuid;
  final String serverEventId;
  final String deviceId;
  final String status;
  final DateTime receivedAt;
  final DateTime acknowledgedAt;
  final String analysisState;
  final String? classificationLabel;
  final double? reportabilityScore;
  final String? classificationSource;

  const EventReceipt({
    required this.eventUuid,
    required this.serverEventId,
    required this.deviceId,
    required this.status,
    required this.receivedAt,
    required this.acknowledgedAt,
    required this.analysisState,
    this.classificationLabel,
    this.reportabilityScore,
    this.classificationSource,
  });

  factory EventReceipt.fromJson(Map<String, dynamic> json) {
    return EventReceipt(
      eventUuid: json['event_uuid'] as String,
      serverEventId: json['server_event_id'] as String,
      deviceId: json['device_id'] as String,
      status: json['status'] as String,
      receivedAt: DateTime.parse(json['received_at'] as String),
      acknowledgedAt: DateTime.parse(json['acknowledged_at'] as String),
      analysisState: (json['analysis_state'] as String?) ?? 'not_started',
      classificationLabel: json['classification_label'] as String?,
      reportabilityScore: (json['reportability_score'] as num?)?.toDouble(),
      classificationSource: json['classification_source'] as String?,
    );
  }
}

class EventStatusModel {
  final String eventUuid;
  final String serverEventId;
  final String deviceId;
  final String lifecycleState;
  final String analysisState;
  final String? classificationLabel;
  final double? classificationConfidence;
  final String? classificationSource;
  final String? segmentType;
  final double? reportabilityScore;
  final String? reportabilityReason;
  final double? peakToAverageDeltaDb;
  final double? variabilityDb;
  final double? thresholdExceedanceRatio;
  final DateTime receivedAt;
  final DateTime acknowledgedAt;
  final DateTime? analysisUpdatedAt;

  const EventStatusModel({
    required this.eventUuid,
    required this.serverEventId,
    required this.deviceId,
    required this.lifecycleState,
    required this.analysisState,
    this.classificationLabel,
    this.classificationConfidence,
    this.classificationSource,
    this.segmentType,
    this.reportabilityScore,
    this.reportabilityReason,
    this.peakToAverageDeltaDb,
    this.variabilityDb,
    this.thresholdExceedanceRatio,
    required this.receivedAt,
    required this.acknowledgedAt,
    this.analysisUpdatedAt,
  });

  factory EventStatusModel.fromJson(Map<String, dynamic> json) {
    return EventStatusModel(
      eventUuid: json['event_uuid'] as String,
      serverEventId: json['server_event_id'] as String,
      deviceId: json['device_id'] as String,
      lifecycleState: json['lifecycle_state'] as String,
      analysisState: json['analysis_state'] as String,
      classificationLabel: json['classification_label'] as String?,
      classificationConfidence:
          (json['classification_confidence'] as num?)?.toDouble(),
      classificationSource: json['classification_source'] as String?,
      segmentType: json['segment_type'] as String?,
      reportabilityScore: (json['reportability_score'] as num?)?.toDouble(),
      reportabilityReason: json['reportability_reason'] as String?,
      peakToAverageDeltaDb:
          (json['peak_to_average_delta_db'] as num?)?.toDouble(),
      variabilityDb: (json['variability_db'] as num?)?.toDouble(),
      thresholdExceedanceRatio:
          (json['threshold_exceedance_ratio'] as num?)?.toDouble(),
      receivedAt: DateTime.parse(json['received_at'] as String),
      acknowledgedAt: DateTime.parse(json['acknowledged_at'] as String),
      analysisUpdatedAt: json['analysis_updated_at'] == null
          ? null
          : DateTime.parse(json['analysis_updated_at'] as String),
    );
  }
}

/// Authentication request models
@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class RegisterRequest {
  final String email;
  final String password;
  @JsonKey(name: 'full_name')
  final String fullName;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

/// Authentication response models
@JsonSerializable()
class AuthTokens {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'token_type')
  final String tokenType;
  @JsonKey(name: 'expires_in')
  final int expiresIn;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);
  Map<String, dynamic> toJson() => _$AuthTokensToJson(this);
}

/// API response wrapper
@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
  });

  factory ApiResponse.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$ApiResponseFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}

/// Device heartbeat request
@JsonSerializable()
class HeartbeatRequest {
  @JsonKey(name: 'device_id')
  final String deviceId;
  final DateTime timestamp;
  @JsonKey(name: 'location_lat')
  final double? locationLat;
  @JsonKey(name: 'location_lng')
  final double? locationLng;
  @JsonKey(name: 'battery_level')
  final double? batteryLevel;
  @JsonKey(name: 'signal_strength')
  final int? signalStrength;

  HeartbeatRequest({
    required this.deviceId,
    required this.timestamp,
    this.locationLat,
    this.locationLng,
    this.batteryLevel,
    this.signalStrength,
  });

  factory HeartbeatRequest.fromJson(Map<String, dynamic> json) =>
      _$HeartbeatRequestFromJson(json);
  Map<String, dynamic> toJson() => _$HeartbeatRequestToJson(this);
}

/// Result of connection testing with detailed information
class ConnectionTestResult {
  final bool success;
  final int? latencyMs;
  final String? error;
  final String baseUrl;

  const ConnectionTestResult({
    required this.success,
    this.latencyMs,
    this.error,
    required this.baseUrl,
  });

  @override
  String toString() {
    if (success) {
      return 'Connection successful (${latencyMs}ms)';
    } else {
      return 'Connection failed: $error';
    }
  }
}

DateTime? _parseDateTimeValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

double? _parseDoubleValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

int? _parseIntValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

String? _parseStringValue(dynamic value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}

Map<String, dynamic>? _parseMapValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return null;
}

class OrganizationResponse {
  final String id;
  final String name;
  final String slug;
  final String planTier;
  final String status;
  final String billingState;
  final String createdById;
  final String currentUserRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrganizationResponse({
    required this.id,
    required this.name,
    required this.slug,
    required this.planTier,
    required this.status,
    required this.billingState,
    required this.createdById,
    required this.currentUserRole,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizationResponse.fromJson(Map<String, dynamic> json) {
    return OrganizationResponse(
      id: json['id'].toString(),
      name: json['name'].toString(),
      slug: json['slug'].toString(),
      planTier: json['plan_tier'].toString(),
      status: json['status'].toString(),
      billingState: json['billing_state'].toString(),
      createdById: json['created_by_id'].toString(),
      currentUserRole: json['current_user_role'].toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class SiteResponse {
  final String id;
  final String organizationId;
  final String name;
  final String timezone;
  final String? address;
  final double? locationLat;
  final double? locationLng;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SiteResponse({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.timezone,
    required this.address,
    required this.locationLat,
    required this.locationLng,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteResponse.fromJson(Map<String, dynamic> json) {
    return SiteResponse(
      id: json['id'].toString(),
      organizationId: json['organization_id'].toString(),
      name: json['name'].toString(),
      timezone: json['timezone'].toString(),
      address: _parseStringValue(json['address']),
      locationLat: _parseDoubleValue(json['location_lat']),
      locationLng: _parseDoubleValue(json['location_lng']),
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class ZoneResponse {
  final String id;
  final String siteId;
  final String name;
  final String? description;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ZoneResponse({
    required this.id,
    required this.siteId,
    required this.name,
    required this.description,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ZoneResponse.fromJson(Map<String, dynamic> json) {
    return ZoneResponse(
      id: json['id'].toString(),
      siteId: json['site_id'].toString(),
      name: json['name'].toString(),
      description: _parseStringValue(json['description']),
      quietHoursStart: _parseStringValue(json['quiet_hours_start']),
      quietHoursEnd: _parseStringValue(json['quiet_hours_end']),
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class PolicyResponse {
  final String id;
  final String scopeType;
  final String? organizationId;
  final String? siteId;
  final String? zoneId;
  final String name;
  final String evidenceMode;
  final int retentionDays;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final double? dayThresholdDb;
  final double? nightThresholdDb;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PolicyResponse({
    required this.id,
    required this.scopeType,
    required this.organizationId,
    required this.siteId,
    required this.zoneId,
    required this.name,
    required this.evidenceMode,
    required this.retentionDays,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.dayThresholdDb,
    required this.nightThresholdDb,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PolicyResponse.fromJson(Map<String, dynamic> json) {
    return PolicyResponse(
      id: json['id'].toString(),
      scopeType: json['scope_type'].toString(),
      organizationId: _parseStringValue(json['organization_id']),
      siteId: _parseStringValue(json['site_id']),
      zoneId: _parseStringValue(json['zone_id']),
      name: json['name'].toString(),
      evidenceMode: json['evidence_mode'].toString(),
      retentionDays: _parseIntValue(json['retention_days']) ?? 0,
      quietHoursStart: _parseStringValue(json['quiet_hours_start']),
      quietHoursEnd: _parseStringValue(json['quiet_hours_end']),
      dayThresholdDb: _parseDoubleValue(json['day_threshold_db']),
      nightThresholdDb: _parseDoubleValue(json['night_threshold_db']),
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class CalibrationProfileResponse {
  final String id;
  final String organizationId;
  final String? siteId;
  final String name;
  final double offsetDb;
  final String? method;
  final double? confidence;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalibrationProfileResponse({
    required this.id,
    required this.organizationId,
    required this.siteId,
    required this.name,
    required this.offsetDb,
    required this.method,
    required this.confidence,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalibrationProfileResponse.fromJson(Map<String, dynamic> json) {
    return CalibrationProfileResponse(
      id: json['id'].toString(),
      organizationId: json['organization_id'].toString(),
      siteId: _parseStringValue(json['site_id']),
      name: json['name'].toString(),
      offsetDb: _parseDoubleValue(json['offset_db']) ?? 0.0,
      method: _parseStringValue(json['method']),
      confidence: _parseDoubleValue(json['confidence']),
      notes: _parseStringValue(json['notes']),
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class DeviceAssignmentResponse {
  final String deviceId;
  final String siteId;
  final String? zoneId;
  final String? calibrationProfileId;
  final DateTime updatedAt;

  const DeviceAssignmentResponse({
    required this.deviceId,
    required this.siteId,
    required this.zoneId,
    required this.calibrationProfileId,
    required this.updatedAt,
  });

  factory DeviceAssignmentResponse.fromJson(Map<String, dynamic> json) {
    return DeviceAssignmentResponse(
      deviceId: json['device_id'].toString(),
      siteId: json['site_id'].toString(),
      zoneId: _parseStringValue(json['zone_id']),
      calibrationProfileId: _parseStringValue(json['calibration_profile_id']),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class SiteDeviceResponse {
  final String id;
  final String deviceId;
  final String name;
  final String deviceType;
  final String? siteId;
  final String? zoneId;
  final String? calibrationProfileId;
  final bool isActive;
  final Map<String, dynamic>? hardwareInfo;
  final DateTime? lastSeen;
  final DateTime? lastHeartbeat;
  final DateTime updatedAt;

  const SiteDeviceResponse({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.deviceType,
    required this.siteId,
    required this.zoneId,
    required this.calibrationProfileId,
    required this.isActive,
    required this.hardwareInfo,
    required this.lastSeen,
    required this.lastHeartbeat,
    required this.updatedAt,
  });

  factory SiteDeviceResponse.fromJson(Map<String, dynamic> json) {
    return SiteDeviceResponse(
      id: json['id'].toString(),
      deviceId: json['device_id'].toString(),
      name: json['name'].toString(),
      deviceType: json['device_type'].toString(),
      siteId: _parseStringValue(json['site_id']),
      zoneId: _parseStringValue(json['zone_id']),
      calibrationProfileId: _parseStringValue(json['calibration_profile_id']),
      isActive: json['is_active'] as bool? ?? false,
      hardwareInfo: _parseMapValue(json['hardware_info']),
      lastSeen: _parseDateTimeValue(json['last_seen']),
      lastHeartbeat: _parseDateTimeValue(json['last_heartbeat']),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class ProDeviceContextSnapshot {
  final String deviceId;
  final bool authenticated;
  final String accessState;
  final String assignmentFingerprint;
  final OrganizationResponse? organization;
  final SiteResponse? site;
  final ZoneResponse? zone;
  final CalibrationProfileResponse? calibrationProfile;
  final PolicyResponse? effectivePolicy;
  final List<PolicyResponse> policies;
  final int organizationPolicyCount;
  final int sitePolicyCount;
  final int zonePolicyCount;
  final int activePolicyCount;
  final DateTime? deviceUpdatedAt;
  final DateTime? contextRefreshedAt;
  final String? sourceNote;

  const ProDeviceContextSnapshot({
    required this.deviceId,
    required this.authenticated,
    required this.accessState,
    required this.assignmentFingerprint,
    required this.organization,
    required this.site,
    required this.zone,
    required this.calibrationProfile,
    required this.effectivePolicy,
    required this.policies,
    required this.organizationPolicyCount,
    required this.sitePolicyCount,
    required this.zonePolicyCount,
    required this.activePolicyCount,
    required this.deviceUpdatedAt,
    required this.contextRefreshedAt,
    required this.sourceNote,
  });

  String? get organizationId => organization?.id;
  String? get organizationName => organization?.name;
  String? get organizationPlan => organization?.planTier;
  String? get siteId => site?.id;
  String? get siteName => site?.name;
  String? get zoneId => zone?.id;
  String? get zoneName => zone?.name;
  String? get calibrationProfileId => calibrationProfile?.id;
  String? get calibrationProfileName => calibrationProfile?.name;

  String? get effectivePolicyName => effectivePolicy?.name;
  String? get effectivePolicyScope => effectivePolicy?.scopeType;
  String? get effectiveEvidenceMode => effectivePolicy?.evidenceMode;
  double? get effectiveDayThresholdDb => effectivePolicy?.dayThresholdDb;
  double? get effectiveNightThresholdDb => effectivePolicy?.nightThresholdDb;
  int? get effectiveRetentionDays => effectivePolicy?.retentionDays;
  String? get effectivePolicyId => effectivePolicy?.id;

  Map<String, dynamic> toDiagnosticMap() {
    return {
      'device_id': deviceId,
      'authenticated': authenticated,
      'access_state': accessState,
      'assignment_fingerprint': assignmentFingerprint,
      'organization': organization == null
          ? null
          : {
              'id': organization!.id,
              'name': organization!.name,
              'slug': organization!.slug,
              'plan_tier': organization!.planTier,
              'status': organization!.status,
              'billing_state': organization!.billingState,
              'current_user_role': organization!.currentUserRole,
            },
      'site': site == null
          ? null
          : {
              'id': site!.id,
              'name': site!.name,
              'timezone': site!.timezone,
              'address': site!.address,
              'location_lat': site!.locationLat,
              'location_lng': site!.locationLng,
              'is_public': site!.isPublic,
            },
      'zone': zone == null
          ? null
          : {
              'id': zone!.id,
              'name': zone!.name,
              'description': zone!.description,
              'quiet_hours_start': zone!.quietHoursStart,
              'quiet_hours_end': zone!.quietHoursEnd,
              'is_public': zone!.isPublic,
            },
      'calibration_profile': calibrationProfile == null
          ? null
          : {
              'id': calibrationProfile!.id,
              'name': calibrationProfile!.name,
              'offset_db': calibrationProfile!.offsetDb,
              'method': calibrationProfile!.method,
              'confidence': calibrationProfile!.confidence,
              'is_active': calibrationProfile!.isActive,
            },
      'effective_policy': effectivePolicy == null
          ? null
          : {
              'id': effectivePolicy!.id,
              'name': effectivePolicy!.name,
              'scope_type': effectivePolicy!.scopeType,
              'evidence_mode': effectivePolicy!.evidenceMode,
              'retention_days': effectivePolicy!.retentionDays,
              'quiet_hours_start': effectivePolicy!.quietHoursStart,
              'quiet_hours_end': effectivePolicy!.quietHoursEnd,
              'day_threshold_db': effectivePolicy!.dayThresholdDb,
              'night_threshold_db': effectivePolicy!.nightThresholdDb,
              'is_active': effectivePolicy!.isActive,
            },
      'policy_counts': {
        'organization': organizationPolicyCount,
        'site': sitePolicyCount,
        'zone': zonePolicyCount,
        'active_total': activePolicyCount,
      },
      'policies': policies
          .map(
            (policy) => {
              'id': policy.id,
              'name': policy.name,
              'scope_type': policy.scopeType,
              'evidence_mode': policy.evidenceMode,
              'retention_days': policy.retentionDays,
              'quiet_hours_start': policy.quietHoursStart,
              'quiet_hours_end': policy.quietHoursEnd,
              'day_threshold_db': policy.dayThresholdDb,
              'night_threshold_db': policy.nightThresholdDb,
              'is_active': policy.isActive,
            },
          )
          .toList(),
      'device_updated_at': deviceUpdatedAt?.toIso8601String(),
      'context_refreshed_at': contextRefreshedAt?.toIso8601String(),
      'source_note': sourceNote,
    };
  }
}
