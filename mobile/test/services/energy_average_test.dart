import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/energy_average.dart';

void main() {
  test('combines equal-duration levels in the energy domain', () {
    final expected = 10 * log((pow(10, 6) + pow(10, 7)) / 2) / ln10;
    expect(energyAverageDb([(60, 1), (70, 1)]), closeTo(expected, 1e-10));
    expect(energyAverageDb([(60, 1), (70, 1)]), isNot(closeTo(65, 0.1)));
  });

  test('weights partial hours by the number of observed minutes', () {
    final expected = 10 * log((pow(10, 6) * 3 + pow(10, 7)) / 4) / ln10;
    expect(energyAverageDb([(60, 3), (70, 1)]), closeTo(expected, 1e-10));
    expect(energyAverageDb([(double.nan, 1), (70, 0)]), isNull);
  });
  test('quarter-hour peak requires 15 consecutive minute records', () {
    final observations =
        List.generate(16, (i) => (i * 60, i == 15 ? 70.0 : 60.0));
    final expected = 10 * log((14 * pow(10, 6) + pow(10, 7)) / 15) / ln10;
    expect(highestQuarterHourEstimate(observations), closeTo(expected, 1e-10));
    expect(highestQuarterHourEstimate(observations.take(14)), isNull);
    expect(
        highestQuarterHourEstimate(observations.where((p) => p.$1 != 7 * 60)),
        isNull);
  });
}
