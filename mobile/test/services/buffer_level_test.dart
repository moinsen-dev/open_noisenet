import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/buffer_level.dart';

void main() {
  test('uses RMS energy instead of the largest sample', () {
    final steady = bufferLevelDb(const [0.5, -0.5, 0.5, -0.5])!;
    final transient = bufferLevelDb(const [0.5, 0, 0, 0])!;
    expect(steady - transient, closeTo(20 * log(2) / ln10, 1e-9));
    expect(bufferLevelDb(const [0.5, -0.5], offsetDb: 3),
        closeTo(steady + 3, 1e-9));
  });

  test('handles silence and rejects invalid buffers', () {
    expect(bufferLevelDb(const [0, 0]), 10);
    expect(bufferLevelDb(const []), isNull);
    expect(bufferLevelDb([0.2, double.nan]), isNull);
    expect(bufferLevelDb(const [0.2], offsetDb: double.infinity), isNull);
  });
}
