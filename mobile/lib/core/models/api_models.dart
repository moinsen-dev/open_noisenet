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

  factory DeviceModel.fromJson(Map<String, dynamic> json) => _$DeviceModelFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceModelToJson(this);
}

/// Noise event model for API submission
@JsonSerializable()
class NoiseEventModel {
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

  NoiseEventModel({
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
  });

  factory NoiseEventModel.fromJson(Map<String, dynamic> json) => _$NoiseEventModelFromJson(json);
  Map<String, dynamic> toJson() => _$NoiseEventModelToJson(this);
}

/// Authentication request models
@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
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

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);
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

  factory AuthTokens.fromJson(Map<String, dynamic> json) => _$AuthTokensFromJson(json);
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

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
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

  factory HeartbeatRequest.fromJson(Map<String, dynamic> json) => _$HeartbeatRequestFromJson(json);
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
