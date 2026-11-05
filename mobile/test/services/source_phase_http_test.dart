import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_repository.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/sound_analysis/source_phase_upload.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';

class ControlledApi extends ApiClientService {
  ControlledApi(SharedPreferences prefs)
      : super(prefs: prefs, logger: Talker());
  bool offline = false, loseAck = false;
  int lostAcks = 0;
  @override
  Future<void> preparePhaseUpload(String destination, String device) async {
    if (offline) throw StateError('controlled offline interval');
    await super.preparePhaseUpload(destination, device);
  }

  @override
  Future<Map<String, dynamic>> putSourcePhase(String destination, String device,
      Map<String, dynamic> payload, bool Function() permitted) async {
    final response =
        await super.putSourcePhase(destination, device, payload, permitted);
    if (loseAck) {
      loseAck = false;
      lostAcks++;
      throw StateError('controlled lost ACK after server commit');
    }
    return response;
  }
}

// Ordinary widget tests deliberately replace HTTP with a 400 response. This
// explicitly gated loopback integration test needs the real transport.
class LoopbackIntegrationBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  LoopbackIntegrationBinding();
  final root = Platform.environment['ONN_PHASE_FIXTURES'];
  final endpoint = Platform.environment['ONN_PHASE_QA_URL'];
  test(
      'natural twenty-minute phase survives real HTTP continuations, offline, restart and erasure',
      () async {
    final uri = Uri.parse(endpoint!);
    expect(uri.host, '127.0.0.1');
    final probe = Dio();
    final marker =
        await probe.get<Map<String, dynamic>>('${uri.origin}/__qa_marker');
    expect(marker.data!['database'], 'source_phase_qa');
    probe.close();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory(root!).createTemp('phase-http-db-');
    await databaseFactory.setDatabasesPath(directory.path);
    await LocalDiaryRepository.resetForTesting();
    SharedPreferences.setMockInitialValues({'api_base_url': endpoint});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ControlledApi(prefs);
    final frames =
        StreamController<SoundClassificationFrame>.broadcast(sync: true);
    final activities =
        StreamController<SoundSourceActivitySnapshot>.broadcast(sync: true);
    final store = EncryptedPhaseUploadStore();
    final origin = DateTime.utc(2026, 11, 5);
    SourcePhaseUploadService make() => SourcePhaseUploadService(
        store: store,
        transport: api,
        preferences: prefs,
        frames: frames.stream,
        activity: activities.stream,
        now: () => origin);
    var service = make();
    await service.initialize(automatic: false);
    await service.setEnabled(true);
    addTearDown(() async {
      service.dispose();
      await frames.close();
      await activities.close();
      await LocalDiaryRepository.resetForTesting();
      await directory.delete(recursive: true);
    });
    void add(Map<String, dynamic> row, {int offset = 0}) {
      final a =
          origin.add(Duration(milliseconds: (row['start_ms'] as int) + offset));
      final b =
          origin.add(Duration(milliseconds: (row['end_ms'] as int) + offset));
      frames.add(SoundClassificationFrame(
          windowStart: a,
          windowEnd: b,
          category: 'unknown_sound_source',
          confidence: 0,
          categoryScores: (row['scores'] as Map)
              .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
          topYamnetScores: const [],
          inferenceMs: 1));
    }

    final scene = jsonDecode(
        await File('$root/EN2006a.Array1-01.mapped-frames.json')
            .readAsString()) as Map;
    final rows = (scene['frames'] as List).cast<Map<String, dynamic>>();
    var checkpoint = 60000;
    for (final row in rows) {
      add(row);
      if ((row['start_ms'] as int) >= checkpoint) {
        api.offline = checkpoint >= 180000 && checkpoint < 300000;
        if (checkpoint == 420000) api.loseAck = true;
        await service.checkpointAndSync();
        if (checkpoint == 420000) {
          expect(service.pendingCount, greaterThan(0));
          await service
              .checkpointAndSync(); // identical retry, after committed but lost ACK
        }
        checkpoint += 60000;
      }
    }
    await service.stopCapture();
    await service.checkpointAndSync();
    expect(service.error, isNull);
    expect(service.pendingCount, 0);
    expect(api.lostAcks, 1);
    final remote = await api.listSourcePhases();
    expect(remote.length, 1);
    expect(remote.single['family'], 'speech');
    expect(remote.single['state'], 'closed');
    expect(remote.single['end_ms'] - remote.single['start_ms'], 1199535);
    expect(remote.single['revision'], greaterThan(10));
    final initialId = remote.single['phase_id'];
    // A separate offline process interruption must not extend that natural phase.
    api.offline = true;
    for (final row in rows.take(100)) {
      add(row, offset: 4000000);
    }
    await service.checkpointAndSync();
    expect(service.pendingCount, 1);
    service.dispose();
    await LocalDiaryRepository.resetForTesting();
    service = make();
    await service.initialize(automatic: false);
    api.offline = false;
    await service.checkpointAndSync();
    final recovered = await api.listSourcePhases();
    expect(recovered.length, 2);
    expect(recovered.where((p) => p['state'] == 'interrupted').length, 1);
    expect(recovered.where((p) => p['phase_id'] == initialId).length, 1);
    await service.deleteRemotePhases();
    expect(service.pendingCount, 0);
    expect(await api.listSourcePhases(), isEmpty);
    expect(await store.list(), isEmpty);
    final report = {
      'natural_scene': 'EN2006a.Array1-01',
      'natural_phase_count': remote.length,
      'span_ms': 1199535,
      'last_revision': remote.single['revision'],
      'lost_ack_retried': true,
      'offline_resume': true,
      'restart_marked_interrupted': true,
      'remote_erasure_confirmed': true,
      'backend': 'dedicated local HTTP and PostgreSQL, no Pixel connection'
    };
    await File('$root/http-integration-result.json')
        .writeAsString(jsonEncode(report));
  },
      skip: root == null || endpoint == null
          ? 'Needs explicit disposable QA server and public natural fixtures'
          : false,
      timeout: const Timeout(Duration(minutes: 3)));
}
