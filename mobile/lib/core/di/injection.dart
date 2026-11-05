import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../features/app/presentation/bloc/app_bloc.dart';
import '../../features/noise_monitoring/presentation/bloc/monitoring_bloc.dart';
import '../../services/sqlite_preferences_service.dart';
import '../../services/preferences_migration_service.dart';
import '../../services/audio_capture_service.dart';
import '../../services/api_client_service.dart';
import '../../services/backend_sync_service.dart';
import '../../services/noise_pattern_analyzer.dart';
import '../../services/ai_analysis_service.dart';
import '../../services/intelligent_recommendation_engine.dart';
import '../../services/sound_analysis/on_device_sound_analysis_service.dart';
import '../../features/noise_history/data/noise_history.dart';
import '../logging/app_logger.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Register external dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Configure Dio
  final dio = Dio();
  dio.options = BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL',
        defaultValue: 'http://localhost:8100/api/v1'),
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

  // Register already initialized logger
  getIt.registerSingleton<Talker>(AppLogger.instance);

  // Initialize SQLite preferences system
  final sqlitePreferencesService = SQLitePreferencesService();
  await sqlitePreferencesService.initialize();
  getIt.registerSingleton<SQLitePreferencesService>(sqlitePreferencesService);

  // Initialize AudioCaptureService and load calibration settings
  final audioCaptureService = AudioCaptureService();
  await audioCaptureService.loadCalibrationSettings();
  getIt.registerSingleton<AudioCaptureService>(audioCaptureService);

  // The model is loaded lazily when monitoring starts so app startup remains
  // fast. All inference stays on-device and consumes the shared PCM stream.
  getIt.registerSingleton<OnDeviceSoundAnalysisService>(
    OnDeviceSoundAnalysisService(),
  );
  getIt.registerSingleton<SoundHistoryCollector>(SoundHistoryCollector(
    store: EncryptedSourceHistoryStore(),
    preferences: sharedPreferences,
    activity: getIt<OnDeviceSoundAnalysisService>().sourceActivity,
    frames: getIt<OnDeviceSoundAnalysisService>().results,
  ));

  // Initialize API client service
  final logger = AppLogger.instance;
  final apiClientService = ApiClientService(
    prefs: sharedPreferences,
    logger: logger,
  );
  getIt.registerSingleton<ApiClientService>(apiClientService);

  // Perform preferences migration if needed
  final migrationService = PreferencesMigrationService();
  try {
    await migrationService.performSafeMigration();
  } catch (e) {
    debugPrint('⚠️ Preferences migration failed, continuing with defaults: $e');
  }

  // Register BLoCs
  getIt.registerFactory(() => AppBloc());
  // The screen and a restarted Android service share one sensor session.
  getIt.registerLazySingleton(() => MonitoringBloc());

  // Initialize backend sync service after all dependencies are registered
  final backendSyncService = BackendSyncService();
  await backendSyncService.initialize();
  getIt.registerSingleton<BackendSyncService>(backendSyncService);

  // Register analysis services (no on-device LLM).
  getIt.registerLazySingleton<NoisePatternAnalyzer>(
      () => NoisePatternAnalyzer());
  getIt.registerLazySingleton<AIAnalysisService>(() => AIAnalysisService(
        patternAnalyzer: getIt<NoisePatternAnalyzer>(),
        soundAnalysisService: getIt<OnDeviceSoundAnalysisService>(),
      ));
  getIt.registerLazySingleton<IntelligentRecommendationEngine>(
      () => IntelligentRecommendationEngine(
            aiAnalysisService: getIt<AIAnalysisService>(),
          ));
}
