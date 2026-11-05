import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/audio_processing_service.dart';
import 'package:noisenet_mobile/services/level_history.dart';

void main() {
  test('retains 15 minutes at microphone buffer rates, not 900 buffers', () {
    final start = DateTime.utc(2026, 11, 3);
    final history = LevelHistory();
    for (var i = 0; i <= 15 * 60 * 8; i++) {
      history.add(TimestampedSPL(
        timestamp: start.add(Duration(milliseconds: i * 125)),
        splDb: 60,
      ));
    }
    expect(history.samples.length, 7201);
    expect(history.samples.first.timestamp, start);
    history.add(TimestampedSPL(
      timestamp: start.add(const Duration(minutes: 15, milliseconds: 125)),
      splDb: 70,
    ));
    expect(history.samples.length, 7201);
    expect(history.samples.first.timestamp,
        start.add(const Duration(milliseconds: 125)));
  });

  test('bounds memory when buffers arrive at an unexpected rate', () {
    final history = LevelHistory(maxSamples: 2);
    final now = DateTime.utc(2026, 11, 3);
    for (var i = 0; i < 3; i++) {
      history.add(TimestampedSPL(
          timestamp: now.add(Duration(milliseconds: i)),
          splDb: 50 + i.toDouble()));
    }
    expect(history.samples.map((sample) => sample.splDb), [51, 52]);
  });
}
