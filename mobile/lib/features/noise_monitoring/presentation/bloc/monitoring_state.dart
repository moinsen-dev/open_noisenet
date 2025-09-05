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