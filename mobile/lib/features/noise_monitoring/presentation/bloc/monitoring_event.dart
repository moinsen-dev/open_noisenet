part of 'monitoring_bloc.dart';

abstract class MonitoringEvent extends Equatable {
  const MonitoringEvent();

  @override
  List<Object?> get props => [];
}

class StartMonitoring extends MonitoringEvent {
  const StartMonitoring();
}

class StopMonitoring extends MonitoringEvent {
  const StopMonitoring();
}

class UpdateNoiseLevel extends MonitoringEvent {
  const UpdateNoiseLevel(this.level);
  
  final double level;
  
  @override
  List<Object?> get props => [level];
}