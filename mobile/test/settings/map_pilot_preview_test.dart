import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/features/settings/presentation/widgets/map_pilot_preview.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_consent_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi implements ApiClientService {
  int enables = 0;
  int withdrawals = 0;
  @override
  Future<String> mapPilotIdentity(String destination) async =>
      '00000000-0000-0000-0000-000000000001';
  @override
  int get credentialEpoch => 0;
  @override
  String get baseUrl => 'https://pilot.example/api/v1';
  @override
  bool get isAuthenticated => true;
  @override
  Future<Map<String, dynamic>> enableMapPilot(String destination) async {
    enables++;
    return {
      'enabled': true,
      'generation': '00000000-0000-0000-0000-000000000001'
    };
  }

  @override
  Future<void> withdrawMapPilot(String destination,
      {String? expectedGeneration}) async {
    withdrawals++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'production preview explains the closed pilot without enabling it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi();
    final controller = PilotConsentController(
        await SharedPreferences.getInstance(), api,
        clearOutbox: () async {});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MapPilotPreview(
                controller: controller, destination: api.baseUrl))));
    expect(find.textContaining('noch nicht freigegeben'), findsOneWidget);
    expect(find.text('Freiwillig aktivieren'), findsNothing);
    expect(api.enables, 0);
  });
  testWidgets('synthetic opt-in and withdrawal show server outcomes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi();
    final controller = PilotConsentController(
        await SharedPreferences.getInstance(), api,
        clearOutbox: () async {});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MapPilotPreview(
                controller: controller,
                destination: api.baseUrl,
                available: true))));
    await tester.tap(find.text('Freiwillig aktivieren'));
    await tester.pumpAndSettle();
    expect(find.text('Freigabe gespeichert.'), findsOneWidget);
    await tester.tap(find.text('Widerruf senden'));
    await tester.pumpAndSettle();
    expect(find.text('Widerruf vom Server bestätigt.'), findsOneWidget);
    expect(api.enables, 1);
    expect(api.withdrawals, 1);
  });
}
