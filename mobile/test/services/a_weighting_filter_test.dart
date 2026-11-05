import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/a_weighting_filter.dart';

List<double> tone(int rate, double frequency, int count) => List.generate(
    count, (i) => 0.2 * math.sin(2 * math.pi * frequency * i / rate));

double rms(List<double> samples) =>
    math.sqrt(samples.fold<double>(0, (sum, sample) => sum + sample * sample) /
        samples.length);

double gainDb(int rate, double frequency) {
  final input = tone(rate, frequency, rate);
  final output = AWeightingFilter(rate).process(input);
  // Discard the startup transient before evaluating steady-state response.
  return 20 *
      math.log(rms(output.sublist(rate ~/ 2)) / rms(input.sublist(rate ~/ 2))) /
      math.ln10;
}

double referenceGainDb(double frequency) {
  double response(double f) {
    final squared = f * f;
    return math.pow(12194.217, 2) *
        math.pow(f, 4) /
        ((squared + math.pow(20.598997, 2)) *
            math.sqrt((squared + math.pow(107.65265, 2)) *
                (squared + math.pow(737.86223, 2))) *
            (squared + math.pow(12194.217, 2)));
  }

  return 20 * math.log(response(frequency) / response(1000)) / math.ln10;
}

void main() {
  test('matches the analytical response from 20 Hz to 20 kHz', () {
    for (final rate in [44100, 48000]) {
      for (final frequency in [
        20.0,
        31.5,
        63.0,
        100.0,
        250.0,
        500.0,
        1000.0,
        2000.0,
        4000.0,
        8000.0,
        10000.0,
        12500.0,
        16000.0,
        20000.0
      ]) {
        expect(
            gainDb(rate, frequency), closeTo(referenceGainDb(frequency), 0.4),
            reason: '$rate Hz sample rate, $frequency Hz tone');
      }
    }
  });

  test('preserves state across buffers and can be reset', () {
    final input = tone(48000, 100, 12000);
    final whole = AWeightingFilter(48000).process(input);
    final filter = AWeightingFilter(48000);
    final split = [
      ...filter.process(input.sublist(0, 1111)),
      ...filter.process(input.sublist(1111))
    ];
    for (var i = 0; i < whole.length; i++) {
      expect(split[i], closeTo(whole[i], 1e-12));
    }
    filter.reset();
    expect(filter.process(input), orderedEquals(whole));
  });

  test('rejects invalid input without contaminating filter state', () {
    expect(() => AWeightingFilter(16000), throwsArgumentError);
    final filter = AWeightingFilter(48000);
    expect(() => filter.process([double.nan]), throwsArgumentError);
    expect(filter.process([0, 0, 0]), [0, 0, 0]);
  });
}
