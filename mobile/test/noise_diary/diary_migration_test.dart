import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
      'migration is transactional, encrypts data and fails closed on missing key',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('diary-migration-test-');
    addTearDown(() async {
      await LocalDiaryRepository.resetForTesting();
      await directory.delete(recursive: true);
    });
    await databaseFactory.setDatabasesPath(directory.path);
    final dbPath = path.join(directory.path, 'personal_noise_diary.db');
    var db =
        await openDatabase(dbPath, version: 1, onCreate: (db, version) async {
      await db.execute(
          'CREATE TABLE diary_entries (id TEXT PRIMARY KEY, started_at INTEGER NOT NULL, ended_at INTEGER, description TEXT NOT NULL, impact TEXT NOT NULL)');
      await db.insert('diary_entries', {
        'id': 'legacy',
        'started_at': 1000,
        'ended_at': null,
        'description': 'very_private_test_sentence',
        'impact': 'test effect'
      });
    });
    await db.close();

    FlutterSecureStorage.setMockInitialValues(
        {'personal_noise_diary_key_v1': 'invalid'});
    final repo = LocalDiaryRepository();
    await expectLater(repo.list(), throwsA(anything));
    await LocalDiaryRepository.resetForTesting();
    db = await openDatabase(dbPath, version: 1);
    expect((await db.query('diary_entries')).single['description'],
        'very_private_test_sentence');
    await db.close();

    FlutterSecureStorage.setMockInitialValues({});
    final entries = await repo.list();
    expect(entries.single.description, 'very_private_test_sentence');
    const storage = FlutterSecureStorage();
    final key = await storage.read(key: 'personal_noise_diary_key_v1');
    expect(key, isNotNull);
    await LocalDiaryRepository.resetForTesting();
    final raw = await File(dbPath).readAsBytes();
    expect(String.fromCharCodes(raw),
        isNot(contains('very_private_test_sentence')));

    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(repo.list(), throwsA(anything));
    await expectLater(
        repo.save(DiaryEntry(
            id: 'new',
            startedAt: DateTime.now(),
            description: 'must not overwrite')),
        throwsA(anything));
    await LocalDiaryRepository.resetForTesting();
    FlutterSecureStorage.setMockInitialValues(
        {'personal_noise_diary_key_v1': key!});
    expect(
        (await repo.list()).single.description, 'very_private_test_sentence');
  });
}
