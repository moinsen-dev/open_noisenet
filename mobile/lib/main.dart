import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/app/presentation/bloc/app_bloc.dart';
import 'features/noise_monitoring/presentation/bloc/monitoring_bloc.dart';
import 'services/background_monitoring_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging framework
  AppLogger.initialize(enableInRelease: false);
  
  // Initialize dependency injection
  await configureDependencies();
  
  // Initialize background monitoring service
  final backgroundService = BackgroundMonitoringService();
  await backgroundService.initialize();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const NoiseNetApp());
}

class NoiseNetApp extends StatelessWidget {
  const NoiseNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => getIt<AppBloc>()..add(const AppStarted()),
        ),
        BlocProvider(
          create: (context) => getIt<MonitoringBloc>(),
        ),
      ],
      child: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          return MaterialApp.router(
            title: 'OpenNoiseNet',
            debugShowCheckedModeBanner: false,
            
            // Theme configuration
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _getThemeMode(state),
            
            // Router configuration
            routerConfig: AppRouter.router,
            
            // Localization (to be implemented)
            // localizationsDelegates: AppLocalizations.localizationsDelegates,
            // supportedLocales: AppLocalizations.supportedLocales,
            
            builder: (context, child) {
              // Global error handling and loading states
              return BlocListener<AppBloc, AppState>(
                listener: (context, state) {
                  // Handle global app state changes
                  if (state is AppError) {
                    _showErrorSnackBar(context, state.message);
                  }
                },
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(AppState state) {
    if (state is AppLoaded) {
      return state.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
    return ThemeMode.system;
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}