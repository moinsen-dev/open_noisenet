import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_consent_controller.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_withdrawal_retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi implements ApiClientService {
  bool offline = false;
  bool failEnable = false;
  Completer<void>? enableGate;
  int withdrawals = 0;
  String? lastExpectedGeneration;
  String accountId = '00000000-0000-0000-0000-000000000001';
  @override
  Future<String> mapPilotIdentity(String destination) async => accountId;
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
    return {
      'enabled': true,
      'generation': '00000000-0000-0000-0000-000000000001'
    };
  }

  @override
  Future<void> withdrawMapPilot(String destination,
      {String? expectedGeneration}) async {
    withdrawals++;
    lastExpectedGeneration = expectedGeneration;
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
    var controller =
        PilotConsentController(prefs, api, clearOutbox: () async {});
    expect(controller.enabled, isFalse);
    await controller.enable('https://pilot.example/api/v1');
    expect(
        controller.permits('https://pilot.example/api/v1',
            '00000000-0000-0000-0000-000000000001'),
        isTrue);
    expect(
        controller.permits('https://other.example/api/v1',
            '00000000-0000-0000-0000-000000000001'),
        isFalse);
    api.offline = true;
    final withdrawal = controller.withdraw();
    expect(
        controller.permits('https://pilot.example/api/v1',
            '00000000-0000-0000-0000-000000000001'),
        isFalse);
    expect(await withdrawal, isFalse);
    expect(controller.enabled, isFalse);
    expect(
        controller.permits('https://pilot.example/api/v1',
            '00000000-0000-0000-0000-000000000001'),
        isFalse);
    controller = PilotConsentController(prefs, api, clearOutbox: () async {});
    expect(controller.pendingWithdrawal, isTrue);
    await expectLater(
        controller.enable('https://pilot.example/api/v1'), throwsStateError);
    api.offline = false;
    final offlineModeRetry =
        PilotWithdrawalRetry(controller, () async => false);
    await offlineModeRetry.attempt();
    expect(api.withdrawals, 1);
    api.accountId = '00000000-0000-0000-0000-000000000002';
    expect(await controller.withdraw(), isFalse);
    expect(api.withdrawals, 1); // Wrong account never receives a deletion.
    api.accountId = '00000000-0000-0000-0000-000000000001';
    final retry = PilotWithdrawalRetry(controller, () async => true);
    await retry.attempt();
    expect(api.lastExpectedGeneration, '00000000-0000-0000-0000-000000000001');
    expect(controller.pendingWithdrawal, isFalse);
  });
  test('fresh process never trusts saved active consent without reconciliation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi();
    final first = PilotConsentController(prefs, api, clearOutbox: () async {});
    await first.enable('https://pilot.example/api/v1');
    expect(first.enabled, isTrue);
    api.credentialEpoch++;
    expect(first.enabled, isFalse);
    expect(
        first.permits('https://pilot.example/api/v1',
            '00000000-0000-0000-0000-000000000001'),
        isFalse);
    final restarted =
        PilotConsentController(prefs, api, clearOutbox: () async {});
    expect(restarted.enabled, isFalse);
    expect(
        restarted.permits('https://pilot.example/api/v1',
            '00000000-0000-0000-0000-000000000001'),
        isFalse);
  });
  test('uncertain opt-in is persisted as pending withdrawal', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi()..failEnable = true;
    var controller =
        PilotConsentController(prefs, api, clearOutbox: () async {});
    await expectLater(
        controller.enable('https://pilot.example/api/v1'), throwsStateError);
    controller = PilotConsentController(prefs, api, clearOutbox: () async {});
    expect(controller.enabled, isFalse);
    expect(controller.pendingWithdrawal, isTrue);
    final retry = PilotWithdrawalRetry(controller, () async => true);
    await retry.attempt();
    expect(
        api.withdrawals, 0); // Unknown generation never retries automatically.
    expect(await controller.withdraw(), isTrue);
  });
  test('startup retry processes an eligible pending withdrawal while online',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi();
    final controller =
        PilotConsentController(prefs, api, clearOutbox: () async {});
    await controller.enable('https://pilot.example/api/v1');
    api.offline = true;
    expect(await controller.withdraw(), isFalse);
    api.offline = false;
    final retry = PilotWithdrawalRetry(controller, () async => true,
        interval: const Duration(milliseconds: 50));
    retry.start();
    for (var i = 0; i < 30 && controller.pendingWithdrawal; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    retry.dispose();
    expect(controller.pendingWithdrawal, isFalse);
    expect(api.lastExpectedGeneration, '00000000-0000-0000-0000-000000000001');
  });
  test('server deletion is attempted even when local outbox cleanup fails',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi();
    var failCleanup = true;
    final controller =
        PilotConsentController(prefs, api, clearOutbox: () async {
      if (failCleanup) throw StateError('synthetic storage failure');
    });
    await controller.enable('https://pilot.example/api/v1');
    expect(await controller.withdraw(), isFalse);
    expect(api.withdrawals, 1);
    expect(controller.pendingWithdrawal, isTrue);
    failCleanup = false;
    expect(await controller.withdraw(automatic: true), isTrue);
    expect(controller.pendingWithdrawal, isFalse);
  });
  test('withdrawal during opt-in does not enable uploads', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi()..enableGate = Completer<void>();
    final controller =
        PilotConsentController(prefs, api, clearOutbox: () async {});
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
        await SharedPreferences.getInstance(), FakeApi(),
        clearOutbox: () async {});
    expect(controller.enabled, isFalse);
    expect(controller.pendingWithdrawal, isTrue);
    await expectLater(
        controller.enable('https://pilot.example/api/v1'), throwsStateError);
    await expectLater(controller.withdraw(), throwsStateError);
  });
  test('malformed decoded state is treated as pending and never uploaded',
      () async {
    SharedPreferences.setMockInitialValues(
        {'map_pilot_consent_v1': '{"enabled":"true"}'});
    final controller = PilotConsentController(
        await SharedPreferences.getInstance(), FakeApi(),
        clearOutbox: () async {});
    expect(controller.enabled, isFalse);
    expect(controller.pendingWithdrawal, isTrue);
    await expectLater(
        controller.enable('https://pilot.example/api/v1'), throwsStateError);
  });
}
