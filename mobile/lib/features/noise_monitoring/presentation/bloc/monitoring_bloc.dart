import 'dart:io';
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../services/audio_capture_service.dart';
import '../../../../services/backend_sync_service.dart';
import '../../../../services/recording_service.dart';
import '../../../../services/event_detection_service.dart';
import '../../../../services/api_client_service.dart';
import '../../../../services/statistics_service.dart';
import '../../../../services/background_monitoring_service.dart';
import '../../../../services/ios_background_service.dart';
import '../../../../services/sqlite_preferences_service.dart';

part 'monitoring_event.dart';
part 'monitoring_state.dart';

class MonitoringBloc extends Bloc<MonitoringEvent, MonitoringState> {
  MonitoringBloc() : super(const MonitoringInactive()) {
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
    on<UpdateNoiseLevel>(_onUpdateNoiseLevel);
    on<MonitoringFailureOccurred>(_onMonitoringFailureOccurred);
    on<MonitoringWatchdogTick>(_onMonitoringWatchdogTick);
    on<StartBackgroundMonitoring>(_onStartBackgroundMonitoring);
    on<StopBackgroundMonitoring>(_onStopBackgroundMonitoring);
    on<UpdateBackgroundStatus>(_onUpdateBackgroundStatus);
    on<BackgroundStateChanged>(_onBackgroundStateChanged);
  }

  final AudioCaptureService _audioCaptureService =
      GetIt.instance<AudioCaptureService>();
  final BackendSyncService _backendSync = GetIt.instance<BackendSyncService>();
  final RecordingService _recordingService = RecordingService();
  final EventDetectionService _eventDetectionService = EventDetectionService();
  final StatisticsService _statisticsService = StatisticsService();
  final BackgroundMonitoringService _backgroundMonitoringService =
      BackgroundMonitoringService();
  final IOSBackgroundService _iosBackgroundService = IOSBackgroundService();
  final SQLitePreferencesService _preferencesService =
      GetIt.instance<SQLitePreferencesService>();

  final ApiClientService _apiClient = GetIt.instance<ApiClientService>();

  StreamSubscription<double>? _splSubscription;
  StreamSubscription<BackgroundMonitoringState>? _backgroundStateSubscription;
  StreamSubscription<Map<String, dynamic>>? _backgroundStatusSubscription;
  Timer? _monitoringWatchdogTimer;
  DateTime? _lastNoiseSampleAt;
  bool _recoveryInProgress = false;

  static const Duration _watchdogInterval = Duration(seconds: 15);
  static const Duration _watchdogStallThreshold = Duration(seconds: 20);

  Future<void> _onStartMonitoring(
      StartMonitoring event, Emitter<MonitoringState> emit) async {
    try {
      emit(const MonitoringStarting());

      if (Platform.isIOS) {
        final backgroundReady =
            await _iosBackgroundService.startBackgroundSession();
        if (!backgroundReady) {
          emit(const MonitoringError(
              'Failed to prepare iOS sensor session for unattended monitoring.'));
          return;
        }
      }

      // Start real audio capture
      final success =
          await _audioCaptureService.startCapture(context: event.context);

      if (!success) {
        if (Platform.isIOS) {
          await _iosBackgroundService.stopBackgroundSession();
        }
        await _backendSync.setSensorModeActive(false);
        emit(const MonitoringError(
            'Failed to start audio capture. Please check microphone permissions.'));
        return;
      }

      // Initialize continuous recording service
      await _recordingService.initialize();

      // Keep the persisted threshold consistent across local recording and
      // reportable-event submission.
      final noiseThreshold = await _preferencesService.getNoiseThreshold();
      _eventDetectionService.setThreshold(noiseThreshold);

      // Configure day/night thresholds from Pro context or local defaults
      final dayThresholdDb = _apiClient.effectiveDayThresholdDb ?? 65.0;
      final nightThresholdDb = _apiClient.effectiveNightThresholdDb ?? 55.0;
      _eventDetectionService.setDayNightThresholds(
        dayThresholdDb: dayThresholdDb,
        nightThresholdDb: nightThresholdDb,
      );
      AppLogger.event(
        'Day/night thresholds set: day=$dayThresholdDb dB (${_apiClient.effectiveDayThresholdDb != null ? "Pro" : "local"}), '
        'night=$nightThresholdDb dB (${_apiClient.effectiveNightThresholdDb != null ? "Pro" : "local"})',
      );

      // Ensure continuous recording is enabled and start it
      await _recordingService.updateSettings(enableContinuousRecording: true);
      await _recordingService.startRecording();

      // Start event detection service for database storage
      await _eventDetectionService
          .startMonitoring(_audioCaptureService.splStream);

      // Start statistics service for real-time updates
      _statisticsService.start();

      // Listen to SPL stream
      _splSubscription = _audioCaptureService.splStream.listen(
        (spl) {
          if (!isClosed) {
            _lastNoiseSampleAt = DateTime.now();

            // Feed noise measurements to continuous recording service
            _recordingService.addNoiseMeasurement(spl);

            // Feed SPL data to statistics service for real-time averages
            _statisticsService.addSample(spl);

            add(UpdateNoiseLevel(spl));
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            add(MonitoringFailureOccurred('Audio capture error: $error'));
          }
        },
      );

      _startMonitoringWatchdog();
      await _backendSync.setSensorModeActive(true);
      emit(const MonitoringActive(currentLevel: 0.0));
    } catch (e) {
      await _backendSync.setSensorModeActive(false);
      emit(MonitoringError(e.toString()));
    }
  }

  Future<void> _onStopMonitoring(
      StopMonitoring event, Emitter<MonitoringState> emit) async {
    emit(const MonitoringStopping());

    _monitoringWatchdogTimer?.cancel();
    _monitoringWatchdogTimer = null;
    await _splSubscription?.cancel();
    _splSubscription = null;
    _lastNoiseSampleAt = null;
    _recoveryInProgress = false;

    // Stop audio capture
    await _audioCaptureService.stopCapture();

    // Stop continuous recording
    await _recordingService.stopRecording();

    // Stop event detection service
    await _eventDetectionService.stopMonitoring();

    // Stop statistics service
    _statisticsService.stop();
    await _backendSync.setSensorModeActive(false);

    if (Platform.isIOS) {
      await _iosBackgroundService.stopBackgroundSession();
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    emit(const MonitoringInactive());
  }

  Future<void> _onUpdateNoiseLevel(
      UpdateNoiseLevel event, Emitter<MonitoringState> emit) async {
    if (state is MonitoringActive) {
      emit(MonitoringActive(currentLevel: event.level));
    }
  }

  Future<void> _onMonitoringFailureOccurred(
      MonitoringFailureOccurred event, Emitter<MonitoringState> emit) async {
    if (state is! MonitoringActive) {
      emit(MonitoringError(event.message));
      return;
    }

    final recovered = await _attemptSensorRecovery(event.message);
    if (!recovered) {
      emit(MonitoringError(event.message));
    }
  }

  Future<void> _onMonitoringWatchdogTick(
      MonitoringWatchdogTick event, Emitter<MonitoringState> emit) async {
    if (state is! MonitoringActive || _recoveryInProgress) {
      return;
    }

    final lastSampleAt =
        _audioCaptureService.lastSampleAt ?? _lastNoiseSampleAt;
    if (lastSampleAt == null) {
      return;
    }

    final stalledFor = DateTime.now().difference(lastSampleAt);
    if (stalledFor < _watchdogStallThreshold) {
      return;
    }

    await _attemptSensorRecovery(
      'Sensor stream stalled for ${stalledFor.inSeconds}s',
    );
  }

  Future<void> _onStartBackgroundMonitoring(
      StartBackgroundMonitoring event, Emitter<MonitoringState> emit) async {
    try {
      emit(const BackgroundMonitoringStarting());

      if (Platform.isIOS) {
        final success = await _iosBackgroundService.startBackgroundSession();
        if (!success) {
          emit(const BackgroundMonitoringError(
              'Failed to start iOS background session'));
          return;
        }
        emit(BackgroundMonitoringActive(
          status: _iosBackgroundService.getServiceStatistics(),
          lastRunTime: DateTime.now(),
        ));
        return;
      }

      // Subscribe to background service state changes
      _backgroundStateSubscription =
          _backgroundMonitoringService.stateStream.listen((state) {
        if (!isClosed) {
          add(BackgroundStateChanged(state));
        }
      });

      // Subscribe to background service status updates
      _backgroundStatusSubscription =
          _backgroundMonitoringService.statusStream.listen((status) {
        if (!isClosed) {
          add(UpdateBackgroundStatus(status));
        }
      });

      // Start background monitoring
      final success =
          await _backgroundMonitoringService.startBackgroundMonitoring(
        monitoringInterval: event.monitoringInterval,
        requiresCharging: event.requiresCharging,
        requiresWifi: event.requiresWifi,
      );

      if (!success) {
        emit(const BackgroundMonitoringError(
            'Failed to start background monitoring'));
      }
    } catch (e) {
      emit(BackgroundMonitoringError(e.toString()));
    }
  }

  Future<void> _onStopBackgroundMonitoring(
      StopBackgroundMonitoring event, Emitter<MonitoringState> emit) async {
    emit(const BackgroundMonitoringStopping());

    await _backgroundStateSubscription?.cancel();
    await _backgroundStatusSubscription?.cancel();
    _backgroundStateSubscription = null;
    _backgroundStatusSubscription = null;

    if (Platform.isIOS) {
      await _iosBackgroundService.stopBackgroundSession();
    } else {
      // Stop background monitoring
      await _backgroundMonitoringService.stopBackgroundMonitoring();
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    emit(const BackgroundMonitoringInactive());
  }

  Future<void> _onUpdateBackgroundStatus(
      UpdateBackgroundStatus event, Emitter<MonitoringState> emit) async {
    if (state is BackgroundMonitoringActive) {
      emit(BackgroundMonitoringActive(
        status: event.status,
        lastRunTime: event.status['started_at'] != null
            ? DateTime.tryParse(event.status['started_at'].toString())
            : null,
        nextRunTime: event.status['next_run_at'] != null
            ? DateTime.tryParse(event.status['next_run_at'].toString())
            : null,
      ));
    }
  }

  Future<void> _onBackgroundStateChanged(
      BackgroundStateChanged event, Emitter<MonitoringState> emit) async {
    switch (event.backgroundState) {
      case BackgroundMonitoringState.running:
        emit(const BackgroundMonitoringActive());
        break;
      case BackgroundMonitoringState.stopped:
        emit(const BackgroundMonitoringInactive());
        break;
      case BackgroundMonitoringState.error:
        emit(const BackgroundMonitoringError('Background monitoring failed'));
        break;
      default:
        break;
    }
  }

  void _startMonitoringWatchdog() {
    _monitoringWatchdogTimer?.cancel();
    _monitoringWatchdogTimer = Timer.periodic(_watchdogInterval, (_) {
      if (!isClosed) {
        add(const MonitoringWatchdogTick());
      }
    });
  }

  Future<bool> _attemptSensorRecovery(String reason) async {
    if (_recoveryInProgress) {
      return false;
    }

    _recoveryInProgress = true;
    AppLogger.warning('MonitoringBloc: attempting sensor recovery ($reason)');

    try {
      if (Platform.isIOS && !_iosBackgroundService.isActive) {
        final backgroundReady =
            await _iosBackgroundService.startBackgroundSession();
        if (!backgroundReady) {
          AppLogger.warning(
              'MonitoringBloc: iOS background session did not recover');
        }
      }

      final restarted = await _audioCaptureService.restartCapture();
      if (restarted) {
        _lastNoiseSampleAt = DateTime.now();
        await _backendSync.performImmediateMaintenance();
        AppLogger.success('MonitoringBloc: sensor stream recovered');
        return true;
      }

      AppLogger.error('MonitoringBloc: sensor recovery failed');
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('MonitoringBloc: sensor recovery threw', e, stackTrace);
      return false;
    } finally {
      _recoveryInProgress = false;
    }
  }

  @override
  Future<void> close() async {
    _monitoringWatchdogTimer?.cancel();
    await _splSubscription?.cancel();
    await _backgroundStateSubscription?.cancel();
    await _backgroundStatusSubscription?.cancel();
    await _audioCaptureService.stopCapture();
    await _recordingService.stopRecording();
    if (Platform.isIOS) {
      await _iosBackgroundService.stopBackgroundSession();
    } else {
      await _backgroundMonitoringService.stopBackgroundMonitoring();
    }
    await _eventDetectionService.stopMonitoring();
    _statisticsService.stop();
    return super.close();
  }
}
