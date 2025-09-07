import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/sqlite_preferences_service.dart';
import '../../../../services/backend_sync_service.dart';

part 'app_event.dart';
part 'app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final SQLitePreferencesService _preferencesService =
      GetIt.instance<SQLitePreferencesService>();
  final BackendSyncService _syncService =
      GetIt.instance<BackendSyncService>();

  AppBloc() : super(const AppInitial()) {
    on<AppStarted>(_onAppStarted);
    on<AppThemeChanged>(_onThemeChanged);
    on<AppLanguageChanged>(_onLanguageChanged);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AppState> emit) async {
    try {
      emit(const AppLoading());

      // SQLite preferences service is already initialized in DI

      // Load app preferences from SQLite
      final isDarkMode = await _preferencesService.getIsDarkMode();
      final isOnboardingComplete =
          await _preferencesService.getOnboardingComplete();

      // Initialize backend sync service and check connectivity
      await _syncService.initialize();
      
      // Check backend status and emit connection notification
      final backendStatus = await _syncService.getBackendStatus();
      final mode = backendStatus['mode'] as String;
      final queuedEvents = backendStatus['queued_events'] as int;
      
      String connectionMessage;
      bool isConnected;
      
      switch (mode) {
        case 'offline':
          isConnected = false;
          connectionMessage = queuedEvents > 0 
              ? 'Running offline - $queuedEvents events queued for sync'
              : 'Running in offline mode - Events stored locally';
          break;
        case 'anonymous':
          isConnected = true;
          connectionMessage = 'Connected - Anonymous data sharing enabled';
          break;
        case 'authenticated':
          isConnected = true;
          connectionMessage = 'Connected and authenticated - Full sync enabled';
          break;
        default:
          isConnected = false;
          connectionMessage = 'Unknown connection status';
      }
      
      // Emit connection status notification
      emit(AppConnectionStatus(
        isConnected: isConnected,
        mode: mode,
        message: connectionMessage,
      ));
      
      // Small delay to show the notification, then load the main app
      await Future.delayed(const Duration(milliseconds: 500));

      // TODO: Check if user is authenticated
      // TODO: Initialize other services

      emit(AppLoaded(
        isAuthenticated: false,
        isDarkMode: isDarkMode,
        language: 'en',
        isOnboardingComplete: isOnboardingComplete,
      ));
    } catch (e) {
      emit(AppError(e.toString()));
    }
  }

  Future<void> _onThemeChanged(
      AppThemeChanged event, Emitter<AppState> emit) async {
    if (state is AppLoaded) {
      try {
        // Save theme preference to SQLite
        await _preferencesService.setIsDarkMode(event.isDarkMode);

        final currentState = state as AppLoaded;
        emit(currentState.copyWith(isDarkMode: event.isDarkMode));
      } catch (e) {
        emit(AppError('Failed to save theme preference: $e'));
      }
    }
  }

  Future<void> _onLanguageChanged(
      AppLanguageChanged event, Emitter<AppState> emit) async {
    if (state is AppLoaded) {
      final currentState = state as AppLoaded;
      emit(currentState.copyWith(language: event.language));
    }
  }
}
