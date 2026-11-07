import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_client_service.dart';

/// Private, opt-in state. This controller is not connected to the UI or a worker.
/// Persist a pending withdrawal before making any request, including opt-in, so
/// a crash cannot leave a locally usable consent whose server state is unknown.
class PilotConsentController {
  PilotConsentController(this._prefs, this._api);
  static const _key = 'map_pilot_consent_v1';
  final SharedPreferences _prefs;
  final ApiClientService _api;
  Future<void> _operations = Future.value();
  bool _blocked = false;
  // A fresh process must not send until a future server reconciliation flow
  // is implemented. This also fails closed if a crash races a local write.
  bool _sessionValidated = false;
  int? _consentEpoch;
  int _withdrawalEpoch = 0;

  Map<String, dynamic> _read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Corrupt state is never treated as enabled.
    }
    return {'pending': true, 'corrupt': true};
  }

  Future<void> _save(Map<String, dynamic> value) async {
    if (!await _prefs.setString(_key, jsonEncode(value))) {
      throw StateError('Could not persist pilot consent state');
    }
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operations = _operations.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  bool get enabled {
    final state = _read();
    return _sessionValidated &&
        !_blocked &&
        _api.isAuthenticated &&
        _api.baseUrl == state['destination'] &&
        _api.credentialEpoch == _consentEpoch &&
        state['enabled'] == true &&
        state['pending'] != true;
  }

  bool get pendingWithdrawal => _read()['pending'] == true;

  bool permits(String destination, String generation) {
    final state = _read();
    return _sessionValidated &&
        !_blocked &&
        _api.isAuthenticated &&
        _api.baseUrl == destination &&
        _api.credentialEpoch == _consentEpoch &&
        state['enabled'] == true &&
        state['pending'] != true &&
        state['destination'] == destination &&
        state['generation'] == generation;
  }

  Future<void> enable(String destination) {
    final epoch = _withdrawalEpoch;
    final accountEpoch = _api.credentialEpoch;
    return _serial(() async {
      final current = _read();
      if (current['pending'] == true) {
        throw StateError('Resolve the pending pilot withdrawal first');
      }
      if (current['enabled'] == true) {
        if (current['destination'] == destination) return;
        throw StateError('Withdraw from the previous server first');
      }
      await _save(
          {'enabled': false, 'pending': true, 'destination': destination});
      final response = await _api.enableMapPilot(destination);
      if (epoch != _withdrawalEpoch ||
          _api.credentialEpoch != accountEpoch ||
          _api.baseUrl != destination ||
          !_api.isAuthenticated) {
        throw StateError('Pilot consent was withdrawn while enabling');
      }
      final generation = response['generation'];
      if (response['enabled'] != true ||
          generation is! String ||
          generation.isEmpty) {
        throw StateError('Pilot consent was not confirmed');
      }
      await _save({
        'enabled': true,
        'pending': false,
        'destination': destination,
        'generation': generation
      });
      if (epoch == _withdrawalEpoch &&
          _api.credentialEpoch == accountEpoch &&
          _api.baseUrl == destination &&
          _api.isAuthenticated) {
        _blocked = false;
        _sessionValidated = true;
        _consentEpoch = accountEpoch;
      }
    });
  }

  Future<bool> withdraw() {
    // Stop new transfers synchronously, before persistence or network awaits.
    _blocked = true;
    _sessionValidated = false;
    _withdrawalEpoch++;
    return _serial(() async {
      final current = _read();
      if (current.isEmpty) return true;
      final destination = current['destination'];
      if (destination is! String ||
          destination.isEmpty ||
          current['corrupt'] == true) {
        throw StateError('Pilot withdrawal destination is unavailable');
      }
      await _save(
          {'enabled': false, 'pending': true, 'destination': destination});
      try {
        await _api.withdrawMapPilot(destination);
      } catch (_) {
        return false;
      }
      await _save({});
      return true;
    });
  }
}
