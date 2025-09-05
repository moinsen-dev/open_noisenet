import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'monitoring_event.dart';
part 'monitoring_state.dart';

@injectable
class MonitoringBloc extends Bloc<MonitoringEvent, MonitoringState> {
  MonitoringBloc() : super(const MonitoringInactive()) {
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
    on<UpdateNoiseLevel>(_onUpdateNoiseLevel);
  }

  Timer? _monitoringTimer;

  Future<void> _onStartMonitoring(StartMonitoring event, Emitter<MonitoringState> emit) async {
    try {
      emit(const MonitoringStarting());
      
      // TODO: Initialize audio capture
      // TODO: Request permissions
      // TODO: Start background service
      
      // Simulate monitoring with random data for now
      emit(const MonitoringActive(currentLevel: 42.5));
      
      // Start periodic updates (in real implementation, this would come from audio processing)
      _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isClosed) {
          final randomLevel = 35.0 + (DateTime.now().millisecond % 30);
          add(UpdateNoiseLevel(randomLevel));
        }
      });
      
    } catch (e) {
      emit(MonitoringError(e.toString()));
    }
  }

  Future<void> _onStopMonitoring(StopMonitoring event, Emitter<MonitoringState> emit) async {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    // TODO: Stop audio capture
    // TODO: Stop background service
    
    emit(const MonitoringStopping());
    await Future.delayed(const Duration(milliseconds: 500));
    emit(const MonitoringInactive());
  }

  Future<void> _onUpdateNoiseLevel(UpdateNoiseLevel event, Emitter<MonitoringState> emit) async {
    if (state is MonitoringActive) {
      emit(MonitoringActive(currentLevel: event.level));
    }
  }

  @override
  Future<void> close() {
    _monitoringTimer?.cancel();
    return super.close();
  }
}