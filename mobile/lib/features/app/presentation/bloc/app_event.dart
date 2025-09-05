part of 'app_bloc.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AppEvent {
  const AppStarted();
}

class AppThemeChanged extends AppEvent {
  const AppThemeChanged({required this.isDarkMode});

  final bool isDarkMode;

  @override
  List<Object?> get props => [isDarkMode];
}

class AppLanguageChanged extends AppEvent {
  const AppLanguageChanged({required this.language});

  final String language;

  @override
  List<Object?> get props => [language];
}