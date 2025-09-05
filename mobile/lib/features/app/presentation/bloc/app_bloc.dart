import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'app_event.dart';
part 'app_state.dart';

@injectable
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(const AppInitial()) {
    on<AppStarted>(_onAppStarted);
    on<AppThemeChanged>(_onThemeChanged);
    on<AppLanguageChanged>(_onLanguageChanged);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AppState> emit) async {
    try {
      emit(const AppLoading());
      
      // Simulate initialization tasks
      await Future.delayed(const Duration(seconds: 2));
      
      // TODO: Check if user is authenticated
      // TODO: Load app preferences
      // TODO: Initialize services
      
      emit(const AppLoaded(
        isAuthenticated: false,
        isDarkMode: false,
        language: 'en',
      ));
    } catch (e) {
      emit(AppError(e.toString()));
    }
  }

  Future<void> _onThemeChanged(AppThemeChanged event, Emitter<AppState> emit) async {
    if (state is AppLoaded) {
      final currentState = state as AppLoaded;
      emit(currentState.copyWith(isDarkMode: event.isDarkMode));
    }
  }

  Future<void> _onLanguageChanged(AppLanguageChanged event, Emitter<AppState> emit) async {
    if (state is AppLoaded) {
      final currentState = state as AppLoaded;
      emit(currentState.copyWith(language: event.language));
    }
  }
}