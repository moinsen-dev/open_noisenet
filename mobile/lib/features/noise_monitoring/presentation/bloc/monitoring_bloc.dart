import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/audio_capture_service.dart';
import '../../../../services/continuous_recording_service.dart';

part 'monitoring_event.dart';
part 'monitoring_state.dart';

class MonitoringBloc extends Bloc<MonitoringEvent, MonitoringState> {
  MonitoringBloc() : super(const MonitoringInactive()) {
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
    on<UpdateNoiseLevel>(_onUpdateNoiseLevel);
  }

  final AudioCaptureService _audioCaptureService = GetIt.instance<AudioCaptureService>();
  final ContinuousRecordingService _continuousRecordingService = ContinuousRecordingService();
  StreamSubscription<double>? _splSubscription;

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
      await _continuousRecordingService.initialize();
      
      // Start continuous recording if enabled
      await _continuousRecordingService.startContinuousRecording();

      // Listen to SPL stream
      _splSubscription = _audioCaptureService.splStream.listen(
        (spl) {
          if (!isClosed) {
            // Feed noise measurements to continuous recording service
            _continuousRecordingService.addNoiseMeasurement(spl);
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
    await _continuousRecordingService.stopContinuousRecording();

    await Future<void>.delayed(const Duration(milliseconds: 500));
    emit(const MonitoringInactive());
  }

  Future<void> _onUpdateNoiseLevel(
      UpdateNoiseLevel event, Emitter<MonitoringState> emit) async {
    if (state is MonitoringActive) {
      emit(MonitoringActive(currentLevel: event.level));
    }
  }

  @override
  Future<void> close() async {
    await _splSubscription?.cancel();
    await _audioCaptureService.stopCapture();
    await _continuousRecordingService.stopContinuousRecording();
    return super.close();
  }
}
