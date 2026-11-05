import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// A model suggestion is never a statement about a person or a proven source.
class DiarySoundHint {
  const DiarySoundHint(
      {required this.category, required this.start, required this.end});
  final String category;
  final DateTime start;
  final DateTime end;

  Map<String, Object?> toMap() => {
        'category': category,
        'start': start.toUtc().millisecondsSinceEpoch,
        'end': end.toUtc().millisecondsSinceEpoch,
      };

  factory DiarySoundHint.fromMap(Map<String, dynamic> map) => DiarySoundHint(
        category: map['category'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(map['start'] as int,
                isUtc: true)
            .toLocal(),
        end: DateTime.fromMillisecondsSinceEpoch(map['end'] as int, isUtc: true)
            .toLocal(),
      );
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.startedAt,
    required this.description,
    this.endedAt,
    this.impact = '',
    this.soundHint,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String description;
  final String impact;
  final DiarySoundHint? soundHint;

  Map<String, Object?> toMap() => {
        'id': id,
        'started_at': startedAt.toUtc().millisecondsSinceEpoch,
        'ended_at': endedAt?.toUtc().millisecondsSinceEpoch,
        'description': description,
        'impact': impact,
        if (soundHint != null) 'sound_hint': soundHint!.toMap(),
      };

  factory DiaryEntry.fromMap(Map<String, dynamic> data) => DiaryEntry(
        id: data['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
                data['started_at'] as int,
                isUtc: true)
            .toLocal(),
        endedAt: data['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(data['ended_at'] as int,
                    isUtc: true)
                .toLocal(),
        description: data['description'] as String,
        impact: data['impact'] as String,
        soundHint: data['sound_hint'] == null
            ? null
            : DiarySoundHint.fromMap(
                Map<String, dynamic>.from(data['sound_hint'] as Map)),
      );
}

abstract class DiaryRepository {
  Future<List<DiaryEntry>> list();
  Future<void> save(DiaryEntry entry);
  Future<void> delete(String id);
}

/// Encrypt the entire entry, including its timestamps, and bind it to its id.
class DiaryCipher {
  final AesGcm _algorithm = AesGcm.with256bits();

  Future<Map<String, Object?>> encrypt(DiaryEntry entry, SecretKey key) async {
    return encryptPayload(entry.id, entry.toMap(), key);
  }

  Future<Map<String, Object?>> encryptPayload(
      String id, Map<String, Object?> payload, SecretKey key) async {
    final box = await _algorithm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
      nonce: _algorithm.newNonce(),
      aad: utf8.encode(id),
    );
    return {
      'id': id,
      'nonce': Uint8List.fromList(box.nonce),
      'payload': Uint8List.fromList(box.cipherText),
      'tag': Uint8List.fromList(box.mac.bytes)
    };
  }

  Future<DiaryEntry> decrypt(Map<String, Object?> row, SecretKey key) async {
    final entry = DiaryEntry.fromMap(await decryptPayload(row, key));
    if (entry.id != row['id'])
      throw StateError('Diary entry identity mismatch');
    return entry;
  }

  Future<Map<String, dynamic>> decryptPayload(
      Map<String, Object?> row, SecretKey key) async {
    final id = row['id'] as String;
    final box = SecretBox(row['payload'] as List<int>,
        nonce: row['nonce'] as List<int>, mac: Mac(row['tag'] as List<int>));
    final clear =
        await _algorithm.decrypt(box, secretKey: key, aad: utf8.encode(id));
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }
}

/// Separate app-private database; entries never enter event or upload tables.
class LocalDiaryRepository implements DiaryRepository {
  static const _keyName = 'personal_noise_diary_key_v1';
  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static final DiaryCipher _cipher = DiaryCipher();
  static Future<Database>? _database;
  static Future<SecretKey>? _key;

  @visibleForTesting
  static Future<void> resetForTesting() async {
    final openDatabase = _database;
    _database = null;
    _key = null;
    if (openDatabase != null) {
      try {
        await (await openDatabase).close();
      } catch (_) {/* Failed open has nothing to close. */}
    }
  }

  Future<Database> get _db => _database ??= _open().catchError((Object error) {
        _database = null;
        throw error;
      });

  static Future<SecretKey> _loadKey({required bool create}) async {
    final existing = await _secureStorage.read(key: _keyName);
    if (existing != null) {
      final bytes = base64Decode(existing);
      if (bytes.length != 32) throw StateError('Invalid diary key');
      return SecretKey(bytes);
    }
    if (!create)
      throw StateError(
          'Diary key unavailable; existing entries were preserved');
    final key = await AesGcm.with256bits().newSecretKey();
    final encoded = base64Encode(await key.extractBytes());
    await _secureStorage.write(key: _keyName, value: encoded);
    // Fail closed if the platform storage cannot read the key back.
    if (await _secureStorage.read(key: _keyName) != encoded) {
      throw StateError('Diary key could not be persisted');
    }
    return key;
  }

  static Future<SecretKey> _getKey({required bool create}) =>
      _key ??= _loadKey(create: create).catchError((Object error) {
        _key = null;
        throw error;
      });

  static Future<void> _createTable(DatabaseExecutor db) => db.execute('''
    CREATE TABLE diary_secure_entries (
      id TEXT PRIMARY KEY,
      nonce BLOB NOT NULL,
      payload BLOB NOT NULL,
      tag BLOB NOT NULL
    )
  ''');

  static Future<void> _createHistoryTable(DatabaseExecutor db) => db.execute('''
    CREATE TABLE source_history (
      id TEXT PRIMARY KEY,
      nonce BLOB NOT NULL,
      payload BLOB NOT NULL,
      tag BLOB NOT NULL
    )
  ''');

  static Future<bool> _hasEncryptedEntries(DatabaseExecutor db) async =>
      (Sqflite.firstIntValue(await db.rawQuery('''
        SELECT (SELECT COUNT(*) FROM diary_secure_entries) +
               (SELECT COUNT(*) FROM source_history)
      ''')) ?? 0) > 0;

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    return openDatabase(path.join(directory, 'personal_noise_diary.db'),
        version: 3, onConfigure: (db) async {
      // This pragma returns a row. Darwin's SQLite rejects execute() for
      // row-producing statements even though Android accepts it.
      final result = await db.rawQuery('PRAGMA secure_delete = ON');
      if (Sqflite.firstIntValue(result) != 1) {
        throw StateError('Secure deletion could not be enabled');
      }
    }, onCreate: (db, version) async {
      await _createTable(db);
      await _createHistoryTable(db);
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await _createTable(db);
        final legacy = await db.query('diary_entries');
        if (legacy.isNotEmpty) {
          final key = await _getKey(create: true);
          for (final row in legacy) {
            final entry = DiaryEntry.fromMap(row);
            await db.insert(
                'diary_secure_entries', await _cipher.encrypt(entry, key));
          }
        }
        // onUpgrade is transactional: a failure preserves the original table.
        await db.execute('DROP TABLE diary_entries');
      }
      if (oldVersion < 3) await _createHistoryTable(db);
    });
  }

  @override
  Future<List<DiaryEntry>> list() async {
    final rows = await (await _db).query('diary_secure_entries');
    if (rows.isEmpty) return [];
    final key = await _getKey(create: false);
    final entries = <DiaryEntry>[];
    for (final row in rows) {
      entries.add(await _cipher.decrypt(row, key));
    }
    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries;
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    final db = await _db;
    final key = await _getKey(create: !await _hasEncryptedEntries(db));
    await db.insert('diary_secure_entries', await _cipher.encrypt(entry, key),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String id) async {
    await (await _db)
        .delete('diary_secure_entries', where: 'id = ?', whereArgs: [id]);
  }

  /// History records share the diary's device-bound key and backup rules.
  /// Timestamps, categories and scores are inside the authenticated ciphertext.
  Future<void> saveSourceHistory(String id, Map<String, Object?> value) async {
    final db = await _db;
    final key = await _getKey(create: !await _hasEncryptedEntries(db));
    await db.insert(
        'source_history', await _cipher.encryptPayload(id, value, key),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> listSourceHistory() async {
    final rows = await (await _db).query('source_history');
    if (rows.isEmpty) return [];
    final key = await _getKey(create: false);
    return Future.wait(rows.map((row) => _cipher.decryptPayload(row, key)));
  }

  Future<void> clearSourceHistory() async {
    await (await _db).delete('source_history');
  }
}

String newDiaryEntryId() => const Uuid().v4();
