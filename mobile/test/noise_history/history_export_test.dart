import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/core/database/models/noise_measurement.dart';
import 'package:noisenet_mobile/features/noise_history/data/history_export.dart';
import 'package:noisenet_mobile/features/noise_history/data/noise_history.dart';
import 'package:noisenet_mobile/features/noise_history/presentation/noise_history_page.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmptyHistory implements SourceHistoryStore {
  @override
  Future<void> clear() async {}
  @override
  Future<List<SourceHistoryEntry>> list() async => [];
  @override
  Future<void> save(SourceHistoryEntry entry) async {}
}

NoiseMeasurement minute(int stamp, double level) => NoiseMeasurement(
    id: 999,
    timestamp: stamp,
    leqDb: level,
    lmaxDb: level + 2,
    samplesCount: 100,
    createdAt: stamp);

void main() {
  test(
      'source phase export is independent of level threshold and clips coverage',
      () {
    final start = DateTime.utc(2026, 11, 5);
    SourceHistoryEntry entry(int a, int b, bool coverage) => SourceHistoryEntry(
        id: 'private-$a-$coverage',
        category: coverage ? 'unknown_sound_source' : 'loud_conversation',
        start: start.add(Duration(seconds: a)),
        end: start.add(Duration(seconds: b)),
        confidence: coverage ? 0 : .8,
        isCoverage: coverage);
    final data = jsonDecode(historyExportJson(
        minutes: [],
        hints: [
          entry(-10, 500, true),
          entry(0, 60, false),
          entry(80, 180, false)
        ],
        start: start,
        end: start.add(const Duration(seconds: 200)),
        comparisonLine: 100,
        maxPauseMinutes: 0));
    expect(data['episodes'], isEmpty);
    expect(data['source_hints'], hasLength(2));
    expect(data['analysis_coverage'].single['start_ms'],
        start.millisecondsSinceEpoch);
    expect(data['acoustic_phases'].single['active_ms'], 160000);
    expect(data['acoustic_phases'].single['pause_ms'], 20000);
  });
  test('export clips the chosen window, joins pauses and excludes identities',
      () {
    final start = DateTime.fromMillisecondsSinceEpoch(60000, isUtc: true);
    final end = DateTime.fromMillisecondsSinceEpoch(240000, isUtc: true);
    final text = historyExportJson(minutes: [
      minute(0, 80),
      minute(60, 40),
      minute(120, 20),
      minute(180, 40),
      minute(240, 90)
    ], hints: [
      SourceHistoryEntry(
          id: 'private-row-identity',
          category: 'road_traffic',
          start: start.subtract(const Duration(seconds: 20)),
          end: end.add(const Duration(seconds: 20)),
          confidence: .6)
    ], start: start, end: end, comparisonLine: 30, maxPauseMinutes: 1);
    final data = jsonDecode(text) as Map<String, dynamic>;
    expect((data['minutes'] as List).length, 3);
    expect(data['source_hints'][0]['start'], start.toIso8601String());
    expect(data['source_hints'][0]['end'], end.toIso8601String());
    expect(data['episodes'][0]['active_minutes'], 2);
    expect(data['episodes'][0]['pause_minutes'], 1);
    expect(data['episodes'][0]['source_coverage_ms'], 180000);
    expect(text, isNot(contains('private-row-identity')));
    expect(data['minutes'][0], isNot(contains('id')));
    expect(data['limitations']['levels'],
        contains('method_not_stored_per_minute'));
  });

  testWidgets(
      'cancel creates no export and saving requires explicit confirmation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final activity =
        StreamController<SoundSourceActivitySnapshot>.broadcast(sync: true);
    final collector = SoundHistoryCollector(
        store: EmptyHistory(),
        preferences: await SharedPreferences.getInstance(),
        activity: activity.stream);
    addTearDown(() async {
      collector.dispose();
      await activity.close();
    });
    var saves = 0;
    String? exported;
    await tester.pumpWidget(MaterialApp(
        home: NoiseHistoryPage(
            collector: collector,
            loadMeasurements: () async => [],
            saveExport: (document) async {
              saves++;
              exported = document;
              return true;
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Verlauf exportieren'));
    await tester.pumpAndSettle();
    expect(find.textContaining('unverschlüsselt'), findsWidgets);
    expect(saves, 0);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    await tester.tap(find.byTooltip('Verlauf exportieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speicherort wählen'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(jsonDecode(exported!)['schema'], 'opennoisenet.private_history.v1');
    await tester.pumpWidget(const SizedBox());
  });
}
