import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_consent_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi implements ApiClientService {
  bool offline = false;
  bool failEnable = false;
  Completer<void>? enableGate;
  int withdrawals = 0;
  @override
  int credentialEpoch = 0;
  @override
  String get baseUrl => 'https://pilot.example/api/v1';
  @override
  bool get isAuthenticated => true;
  @override
  Future<Map<String, dynamic>> enableMapPilot(String destination) async {
    if (enableGate != null) await enableGate!.future;
    if (failEnable) throw StateError('offline');
    return {'enabled': true, 'generation': 'synthetic-generation'};
  }

  @override
  Future<void> withdrawMapPilot(String destination) async {
    withdrawals++;
    if (offline) throw StateError('offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'offline withdrawal stops permits and survives restart until server confirms',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi();
    var controller = PilotConsentController(prefs, api);
    expect(controller.enabled, isFalse);
    await controller.enable('https://pilot.example/api/v1');
    expect(
        controller.permits(
            'https://pilot.example/api/v1', 'synthetic-generation'),
        isTrue);
    expect(
        controller.permits(
            'https://other.example/api/v1', 'synthetic-generation'),
        isFalse);
    api.offline = true;
    final withdrawal = controller.withdraw();
    expect(
        controller.permits(
            'https://pilot.example/api/v1', 'synthetic-generation'),
        isFalse);
    expect(await withdrawal, isFalse);
    expect(controller.enabled, isFalse);
    expect(
        controller.permits(
            'https://pilot.example/api/v1', 'synthetic-generation'),
        isFalse);
    controller = PilotConsentController(prefs, api);
    expect(controller.pendingWithdrawal, isTrue);
    await expectLater(
        controller.enable('https://pilot.example/api/v1'), throwsStateError);
    api.offline = false;
    expect(await controller.withdraw(), isTrue);
    expect(controller.pendingWithdrawal, isFalse);
  });
  test('fresh process never trusts saved active consent without reconciliation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi();
    final first = PilotConsentController(prefs, api);
    await first.enable('https://pilot.example/api/v1');
    expect(first.enabled, isTrue);
    api.credentialEpoch++;
    expect(first.enabled, isFalse);
    expect(
        first.permits('https://pilot.example/api/v1', 'synthetic-generation'),
        isFalse);
    final restarted = PilotConsentController(prefs, api);
    expect(restarted.enabled, isFalse);
    expect(
        restarted.permits(
            'https://pilot.example/api/v1', 'synthetic-generation'),
        isFalse);
  });
  test('uncertain opt-in is persisted as pending withdrawal', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi()..failEnable = true;
    var controller = PilotConsentController(prefs, api);
    await expectLater(
        controller.enable('https://pilot.example/api/v1'), throwsStateError);
    controller = PilotConsentController(prefs, api);
    expect(controller.enabled, isFalse);
    expect(controller.pendingWithdrawal, isTrue);
    expect(await controller.withdraw(), isTrue);
  });
  test('withdrawal during opt-in does not enable uploads', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi()..enableGate = Completer<void>();
    final controller = PilotConsentController(prefs, api);
    final enabling = controller.enable('https://pilot.example/api/v1');
    await Future<void>.delayed(Duration.zero);
    final withdrawing = controller.withdraw();
    expect(controller.enabled, isFalse);
    api.enableGate!.complete();
    await expectLater(enabling, throwsStateError);
    expect(await withdrawing, isTrue);
    expect(controller.enabled, isFalse);
    expect(api.withdrawals, 1);
  });
  test('corrupt state fails closed and cannot silently be replaced', () async {
    SharedPreferences.setMockInitialValues({'map_pilot_consent_v1': '{bad'});
    final controller = PilotConsentController(
        await SharedPreferences.getInstance(), FakeApi());
    expect(controller.enabled, isFalse);
    expect(controller.pendingWithdrawal, isTrue);
    await expectLater(
        controller.enable('https://pilot.example/api/v1'), throwsStateError);
    await expectLater(controller.withdraw(), throwsStateError);
  });
}
