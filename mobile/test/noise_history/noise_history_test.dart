import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:noisenet_mobile/core/database/models/noise_measurement.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_repository.dart';
import 'package:noisenet_mobile/features/noise_history/data/noise_history.dart';
import 'package:noisenet_mobile/features/noise_history/presentation/noise_history_page.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_diagnostics_privacy.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MemoryStore implements SourceHistoryStore {
  final Map<String, SourceHistoryEntry> records = {};
  @override
  Future<void> save(SourceHistoryEntry entry) async =>
      records[entry.id] = entry;
  @override
  Future<List<SourceHistoryEntry>> list() async => records.values.toList();
  @override
  Future<void> clear() async => records.clear();
}

SoundSourceSegment segment(DateTime start, int seconds,
        {String category = OpenNoiseCategory.loudConversation}) =>
    SoundSourceSegment(
        start: start,
        end: start.add(Duration(seconds: seconds)),
        category: category,
        confidence: .5,
        evidenceFrameCount: 4,
        strongestYamnetScores: const [],
        timingBasis: 'test');
SoundSourceActivitySnapshot snap(SoundSourceSegment? active,
        [SoundSourceSegment? completed]) =>
    SoundSourceActivitySnapshot(
        observedAt: DateTime.now(),
        latestCategory: 'unknown_sound_source',
        latestConfidence: 0,
        activeSegment: active,
        lastCompletedSegment: completed);
NoiseMeasurement minute(int timestamp, double level) => NoiseMeasurement(
    timestamp: timestamp,
    leqDb: level,
    lmaxDb: level + 5,
    createdAt: timestamp,
    samplesCount: 400);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
      'history is opt-in, starts at activation, checkpoints, and clears safely',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final stream =
        StreamController<SoundSourceActivitySnapshot>.broadcast(sync: true);
    final store = MemoryStore();
    var now = DateTime.utc(2026, 11, 4, 7, 10);
    final collector = SoundHistoryCollector(
        store: store,
        preferences: prefs,
        activity: stream.stream,
        now: () => now);
    addTearDown(() async {
      collector.dispose();
      await stream.close();
    });
    final before = now.subtract(const Duration(minutes: 1));
    stream.add(snap(segment(before, 90)));
    await collector.flush();
    expect(store.records, isEmpty);
    await collector.setEnabled(true);
    stream.add(snap(segment(before, 90)));
    await collector.flush();
    expect(store.records.values.single.start, now);
    stream.add(snap(segment(before, 115)));
    await collector.flush();
    expect(store.records.values.single.end,
        before.add(const Duration(seconds: 90)));
    stream.add(snap(segment(before, 125)));
    await collector.flush();
    expect(store.records.values.single.end,
        before.add(const Duration(seconds: 125)));
    stream.add(snap(null, segment(before, 130)));
    stream.add(snap(null, segment(before, 130)));
    await collector.flush();
    expect(store.records.length, 1);
    expect(store.records.values.single.end,
        before.add(const Duration(seconds: 130)));
    now = now.add(const Duration(minutes: 3));
    await collector.clear();
    expect(store.records, isEmpty);
    stream.add(snap(null, segment(before, 130)));
    await collector.flush();
    expect(store.records, isEmpty);
    await collector.setEnabled(false);
    expect(prefs.getBool('private_source_history_enabled_v1'), isFalse);
  });

  test('groups with explicit gaps and keeps source and minute overlap separate',
      () {
    final start = DateTime.utc(2026, 11, 4, 7);
    SourceHistoryEntry e(int a, int b, String id) => SourceHistoryEntry(
        id: id,
        category: OpenNoiseCategory.loudConversation,
        start: start.add(Duration(seconds: a)),
        end: start.add(Duration(seconds: b)),
        confidence: .5);
    final groups =
        groupSourceHistory([e(0, 10, 'a'), e(30, 40, 'b'), e(110, 120, 'c')]);
    expect(groups.length, 2);
    expect(groups.last.span, const Duration(seconds: 40));
    expect(groups.last.detected, const Duration(seconds: 20));
    expect(groups.last.gaps, 1);
    final s = start.millisecondsSinceEpoch ~/ 1000;
    final levels = groupLevelHistory([
      minute(s, 60),
      minute(s + 60, 61),
      minute(s + 180, 62),
      minute(s + 240, 20)
    ], threshold: 55);
    expect(levels.map((b) => b.duration.inMinutes), [1, 2]);
    final ambiguous = [
      minute(s, 60),
      minute(s + 60, 60),
      minute(s + 60, 80),
      minute(s + 120, 60)
    ];
    final split = groupLevelHistory(ambiguous, threshold: 55);
    expect(split.map((b) => b.duration.inMinutes), [1, 1]);
    expect(overlappingMinutes(groups.last, [minute(s, 60), minute(s, 80)]),
        isEmpty);
    expect(
        overlappingSources(levels.last, [e(10, 20, 'x'), e(120, 130, 'y')])
            .length,
        1);
    expect(
        overlappingMinutes(groups.last, [minute(s, 60), minute(s + 60, 60)])
            .length,
        1);
  });

  test('heartbeat allowlist does not expose source labels or scores', () {
    final filtered = publicSoundHealth({
      'initialized': true,
      'inference_count': 4,
      'latest_category': 'loud_conversation',
      'latest_top_yamnet_scores': ['private'],
      'active_source_category': 'loud_conversation',
      'new_future_sensitive_field': 'private'
    });
    expect(filtered, {'initialized': true, 'inference_count': 4});
  });

  test('multi-source collection persists coverage, splits gaps and clears both',
      () async {
    SharedPreferences.setMockInitialValues({});
    final activity =
        StreamController<SoundSourceActivitySnapshot>.broadcast(sync: true);
    final frames =
        StreamController<SoundClassificationFrame>.broadcast(sync: true);
    final store = MemoryStore();
    final start = DateTime.utc(2026, 11, 5);
    final collector = SoundHistoryCollector(
        store: store,
        preferences: await SharedPreferences.getInstance(),
        activity: activity.stream,
        frames: frames.stream,
        now: () => start);
    addTearDown(() async {
      collector.dispose();
      await activity.close();
      await frames.close();
    });
    SoundClassificationFrame frame(int t) => SoundClassificationFrame(
        windowStart: start.add(Duration(milliseconds: t)),
        windowEnd: start.add(Duration(milliseconds: t + 975)),
        category: 'road_traffic',
        confidence: .9,
        categoryScores: const {'loud_conversation': .5, 'road_traffic': .9},
        topYamnetScores: const [],
        inferenceMs: 1);
    frames.add(frame(0));
    await collector.flush();
    expect(store.records, isEmpty);
    await collector.setEnabled(true);
    for (final t in [0, 480, 960, 1440, 10000, 10480, 10960]) {
      frames.add(frame(t));
    }
    activity.add(SoundSourceActivitySnapshot(
        isFinal: true,
        observedAt: start,
        latestCategory: 'unknown_sound_source',
        latestConfidence: 0,
        activeSegment: null,
        lastCompletedSegment: null));
    await collector.flush();
    final entries = await store.list();
    expect(entries.where((e) => e.isCoverage), hasLength(2));
    expect(
        entries
            .where((e) => !e.isCoverage && e.category == 'loud_conversation'),
        hasLength(2));
    final phases = sourcePhases(entries);
    expect(phases.where((p) => p.family == 'speech'), hasLength(2));
    expect(phases.where((p) => p.family == 'traffic'), hasLength(2));
    await collector.clear();
    await collector.flush();
    expect(await store.list(), isEmpty);
    await collector.setEnabled(false);
    frames.add(frame(20000));
    await collector.flush();
    expect(await store.list(), isEmpty);
  });

  test('maximal episode bridges short measured pauses but never missing data',
      () {
    final start = DateTime.utc(2026, 11, 5).millisecondsSinceEpoch ~/ 1000;
    final repeated = List.generate(
        33, (i) => minute(start + i * 60, i % 5 == 3 || i % 5 == 4 ? 30 : 60));
    final episode = groupLevelHistory(repeated, threshold: 55).single;
    expect(episode.duration.inMinutes, 33);
    expect(episode.activeMinutes, 21);
    expect(episode.pauseMinutes, 12);
    expect(episode.pauseCount, 6);
    expect(
        groupLevelHistory(repeated, threshold: 55, maxPauseMinutes: 0).length,
        7);
    final missing = [...repeated]..removeAt(10);
    expect(groupLevelHistory(missing, threshold: 55).length, 2);
    final invalid = [...repeated]..[10] = minute(start + 600, double.nan);
    expect(groupLevelHistory(invalid, threshold: 55).length, 2);
    final longPause = [60.0, 30.0, 30.0, 30.0, 60.0, 30.0]
        .asMap()
        .entries
        .map((e) => minute(start + e.key * 60, e.value))
        .toList();
    expect(
        groupLevelHistory(longPause, threshold: 55)
            .map((b) => b.duration.inMinutes),
        [1, 1]);
  });

  test('source coverage clips to episode and unions overlapping hints', () {
    final start = DateTime.utc(2026, 11, 5);
    final block = groupLevelHistory(
            [minute(start.millisecondsSinceEpoch ~/ 1000, 60)],
            threshold: 55)
        .single;
    SourceHistoryEntry hint(int a, int b) => SourceHistoryEntry(
        id: '$a',
        category: OpenNoiseCategory.loudConversation,
        start: start.add(Duration(seconds: a)),
        end: start.add(Duration(seconds: b)),
        confidence: .5);
    expect(sourceCoverage(block, [hint(-10, 20), hint(10, 30), hint(50, 90)]),
        const Duration(seconds: 40));
    expect(sourceCoverage(block, []), Duration.zero);
  });

  test(
      'source records encrypt timestamps and categories; missing key preserves data',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('noise-history-test-');
    addTearDown(() async {
      await LocalDiaryRepository.resetForTesting();
      await directory.delete(recursive: true);
    });
    await databaseFactory.setDatabasesPath(directory.path);
    FlutterSecureStorage.setMockInitialValues({});
    final repo = LocalDiaryRepository();
    final store = EncryptedSourceHistoryStore(repo);
    final start = DateTime.utc(2026, 11, 4, 7);
    await store.save(SourceHistoryEntry(
        id: 'history-test-id',
        category: OpenNoiseCategory.loudConversation,
        start: start,
        end: start.add(const Duration(seconds: 10)),
        confidence: .5));
    await repo.save(DiaryEntry(
        id: 'diary-test-id', startedAt: start, description: 'private diary'));
    const storage = FlutterSecureStorage();
    final key = await storage.read(key: 'personal_noise_diary_key_v1');
    expect((await store.list()).single.category,
        OpenNoiseCategory.loudConversation);
    await store.save(SourceHistoryEntry(
        id: 'coverage-test-id',
        category: 'unknown_sound_source',
        start: start,
        end: start.add(const Duration(seconds: 40)),
        confidence: 0,
        isCoverage: true));
    await LocalDiaryRepository.resetForTesting();
    final bytes =
        await File(path.join(directory.path, 'personal_noise_diary.db'))
            .readAsBytes();
    expect(String.fromCharCodes(bytes), isNot(contains('loud_conversation')));
    expect(String.fromCharCodes(bytes),
        isNot(contains(start.millisecondsSinceEpoch.toString())));
    expect(String.fromCharCodes(bytes), isNot(contains('private diary')));
    expect(
        String.fromCharCodes(bytes), isNot(contains('inference_coverage_v1')));
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(store.list(), throwsA(anything));
    await expectLater(
        repo.save(
            DiaryEntry(id: 'new', startedAt: start, description: 'must fail')),
        throwsA(anything));
    await LocalDiaryRepository.resetForTesting();
    FlutterSecureStorage.setMockInitialValues(
        {'personal_noise_diary_key_v1': key!});
    expect((await store.list()).length, 2);
    expect((await store.list()).where((e) => e.isCoverage), hasLength(1));
    await store.clear();
    expect(await store.list(), isEmpty);
    expect((await repo.list()).single.description, 'private diary');
  });

  testWidgets('history screen enables collection and displays a source hint',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final stream =
        StreamController<SoundSourceActivitySnapshot>.broadcast(sync: true);
    final store = MemoryStore();
    final now = DateTime.now();
    final collector = SoundHistoryCollector(
        store: store,
        preferences: prefs,
        activity: stream.stream,
        now: () => now);
    addTearDown(() async {
      collector.dispose();
      await stream.close();
    });
    await tester.pumpWidget(MaterialApp(
        home: NoiseHistoryPage(
            collector: collector, loadMeasurements: () async => [])));
    await tester.pumpAndSettle();
    expect(find.text('Geräuschhinweise speichern'), findsOneWidget);
    await tester.tap(find.text('Letzte 24 Stunden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gesamter gespeicherter Zeitraum').last);
    await tester.pumpAndSettle();
    expect(find.text('Gesamter gespeicherter Zeitraum'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(collector.enabled, isTrue);
    stream.add(snap(null, segment(now, 22)));
    await collector.flush();
    await tester.tap(find.byTooltip('Aktualisieren'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Laute Stimmen · ungeprüft'), 350);
    expect(find.text('Laute Stimmen · ungeprüft'), findsOneWidget);
  });
}
