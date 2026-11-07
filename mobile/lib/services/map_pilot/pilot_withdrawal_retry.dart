import 'dart:async';
import 'pilot_consent_controller.dart';

/// Retries only generation-bound withdrawals while this process is running.
/// The OS can suspend or terminate the app; this is not a background promise.
class PilotWithdrawalRetry {
  PilotWithdrawalRetry(this.controller, this.allowNetwork,
      {this.interval = const Duration(minutes: 15)});
  final PilotConsentController controller;
  final Future<bool> Function() allowNetwork;
  final Duration interval;
  Timer? _timer;
  bool _running = false;

  void start() {
    if (_timer != null) return;
    unawaited(attempt());
    _timer = Timer.periodic(interval, (_) => unawaited(attempt()));
  }

  Future<void> attempt() async {
    if (_running || !controller.canRetryAutomatically) return;
    _running = true;
    try {
      if (await allowNetwork()) await controller.withdraw(automatic: true);
    } catch (_) {
      // Retain the pending state; do not log account details or credentials.
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
