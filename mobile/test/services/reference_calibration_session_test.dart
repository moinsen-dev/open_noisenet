import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/reference_calibration_session.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';

PcmAudioFrame frame(List<double> values, int seconds, {int rate = 4}) =>
    PcmAudioFrame(
        samples: values,
        sampleRate: rate,
        capturedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: seconds)));

void main() {
  test('uses the entire comparison interval, not the last buffer', () {
    final session =
        ReferenceCalibrationSession(duration: const Duration(seconds: 2));
    session.addFrame(frame([0.1, -0.1, 0.1, -0.1], 0));
    session.addFrame(frame([0.2, -0.2, 0.2, -0.2], 1));
    final expectedRms = math.sqrt((0.01 + 0.04) / 2);
    final expected = 70 - 20 * math.log(32768 * expectedRms) / math.ln10;
    expect(session.isComplete, isTrue);
    expect(session.offsetForReference(70), closeTo(expected, 1e-10));
  });

  test('rejects interruptions, changed rate, silence and clipping', () {
    final interrupted =
        ReferenceCalibrationSession(duration: const Duration(seconds: 2));
    interrupted.addFrame(frame([0.1, 0.1, 0.1, 0.1], 0));
    interrupted.addFrame(frame([0.1, 0.1, 0.1, 0.1], 3));
    expect(interrupted.offsetForReference(70), isNull);
    expect(interrupted.error, isNotNull);
    final changed =
        ReferenceCalibrationSession(duration: const Duration(seconds: 2));
    changed.addFrame(frame([0.1, 0.1, 0.1, 0.1], 0));
    changed.addFrame(frame([0.1, 0.1, 0.1, 0.1], 1, rate: 8));
    expect(changed.error, isNotNull);
    for (final sample in [0.0, 1.0]) {
      final rejected =
          ReferenceCalibrationSession(duration: const Duration(seconds: 1));
      rejected.addFrame(frame(List.filled(4, sample), 0));
      expect(rejected.offsetForReference(70), isNull);
    }
  });

  test('rejects repeated missing buffers even when individual gaps are short',
      () {
    final session =
        ReferenceCalibrationSession(duration: const Duration(seconds: 4));
    for (var second = 0; second < 4; second++) {
      session.addFrame(frame([0.1, 0.1], second));
    }
    expect(session.error, isNull);
    session.addFrame(frame([0.1, 0.1], 4));
    session.addFrame(frame([0.1, 0.1], 5));
    expect(session.error, isNotNull);
    expect(session.offsetForReference(70), isNull);
  });
}
