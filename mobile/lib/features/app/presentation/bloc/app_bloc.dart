import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/sqlite_preferences_service.dart';

part 'app_event.dart';
part 'app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final SQLitePreferencesService _preferencesService =
      GetIt.instance<SQLitePreferencesService>();

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
