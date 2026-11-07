// Screenshot fixture loader, never a store entry point.
// Run only on a fresh, dedicated Android emulator. Replace this APK with the
// unmodified release APK (same local QA signing key) before taking screenshots.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:noisenet_mobile/core/database/dao/noise_measurement_dao.dart';
import 'package:noisenet_mobile/core/database/models/noise_measurement.dart';
import 'package:noisenet_mobile/features/noise_diary/data/diary_repository.dart';
import 'package:noisenet_mobile/features/noise_history/data/noise_history.dart';
import 'package:noisenet_mobile/main.dart' as app;
import 'package:noisenet_mobile/services/sqlite_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  if (!kDebugMode ||
      !Platform.isAndroid ||
      !const bool.fromEnvironment('ONN_ASO_FIXTURE')) {
    throw StateError('Fixture loader requires an explicit Android debug run');
  }
  final emulator = await Process.run('/system/bin/getprop', ['ro.kernel.qemu']);
  if (emulator.exitCode != 0 || emulator.stdout.toString().trim() != '1') {
    throw StateError('Fixture loader refuses physical devices');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final diary = LocalDiaryRepository();
  final history = EncryptedSourceHistoryStore(diary);
  final measurements = NoiseMeasurementDao();
  if (prefs.getBool('aso_fixture_20261107') == true) {
    app.main();
    return;
  }
  if ((await diary.list()).isNotEmpty ||
      (await history.list()).isNotEmpty ||
      (await measurements.count()) > 0) {
    throw StateError('Existing user data found; no fixture written');
  }
  final day = DateTime.now();
  DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);
  if (day.isBefore(at(9, 15))) {
    throw StateError(
        'Run after 09:15 local time so all examples are in the past');
  }
  var nextId = 0;
  Future<void> scene(String category, DateTime start, int seconds,
      List<(int, int)> intervals) async {
    await history.save(SourceHistoryEntry(
        id: 'aso-coverage-${nextId++}',
        category: 'unknown_sound_source',
        start: start,
        end: start.add(Duration(seconds: seconds)),
        confidence: 0,
        isCoverage: true));
    for (final interval in intervals) {
      await history.save(SourceHistoryEntry(
          id: 'aso-source-${nextId++}',
          category: category,
          start: start.add(Duration(seconds: interval.$1)),
          end: start.add(Duration(seconds: interval.$2)),
          confidence: .78));
    }
  }

  await scene('road_traffic', at(8, 12), 1140,
      [(0, 260), (280, 590), (610, 900), (920, 1140)]);
  await scene('drilling', at(8, 45), 1080, [(0, 330), (345, 705), (720, 1080)]);
  await scene(
      'loud_conversation', at(9, 5), 480, [(0, 150), (165, 315), (330, 480)]);
  await measurements.insertBatch([
    for (var i = 0; i < 70; i++)
      NoiseMeasurement(
          timestamp:
              at(8, 10).add(Duration(minutes: i)).millisecondsSinceEpoch ~/
                  1000,
          leqDb: i >= 2 && i < 21
              ? 58 + (i % 6).toDouble()
              : i >= 35 && i < 53
                  ? 61 + (i % 7).toDouble()
                  : 39 + (i % 5).toDouble(),
          samplesCount: 60,
          createdAt:
              at(8, 10).add(Duration(minutes: i + 1)).millisecondsSinceEpoch ~/
                  1000),
  ]);
  await diary.save(DiaryEntry(
      id: 'aso-diary-traffic',
      startedAt: at(8, 12),
      endedAt: at(8, 31),
      description: 'Beispiel: Wiederholt Fahrzeuge am offenen Fenster.',
      impact: 'Lesen mehrmals unterbrochen.',
      soundHint: DiarySoundHint(
          category: 'road_traffic', start: at(8, 12), end: at(8, 31))));
  await diary.save(DiaryEntry(
      id: 'aso-diary-tools',
      startedAt: at(8, 45),
      endedAt: at(9, 3),
      description: 'Beispiel: Wiederholtes Bohren aus Richtung Hinterhof.',
      impact: 'Fenster geschlossen; Konzentration fiel schwer.',
      soundHint: DiarySoundHint(
          category: 'drilling', start: at(8, 45), end: at(9, 3))));
  final settings = SQLitePreferencesService();
  await settings.initialize();
  await settings.setIsDarkMode(true);
  await settings.setForceOfflineMode(true);
  await settings.setAutoSubmissionEnabled(false);
  await settings.setOnboardingComplete(true);
  await prefs.setBool('is_dark_mode', true);
  await prefs.setBool('private_source_history_enabled_v1', true);
  await prefs.setBool('aso_fixture_20261107', true);
  debugPrint(
      'ONN_ASO_SEED_READY: 3 scenes, 2 diary entries, 70 synthetic minutes');
  app.main();
}
