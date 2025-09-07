import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../services/sqlite_preferences_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRequestingPermissions = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestMicrophonePermission() async {
    setState(() => _isRequestingPermissions = true);

    try {
      AppLogger.permission('Requesting microphone permission');

      final status = await Permission.microphone.request();

      if (status.isGranted) {
        AppLogger.success('Microphone permission granted');
        _nextPage();
      } else if (status.isDenied) {
        AppLogger.warning('Microphone permission denied');
        _showPermissionDeniedDialog(
          'Microphone Permission Required',
          'OpenNoiseNet needs microphone access to monitor noise levels. Without this permission, the app cannot function.',
          Permission.microphone,
        );
      } else if (status.isPermanentlyDenied) {
        AppLogger.warning('Microphone permission permanently denied');
        _showSettingsDialog(
          'Microphone Permission Required',
          'Please enable microphone permission in Settings to use OpenNoiseNet.',
        );
      }
    } catch (e) {
      AppLogger.failure('Error requesting microphone permission', e);
    } finally {
      setState(() => _isRequestingPermissions = false);
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isRequestingPermissions = true);

    try {
      AppLogger.permission('Requesting location permission');

      final status = await Permission.locationWhenInUse.request();

      if (status.isGranted) {
        AppLogger.success('Location permission granted');
        await _completeOnboarding();
      } else if (status.isDenied) {
        AppLogger.warning('Location permission denied');
        _showPermissionDeniedDialog(
          'Location Permission Required',
          'OpenNoiseNet needs location access to create accurate noise maps. Without this permission, we cannot determine where noise events occur.',
          Permission.locationWhenInUse,
        );
      } else if (status.isPermanentlyDenied) {
        AppLogger.warning('Location permission permanently denied');
        _showSettingsDialog(
          'Location Permission Required',
          'Please enable location permission in Settings to use OpenNoiseNet.',
        );
      }
    } catch (e) {
      AppLogger.failure('Error requesting location permission', e);
    } finally {
      setState(() => _isRequestingPermissions = false);
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      AppLogger.onboarding('Completing onboarding process');

      // Mark onboarding as complete
      final prefsService = GetIt.instance<SQLitePreferencesService>();
      await prefsService.setOnboardingComplete(true);

      AppLogger.success('Onboarding completed successfully');

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      AppLogger.failure('Error completing onboarding', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing setup: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog(
      String title, String message, Permission permission) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Try requesting permission again
              if (permission == Permission.microphone) {
                await _requestMicrophonePermission();
              } else {
                await _requestLocationPermission();
              }
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppLogger.ui('User closed app due to missing permissions');
              // User cannot proceed without permissions
            },
            child: const Text('Exit App'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppLogger.ui('User closed app due to missing permissions');
            },
            child: const Text('Exit App'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              AppLogger.ui('Opening app settings for permissions');
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            if (_currentPage > 0)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / 4,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                ),
              ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  AppLogger.ui('Onboarding page changed to $page');
                },
                children: [
                  _buildWelcomePage(),
                  _buildHowItWorksPage(),
                  _buildMicrophonePermissionPage(),
                  _buildLocationPermissionPage(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isRequestingPermissions ? null : _previousPage,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isRequestingPermissions
                          ? null
                          : _getNextButtonAction(),
                      child: _isRequestingPermissions
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_getNextButtonText()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback _getNextButtonAction() {
    switch (_currentPage) {
      case 0:
      case 1:
        return _nextPage;
      case 2:
        return _requestMicrophonePermission;
      case 3:
        return _requestLocationPermission;
      default:
        return _nextPage;
    }
  }

  String _getNextButtonText() {
    switch (_currentPage) {
      case 0:
      case 1:
        return 'Continue';
      case 2:
        return 'Grant Microphone Access';
      case 3:
        return 'Grant Location Access';
      default:
        return 'Continue';
    }
  }

  Widget _buildWelcomePage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40), // Add top spacing
          Icon(
            Icons.headset_mic_rounded,
            size: 120,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to OpenNoiseNet',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Transform your smartphone into a powerful environmental noise monitoring sensor and help build a global network for citizen science.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.public,
                  color: colorScheme.onPrimaryContainer,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Join thousands of citizens worldwide creating open noise pollution maps',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40), // Add bottom spacing
        ],
      ),
    );
  }

  Widget _buildHowItWorksPage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40), // Add top spacing
          Icon(
            Icons.timeline,
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'How OpenNoiseNet Works',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Icons.mic,
            'Monitor Noise Levels',
            'Your phone\'s microphone captures ambient sound and calculates real-time noise levels in decibels.',
            colorScheme,
            theme,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            Icons.location_on,
            'Create Noise Maps',
            'Location data helps create accurate community noise maps to identify pollution hotspots.',
            colorScheme,
            theme,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            Icons.share,
            'Share for Science',
            'Contribute to environmental research and help communities advocate for quieter spaces.',
            colorScheme,
            theme,
          ),
          const SizedBox(height: 40), // Add bottom spacing
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description,
      ColorScheme colorScheme, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colorScheme.onSecondaryContainer, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMicrophonePermissionPage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40), // Add top spacing
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic,
              size: 64,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Microphone Permission Required',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'OpenNoiseNet needs access to your microphone to measure ambient noise levels.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy Guarantee',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We only measure sound levels, never record audio. Your privacy is protected.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'This permission is mandatory for the app to function.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40), // Add bottom spacing
        ],
      ),
    );
  }

  Widget _buildLocationPermissionPage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40), // Add top spacing
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on,
              size: 64,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Location Permission Required',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Location data is essential for creating accurate noise pollution maps and identifying problem areas in communities.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: colorScheme.onTertiaryContainer,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Why Location Matters',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Without location data, we cannot determine where noise events occur, making it impossible to create meaningful noise maps for environmental advocacy.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'This permission is mandatory for the app to function.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40), // Add bottom spacing
        ],
      ),
    );
  }
}
