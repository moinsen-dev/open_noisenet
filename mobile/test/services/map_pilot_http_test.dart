import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_consent_controller.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_withdrawal_retry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  test('pilot protocol is server-bound and rejects paused or extra data',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final destination = 'http://127.0.0.1:${server.port}/api/v1';
    SharedPreferences.setMockInitialValues(
        {'api_base_url': destination, 'access_token': 'synthetic-token'});
    final api = ApiClientService(
        prefs: await SharedPreferences.getInstance(), logger: Talker());
    var calls = 0;
    var deletionStatus = 204;
    server.listen((request) async {
      calls++;
      expect(request.headers.value('Authorization'), 'Bearer synthetic-token');
      if (request.method == 'GET') {
        expect(request.uri.path, '/api/v1/map-pilot/identity');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
            jsonEncode({'account_id': '00000000-0000-0000-0000-000000000002'}));
      } else if (request.method == 'POST') {
        expect(jsonDecode(await utf8.decoder.bind(request).join()),
            {'notice_version': 'pilot-draft-2026-11-07', 'accepted': true});
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'enabled': true,
          'generation': '00000000-0000-0000-0000-000000000001'
        }));
      } else if (request.method == 'PUT') {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['cell_id'], 'hamburg-eimsbuettel');
        expect(body.keys,
            unorderedEquals(['generation', 'day', 'cell_id', 'level_band']));
        request.response.statusCode = 204;
      } else if (request.method == 'DELETE') {
        final body = await utf8.decoder.bind(request).join();
        if (body.isNotEmpty) {
          expect(jsonDecode(body),
              {'expected_generation': '00000000-0000-0000-0000-000000000001'});
        }
        request.response.statusCode = deletionStatus;
      }
      await request.response.close();
    });
    await expectLater(
        api.enableMapPilot('$destination/other'), throwsStateError);
    expect(calls, 0);
    final consent = await api.enableMapPilot(destination);
    expect(consent['generation'], '00000000-0000-0000-0000-000000000001');
    final contribution = <String, dynamic>{
      'generation': '00000000-0000-0000-0000-000000000001',
      'day': '2026-10-27',
      'cell_id': 'hamburg-eimsbuettel',
      'level_band': 'medium'
    };
    await expectLater(
        api.uploadMapPilotContribution(
            destination, {...contribution, 'latitude': 53.5}, () => true),
        throwsArgumentError);
    await expectLater(
        api.uploadMapPilotContribution(destination,
            {...contribution, 'day': 'private diary text'}, () => true),
        throwsArgumentError);
    await expectLater(
        api.uploadMapPilotContribution(destination, contribution, () => false),
        throwsStateError);
    expect(calls, 1);
    await api.uploadMapPilotContribution(destination, contribution, () => true);
    deletionStatus = 200;
    await expectLater(api.withdrawMapPilot(destination), throwsStateError);
    deletionStatus = 204;
    await api.withdrawMapPilot(destination,
        expectedGeneration: '00000000-0000-0000-0000-000000000001');
    expect(calls, 4);
    final controller =
        PilotConsentController(await SharedPreferences.getInstance(), api);
    await controller.enable(destination);
    deletionStatus = 503;
    expect(await controller.withdraw(), isFalse);
    expect(controller.pendingWithdrawal, isTrue);
    deletionStatus = 204;
    final retry = PilotWithdrawalRetry(controller, () async => true);
    await retry.attempt();
    expect(controller.pendingWithdrawal, isFalse);
    expect(calls, 10);
  });
}
