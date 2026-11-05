import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/features/noise_history/data/noise_history.dart';
import 'package:noisenet_mobile/features/noise_history/presentation/noise_history_page.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SceneStore implements SourceHistoryStore {
  SceneStore(this.entries);
  final List<SourceHistoryEntry> entries;
  @override
  Future<void> clear() async => entries.clear();
  @override
  Future<List<SourceHistoryEntry>> list() async => entries;
  @override
  Future<void> save(SourceHistoryEntry entry) async => entries.add(entry);
}

void main() {
  testWidgets(
      '33 minute source phase appears without level events and exports intact',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previewFont = Platform.environment['ONN_PHASE_FONT'];
    if (previewFont != null) {
      await tester.runAsync(() async {
        final font = FontLoader('PhasePreview');
        font.addFont(Future.value(
            ByteData.sublistView(await File(previewFont).readAsBytes())));
        await font.load();
      });
    }
    SharedPreferences.setMockInitialValues({});
    final start = DateTime.now().subtract(const Duration(hours: 1));
    SourceHistoryEntry entry(int a, int b, {bool coverage = false}) =>
        SourceHistoryEntry(
            id: '$a-$coverage',
            category: coverage ? 'unknown_sound_source' : 'loud_conversation',
            start: start.add(Duration(seconds: a)),
            end: start.add(Duration(seconds: b)),
            confidence: coverage ? 0 : .7,
            isCoverage: coverage);
    final records = [
      entry(0, 1980, coverage: true),
      for (var t = 0; t < 1980; t += 30) entry(t, t + 20),
      entry(1970, 1980)
    ];
    final activity = StreamController<SoundSourceActivitySnapshot>.broadcast();
    final collector = SoundHistoryCollector(
        store: SceneStore(records),
        preferences: await SharedPreferences.getInstance(),
        activity: activity.stream);
    addTearDown(() async {
      collector.dispose();
      await activity.close();
    });
    String? exported;
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: previewFont == null
                ? null
                : ThemeData(fontFamily: 'PhasePreview'),
            home: NoiseHistoryPage(
                collector: collector,
                loadMeasurements: () async => [],
                saveExport: (document) async {
                  exported = document;
                  return true;
                }))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Sprachaktivität · Modellhinweis'), 250);
    await tester.tap(find.text('Sprachaktivität · Modellhinweis'));
    await tester.pumpAndSettle();
    expect(find.textContaining('33 Min.'), findsWidgets);
    expect(tester.takeException(), isNull);
    // Optional actual Flutter-rendered preview, never a fabricated device shot.
    final preview = Platform.environment['ONN_PHASE_PREVIEW'];
    if (preview != null) {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byTooltip('Verlauf exportieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speicherort wählen'));
    await tester.pumpAndSettle();
    final data = jsonDecode(exported!);
    expect(data['episodes'], isEmpty);
    expect(
        data['acoustic_phases'].single['end_ms'] -
            data['acoustic_phases'].single['start_ms'],
        1980000);
    expect(data['acoustic_phases'].single['active_ms'], 1330000);
    await tester.pumpWidget(const SizedBox());
  });
}
