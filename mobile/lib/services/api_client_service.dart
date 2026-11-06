// API client service for communicating with the OpenNoiseNet backend.

import '../core/config/backend_defaults.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../core/models/api_models.dart';
import 'network_utils.dart';
import 'device_credential_store.dart';
import 'sound_analysis/phase_upload_transport.dart';

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) {
      return item;
    }
  }
  return null;
}

class ApiClientService implements PhaseUploadTransport {
  static const String _baseUrlKey = 'api_base_url';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _deviceIdKey = 'device_id';

  static String get _defaultBaseUrl => BackendDefaults.current;

  static String get defaultBaseUrl => _defaultBaseUrl;

  late final Dio _dio;
  final SharedPreferences _prefs;
  final Talker _logger;
  final DeviceCredentialStore _deviceCredentials;

  String? _accessToken;
  String? _refreshToken;
  String? _deviceId;
  Map<String, dynamic>? _lastDevicePayload;
  ProDeviceContextSnapshot? _lastProContext;
  DateTime? _lastProContextRefreshedAt;
  String? _lastProContextError;
  bool _proContextRefreshInProgress = false;
  String _baseUrl = _defaultBaseUrl;
  int _credentialEpoch = 0;
  Future<void> _credentialMutations = Future<void>.value();

  ApiClientService({
    required SharedPreferences prefs,
    required Talker logger,
    DeviceCredentialStore? deviceCredentials,
  })  : _prefs = prefs,
        _logger = logger,
        _deviceCredentials = deviceCredentials ?? DeviceCredentialStore() {
    _initializeClient();
    _loadStoredCredentials();
  }

  void _initializeClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      // Never forward account credentials or request bodies to redirects.
      followRedirects: false,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add request interceptor for authentication
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final phasePermit = options.extra['source_phase_permitted'];
        if (phasePermit is bool Function() && !phasePermit()) {
          handler.reject(DioException(requestOptions: options,
              error: 'Source phase transfer was paused'));
          return;
        }
        final configuredUri = Uri.tryParse(_baseUrl);
        if (BackendDefaults.isLocalOnly(options.uri) ||
            configuredUri == null ||
            options.uri.origin != configuredUri.origin ||
            (kReleaseMode && options.uri.scheme != 'https')) {
          handler.reject(DioException(
            requestOptions: options,
            error: 'Request is outside the configured secure backend',
          ));
          return;
        }
        final previousEpoch = options.extra['noisenet_backend_epoch'];
        if (previousEpoch != null && previousEpoch != _credentialEpoch) {
          handler.reject(DioException(
            requestOptions: options,
            error: 'Backend changed while the request was in progress',
          ));
          return;
        }
        options.extra['noisenet_backend_epoch'] = _credentialEpoch;
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        _logger.debug('API Request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (response.requestOptions.extra['noisenet_backend_epoch'] !=
            _credentialEpoch) {
          handler.reject(DioException(
            requestOptions: response.requestOptions,
            error: 'Backend changed while the request was in progress',
          ));
          return;
        }
        _logger.debug(
            'API Response: ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) async {
        _logger.error('API Error: ${error.message}', error);

        // Handle token refresh on 401 errors
        if (error.response?.statusCode == 401 &&
            _refreshToken != null &&
            error.requestOptions.uri.origin == Uri.tryParse(_baseUrl)?.origin &&
            error.requestOptions.extra['noisenet_backend_epoch'] ==
                _credentialEpoch &&
            error.requestOptions.extra['noisenet_refresh_attempted'] != true &&
            !error.requestOptions.path.endsWith('/auth/refresh')) {
          error.requestOptions.extra['noisenet_refresh_attempted'] = true;
          final refreshEpoch = _credentialEpoch;
          try {
            await _refreshAccessToken();
            // Retry the original request
            final clonedRequest = error.requestOptions;
            clonedRequest.headers['Authorization'] = 'Bearer $_accessToken';
            final response = await _dio.fetch<dynamic>(clonedRequest);
            handler.resolve(response);
            return;
          } catch (e) {
            _logger.error('Token refresh failed', e);
            if (refreshEpoch == _credentialEpoch) {
              await _clearStoredCredentials();
            }
          }
        }

        handler.next(error);
      },
    ));

    // Set base URL
    _baseUrl = _prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    _dio.options.baseUrl = _baseUrl;
  }

  void _loadStoredCredentials() {
    _accessToken = _prefs.getString(_accessTokenKey);
    _refreshToken = _prefs.getString(_refreshTokenKey);
    _deviceId = _prefs.getString(_deviceIdKey);

    _logger.info('Loaded API credentials', {
      'hasAccessToken': _accessToken != null,
      'hasRefreshToken': _refreshToken != null,
      'deviceId': _deviceId,
    });
  }

  Future<void> _withCredentialLock(Future<void> Function() action) {
    final result = _credentialMutations.then((_) => action());
    _credentialMutations = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _storeCredentials({
    String? accessToken,
    String? refreshToken,
    String? deviceId,
    int? expectedEpoch,
    String? expectedDestination,
  }) async {
    if (accessToken != null || refreshToken != null) {
      await _withCredentialLock(() async {
        if (expectedEpoch != _credentialEpoch ||
            expectedDestination != _baseUrl) {
          throw StateError(
              'Backend changed while authentication was in progress');
        }
        if (accessToken != null) {
          await _prefs.setString(_accessTokenKey, accessToken);
          _accessToken = accessToken;
        }
        if (refreshToken != null) {
          await _prefs.setString(_refreshTokenKey, refreshToken);
          _refreshToken = refreshToken;
        }
      });
    }
    if (deviceId != null) {
      await _prefs.setString(_deviceIdKey, deviceId);
      _deviceId = deviceId;
    }
  }

  Future<void> _clearStoredCredentialsUnlocked() async {
    _accessToken = null;
    _refreshToken = null;
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
  }

  Future<void> _clearStoredCredentials() =>
      _withCredentialLock(_clearStoredCredentialsUnlocked);

  static Uri _validatedBackendUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
          'Enter a valid backend URL without embedded credentials, query or fragment.');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw const FormatException('HTTPS is required in release builds.');
    }
    return uri;
  }

  Future<void> setBaseUrl(String baseUrl) async {
    final destination = baseUrl.trim();
    _validatedBackendUrl(destination);
    if (destination == _baseUrl) return;
    final changeEpoch = ++_credentialEpoch;
    await _withCredentialLock(() async {
      if (changeEpoch != _credentialEpoch) {
        throw StateError('A newer backend change superseded this one');
      }
      // Credentials and cached tenant state belong to the previous backend.
      await _clearStoredCredentialsUnlocked();
      _lastDevicePayload = null;
      _lastProContext = null;
      _lastProContextRefreshedAt = null;
      _lastProContextError = null;
      _baseUrl = destination;
      _dio.options.baseUrl = destination;
      await _prefs.setString(_baseUrlKey, destination);
    });
    _logger.info('Updated API base URL: $destination');
  }

  @override
  String get baseUrl => _baseUrl;
  @override
  String? get deviceId => _deviceId;

  void _checkPhaseDestination(String destination, String device) {
    if (destination != _baseUrl || device != _deviceId) {
      throw StateError('Queued phase belongs to a different backend or device');
    }
  }

  @override
  Future<void> preparePhaseUpload(String destination, String device) async {
    _checkPhaseDestination(destination, device);
    await ensureDeviceRegistered();
    _checkPhaseDestination(destination, device);
  }

  @override
  Future<Map<String, dynamic>> putSourcePhase(String destination, String device,
      Map<String, dynamic> payload, bool Function() permitted) async {
    _checkPhaseDestination(destination, device);
    final options = await _deviceOptions(device);
    _checkPhaseDestination(destination, device);
    options.extra!['source_phase_permitted'] = permitted;
    final response = await _dio.put<Map<String,dynamic>>(
      '/source-phases/${Uri.encodeComponent(device)}/${payload['phase_id']}',
      data: payload, options: options);
    return response.data ?? <String,dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> deleteSourcePhase(String destination, String device,
      String phaseId, bool Function() permitted) async {
    _checkPhaseDestination(destination, device);
    final options = await _deviceOptions(device);
    _checkPhaseDestination(destination, device);
    options.extra!['source_phase_permitted'] = permitted;
    final response = await _dio.delete<Map<String,dynamic>>(
      '/source-phases/${Uri.encodeComponent(device)}/$phaseId', options: options);
    return response.data ?? <String,dynamic>{};
  }

  Future<List<Map<String,dynamic>>> listSourcePhases({int offset = 0}) async {
    final device = _deviceId;
    if (device == null) return [];
    final response = await _dio.get<Map<String,dynamic>>(
      '/source-phases/${Uri.encodeComponent(device)}',
      queryParameters: {'offset':offset,'limit':100}, options:await _deviceOptions(device));
    return (response.data!['items'] as List)
        .map((v) => Map<String,dynamic>.from(v as Map)).toList();
  }

  Future<Options> _deviceOptions(String? deviceId,
      {bool create = false}) async {
    final destination = _baseUrl;
    final epoch = _credentialEpoch;
    final uri = Uri.parse(destination);
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('Device credentials require an HTTPS backend');
    }
    final key = deviceId == null
        ? null
        : await _deviceCredentials.get(destination, deviceId, create: create);
    if (_baseUrl != destination || _credentialEpoch != epoch) {
      throw StateError('Backend changed while preparing device credentials');
    }
    return Options(
      followRedirects: false,
      extra: {'noisenet_backend_epoch': epoch},
      headers: key == null ? null : {'X-Device-Key': key},
    );
  }

  bool get isAuthenticated => _accessToken != null;
  String? get assignedSiteId => _lastDevicePayload?['site_id']?.toString();
  String? get assignedZoneId => _lastDevicePayload?['zone_id']?.toString();
  String? get assignedCalibrationProfileId =>
      _lastDevicePayload?['calibration_profile_id']?.toString();
  String? get assignedSiteName => _lastProContext?.siteName;
  String? get assignedZoneName => _lastProContext?.zoneName;
  String? get assignedCalibrationProfileName =>
      _lastProContext?.calibrationProfileName;
  String? get assignedOrganizationId => _lastProContext?.organizationId;
  String? get assignedOrganizationName => _lastProContext?.organizationName;
  String? get assignedOrganizationPlan => _lastProContext?.organizationPlan;
  String? get effectivePolicyId => _lastProContext?.effectivePolicyId;
  String? get effectivePolicyName => _lastProContext?.effectivePolicyName;
  String? get effectivePolicyScope => _lastProContext?.effectivePolicyScope;
  String? get effectiveEvidenceMode => _lastProContext?.effectiveEvidenceMode;
  int? get effectivePolicyRetentionDays =>
      _lastProContext?.effectiveRetentionDays;
  double? get effectiveDayThresholdDb =>
      _lastProContext?.effectiveDayThresholdDb;
  double? get effectiveNightThresholdDb =>
      _lastProContext?.effectiveNightThresholdDb;
  DateTime? get lastProContextRefreshedAt => _lastProContextRefreshedAt;
  String? get lastProContextError => _lastProContextError;
  ProDeviceContextSnapshot? get lastProContext => _lastProContext;
  DateTime? get lastHeartbeatAt {
    final value = _lastDevicePayload?['last_heartbeat'] as String?;
    return value == null ? null : DateTime.tryParse(value);
  }

  Map<String, dynamic>? get lastRuntimeStatus =>
      (_lastDevicePayload?['hardware_info']
              as Map<String, dynamic>?)?['last_runtime_status']
          as Map<String, dynamic>?;

  @override
  Future<String> ensureDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) {
      return _deviceId!;
    }

    final generatedDeviceId = _generateDeviceId();
    await _storeCredentials(deviceId: generatedDeviceId);
    _logger.info('Generated local device identity: $generatedDeviceId');
    return generatedDeviceId;
  }

  // Authentication endpoints
  Future<AuthTokens> login(String email, String password) async {
    try {
      final credentialDestination = _baseUrl;
      final credentialEpoch = _credentialEpoch;
      final request = LoginRequest(email: email, password: password);
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: request.toJson(),
      );

      if (_baseUrl != credentialDestination) {
        throw StateError(
            'Backend changed while authentication was in progress');
      }
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _storeCredentials(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expectedEpoch: credentialEpoch,
        expectedDestination: credentialDestination,
      );

      _logger.info('User logged in successfully');
      return tokens;
    } catch (e) {
      _logger.error('Login failed', e);
      rethrow;
    }
  }

  Future<AuthTokens> register(
      String email, String password, String fullName) async {
    try {
      final credentialDestination = _baseUrl;
      final credentialEpoch = _credentialEpoch;
      final request = RegisterRequest(
        email: email,
        password: password,
        fullName: fullName,
      );
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: request.toJson(),
      );

      if (_baseUrl != credentialDestination) {
        throw StateError(
            'Backend changed while authentication was in progress');
      }
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _storeCredentials(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expectedEpoch: credentialEpoch,
        expectedDestination: credentialDestination,
      );

      _logger.info('User registered successfully');
      return tokens;
    } catch (e) {
      _logger.error('Registration failed', e);
      rethrow;
    }
  }

  Future<void> logout() async {
    _credentialEpoch++;
    await _clearStoredCredentials();
    _logger.info('User logged out locally');
  }

  Future<DeviceModel> ensureDeviceRegistered({
    String? name,
    double? locationLat,
    double? locationLng,
    String? address,
    bool isPublic = false,
  }) async {
    final resolvedDeviceId = await ensureDeviceId();
    final deviceName = name ?? _defaultDeviceName();

    final device = DeviceModel(
      deviceId: resolvedDeviceId,
      name: deviceName,
      deviceType: DeviceType.smartphone,
      firmwareVersion: 'mobile-0.1.0',
      hardwareInfo: <String, dynamic>{
        'platform': _platformLabel(),
        'authenticated': isAuthenticated,
      },
      calibrationOffset: 0.0,
      locationLat: locationLat,
      locationLng: locationLng,
      address: address,
      isPublic: isPublic,
    );

    return await registerDevice(device);
  }

  Future<AuthTokens> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final refreshEpoch = _credentialEpoch;
    try {
      final credentialDestination = _baseUrl;
      final credentialEpoch = refreshEpoch;
      final response =
          await _dio.post<Map<String, dynamic>>('/auth/refresh', data: {
        'refresh_token': _refreshToken,
      });

      if (_baseUrl != credentialDestination) {
        throw StateError(
            'Backend changed while authentication was in progress');
      }
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _storeCredentials(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expectedEpoch: credentialEpoch,
        expectedDestination: credentialDestination,
      );

      _logger.info('Access token refreshed');
      return tokens;
    } catch (e) {
      _logger.error('Token refresh failed', e);
      if (refreshEpoch == _credentialEpoch) {
        await _clearStoredCredentials();
      }
      rethrow;
    }
  }

  // Device management endpoints
  Future<DeviceModel> registerDevice(DeviceModel device) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/devices/register',
        data: device.toJson(),
        options: await _deviceOptions(device.deviceId, create: true),
      );
      final payload = response.data as Map<String, dynamic>;
      _lastDevicePayload = payload;
      final registeredDevice = DeviceModel.fromJson(payload);

      // Store device ID for future requests
      await _storeCredentials(deviceId: registeredDevice.deviceId);

      _logger
          .info('Device registered successfully: ${registeredDevice.deviceId}');
      return registeredDevice;
    } catch (e) {
      _logger.error('Device registration failed', e);
      rethrow;
    }
  }

  Future<DeviceModel> getDevice(String deviceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/devices/$deviceId',
        options: await _deviceOptions(deviceId == _deviceId ? deviceId : null),
      );
      final payload = response.data as Map<String, dynamic>;
      _lastDevicePayload = payload;
      return DeviceModel.fromJson(payload);
    } catch (e) {
      _logger.error('Failed to get device: $deviceId', e);
      rethrow;
    }
  }

  Future<DeviceModel> updateDevice(String deviceId, DeviceModel device) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/devices/$deviceId',
        data: device.toJson(),
        options: await _deviceOptions(deviceId == _deviceId ? deviceId : null),
      );
      final payload = response.data as Map<String, dynamic>;
      _lastDevicePayload = payload;
      final updatedDevice = DeviceModel.fromJson(payload);

      _logger.info('Device updated successfully: $deviceId');
      return updatedDevice;
    } catch (e) {
      _logger.error('Failed to update device: $deviceId', e);
      rethrow;
    }
  }

  Future<void> sendHeartbeat(
    HeartbeatRequest heartbeat, {
    Map<String, dynamic>? status,
  }) async {
    try {
      final payload = <String, dynamic>{
        ...heartbeat.toJson(),
        if (status != null && status.isNotEmpty) 'status': status,
      };
      await _dio.post<Map<String, dynamic>>(
        '/devices/${heartbeat.deviceId}/heartbeat',
        data: payload,
        options: await _deviceOptions(heartbeat.deviceId),
      );
      _logger.debug('Heartbeat sent for device: ${heartbeat.deviceId}');
      await refreshKnownDeviceContext();
    } catch (e) {
      _logger.error('Failed to send heartbeat', e);
      rethrow;
    }
  }

  Future<List<DeviceModel>> listDevices() async {
    try {
      final response = await _dio.get<List<dynamic>>('/devices/',
          options: await _deviceOptions(_deviceId));
      final List<dynamic> deviceList = response.data as List<dynamic>;
      return deviceList
          .map((json) => DeviceModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('Failed to list devices', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> refreshKnownDeviceContext() async {
    final resolvedDeviceId = _deviceId;
    if (resolvedDeviceId == null || resolvedDeviceId.isEmpty) {
      return _lastDevicePayload;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/devices/$resolvedDeviceId',
        options: await _deviceOptions(resolvedDeviceId),
      );
      _lastDevicePayload = response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.warning('Failed to refresh known device context', e);
    }

    return _lastDevicePayload;
  }

  Future<OrganizationResponse> getOrganization(String organizationId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$organizationId',
    );
    return OrganizationResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SiteResponse> getSite(String siteId) async {
    final response = await _dio.get<Map<String, dynamic>>('/sites/$siteId');
    return SiteResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ZoneResponse> getZone(String zoneId) async {
    final response = await _dio.get<Map<String, dynamic>>('/zones/$zoneId');
    return ZoneResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PolicyResponse> getPolicy(String policyId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/policies/$policyId');
    return PolicyResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PolicyResponse>> listPolicies({
    String? organizationId,
    String? siteId,
    String? zoneId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (organizationId != null) {
      queryParams['organization_id'] = organizationId;
    }
    if (siteId != null) {
      queryParams['site_id'] = siteId;
    }
    if (zoneId != null) {
      queryParams['zone_id'] = zoneId;
    }
    final response = await _dio.get<List<dynamic>>(
      '/policies/',
      queryParameters: queryParams,
    );
    final payload = response.data ?? const <dynamic>[];
    return payload
        .map((json) => PolicyResponse.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CalibrationProfileResponse> getCalibrationProfile(
      String profileId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/calibration-profiles/$profileId',
    );
    return CalibrationProfileResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<List<CalibrationProfileResponse>> listCalibrationProfiles({
    required String organizationId,
    String? siteId,
  }) async {
    final queryParams = <String, dynamic>{
      'organization_id': organizationId,
    };
    if (siteId != null) {
      queryParams['site_id'] = siteId;
    }
    final response = await _dio.get<List<dynamic>>(
      '/calibration-profiles/',
      queryParameters: queryParams,
    );
    final payload = response.data ?? const <dynamic>[];
    return payload
        .map((json) => CalibrationProfileResponse.fromJson(
              json as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<DeviceAssignmentResponse> updateDeviceAssignment({
    required String deviceId,
    required String siteId,
    String? zoneId,
    String? calibrationProfileId,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/sites/devices/$deviceId/assignment',
      options: await _deviceOptions(deviceId == _deviceId ? deviceId : null),
      data: {
        'site_id': siteId,
        if (zoneId != null) 'zone_id': zoneId,
        if (calibrationProfileId != null)
          'calibration_profile_id': calibrationProfileId,
      },
    );
    return DeviceAssignmentResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<List<SiteDeviceResponse>> listSiteDevices(String siteId) async {
    final response = await _dio.get<List<dynamic>>(
      '/sites/$siteId/devices',
    );
    final payload = response.data ?? const <dynamic>[];
    return payload
        .map(
            (json) => SiteDeviceResponse.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ProDeviceContextSnapshot?> refreshProDeviceContext({
    bool force = false,
  }) async {
    if (_proContextRefreshInProgress) {
      return _lastProContext;
    }

    final resolvedDeviceId = _deviceId;
    if (resolvedDeviceId == null || resolvedDeviceId.isEmpty) {
      return _lastProContext;
    }

    final devicePayload =
        await refreshKnownDeviceContext() ?? _lastDevicePayload;
    final siteId = devicePayload?['site_id']?.toString();
    final zoneId = devicePayload?['zone_id']?.toString();
    final calibrationProfileId =
        devicePayload?['calibration_profile_id']?.toString();
    final fingerprint =
        '$resolvedDeviceId|${siteId ?? ''}|${zoneId ?? ''}|${calibrationProfileId ?? ''}';

    final cached = _lastProContext;
    final isFresh = _lastProContextRefreshedAt != null &&
        DateTime.now().difference(_lastProContextRefreshedAt!) <
            const Duration(minutes: 5);
    if (!force &&
        cached != null &&
        cached.assignmentFingerprint == fingerprint &&
        isFresh &&
        cached.accessState != 'pro_context_error' &&
        _lastProContextError == null) {
      return cached;
    }

    if (!isAuthenticated) {
      final snapshot = _buildMinimalProContext(
        deviceId: resolvedDeviceId,
        devicePayload: devicePayload,
        fingerprint: fingerprint,
        accessState:
            siteId == null ? 'anonymous_device_only' : 'anonymous_assigned',
        sourceNote: 'pro context unavailable without authentication',
      );
      _lastProContext = snapshot;
      _lastProContextRefreshedAt = DateTime.now();
      _lastProContextError = null;
      return snapshot;
    }

    if (siteId == null || siteId.isEmpty) {
      final snapshot = _buildMinimalProContext(
        deviceId: resolvedDeviceId,
        devicePayload: devicePayload,
        fingerprint: fingerprint,
        accessState: 'pro_unassigned',
        sourceNote: 'device has no site assignment yet',
      );
      _lastProContext = snapshot;
      _lastProContextRefreshedAt = DateTime.now();
      _lastProContextError = null;
      return snapshot;
    }

    _proContextRefreshInProgress = true;
    try {
      final site = await getSite(siteId);
      final organization = await getOrganization(site.organizationId);
      final zone =
          zoneId == null || zoneId.isEmpty ? null : await getZone(zoneId);
      final calibrationProfile =
          calibrationProfileId == null || calibrationProfileId.isEmpty
              ? null
              : await getCalibrationProfile(calibrationProfileId);

      final policies = <PolicyResponse>[];
      policies.addAll(
        await listPolicies(organizationId: organization.id),
      );
      policies.addAll(
        await listPolicies(siteId: site.id),
      );
      if (zone != null) {
        policies.addAll(
          await listPolicies(zoneId: zone.id),
        );
      }

      final uniquePolicies = <String, PolicyResponse>{};
      for (final policy in policies) {
        uniquePolicies[policy.id] = policy;
      }
      final orderedPolicies = uniquePolicies.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final activePolicies =
          orderedPolicies.where((policy) => policy.isActive).toList();
      final zonePolicy = zone == null
          ? null
          : _firstWhereOrNull(
              activePolicies, (policy) => policy.zoneId == zone.id);
      final sitePolicy = _firstWhereOrNull(
        activePolicies,
        (policy) => policy.siteId == site.id && policy.zoneId == null,
      );
      final orgPolicy = _firstWhereOrNull(
        activePolicies,
        (policy) =>
            policy.organizationId == organization.id &&
            policy.siteId == null &&
            policy.zoneId == null,
      );
      final effectivePolicy = zonePolicy ?? sitePolicy ?? orgPolicy;

      final snapshot = ProDeviceContextSnapshot(
        deviceId: resolvedDeviceId,
        authenticated: true,
        accessState: effectivePolicy == null ? 'pro_partial' : 'pro_ready',
        assignmentFingerprint: fingerprint,
        organization: organization,
        site: site,
        zone: zone,
        calibrationProfile: calibrationProfile,
        effectivePolicy: effectivePolicy,
        policies: orderedPolicies,
        organizationPolicyCount: orderedPolicies
            .where((policy) => policy.organizationId == organization.id)
            .length,
        sitePolicyCount:
            orderedPolicies.where((policy) => policy.siteId == site.id).length,
        zonePolicyCount: zone == null
            ? 0
            : orderedPolicies
                .where((policy) => policy.zoneId == zone.id)
                .length,
        activePolicyCount: activePolicies.length,
        deviceUpdatedAt: _lastDevicePayload?['updated_at'] == null
            ? null
            : DateTime.tryParse(_lastDevicePayload!['updated_at'].toString()),
        contextRefreshedAt: DateTime.now(),
        sourceNote: effectivePolicy == null
            ? 'device assigned, but no active policy found'
            : 'resolved via authenticated Pro APIs',
      );

      _lastProContext = snapshot;
      _lastProContextRefreshedAt = DateTime.now();
      _lastProContextError = null;
      return snapshot;
    } catch (e) {
      _lastProContextError = e.toString();
      _logger.warning('Failed to refresh Pro device context', e);
      final fallback = _buildMinimalProContext(
        deviceId: resolvedDeviceId,
        devicePayload: devicePayload,
        fingerprint: fingerprint,
        accessState: 'pro_context_error',
        sourceNote: 'failed to resolve authenticated Pro context',
      );
      _lastProContext = fallback;
      _lastProContextRefreshedAt = DateTime.now();
      return fallback;
    } finally {
      _proContextRefreshInProgress = false;
    }
  }

  ProDeviceContextSnapshot _buildMinimalProContext({
    required String deviceId,
    required Map<String, dynamic>? devicePayload,
    required String fingerprint,
    required String accessState,
    required String sourceNote,
  }) {
    return ProDeviceContextSnapshot(
      deviceId: deviceId,
      authenticated: isAuthenticated,
      accessState: accessState,
      assignmentFingerprint: fingerprint,
      organization: null,
      site: null,
      zone: null,
      calibrationProfile: null,
      effectivePolicy: null,
      policies: const [],
      organizationPolicyCount: 0,
      sitePolicyCount: 0,
      zonePolicyCount: 0,
      activePolicyCount: 0,
      deviceUpdatedAt: _lastDevicePayload?['updated_at'] == null
          ? null
          : DateTime.tryParse(_lastDevicePayload!['updated_at'].toString()),
      contextRefreshedAt: DateTime.now(),
      sourceNote: sourceNote,
    );
  }

  // Event endpoints
  Future<EventReceipt> createEvent(NoiseEventModel event) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/events/',
        data: event.toJson(),
        options: await _deviceOptions(event.deviceId),
      );
      final receipt =
          EventReceipt.fromJson(response.data as Map<String, dynamic>);

      _logger.info('Event created successfully for device: ${event.deviceId}');
      return receipt;
    } catch (e) {
      _logger.error('Failed to create event', e);
      rethrow;
    }
  }

  Future<List<NoiseEventModel>> listEvents({
    String? deviceId,
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (deviceId != null) queryParams['device_id'] = deviceId;
      if (startTime != null)
        queryParams['start_time'] = startTime.toIso8601String();
      if (endTime != null) queryParams['end_time'] = endTime.toIso8601String();
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;

      final response = await _dio.get<Map<String, dynamic>>(
        '/events/',
        queryParameters: queryParams,
        options: await _deviceOptions(_deviceId),
      );
      final data = response.data as Map<String, dynamic>;
      final List<dynamic> eventList = data['events'] as List<dynamic>;
      return eventList
          .map((json) => NoiseEventModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('Failed to list events', e);
      rethrow;
    }
  }

  Future<NoiseEventModel> getEvent(String eventId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/events/$eventId',
          options: await _deviceOptions(_deviceId));
      return NoiseEventModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      _logger.error('Failed to get event: $eventId', e);
      rethrow;
    }
  }

  Future<EventStatusModel> getEventStatus(String eventUuid) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
          '/events/status/$eventUuid',
          options: await _deviceOptions(_deviceId));
      return EventStatusModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      _logger.error('Failed to get event status: $eventUuid', e);
      rethrow;
    }
  }

  // Map endpoints (public, no auth required)
  Future<Map<String, dynamic>> getMapEvents({
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
    int hours = 24,
    int limit = 500,
  }) async {
    try {
      final queryParams = <String, dynamic>{'hours': hours, 'limit': limit};
      if (minLat != null) queryParams['min_lat'] = minLat;
      if (maxLat != null) queryParams['max_lat'] = maxLat;
      if (minLng != null) queryParams['min_lng'] = minLng;
      if (maxLng != null) queryParams['max_lng'] = maxLng;

      final response = await _dio.get<Map<String, dynamic>>(
        '/map/events',
        queryParameters: queryParams,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Failed to get map events', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMapHeatmap({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int hours = 24,
  }) async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>('/map/heatmap', queryParameters: {
        'min_lat': minLat,
        'max_lat': maxLat,
        'min_lng': minLng,
        'max_lng': maxLng,
        'hours': hours,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Failed to get heatmap data', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMapStats() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/map/stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Failed to get map stats', e);
      rethrow;
    }
  }

  // Health check with detailed error information
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      // Health check is at root level, not under /api/v1
      final rootUrl = _baseUrl.replaceAll('/api/v1', '');
      final response = await _dio.get<Map<String, dynamic>>('$rootUrl/health');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Health check failed', e);
      rethrow;
    }
  }

  // Enhanced connection test with detailed error info
  Future<ConnectionTestResult> testConnectionDetailed(
      {String? candidateUrl}) async {
    final destination = (candidateUrl ?? _baseUrl).trim();
    try {
      if (BackendDefaults.isLocalOnly(_validatedBackendUrl(destination))) {
        return ConnectionTestResult(success: false, latencyMs: null,
            error: 'On this device only. Configure a HTTPS backend to connect.',
            baseUrl: destination);
      }
      final startTime = DateTime.now();
      if (candidateUrl == null) {
        await healthCheck();
      } else {
        // A connectivity probe must neither send account credentials nor
        // change the configured backend before the user saves the setting.
        final root = destination.replaceAll('/api/v1', '');
        final probe = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          followRedirects: false,
        ));
        try {
          await probe.get<void>('$root/health');
        } finally {
          probe.close();
        }
      }
      final endTime = DateTime.now();
      final latency = endTime.difference(startTime);

      return ConnectionTestResult(
        success: true,
        latencyMs: latency.inMilliseconds,
        error: null,
        baseUrl: destination,
      );
    } catch (e) {
      String errorMessage;
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
            errorMessage = 'Connection timeout - server not responding';
            break;
          case DioExceptionType.receiveTimeout:
            errorMessage = 'Receive timeout - slow server response';
            break;
          case DioExceptionType.connectionError:
            errorMessage = 'Connection failed - check URL and network';
            break;
          case DioExceptionType.badResponse:
            errorMessage = 'Server error (${e.response?.statusCode})';
            break;
          default:
            errorMessage = 'Network error: ${e.message}';
        }
      } else if (e is FormatException) {
        errorMessage = e.message;
      } else {
        errorMessage = 'Unexpected error: ${e.toString()}';
      }

      return ConnectionTestResult(
        success: false,
        latencyMs: null,
        error: errorMessage,
        baseUrl: destination,
      );
    }
  }

  // Batch event submission for performance
  Future<List<EventReceipt>> createEventsBatch(
      List<NoiseEventModel> events) async {
    final createdEvents = <EventReceipt>[];

    for (final event in events) {
      createdEvents.add(await createEvent(event));
    }

    _logger.info('Sequentially submitted ${createdEvents.length} events');
    return createdEvents;
  }

  // Connection test
  Future<bool> testConnection() async {
    try {
      await healthCheck();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Anonymous event submission (no authentication required)
  Future<EventReceipt?> submitAnonymousEvent(NoiseEventModel event) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/events/',
          data: event.toJson(), options: await _deviceOptions(event.deviceId));

      _logger.info('Anonymous event submitted successfully');
      return EventReceipt.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      _logger.warning('Anonymous event submission failed', e);
      return null;
    }
  }

  // Check if backend is available for any functionality
  Future<bool> isBackendAvailable() async {
    return await testConnection();
  }

  // Get recommended backend URLs for the current platform
  Future<List<BackendPreset>> getRecommendedUrls() async {
    final networkUtils = NetworkUtils();
    final presets = networkUtils.getCommonPresets();

    // Update auto-detect preset with actual detected IP
    for (int i = 0; i < presets.length; i++) {
      if (presets[i].isAutoDetect) {
        final detectedUrl =
            await networkUtils.getRecommendedBackendUrl(port: 8100);
        presets[i] = presets[i].withUrl(detectedUrl);
        break;
      }
    }

    return presets;
  }

  // Get current network information for debugging
  Future<Map<String, dynamic>> getNetworkDebugInfo() async {
    final networkUtils = NetworkUtils();
    final networkInfo = await networkUtils.getNetworkInfo();

    networkInfo['currentBackendUrl'] = _baseUrl;
    networkInfo['isAuthenticated'] = isAuthenticated;
    networkInfo['deviceId'] = _deviceId;

    return networkInfo;
  }

  // Submit events with fallback to queue for later submission
  Future<bool> submitEventWithFallback(NoiseEventModel event,
      {bool forceAnonymous = false}) async {
    // If backend is not available, queue for later
    if (!await isBackendAvailable()) {
      _logger.info('Backend unavailable, event will be stored locally');
      return false;
    }

    // Try authenticated submission first (if logged in and not forced anonymous)
    if (!forceAnonymous && isAuthenticated) {
      try {
        await createEvent(event);
        return true;
      } catch (e) {
        _logger.warning(
            'Authenticated event submission failed, trying anonymous', e);
      }
    }

    // Fallback to anonymous submission
    return await submitAnonymousEvent(event) != null;
  }

  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'mobile-${_platformLabel()}-$timestamp';
  }

  String _defaultDeviceName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'OpenNoiseNet Android Sensor';
      case TargetPlatform.iOS:
        return 'OpenNoiseNet iPhone Sensor';
      case TargetPlatform.macOS:
        return 'OpenNoiseNet Mac Sensor';
      case TargetPlatform.windows:
        return 'OpenNoiseNet Windows Sensor';
      case TargetPlatform.linux:
        return 'OpenNoiseNet Linux Sensor';
      case TargetPlatform.fuchsia:
        return 'OpenNoiseNet Sensor';
    }
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
