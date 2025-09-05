import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../../features/app/presentation/bloc/app_bloc.dart';
import '../../features/noise_monitoring/presentation/bloc/monitoring_bloc.dart';
import '../../services/sqlite_preferences_service.dart';
import '../../services/preferences_migration_service.dart';
import '../../services/audio_capture_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Register external dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  
  // Configure Dio
  final dio = Dio();
  dio.options = BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000'),
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );
  
  // Add logging interceptor in debug mode
  if (const bool.fromEnvironment('DEBUG', defaultValue: false)) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
    ));
  }
  
  getIt.registerSingleton<Dio>(dio);
  
  // Initialize SQLite preferences system
  final sqlitePreferencesService = SQLitePreferencesService();
  await sqlitePreferencesService.initialize();
  getIt.registerSingleton<SQLitePreferencesService>(sqlitePreferencesService);
  
  // Initialize AudioCaptureService and load calibration settings
  final audioCaptureService = AudioCaptureService();
  await audioCaptureService.loadCalibrationSettings();
  getIt.registerSingleton<AudioCaptureService>(audioCaptureService);
  
  // Perform preferences migration if needed
  final migrationService = PreferencesMigrationService();
  try {
    await migrationService.performSafeMigration();
  } catch (e) {
    debugPrint('⚠️ Preferences migration failed, continuing with defaults: $e');
  }
  
  // Register BLoCs
  getIt.registerFactory(() => AppBloc());
  getIt.registerFactory(() => MonitoringBloc());
}