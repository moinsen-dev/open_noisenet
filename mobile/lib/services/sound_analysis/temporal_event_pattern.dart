class TemporalEventPatternResult {
  final String segmentType;
  final String reason;
  final int thresholdRuns;
  final double thresholdOccupancy;

  const TemporalEventPatternResult({
    required this.segmentType,
    required this.reason,
    required this.thresholdRuns,
    required this.thresholdOccupancy,
  });
}

/// Deterministic temporal event head. Source semantics come from YAMNet;
/// begin/end/continuity remain authoritative calculations over level samples.
class TemporalEventPattern {
  const TemporalEventPattern();

  TemporalEventPatternResult analyze({
    required List<double> samples,
    required double thresholdDb,
    required Duration duration,
    required double peakToAverageDeltaDb,
    required double variabilityDb,
  }) {
    if (samples.isEmpty) {
      return const TemporalEventPatternResult(
        segmentType: 'intermittent',
        reason: 'No temporal samples were available for continuity analysis.',
        thresholdRuns: 0,
        thresholdOccupancy: 0,
      );
    }

    final above = samples.map((sample) => sample >= thresholdDb).toList();
    var runs = 0;
    var previous = false;
    for (final isAbove in above) {
      if (isAbove && !previous) runs++;
      previous = isAbove;
    }
    final occupancy = above.where((value) => value).length / above.length;

    if (duration <= const Duration(seconds: 20) &&
        peakToAverageDeltaDb >= 10 &&
        runs <= 2) {
      return TemporalEventPatternResult(
        segmentType: 'impulse',
        reason: 'A short isolated peak dominated the event.',
        thresholdRuns: runs,
        thresholdOccupancy: occupancy,
      );
    }
    if (runs >= 3 && peakToAverageDeltaDb >= 7) {
      return TemporalEventPatternResult(
        segmentType: 'repeated_impulses',
        reason: 'Several distinct high-level bursts occurred in one event.',
        thresholdRuns: runs,
        thresholdOccupancy: occupancy,
      );
    }
    if (duration >= const Duration(minutes: 10) &&
        variabilityDb <= 6 &&
        occupancy >= 0.45) {
      return TemporalEventPatternResult(
        segmentType: 'background_elevation',
        reason: 'The background level remained elevated with little variation.',
        thresholdRuns: runs,
        thresholdOccupancy: occupancy,
      );
    }
    if (occupancy >= 0.70) {
      return TemporalEventPatternResult(
        segmentType: 'continuous',
        reason: 'The level stayed above threshold for most of the event.',
        thresholdRuns: runs,
        thresholdOccupancy: occupancy,
      );
    }
    return TemporalEventPatternResult(
      segmentType: 'intermittent',
      reason:
          'The source stopped or fell below threshold between active parts.',
      thresholdRuns: runs,
      thresholdOccupancy: occupancy,
    );
  }
}
