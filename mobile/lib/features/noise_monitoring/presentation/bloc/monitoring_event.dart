part of 'monitoring_bloc.dart';

abstract class MonitoringEvent extends Equatable {
  const MonitoringEvent();

  @override
  List<Object?> get props => [];
}

class StartMonitoring extends MonitoringEvent {
  const StartMonitoring({this.context});

  final BuildContext? context;

  @override
  List<Object?> get props => [context];
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

class MonitoringFailureOccurred extends MonitoringEvent {
  const MonitoringFailureOccurred(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class MonitoringWatchdogTick extends MonitoringEvent {
  const MonitoringWatchdogTick();
}

class StartBackgroundMonitoring extends MonitoringEvent {
  const StartBackgroundMonitoring({
    this.context,
    this.monitoringInterval = const Duration(minutes: 15),
    this.requiresCharging = false,
    this.requiresWifi = false,
  });

  final BuildContext? context;
  final Duration monitoringInterval;
  final bool requiresCharging;
  final bool requiresWifi;

  @override
  List<Object?> get props =>
      [context, monitoringInterval, requiresCharging, requiresWifi];
}

class StopBackgroundMonitoring extends MonitoringEvent {
  const StopBackgroundMonitoring();
}

class UpdateBackgroundStatus extends MonitoringEvent {
  const UpdateBackgroundStatus(this.status);

  final Map<String, dynamic> status;

  @override
  List<Object?> get props => [status];
}

class BackgroundStateChanged extends MonitoringEvent {
  const BackgroundStateChanged(this.backgroundState);

  final BackgroundMonitoringState backgroundState;

  @override
  List<Object?> get props => [backgroundState];
}
