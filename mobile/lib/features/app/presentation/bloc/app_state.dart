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
  });

  final bool isAuthenticated;
  final bool isDarkMode;
  final String language;

  AppLoaded copyWith({
    bool? isAuthenticated,
    bool? isDarkMode,
    String? language,
  }) {
    return AppLoaded(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
    );
  }

  @override
  List<Object?> get props => [isAuthenticated, isDarkMode, language];
}

class AppError extends AppState {
  const AppError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}