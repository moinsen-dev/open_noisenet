import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/sound_analysis/temporal_event_pattern.dart';

void main() {
  const analyzer = TemporalEventPattern();

  test('recognizes one short impulse', () {
    final result = analyzer.analyze(
      samples: const [45, 46, 78, 47],
      thresholdDb: 60,
      duration: const Duration(seconds: 8),
      peakToAverageDeltaDb: 18,
      variabilityDb: 33,
    );

    expect(result.segmentType, 'impulse');
  });

  test('recognizes repeated impulses before generic intermittency', () {
    final result = analyzer.analyze(
      samples: const [45, 72, 45, 74, 45, 71, 45],
      thresholdDb: 60,
      duration: const Duration(minutes: 2),
      peakToAverageDeltaDb: 12,
      variabilityDb: 29,
    );

    expect(result.segmentType, 'repeated_impulses');
    expect(result.thresholdRuns, 3);
  });

  test('recognizes continuous and background-elevation scenes', () {
    final continuous = analyzer.analyze(
      samples: List<double>.filled(20, 66),
      thresholdDb: 60,
      duration: const Duration(minutes: 3),
      peakToAverageDeltaDb: 2,
      variabilityDb: 4,
    );
    final background = analyzer.analyze(
      samples: List<double>.filled(20, 61),
      thresholdDb: 60,
      duration: const Duration(minutes: 15),
      peakToAverageDeltaDb: 1,
      variabilityDb: 2,
    );

    expect(continuous.segmentType, 'continuous');
    expect(background.segmentType, 'background_elevation');
  });
}
