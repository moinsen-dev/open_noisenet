import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/audio_capture_service.dart';
import '../../../../services/recording_service.dart';
import '../../../../services/event_detection_service.dart';
import '../../../../services/statistics_service.dart';
import '../../../../services/background_monitoring_service.dart';

part 'monitoring_event.dart';
part 'monitoring_state.dart';

class MonitoringBloc extends Bloc<MonitoringEvent, MonitoringState> {
  MonitoringBloc() : super(const MonitoringInactive()) {
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
    on<UpdateNoiseLevel>(_onUpdateNoiseLevel);
    on<StartBackgroundMonitoring>(_onStartBackgroundMonitoring);
    on<StopBackgroundMonitoring>(_onStopBackgroundMonitoring);
    on<UpdateBackgroundStatus>(_onUpdateBackgroundStatus);
  }

  final AudioCaptureService _audioCaptureService = GetIt.instance<AudioCaptureService>();
  final RecordingService _recordingService = RecordingService();
  final EventDetectionService _eventDetectionService = EventDetectionService();
  final StatisticsService _statisticsService = StatisticsService();
  final BackgroundMonitoringService _backgroundMonitoringService = BackgroundMonitoringService();
  
  StreamSubscription<double>? _splSubscription;
  StreamSubscription<BackgroundMonitoringState>? _backgroundStateSubscription;
  StreamSubscription<Map<String, dynamic>>? _backgroundStatusSubscription;

  Future<void> _onStartMonitoring(
      StartMonitoring event, Emitter<MonitoringState> emit) async {
    try {
      emit(const MonitoringStarting());

      // Start real audio capture
      final success =
          await _audioCaptureService.startCapture(context: event.context);

      if (!success) {
        emit(const MonitoringError(
            'Failed to start audio capture. Please check microphone permissions.'));
        return;
      }

      // Initialize continuous recording service
      await _recordingService.initialize();
      
      // Start continuous recording if enabled
      await _recordingService.startRecording();
      
      // Start event detection service for database storage
      _eventDetectionService.startMonitoring();
      
      // Start statistics service for real-time updates
      _statisticsService.start();

      // Listen to SPL stream
      _splSubscription = _audioCaptureService.splStream.listen(
        (spl) {
          if (!isClosed) {
            // Feed noise measurements to continuous recording service
            _recordingService.addNoiseMeasurement(spl);
            
            // Feed SPL data to event detection service for database storage
            _eventDetectionService.addSample(spl);
            
            // Feed SPL data to statistics service for real-time averages
            _statisticsService.addSample(spl);
            
            add(UpdateNoiseLevel(spl));
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            add(const StopMonitoring());
            emit(MonitoringError('Audio capture error: $error'));
          }
        },
      );

      emit(const MonitoringActive(currentLevel: 0.0));
    } catch (e) {
      emit(MonitoringError(e.toString()));
    }
  }

  Future<void> _onStopMonitoring(
      StopMonitoring event, Emitter<MonitoringState> emit) async {
    emit(const MonitoringStopping());
    
    await _splSubscription?.cancel();
    _splSubscription = null;

    // Stop audio capture
    await _audioCaptureService.stopCapture();
    
    // Stop continuous recording
    await _recordingService.stopRecording();
    
    // Stop event detection service
    _eventDetectionService.stopMonitoring();
    
    // Stop statistics service
    _statisticsService.stop();

    await Future<void>.delayed(const Duration(milliseconds: 500));
    emit(const MonitoringInactive());
  }

  Future<void> _onUpdateNoiseLevel(
      UpdateNoiseLevel event, Emitter<MonitoringState> emit) async {
    if (state is MonitoringActive) {
      emit(MonitoringActive(currentLevel: event.level));
    }
  }

  Future<void> _onStartBackgroundMonitoring(
      StartBackgroundMonitoring event, Emitter<MonitoringState> emit) async {
    try {
      emit(const BackgroundMonitoringStarting());

      // Subscribe to background service state changes
      _backgroundStateSubscription = _backgroundMonitoringService.stateStream.listen((state) {
        switch (state) {
          case BackgroundMonitoringState.running:
            if (!isClosed) {
              emit(const BackgroundMonitoringActive());
            }
            break;
          case BackgroundMonitoringState.stopped:
            if (!isClosed) {
              emit(const BackgroundMonitoringInactive());
            }
            break;
          case BackgroundMonitoringState.error:
            if (!isClosed) {
              emit(const BackgroundMonitoringError('Background monitoring failed'));
            }
            break;
          default:
            break;
        }
      });

      // Subscribe to background service status updates
      _backgroundStatusSubscription = _backgroundMonitoringService.statusStream.listen((status) {
        if (!isClosed) {
          add(UpdateBackgroundStatus(status));
        }
      });

      // Start background monitoring
      final success = await _backgroundMonitoringService.startBackgroundMonitoring(
        monitoringInterval: event.monitoringInterval,
        requiresCharging: event.requiresCharging,
        requiresWifi: event.requiresWifi,
      );

      if (!success) {
        emit(const BackgroundMonitoringError('Failed to start background monitoring'));
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

    // Stop background monitoring
    await _backgroundMonitoringService.stopBackgroundMonitoring();

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

  @override
  Future<void> close() async {
    await _splSubscription?.cancel();
    await _backgroundStateSubscription?.cancel();
    await _backgroundStatusSubscription?.cancel();
    await _audioCaptureService.stopCapture();
    await _recordingService.stopRecording();
    await _backgroundMonitoringService.stopBackgroundMonitoring();
    _eventDetectionService.stopMonitoring();
    _statisticsService.stop();
    return super.close();
  }
}
