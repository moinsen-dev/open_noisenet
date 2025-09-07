/// API client service for communicating with OpenNoiseNet backend

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../core/models/api_models.dart';

class ApiClientService {
  static const String _baseUrlKey = 'api_base_url';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _deviceIdKey = 'device_id';
  
  // Smart backend URL detection for development
  static String get _defaultBaseUrl {
    // For iOS simulator, use host machine IP since localhost refers to simulator
    if (!kIsWeb && Platform.isIOS && !kReleaseMode) {
      // Use host machine IP for simulator connectivity to Docker
      return 'http://192.168.178.157:8100/api/v1';
    }
    // For Android emulator, 10.0.2.2 maps to host machine localhost
    if (!kIsWeb && Platform.isAndroid && !kReleaseMode) {
      return 'http://10.0.2.2:8100/api/v1';
    }
    // Default for other platforms or production builds
    return 'http://localhost:8100/api/v1';
  }
  
  late final Dio _dio;
  final SharedPreferences _prefs;
  final Talker _logger;
  
  String? _accessToken;
  String? _refreshToken;
  String? _deviceId;
  String _baseUrl = _defaultBaseUrl;

  ApiClientService({
    required SharedPreferences prefs,
    required Talker logger,
  }) : _prefs = prefs, _logger = logger {
    _initializeClient();
    _loadStoredCredentials();
  }

  void _initializeClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add request interceptor for authentication
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        _logger.debug('API Request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.debug('API Response: ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) async {
        _logger.error('API Error: ${error.message}', error);
        
        // Handle token refresh on 401 errors
        if (error.response?.statusCode == 401 && _refreshToken != null) {
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
            await _clearStoredCredentials();
          }
        }
        
        handler.next(error);
      },
    ));

    // Set base URL
    _baseUrl = _prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    _dio.options.baseUrl = _baseUrl;
  }

  Future<void> _loadStoredCredentials() async {
    _accessToken = _prefs.getString(_accessTokenKey);
    _refreshToken = _prefs.getString(_refreshTokenKey);
    _deviceId = _prefs.getString(_deviceIdKey);
    
    _logger.info('Loaded API credentials', {
      'hasAccessToken': _accessToken != null,
      'hasRefreshToken': _refreshToken != null,
      'deviceId': _deviceId,
    });
  }

  Future<void> _storeCredentials({
    String? accessToken,
    String? refreshToken,
    String? deviceId,
  }) async {
    if (accessToken != null) {
      await _prefs.setString(_accessTokenKey, accessToken);
      _accessToken = accessToken;
    }
    if (refreshToken != null) {
      await _prefs.setString(_refreshTokenKey, refreshToken);
      _refreshToken = refreshToken;
    }
    if (deviceId != null) {
      await _prefs.setString(_deviceIdKey, deviceId);
      _deviceId = deviceId;
    }
  }

  Future<void> _clearStoredCredentials() async {
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
    _accessToken = null;
    _refreshToken = null;
  }

  Future<void> setBaseUrl(String baseUrl) async {
    _baseUrl = baseUrl;
    _dio.options.baseUrl = baseUrl;
    await _prefs.setString(_baseUrlKey, baseUrl);
    _logger.info('Updated API base URL: $baseUrl');
  }

  String get baseUrl => _baseUrl;
  String? get deviceId => _deviceId;
  bool get isAuthenticated => _accessToken != null;

  // Authentication endpoints
  Future<AuthTokens> login(String email, String password) async {
    try {
      final request = LoginRequest(email: email, password: password);
      final response = await _dio.post('/auth/login', data: request.toJson());
      
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _storeCredentials(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      
      _logger.info('User logged in successfully');
      return tokens;
    } catch (e) {
      _logger.error('Login failed', e);
      rethrow;
    }
  }

  Future<AuthTokens> register(String email, String password, String fullName) async {
    try {
      final request = RegisterRequest(
        email: email,
        password: password,
        fullName: fullName,
      );
      final response = await _dio.post('/auth/register', data: request.toJson());
      
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _storeCredentials(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      
      _logger.info('User registered successfully');
      return tokens;
    } catch (e) {
      _logger.error('Registration failed', e);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      if (_refreshToken != null) {
        // Attempt to invalidate token on server
        await _dio.post('/auth/logout', data: {'refresh_token': _refreshToken});
      }
    } catch (e) {
      _logger.warning('Server logout failed, clearing local credentials anyway', e);
    } finally {
      await _clearStoredCredentials();
      _logger.info('User logged out');
    }
  }

  Future<AuthTokens> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    try {
      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': _refreshToken,
      });
      
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _storeCredentials(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      
      _logger.info('Access token refreshed');
      return tokens;
    } catch (e) {
      _logger.error('Token refresh failed', e);
      await _clearStoredCredentials();
      rethrow;
    }
  }

  // Device management endpoints
  Future<DeviceModel> registerDevice(DeviceModel device) async {
    try {
      final response = await _dio.post('/devices/register', data: device.toJson());
      final registeredDevice = DeviceModel.fromJson(response.data as Map<String, dynamic>);
      
      // Store device ID for future requests
      await _storeCredentials(deviceId: registeredDevice.deviceId);
      
      _logger.info('Device registered successfully: ${registeredDevice.deviceId}');
      return registeredDevice;
    } catch (e) {
      _logger.error('Device registration failed', e);
      rethrow;
    }
  }

  Future<DeviceModel> getDevice(String deviceId) async {
    try {
      final response = await _dio.get('/devices/$deviceId');
      return DeviceModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      _logger.error('Failed to get device: $deviceId', e);
      rethrow;
    }
  }

  Future<DeviceModel> updateDevice(String deviceId, DeviceModel device) async {
    try {
      final response = await _dio.put('/devices/$deviceId', data: device.toJson());
      final updatedDevice = DeviceModel.fromJson(response.data as Map<String, dynamic>);
      
      _logger.info('Device updated successfully: $deviceId');
      return updatedDevice;
    } catch (e) {
      _logger.error('Failed to update device: $deviceId', e);
      rethrow;
    }
  }

  Future<void> sendHeartbeat(HeartbeatRequest heartbeat) async {
    try {
      await _dio.post('/devices/${heartbeat.deviceId}/heartbeat', data: heartbeat.toJson());
      _logger.debug('Heartbeat sent for device: ${heartbeat.deviceId}');
    } catch (e) {
      _logger.error('Failed to send heartbeat', e);
      rethrow;
    }
  }

  Future<List<DeviceModel>> listDevices() async {
    try {
      final response = await _dio.get('/devices/');
      final List<dynamic> deviceList = response.data as List<dynamic>;
      return deviceList.map((json) => DeviceModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      _logger.error('Failed to list devices', e);
      rethrow;
    }
  }

  // Event endpoints
  Future<NoiseEventModel> createEvent(NoiseEventModel event) async {
    try {
      final response = await _dio.post('/events/', data: event.toJson());
      final createdEvent = NoiseEventModel.fromJson(response.data as Map<String, dynamic>);
      
      _logger.info('Event created successfully for device: ${event.deviceId}');
      return createdEvent;
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
      if (startTime != null) queryParams['start_time'] = startTime.toIso8601String();
      if (endTime != null) queryParams['end_time'] = endTime.toIso8601String();
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;

      final response = await _dio.get('/events/', queryParameters: queryParams);
      final List<dynamic> eventList = response.data as List<dynamic>;
      return eventList.map((json) => NoiseEventModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      _logger.error('Failed to list events', e);
      rethrow;
    }
  }

  Future<NoiseEventModel> getEvent(String eventId) async {
    try {
      final response = await _dio.get('/events/$eventId');
      return NoiseEventModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      _logger.error('Failed to get event: $eventId', e);
      rethrow;
    }
  }

  // Health check
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      // Health check is at root level, not under /api/v1
      final rootUrl = _baseUrl.replaceAll('/api/v1', '');
      final response = await _dio.get('$rootUrl/health');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Health check failed', e);
      rethrow;
    }
  }

  // Batch event submission for performance
  Future<List<NoiseEventModel>> createEventsBatch(List<NoiseEventModel> events) async {
    try {
      final eventDataList = events.map((event) => event.toJson()).toList();
      final response = await _dio.post('/events/batch', data: {
        'events': eventDataList,
      });
      
      final List<dynamic> createdEventsList = response.data as List<dynamic>;
      final createdEvents = createdEventsList.map((json) => NoiseEventModel.fromJson(json as Map<String, dynamic>)).toList();
      
      _logger.info('Batch created ${createdEvents.length} events');
      return createdEvents;
    } catch (e) {
      _logger.error('Failed to create events batch', e);
      rethrow;
    }
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
  Future<bool> submitAnonymousEvent(NoiseEventModel event) async {
    try {
      // Use the regular /events/ endpoint which handles anonymous submissions by auto-creating devices
      await _dio.post('/events/', data: event.toJson());
      
      _logger.info('Anonymous event submitted successfully');
      return true;
    } catch (e) {
      _logger.warning('Anonymous event submission failed', e);
      return false;
    }
  }

  // Check if backend is available for any functionality
  Future<bool> isBackendAvailable() async {
    return await testConnection();
  }

  // Submit events with fallback to queue for later submission
  Future<bool> submitEventWithFallback(NoiseEventModel event, {bool forceAnonymous = false}) async {
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
        _logger.warning('Authenticated event submission failed, trying anonymous', e);
      }
    }

    // Fallback to anonymous submission
    return await submitAnonymousEvent(event);
  }
}