import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_repository.dart';
import 'package:noisenet_mobile/services/sound_analysis/source_phase_upload.dart';
import 'package:noisenet_mobile/services/sound_analysis/phase_upload_transport.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';

Map<String, dynamic> clone(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class MemoryPhaseStore implements PhaseUploadStore {
  final rows = <String, Map<String, dynamic>>{};
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> list() async =>
      rows.values.map(clone).toList();
  @override
  Future<void> save(String id, Map<String, dynamic> value) async {
    if (fail) throw StateError('disk unavailable');
    rows[id] = clone(value);
  }

  @override
  Future<void> remove(String id) async => rows.remove(id);
}

class FakePhaseTransport implements PhaseUploadTransport {
  @override
  String baseUrl = 'https://one.example.test/api/v1';
  @override
  String deviceId = 'test-device';
  bool offline = false, wrongAck = false, loseResponse = false;
  Future<void> Function()? duringPrepare;
  final sent = <Map<String, dynamic>>[];
  final server = <String, Map<String, dynamic>>{};
  final erased = <String>[];
  @override
  Future<String> ensureDeviceId() async => deviceId;
  @override
  Future<void> preparePhaseUpload(String destination, String device) async {
    if (offline) throw StateError('offline');
    await duringPrepare?.call();
  }

  @override
  Future<Map<String, dynamic>> putSourcePhase(String destination, String device,
      Map<String, dynamic> payload, bool Function() permitted) async {
    if (!permitted()) throw StateError('paused');
    sent.add(clone(payload));
    server[payload['phase_id'] as String] = clone(payload);
    if (loseResponse) {
      loseResponse = false;
      throw StateError('ACK lost');
    }
    return {
      'phase_id': payload['phase_id'],
      'device_id': device,
      'revision': payload['revision'],
      'status': 'acknowledged_by_server',
      'digest': wrongAck ? 'wrong' : await phasePayloadDigest(payload)
    };
  }

  @override
  Future<Map<String, dynamic>> deleteSourcePhase(String destination,
      String device, String phaseId, bool Function() permitted) async {
    if (!permitted()) throw StateError('paused');
    erased.add(phaseId);
    server.remove(phaseId);
    return {'phase_id': phaseId, 'device_id': device, 'status': 'deleted'};
  }
}

class Rig {
  final frames =
      StreamController<SoundClassificationFrame>.broadcast(sync: true);
  final activity =
      StreamController<SoundSourceActivitySnapshot>.broadcast(sync: true);
  final MemoryPhaseStore store;
  final FakePhaseTransport transport;
  final SharedPreferences prefs;
  late SourcePhaseUploadService service;
  bool history = true;
  static final origin = DateTime.utc(2026, 11, 5);
  Rig(this.prefs, {MemoryPhaseStore? store, FakePhaseTransport? transport})
      : store = store ?? MemoryPhaseStore(),
        transport = transport ?? FakePhaseTransport() {
    service = SourcePhaseUploadService(
        store: this.store,
        transport: this.transport,
        preferences: prefs,
        frames: frames.stream,
        activity: activity.stream,
        now: () => origin,
        historyEnabled: () => history);
  }
  Future<void> init() => service.initialize(automatic: false);
  void feed(int start, int end, {bool speech = true}) {
    for (var t = start; t < end; t += 480) {
      final a = origin.add(Duration(milliseconds: t));
      frames.add(SoundClassificationFrame(
          windowStart: a,
          windowEnd: a.add(const Duration(milliseconds: 975)),
          category: 'loud_conversation',
          confidence: speech ? .8 : 0,
          categoryScores: speech ? {'loud_conversation': .8} : const {},
          topYamnetScores: const [],
          inferenceMs: 1));
    }
  }

  Future<void> close() async {
    service.dispose();
    await frames.close();
    await activity.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<Rig> setup() async {
    SharedPreferences.setMockInitialValues({});
    final rig = Rig(await SharedPreferences.getInstance());
    await rig.init();
    addTearDown(rig.close);
    return rig;
  }

  test('opt-in excludes past frames; same phase continues through short pauses',
      () async {
    final r = await setup();
    r.feed(0, 10000);
    await r.service.checkpointAndSync();
    expect(r.store.rows, isEmpty);
    expect(r.transport.sent, isEmpty);
    await r.service.setEnabled(true);
    r.feed(10000, 30000);
    await r.service.checkpointAndSync();
    final id = r.transport.sent.single['phase_id'];
    r.feed(30000, 40000, speech: false);
    r.feed(40000, 60000);
    await r.service.checkpointAndSync();
    expect(r.transport.sent.last['phase_id'], id);
    expect(r.transport.sent.last['revision'], 2);
    expect(r.transport.sent.last['pause_ms'], greaterThan(0));
    expect(r.transport.server.length, 1);
    await r.service.stopCapture();
    await r.service.checkpointAndSync();
    expect(r.transport.sent.last['state'], 'closed');
    expect(r.service.pendingCount, 0);
    expect(r.transport.sent.last['start_ms'],
        Rig.origin.millisecondsSinceEpoch + 10000);
  });

  test(
      'offline snapshots coalesce; process restart closes interrupted phase and retries',
      () async {
    final r = await setup();
    await r.service.setEnabled(true);
    r.transport.offline = true;
    r.feed(0, 30000);
    await r.service.checkpointAndSync();
    r.feed(30000, 60000);
    await r.service.checkpointAndSync();
    expect(r.store.rows.length, 1);
    expect(r.service.pendingCount, 1);
    final oldId = r.store.rows.keys.single;
    final resumed = Rig(r.prefs, store: r.store, transport: r.transport);
    await resumed.init();
    addTearDown(resumed.close);
    r.transport.offline = false;
    await resumed.service.checkpointAndSync();
    expect(r.transport.server[oldId]!['state'], 'interrupted');
    resumed.feed(70000, 90000);
    await resumed.service.checkpointAndSync();
    expect(r.transport.server.length, 2);
    expect(resumed.service.pendingCount, 0);
  });

  test('windows crossing the consent boundary are not uploaded', () async {
    final r = await setup();
    await r.service.setEnabled(true);
    r.feed(-960, 0);
    await r.service.stopCapture();
    await r.service.checkpointAndSync();
    expect(r.store.rows, isEmpty);
    expect(r.transport.sent, isEmpty);
  });

  test('lost or wrong ACK never clears pending work; retries keep the same id',
      () async {
    final r = await setup();
    await r.service.setEnabled(true);
    r.feed(0, 30000);
    r.transport.loseResponse = true;
    await r.service.checkpointAndSync();
    expect(r.service.pendingCount, 1);
    expect(r.transport.server.length, 1);
    r.transport.wrongAck = true;
    await r.service.checkpointAndSync();
    expect(r.service.pendingCount, 1);
    r.transport.wrongAck = false;
    await r.service.checkpointAndSync();
    expect(r.service.pendingCount, 0);
    expect(r.transport.server.length, 1);
    expect(r.transport.sent.map((p) => p['phase_id']).toSet().length, 1);
  });

  test('disable during credential preparation prevents the request', () async {
    final r = await setup();
    await r.service.setEnabled(true);
    r.feed(0, 30000);
    // Do not await the serialized stop from inside a running serialized send.
    r.transport.duringPrepare = () async {
      unawaited(r.service.setEnabled(false));
    };
    await r.service.checkpointAndSync();
    await r.service.settled;
    expect(r.transport.sent, isEmpty);
    expect(r.service.pendingCount, 1);
  });

  test('backend changes cannot redirect previously authorized data', () async {
    final r = await setup();
    await r.service.setEnabled(true);
    r.feed(0, 30000);
    r.transport.duringPrepare = () async {
      r.transport.baseUrl = 'https://two.example.test/api/v1';
    };
    await r.service.checkpointAndSync();
    expect(r.transport.sent, isEmpty);
    r.feed(30000, 40000);
    await r.service.settled;
    expect(r.service.destinationMatches, isFalse);
    expect(r.store.rows.length, 1);
    expect((r.store.rows.values.single['body'] as Map)['state'], 'interrupted');
    expect(r.store.rows.values.single['destination'],
        'https://one.example.test/api/v1');
  });

  test('disk failure retains staged final data for retry without claiming ACK',
      () async {
    final r = await setup();
    await r.service.setEnabled(true);
    r.feed(0, 30000);
    r.store.fail = true;
    await r.service.stopCapture();
    expect(r.service.error, isNotNull);
    expect(r.service.pendingCount, 1);
    expect(r.transport.sent, isEmpty);
    r.store.fail = false;
    await r.service.checkpointAndSync();
    expect(r.transport.sent.single['state'], 'closed');
    expect(r.service.pendingCount, 0);
  });

  test('offline erasure is durable and later deletes rather than uploading',
      () async {
    final r = await setup();
    await r.service.setEnabled(true);
    r.feed(0, 30000);
    await r.service.checkpointAndSync();
    expect(r.transport.server.length, 1);
    r.transport.offline = true;
    await r.service.deleteRemotePhases();
    expect(r.service.enabled, isFalse);
    expect(r.service.pendingCount, 1);
    expect(r.store.rows.values.single['body'], isEmpty);
    final resumed = Rig(r.prefs, store: r.store, transport: r.transport);
    await resumed.init();
    addTearDown(resumed.close);
    r.transport.offline = false;
    await resumed.service.checkpointAndSync();
    expect(r.transport.sent.length, 1);
    expect(r.transport.server, isEmpty);
    expect(r.store.rows, isEmpty);
  });

  test('real inference gap and long absence create different phase identities',
      () async {
    final r = await setup();
    await r.service.setEnabled(true);
    r.feed(0, 30000);
    r.feed(40000, 60000);
    r.feed(60000, 180000, speech: false);
    r.feed(180000, 210000);
    await r.service.stopCapture();
    await r.service.checkpointAndSync();
    expect(r.transport.server.length, 3);
    expect(r.transport.sent.any((p) => p['end_reason'] == 'inference_gap'),
        isTrue);
    expect(
        r.transport.sent.any((p) => p['end_reason'] == 'pause_limit'), isTrue);
  });

  test('phase outbox encrypts all metadata; key loss preserves existing rows',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('phase-encryption-');
    await databaseFactory.setDatabasesPath(dir.path);
    await LocalDiaryRepository.resetForTesting();
    addTearDown(() async {
      await LocalDiaryRepository.resetForTesting();
      await dir.delete(recursive: true);
    });
    FlutterSecureStorage.setMockInitialValues({});
    // Begin with the previous schema and a real encrypted history row.
    final repo = LocalDiaryRepository();
    await repo.saveSourceHistory(
        'old-hint', {'category': 'legacy-private-hint', 'start': 1000});
    await LocalDiaryRepository.resetForTesting();
    final legacy = await openDatabase('${dir.path}/personal_noise_diary.db');
    await legacy.execute('DROP TABLE pilot_outbox');
    await legacy.execute('DROP TABLE phase_uploads');
    await legacy.execute('PRAGMA user_version = 3');
    await legacy.close();
    final store = EncryptedPhaseUploadStore();
    await store.save('synthetic-id', {
      'format': 1,
      'id': 'synthetic-id',
      'body': {'family': 'private_test_source'},
      'destination': 'https://private-test-destination.invalid'
    });
    expect((await repo.listSourceHistory()).single['category'],
        'legacy-private-hint');
    final key = await const FlutterSecureStorage()
        .read(key: 'personal_noise_diary_key_v1');
    await LocalDiaryRepository.resetForTesting();
    final bytes =
        await File('${dir.path}/personal_noise_diary.db').readAsBytes();
    expect(String.fromCharCodes(bytes), isNot(contains('private_test_source')));
    expect(String.fromCharCodes(bytes),
        isNot(contains('private-test-destination')));
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(store.list(), throwsA(anything));
    await expectLater(store.save('new', {'format': 1}), throwsA(anything));
    await LocalDiaryRepository.resetForTesting();
    FlutterSecureStorage.setMockInitialValues(
        {'personal_noise_diary_key_v1': key!});
    expect((await store.list()).single['id'], 'synthetic-id');
  });
}
