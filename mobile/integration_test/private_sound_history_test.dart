import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noisenet_mobile/core/database/models/noise_measurement.dart';
import 'package:noisenet_mobile/core/logging/app_logger.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_repository.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_sound_label.dart';
import 'package:noisenet_mobile/features/noise_history/data/noise_history.dart';
import 'package:noisenet_mobile/features/noise_history/presentation/noise_history_page.dart';
import 'package:noisenet_mobile/services/sound_analysis/on_device_sound_analysis_service.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppLogger.initialize);

  testWidgets(
      'public test PCM reaches encrypted history and the timeline on device',
      (tester) async {
    final fixture = File(path.join(
        (await getApplicationDocumentsDirectory()).path,
        'noisenet_public_test_sample.pcm'));
    if (!await fixture.exists()) {
      fail('Supply the public 48 kHz mono PCM test fixture to this test app.');
    }
    addTearDown(() async {
      if (await fixture.exists()) await fixture.delete();
    });
    final bytes = await fixture.readAsBytes();
    final pcm = ByteData.sublistView(bytes);
    final prefs = await SharedPreferences.getInstance();
    final repository = LocalDiaryRepository();
    final store = EncryptedSourceHistoryStore(repository);
    final input = StreamController<PcmAudioFrame>();
    final analysis = OnDeviceSoundAnalysisService();
    final collector = SoundHistoryCollector(
        store: store, preferences: prefs, activity: analysis.sourceActivity);
    addTearDown(() async {
      await analysis.dispose();
      collector.dispose();
      await input.close();
      await LocalDiaryRepository.resetForTesting();
    });
    await collector.setEnabled(true);
    expect(await analysis.start(input.stream), isTrue);
    final started = DateTime.now().add(const Duration(seconds: 1));
    var frames = 0;
    for (var repeat = 0; repeat < 3; repeat++) {
      for (var offset = 0; offset + 1 < bytes.length; offset += 9600) {
        final end = (offset + 9600).clamp(0, bytes.length);
        final samples = <double>[];
        for (var i = offset; i + 1 < end; i += 2) {
          samples.add(pcm.getInt16(i, Endian.little) / 32768.0);
        }
        input.add(PcmAudioFrame(
            samples: samples,
            sampleRate: 48000,
            capturedAt: started.add(Duration(milliseconds: 100 * ++frames))));
        await Future<void>.delayed(const Duration(milliseconds: 65));
      }
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    await analysis.stop();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await collector.flush();
    expect(analysis.getDiagnostics()['inference_count'], greaterThan(0));
    final stored = await store.list();
    expect(stored, isNotEmpty,
        reason: 'The public example should yield a model hint.');
    final database =
        File(path.join(await getDatabasesPath(), 'personal_noise_diary.db'));
    final raw = await database.readAsBytes();
    final contents = String.fromCharCodes(raw);
    expect(contents, isNot(contains(stored.first.category)));
    expect(contents,
        isNot(contains(stored.first.start.millisecondsSinceEpoch.toString())));

    // Reopen the same database and retrieve its device-bound key, rather than
    // trusting the in-memory cache used for the first write.
    await LocalDiaryRepository.resetForTesting();
    final reopened = await store.list();
    expect(reopened.length, stored.length);
    final stamp = started.millisecondsSinceEpoch ~/ 60000 * 60;
    await tester.pumpWidget(MaterialApp(
        home: NoiseHistoryPage(
            collector: collector,
            loadMeasurements: () async => [
                  NoiseMeasurement(
                      timestamp: stamp,
                      leqDb: 65,
                      lmaxDb: 70,
                      samplesCount: 450,
                      createdAt: stamp)
                ])));
    await tester.pumpAndSettle();
    expect(find.text('Geräuschverlauf'), findsOneWidget);
    final label = '${diarySoundLabel(reopened.first.category)} · ungeprüft';
    await tester.scrollUntilVisible(find.text(label), 350,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(label), findsWidgets);
  });
}
