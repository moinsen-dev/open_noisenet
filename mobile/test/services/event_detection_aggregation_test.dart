import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:noisenet_mobile/core/logging/app_logger.dart';
import 'package:noisenet_mobile/services/event_detection_service.dart';
import 'package:noisenet_mobile/services/sqlite_preferences_service.dart';

class _Settings implements SQLitePreferencesService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppLogger.initialize);

  test('event aggregation excludes pre-trigger windows and counts buffers once',
      () async {
    final locator = GetIt.instance;
    locator.registerSingleton<SQLitePreferencesService>(_Settings());
    addTearDown(locator.reset);
    final detector = EventDetectionService();
    detector.setDayNightThresholds(dayThresholdDb: 90, nightThresholdDb: 90);
    detector.setThreshold(60);
    expect(detector.useTimeBasedThresholds, isFalse,
        reason: 'A local setting must not retain a previous policy override');
    final input = StreamController<double>();
    await detector.startMonitoring(input.stream);
    addTearDown(() async {
      await detector.stopMonitoring();
      await input.close();
    });

    detector.addSample(30); // Before the rolling threshold crossing.
    detector.addSample(70); // Starts the event.
    detector.addSample(70);
    detector.addSample(80);
    final status = detector.getStatus();
    final expected =
        10 * log((pow(10, 7) + pow(10, 7) + pow(10, 8)) / 3) / ln10;
    expect(status['hasActiveEvent'], isTrue);
    expect(status['activeEventSampleCount'], 3);
    expect(status['activeEventAverageDb'], closeTo(expected, 1e-9));
  });
}
