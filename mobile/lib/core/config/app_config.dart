import 'backend_defaults.dart';
import 'package:flutter/foundation.dart';

abstract class AppConfig {
  static const String appName = 'OpenNoiseNet';
  static const String packageName = 'org.noisenet';

  // API Configuration
  String get apiBaseUrl;
  String get websocketUrl;

  // Feature Flags
  bool get enableOnDeviceAI;
  bool get enableBackgroundMonitoring;
  bool get enableAudioSnippets;

  // Audio Settings
  int get sampleRate;
  int get bufferSize;
  Duration get recordingDuration;

  // Thresholds for unweighted digital level estimates (not calibrated dBA).
  double get dayThreshold;
  double get nightThreshold;
  double get peakThreshold;

  // Development settings
  bool get enableDebugLogs;
  bool get enableNetworkLogs;
}

class DevelopmentConfig extends AppConfig {
  @override
  String get apiBaseUrl => 'http://localhost:8100/api/v1';

  @override
  String get websocketUrl => 'ws://localhost:8100/ws';

  @override
  bool get enableOnDeviceAI => true;

  @override
  bool get enableBackgroundMonitoring => true;

  @override
  bool get enableAudioSnippets => false; // Privacy: disabled by default

  @override
  int get sampleRate => 44100;

  @override
  int get bufferSize => 4096;

  @override
  Duration get recordingDuration => const Duration(seconds: 15);

  @override
  double get dayThreshold => 65.0;

  @override
  double get nightThreshold => 55.0;

  @override
  double get peakThreshold => 85.0;

  @override
  bool get enableDebugLogs => kDebugMode;

  @override
  bool get enableNetworkLogs => kDebugMode;
}

class ProductionConfig extends AppConfig {
  @override
  String get apiBaseUrl => BackendDefaults.localOnly;

  @override
  String get websocketUrl => 'wss://offline.invalid/ws';

  @override
  bool get enableOnDeviceAI => true;

  @override
  bool get enableBackgroundMonitoring => true;

  @override
  bool get enableAudioSnippets => false; // Privacy: disabled by default

  @override
  int get sampleRate => 44100;

  @override
  int get bufferSize => 4096;

  @override
  Duration get recordingDuration => const Duration(seconds: 15);

  @override
  double get dayThreshold => 65.0;

  @override
  double get nightThreshold => 55.0;

  @override
  double get peakThreshold => 85.0;

  @override
  bool get enableDebugLogs => false;

  @override
  bool get enableNetworkLogs => false;
}
