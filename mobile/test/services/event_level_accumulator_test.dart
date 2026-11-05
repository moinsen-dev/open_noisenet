import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/event_level_accumulator.dart';

void main() {
  test('averages each buffer once in the energy domain', () {
    final levels = EventLevelAccumulator();
    levels.add(60);
    levels.add(70);
    final expected = 10 * log((pow(10, 6) + pow(10, 7)) / 2) / ln10;

    expect(levels.count, 2);
    expect(levels.averageDb, closeTo(expected, 1e-10));
    expect(levels.minDb, 60);
    expect(levels.maxDb, 70);
    expect(levels.recent, [60, 70]);
  });

  test('bounds classification history without losing event totals', () {
    final levels = EventLevelAccumulator(maxRecentSamples: 2);
    levels.add(30);
    levels.add(40);
    levels.add(50);

    expect(levels.count, 3);
    expect(levels.recent, [40, 50]);
    expect(levels.minDb, 30);
    expect(levels.maxDb, 50);
    expect(
        levels.averageDb,
        closeTo(10 * log((pow(10, 3) + pow(10, 4) + pow(10, 5)) / 3) / ln10,
            1e-10));
  });
}
