import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_export.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_repository.dart';
import 'package:noisenet_mobile/features/noise_diary/presentation/noise_diary_page.dart';

class TestDiaryRepository implements DiaryRepository {
  final Map<String, DiaryEntry> entries = {};
  bool failSave = false;

  @override
  Future<List<DiaryEntry>> list() async => entries.values.toList();
  @override
  Future<void> save(DiaryEntry entry) async {
    if (failSave) throw Exception('disk error');
    entries[entry.id] = entry;
  }

  @override
  Future<void> delete(String id) async => entries.remove(id);
}

void main() {
  test('encrypted entries hide content and reject tampering or wrong identity',
      () async {
    final cipher = DiaryCipher();
    final key = await AesGcm.with256bits().newSecretKey();
    final entry = DiaryEntry(
        id: 'entry-1',
        startedAt: DateTime.utc(2026),
        description: 'Vertrauliche Beobachtung',
        soundHint: DiarySoundHint(
            category: 'drilling',
            start: DateTime.utc(2026),
            end: DateTime.utc(2026, 1, 1, 0, 1)));
    final row = await cipher.encrypt(entry, key);
    expect(row.values.toString(), isNot(contains('Vertrauliche Beobachtung')));
    final restored = await cipher.decrypt(row, key);
    expect(restored.description, entry.description);
    expect(restored.soundHint?.category, 'drilling');
    final second = await cipher.encrypt(entry, key);
    expect(row['nonce'], isNot(equals(second['nonce'])));
    await expectLater(
        cipher.decrypt({...row, 'id': 'other'}, key), throwsA(anything));
    final damaged = List<int>.of(row['payload']! as List<int>);
    damaged[0] ^= 1;
    await expectLater(
        cipher.decrypt({...row, 'payload': damaged}, key), throwsA(anything));
    await expectLater(
        cipher.decrypt(row, await AesGcm.with256bits().newSecretKey()),
        throwsA(anything));
  });

  test('temporary cleanup deletes only our own matching CSV files', () async {
    final temp = await Directory.systemTemp.createTemp('diary-cleanup-test-');
    addTearDown(() => temp.delete(recursive: true));
    final stale = File(
        '${temp.path}/OpenNoiseNet-Tagebuch-12345678-1234-1234-1234-123456789abc.csv');
    final other = File('${temp.path}/personal.csv');
    final lookalike = File('${temp.path}/OpenNoiseNet-Tagebuch-other.csv');
    final folder = Directory(
        '${temp.path}/OpenNoiseNet-Tagebuch-87654321-4321-4321-4321-cba987654321.csv');
    await stale.writeAsString('test');
    await other.writeAsString('keep');
    await lookalike.writeAsString('keep');
    await folder.create();

    await DiaryExporter().cleanTemporaryDirectory(temp);

    expect(await stale.exists(), isFalse);
    expect(await other.readAsString(), 'keep');
    expect(await lookalike.readAsString(), 'keep');
    expect(await folder.exists(), isTrue);
  });

  test('CSV distinguishes hint and observation and guards formula input', () {
    final entry = DiaryEntry(
        id: '1',
        startedAt: DateTime.utc(2026),
        description: '=1+1',
        impact: 'Text, "zitiert"',
        soundHint: DiarySoundHint(
            category: 'drilling',
            start: DateTime.utc(2026),
            end: DateTime.utc(2026, 1, 1, 0, 1)));
    final csv = diaryEntriesCsv([entry]);
    expect(csv, contains("\"'=1+1\""));
    expect(csv, contains('Text, ""zitiert""'));
    expect(csv, contains('App-Vorschlag (ungeprüft)'));
    expect(csv, contains('Bohren'));
  });

  testWidgets('explicit model hint remains separate from user observation',
      (tester) async {
    final repo = TestDiaryRepository();
    final hint = DiarySoundHint(
        category: 'drilling',
        start: DateTime(2026, 11, 3, 10),
        end: DateTime(2026, 11, 3, 10, 1));
    await tester.pumpWidget(MaterialApp(
        home: NoiseDiaryPage(repository: repo, initialSoundHint: hint)));
    await tester.pumpAndSettle();
    expect(find.text('App-Vorschlag: Bohren'), findsOneWidget);
    expect(repo.entries, isEmpty);
    await tester.enterText(
        find.byType(TextFormField).first, 'Ich hörte ein Geräusch');
    await tester.scrollUntilVisible(find.text('Eintrag speichern'), 250,
        scrollable: find
            .descendant(
                of: find.byType(Form), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eintrag speichern'));
    await tester.pumpAndSettle();
    expect(repo.entries.values.single.soundHint?.category, 'drilling');
    expect(repo.entries.values.single.description, 'Ich hörte ein Geräusch');
  });

  test('entry serialization retains unknown end and UTC instant', () {
    final entry = DiaryEntry(
        id: 'a',
        startedAt: DateTime.utc(2026, 11, 3, 21),
        description: 'Klopfen');
    final restored = DiaryEntry.fromMap(entry.toMap());
    expect(restored.startedAt.toUtc(), entry.startedAt);
    expect(restored.endedAt, isNull);
    expect(restored.description, 'Klopfen');
  });

  testWidgets('create, reopen, edit, cancel deletion and delete',
      (tester) async {
    final repo = TestDiaryRepository();
    Future<void> open() async {
      await tester
          .pumpWidget(MaterialApp(home: NoiseDiaryPage(repository: repo)));
      await tester.pumpAndSettle();
    }

    await open();
    expect(
        find.text(
            'Noch keine Einträge. Halte fest, was du selbst beobachtet hast.'),
        findsOneWidget);
    await tester.tap(find.text('Eintrag'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Eintrag speichern'));
    await tester.tap(find.text('Eintrag speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte eine Beobachtung eingeben.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Dumpfes Klopfen');
    await tester.ensureVisible(find.text('Eintrag speichern'));
    await tester.tap(find.text('Eintrag speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Dumpfes Klopfen'), findsOneWidget);
    expect(repo.entries.length, 1);
    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.text('Dumpfes Klopfen'), findsOneWidget);
    await tester.tap(find.text('Dumpfes Klopfen'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Wiederholtes Klopfen');
    await tester.ensureVisible(find.text('Eintrag speichern'));
    await tester.tap(find.text('Eintrag speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Wiederholtes Klopfen'), findsOneWidget);
    expect(repo.entries.length, 1);
    await tester.tap(find.byTooltip('Eintrag löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repo.entries.length, 1);
    await tester.tap(find.byTooltip('Eintrag löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(repo.entries, isEmpty);
  });

  testWidgets('failed save keeps the draft and permits retry', (tester) async {
    final repo = TestDiaryRepository()..failSave = true;
    await tester
        .pumpWidget(MaterialApp(home: NoiseDiaryPage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eintrag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Testbeobachtung');
    await tester.ensureVisible(find.text('Eintrag speichern'));
    await tester.tap(find.text('Eintrag speichern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Speichern fehlgeschlagen'), findsOneWidget);
    expect(find.text('Testbeobachtung'), findsOneWidget);
    expect(repo.entries, isEmpty);
    repo.failSave = false;
    await tester.ensureVisible(find.text('Eintrag speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eintrag speichern'));
    await tester.pumpAndSettle();
    expect(repo.entries.length, 1);
  });
}
