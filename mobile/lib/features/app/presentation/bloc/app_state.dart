part of 'app_bloc.dart';

abstract class AppState extends Equatable {
  const AppState();

  @override
  List<Object?> get props => [];
}

class AppInitial extends AppState {
  const AppInitial();
}

class AppLoading extends AppState {
  const AppLoading();
}

class AppLoaded extends AppState {
  const AppLoaded({
    required this.isAuthenticated,
    required this.isDarkMode,
    required this.language,
    required this.isOnboardingComplete,
  });

  final bool isAuthenticated;
  final bool isDarkMode;
  final String language;
  final bool isOnboardingComplete;

  AppLoaded copyWith({
    bool? isAuthenticated,
    bool? isDarkMode,
    String? language,
    bool? isOnboardingComplete,
  }) {
    return AppLoaded(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
    );
  }

  @override
  List<Object?> get props =>
      [isAuthenticated, isDarkMode, language, isOnboardingComplete];
}

class AppError extends AppState {
  const AppError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class AppConnectionStatus extends AppState {
  const AppConnectionStatus({
    required this.isConnected,
    required this.mode,
    required this.message,
    this.shouldShowNotification = true,
  });

  final bool isConnected;
  final String mode; // 'offline', 'anonymous', 'authenticated'
  final String message;
  final bool shouldShowNotification;

  @override
  List<Object?> get props => [isConnected, mode, message, shouldShowNotification];
}
