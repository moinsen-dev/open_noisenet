part of 'monitoring_bloc.dart';

abstract class MonitoringState extends Equatable {
  const MonitoringState();

  @override
  List<Object?> get props => [];
}

class MonitoringInactive extends MonitoringState {
  const MonitoringInactive();
}

class MonitoringStarting extends MonitoringState {
  const MonitoringStarting();
}

class MonitoringActive extends MonitoringState {
  const MonitoringActive({required this.currentLevel});
  
  final double currentLevel;
  
  @override
  List<Object?> get props => [currentLevel];
}

class MonitoringStopping extends MonitoringState {
  const MonitoringStopping();
}

class MonitoringError extends MonitoringState {
  const MonitoringError(this.message);
  
  final String message;
  
  @override
  List<Object?> get props => [message];
}

class BackgroundMonitoringInactive extends MonitoringState {
  const BackgroundMonitoringInactive();
}

class BackgroundMonitoringStarting extends MonitoringState {
  const BackgroundMonitoringStarting();
}

class BackgroundMonitoringActive extends MonitoringState {
  const BackgroundMonitoringActive({
    this.lastRunTime,
    this.nextRunTime,
    this.status,
  });
  
  final DateTime? lastRunTime;
  final DateTime? nextRunTime;
  final Map<String, dynamic>? status;
  
  @override
  List<Object?> get props => [lastRunTime, nextRunTime, status];
}

class BackgroundMonitoringStopping extends MonitoringState {
  const BackgroundMonitoringStopping();
}

class BackgroundMonitoringError extends MonitoringState {
  const BackgroundMonitoringError(this.message);
  
  final String message;
  
  @override
  List<Object?> get props => [message];
}