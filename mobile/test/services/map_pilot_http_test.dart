import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_consent_controller.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_withdrawal_retry.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_contribution_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'pilot_contribution_outbox_test.dart' show MemoryStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  test(
      'queued synthetic contribution retries real HTTP and stops on withdrawal',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final destination = 'http://127.0.0.1:${server.port}/api/v1';
    SharedPreferences.setMockInitialValues(
        {'api_base_url': destination, 'access_token': 'synthetic-token'});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClientService(prefs: prefs, logger: Talker());
    final store = MemoryStore();
    var uploads = 0;
    var failUpload = true;
    server.listen((request) async {
      expect(request.headers.value('Authorization'), 'Bearer synthetic-token');
      final path = request.uri.path;
      if (path.endsWith('/identity')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
            jsonEncode({'account_id': '00000000-0000-0000-0000-000000000002'}));
      } else if (request.method == 'POST') {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'enabled': true,
          'generation': '00000000-0000-0000-0000-000000000001'
        }));
      } else if (request.method == 'PUT') {
        final payload = jsonDecode(await utf8.decoder.bind(request).join());
        expect(payload.keys,
            unorderedEquals(['generation', 'day', 'cell_id', 'level_band']));
        uploads++;
        request.response.statusCode = failUpload ? 503 : 204;
      } else if (request.method == 'DELETE') {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = 204;
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    final consent = PilotConsentController(prefs, api,
        clearOutbox: store.clear, now: () => DateTime.utc(2026, 11, 1));
    final outbox = PilotContributionOutbox(
        store: store,
        api: api,
        consent: consent,
        qualityReady: () => true,
        now: () => DateTime.utc(2026, 11, 3));
    await consent.enable(destination);
    await outbox.enqueue(
        destination: destination,
        generation: '00000000-0000-0000-0000-000000000001',
        day: '2026-11-02',
        band: 'low');
    expect(await outbox.sync(), 0);
    expect(store.rows, hasLength(1));
    failUpload = false;
    expect(await outbox.sync(), 1);
    expect(store.rows.values.single['acked'], isTrue);
    expect(await consent.withdraw(), isTrue);
    expect(store.rows, isEmpty);
    expect(await outbox.sync(), 0);
    expect(uploads, 2);
  });

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
    final controller = PilotConsentController(
        await SharedPreferences.getInstance(), api,
        clearOutbox: () async {});
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
