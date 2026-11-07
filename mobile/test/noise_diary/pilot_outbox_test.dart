import 'dart:io';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_repository.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_consent_controller.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_contribution_outbox.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SyntheticPilotApi implements ApiClientService {
  bool offline = true;
  @override
  int get credentialEpoch => 0;
  @override
  String get baseUrl => 'https://pilot.example/api/v1';
  @override
  bool get isAuthenticated => true;
  @override
  Future<String> mapPilotIdentity(String destination) async =>
      '00000000-0000-0000-0000-000000000002';
  @override
  Future<Map<String, dynamic>> enableMapPilot(String destination) async =>
      {'enabled': true, 'generation': '00000000-0000-0000-0000-000000000001'};
  @override
  Future<void> withdrawMapPilot(String destination,
      {String? expectedGeneration}) async {
    if (offline) throw StateError('synthetic network failure');
  }

  @override
  Future<void> uploadMapPilotContribution(String destination,
      Map<String, dynamic> contribution, bool Function() permitted) async {
    if (offline || !permitted()) throw StateError('synthetic network failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('pilot outbox is encrypted, separate and fails closed without the key',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('pilot-outbox-test-');
    await databaseFactory.setDatabasesPath(directory.path);
    FlutterSecureStorage.setMockInitialValues({});
    addTearDown(() async {
      await LocalDiaryRepository.resetForTesting();
      await directory.delete(recursive: true);
    });
    final repo = LocalDiaryRepository();
    await repo.save(DiaryEntry(
        id: 'diary',
        startedAt: DateTime.utc(2026),
        description: 'private diary'));
    await repo.savePilotContribution('00000000-0000-0000-0000-000000000001',
        {'day': '2031-06-19', 'band': 'synthetic-private-class'});
    expect((await repo.listPilotContributions()).single['band'],
        'synthetic-private-class');
    await expectLater(
        repo.savePilotContribution(
            '00000000-0000-0000-0000-000000000001', {'day': 'changed'}),
        throwsA(anything));
    final key = await const FlutterSecureStorage()
        .read(key: 'personal_noise_diary_key_v1');
    expect(key, isNotNull);
    await LocalDiaryRepository.resetForTesting();
    final dbPath = path.join(directory.path, 'personal_noise_diary.db');
    final db = await openDatabase(dbPath);
    final stored = (await db.query('pilot_outbox')).single;
    expect(String.fromCharCodes(stored['payload'] as List<int>),
        isNot(contains('synthetic-private-class')));
    expect(await db.getVersion(), 5);
    await db.close();
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(repo.listPilotContributions(), throwsA(anything));
    await expectLater(
        repo.savePilotContribution('00000000-0000-0000-0000-000000000002',
            {'day': 'must not overwrite'}),
        throwsA(anything));
    await LocalDiaryRepository.resetForTesting();
    FlutterSecureStorage.setMockInitialValues(
        {'personal_noise_diary_key_v1': key!});
    expect((await repo.listPilotContributions()).single['band'],
        'synthetic-private-class');
    await LocalDiaryRepository.resetForTesting();
    FlutterSecureStorage.setMockInitialValues({});
    await repo.clearPilotContributions();
    expect(await repo.listPilotContributions(), isEmpty);
    await LocalDiaryRepository.resetForTesting();
    FlutterSecureStorage.setMockInitialValues(
        {'personal_noise_diary_key_v1': key});
    expect((await repo.list()).single.description, 'private diary');
  });

  test('version 4 diary upgrades without losing encrypted entries', () async {
    final directory =
        await Directory.systemTemp.createTemp('pilot-upgrade-test-');
    await databaseFactory.setDatabasesPath(directory.path);
    addTearDown(() async {
      await LocalDiaryRepository.resetForTesting();
      await directory.delete(recursive: true);
    });
    final bytes = List<int>.filled(32, 7);
    FlutterSecureStorage.setMockInitialValues(
        {'personal_noise_diary_key_v1': base64Encode(bytes)});
    final dbPath = path.join(directory.path, 'personal_noise_diary.db');
    final db =
        await openDatabase(dbPath, version: 4, onCreate: (db, version) async {
      for (final table in [
        'diary_secure_entries',
        'source_history',
        'phase_uploads'
      ]) {
        await db.execute(
            'CREATE TABLE $table (id TEXT PRIMARY KEY, nonce BLOB NOT NULL, payload BLOB NOT NULL, tag BLOB NOT NULL)');
      }
      final entry = DiaryEntry(
          id: 'existing',
          startedAt: DateTime.utc(2026),
          description: 'preserved diary');
      await db.insert('diary_secure_entries',
          await DiaryCipher().encrypt(entry, SecretKey(bytes)));
    });
    await db.close();
    final repo = LocalDiaryRepository();
    expect((await repo.list()).single.description, 'preserved diary');
    expect(await repo.listPilotContributions(), isEmpty);
    await LocalDiaryRepository.resetForTesting();
    final upgraded = await openDatabase(dbPath);
    expect(await upgraded.getVersion(), 5);
    await upgraded.close();
  });

  test(
      'offline withdrawal clears the encrypted pilot outbox but preserves diary',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('pilot-revoke-test-');
    await databaseFactory.setDatabasesPath(directory.path);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    addTearDown(() async {
      await LocalDiaryRepository.resetForTesting();
      await directory.delete(recursive: true);
    });
    final repo = LocalDiaryRepository();
    final api = SyntheticPilotApi();
    final store = EncryptedPilotOutboxStore();
    final controller = PilotConsentController(
        await SharedPreferences.getInstance(), api,
        clearOutbox: store.clear, now: () => DateTime.utc(2026, 11, 1));
    await controller.enable(api.baseUrl);
    await repo.save(DiaryEntry(
        id: 'diary', startedAt: DateTime.utc(2026), description: 'keep diary'));
    final outbox = PilotContributionOutbox(
        store: store,
        api: api,
        consent: controller,
        qualityReady: () => true,
        now: () => DateTime.utc(2026, 11, 3));
    await outbox.enqueue(
        destination: api.baseUrl,
        generation: '00000000-0000-0000-0000-000000000001',
        day: '2026-11-02',
        band: 'medium');
    final staleRecord = (await store.list()).single;
    expect(await outbox.sync(), 0);
    final concurrentSave = store
        .save('00000000-0000-0000-0000-000000000003', {'band': 'synthetic'});
    final withdrawal = controller.withdraw();
    await concurrentSave;
    expect(await withdrawal, isFalse);
    expect(controller.pendingWithdrawal, isTrue);
    expect(await repo.listPilotContributions(), isEmpty);
    await store.acknowledge(staleRecord['id'] as String, staleRecord);
    expect(await repo.listPilotContributions(), isEmpty);
    expect((await repo.list()).single.description, 'keep diary');
    api.offline = false;
    expect(await controller.withdraw(automatic: true), isTrue);
  });
}
